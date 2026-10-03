#!/usr/bin/env ruby
# frozen_string_literal: true

# S6 of the self-application design (docs/design/self_application_design_v0_1.md
# §6.3, §6.5 steps 3–4): build T with Codex in a disposable container, keep
# the built container as an image, run the DDC harness inside that image with
# our script, and compare A with T. One subcommand per step, each recorded
# under log/selfapp/s6/<step>_<n>/.
#
#   ruby scripts/selfapp/s6_t.rb codex   --n 1   # Codex builds T (sends the source to Codex's provider)
#   ruby scripts/selfapp/s6_t.rb commit  --n 1   # docker commit → selfapp-t:<n>, checks, removes the container
#   ruby scripts/selfapp/s6_t.rb harness --n 1   # ddc_runs.jsonl entry, then ddc_harness.rb in selfapp-t:<n>
#   ruby scripts/selfapp/s6_t.rb compare --n 1 --a log/selfapp/s5/harness_A_1
#
# INV-S8: the Codex container gets only /given (source.tar = `git archive C`,
# BUILD.md, PROMPT.txt). The frozen inputs, A's results and the expectation
# table never enter it. auth.json is mounted read-only and copied into a
# tmpfs at /root/.codex, which `docker commit` does not keep; the committed
# image is searched for auth.json before anything else runs in it.
# INV-S5: nothing Codex reports is used as a value; T's hashes are computed
# here from the files T's harness run wrote.

require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'optparse'
require 'time'
require_relative 'ddc_common'

REPO = File.realpath(File.join(__dir__, '..', '..'))
S6 = File.join(REPO, 'log/selfapp/s6')
GIVEN = File.join(S6, 'given')
BUILDER = 'selfapp-t-builder:0'
INPUTS = File.join(REPO, 'log/selfapp/ddc_inputs_v1')
RUNS_LOG = File.join(REPO, 'log/selfapp/ddc_runs.jsonl')
SOURCE_SHA256 = '2875eec01fd16598aa2f8e0c673860f9ec8194a1e97fa0cf8f6af370a42ab302'
AUTH = File.expand_path('~/.codex/auth.json')

step = ARGV.shift
opts = {}
OptionParser.new do |o|
  o.on('--n N', Integer) { |v| opts[:n] = v }
  o.on('--a DIR') { |v| opts[:a] = v }
end.parse!
abort 'usage: s6_t.rb codex|commit|harness|compare --n N [--a DIR]' unless %w[codex commit harness compare].include?(step) && opts[:n]

n = opts[:n]
container = "selfapp_t_build_#{n}"
image = "selfapp-t:#{n}"
out = File.join(S6, "#{step}_#{n}")
abort "#{out} exists" if File.exist?(out)

def sh(*cmd)
  o, e, st = Open3.capture3(*cmd)
  [o, e, st.exitstatus]
end

def must(*cmd)
  o, e, code = sh(*cmd)
  abort "#{cmd.first(3).join(' ')} failed (#{code}): #{e[0, 400]}" unless code.zero?
  o
end

def write_json(path, obj) = File.write(path, "#{JSON.pretty_generate(obj)}\n")
def now = Time.now.utc.iso8601(3)

def log_run(entry)
  File.open(RUNS_LOG, 'a') { |f| f.flock(File::LOCK_EX); f.write("#{JSON.generate(entry)}\n") }
end

FileUtils.mkdir_p(out)
meta = { 'step' => step, 'n' => n, 'started_at' => now, 'script_sha256' => Digest::SHA256.file(__FILE__).hexdigest }

case step
when 'codex'
  abort 'source.tar differs from the archive of C' unless Digest::SHA256.file(File.join(GIVEN, 'source.tar')).hexdigest == SOURCE_SHA256
  abort "container #{container} exists" if sh('docker', 'container', 'inspect', container)[2].zero?
  given = Dir.children(GIVEN).sort
  abort "unexpected files in #{GIVEN}: #{given}" unless given == %w[BUILD.md PROMPT.txt source.tar]
  meta['given'] = given.to_h { |f| [f, Digest::SHA256.file(File.join(GIVEN, f)).hexdigest] }
  meta['builder_image_id'] = must('docker', 'image', 'inspect', BUILDER, '--format', '{{.Id}}').strip
  inner = 'install -m 600 /run/codex_auth.json /root/.codex/auth.json && ' \
          'codex exec --skip-git-repo-check --json -m gpt-6-astra -c model_reasoning_effort=high ' \
          '--dangerously-bypass-approvals-and-sandbox -C /build -o /codex_out/last_message.txt - ' \
          '< /given/PROMPT.txt > /codex_out/events.jsonl 2> /codex_out/stderr.txt; echo $? > /codex_out/exit_code'
  args = ['docker', 'run', '--name', container, '--tmpfs', '/root/.codex:rw,mode=700',
          '-v', "#{AUTH}:/run/codex_auth.json:ro", '-v', "#{GIVEN}:/given:ro", '-v', "#{out}:/codex_out",
          BUILDER, 'bash', '-c', inner]
  meta['docker_run'] = args.map { |a| a.sub(AUTH, '~/.codex/auth.json') }
  write_json(File.join(out, 'meta.json'), meta)
  _, e, code = sh(*args)
  meta['docker_exit'] = code
  meta['docker_stderr'] = e[0, 2000]
  meta['codex_exit'] = File.read(File.join(out, 'exit_code')).strip if File.exist?(File.join(out, 'exit_code'))
  meta['events_sha256'] = Digest::SHA256.file(File.join(out, 'events.jsonl')).hexdigest if File.exist?(File.join(out, 'events.jsonl'))

when 'commit'
  must('docker', 'container', 'inspect', container)
  File.write(File.join(out, 'docker_diff.txt'), must('docker', 'diff', container))
  _, _, code = sh('docker', 'cp', "#{container}:/build/BUILD_RECORD.md", File.join(out, 'BUILD_RECORD.md'))
  meta['build_record_copied'] = code.zero?
  abort "image #{image} exists" if sh('docker', 'image', 'inspect', image)[2].zero?
  meta['image_id'] = must('docker', 'commit', container, image).strip
  # Nothing of the credentials may survive into the image.
  leak = must('docker', 'run', '--rm', '--network', 'none', image, 'bash', '-c',
              'ls -A /root/.codex 2>/dev/null; find / -xdev \( -name auth.json -o -name "*.codex*" \) -print 2>/dev/null; true')
  meta['credential_search'] = leak.lines.map(&:strip)
  abort "credentials may be in #{image}: #{leak}" unless leak.strip.empty?
  # Our own computation of the checker packages T holds (INV-S9's first half).
  meta['source_packages_tree_sha256_in_image'] = must(
    'docker', 'run', '--rm', '--network', 'none', '-v', "#{__dir__}:/selfapp_scripts:ro", image,
    'ruby', '-r/selfapp_scripts/ddc_common', '-e', 'puts DdcCommon.tree_sha256(DdcCommon.package_files("/build/source"))'
  ).strip
  meta['gem_list_in_image'] = must('docker', 'run', '--rm', '--network', 'none', image, 'gem', 'list').lines.map(&:strip)
  must('docker', 'rm', container)

when 'harness'
  image_id = must('docker', 'image', 'inspect', image, '--format', '{{.Id}}').strip
  manifest_sha = Digest::SHA256.file(File.join(INPUTS, 'inputs_manifest.json')).hexdigest
  dest = File.join(out, "harness_T_#{n}")
  entry = { 'utc' => now, 'kind' => 'harness_T', 'checker_root' => "/build/source in image #{image_id}",
            'inputs_manifest_sha256' => manifest_sha, 'out' => dest.delete_prefix("#{REPO}/"),
            'resolution' => 'plain ruby, no bundler, gems as installed in the image' }
  log_run(entry)
  meta['ddc_runs_entry'] = entry
  _, e, code = sh('docker', 'run', '--rm', '--network', 'none',
                  '-v', "#{INPUTS}:#{INPUTS}:ro", '-v', "#{__dir__}:/selfapp_scripts:ro", '-v', "#{out}:/out",
                  image, 'ruby', '/selfapp_scripts/ddc_harness.rb', '--checker-root', '/build/source',
                  '--inputs', INPUTS, '--out', "/out/harness_T_#{n}")
  meta['exit'] = code
  meta['stderr'] = e[0, 4000]

when 'compare'
  a = File.realpath(opts[:a] || abort('compare needs --a'))
  t = File.join(S6, "harness_#{n}", "harness_T_#{n}")
  report = File.join(out, 'report.json')
  entry = { 'utc' => now, 'kind' => 'compare', 'reads' => [a.delete_prefix("#{REPO}/"), t.delete_prefix("#{REPO}/")],
            'source_tree' => 'log/selfapp/ddc_inputs_v1/genomicschain_c (the unpacked archive of C)',
            'out' => report.delete_prefix("#{REPO}/") }
  log_run(entry)
  meta['ddc_runs_entry'] = entry
  o, e, code = sh(RbConfig.ruby, File.join(__dir__, 'ddc_compare.rb'), '--a', a, '--t', t,
                  '--source-tree', File.join(INPUTS, 'genomicschain_c'), '--out', report)
  File.write(File.join(out, 'stdout.txt'), o)
  meta['exit'] = code
  meta['stderr'] = e[0, 4000]
end

meta['finished_at'] = now
write_json(File.join(out, 'meta.json'), meta)
puts JSON.pretty_generate(meta.except('gem_list_in_image', 'docker_run'))
