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
# Round 2 (design §14): add --round 2 to every step; records go under
# log/selfapp/r2/s6/, and `audit --n N --round 2` runs after `codex`, before
# `commit`.
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
BUILDER = 'selfapp-t-builder:0'
INPUTS = File.join(REPO, 'log/selfapp/ddc_inputs_v1')
AUTH = File.expand_path('~/.codex/auth.json')

# Round 1 (C) as it ran; round 2 (C', design §14) added after round 2's
# fixing. Round 2 gives Codex the parts-only archive (the five packages,
# Gemfile, Gemfile.lock, .ruby-version), keeps its own runs log so A'/T'
# pairing never mixes with round 1, and adds the audit step.
ROUNDS = {
  1 => { s6: 'log/selfapp/s6', runs_log: 'log/selfapp/ddc_runs.jsonl', image: 'selfapp-t', container: 'selfapp_t_build',
         source_sha256: '2875eec01fd16598aa2f8e0c673860f9ec8194a1e97fa0cf8f6af370a42ab302',
         source_tree: 'log/selfapp/ddc_inputs_v1/genomicschain_c', source_note: 'the unpacked archive of C' },
  2 => { s6: 'log/selfapp/r2/s6', runs_log: 'log/selfapp/r2/ddc_runs.jsonl', image: 'selfapp-t-r2',
         container: 'selfapp_t_r2_build',
         source_sha256: '9055a080ee50a6b65a525c459889961b9af183943d5a24bd40001684e9779f74',
         source_tree: 'log/selfapp/r2/c_prime_parts', source_note: "the unpacked parts-only archive of C'" }
}.freeze

step = ARGV.shift
opts = { round: 1 }
OptionParser.new do |o|
  o.on('--round N', Integer) { |v| opts[:round] = v }
  o.on('--n N', Integer) { |v| opts[:n] = v }
  o.on('--a DIR') { |v| opts[:a] = v }
  o.on('--attempt K', Integer) { |v| opts[:attempt] = v }
end.parse!
STEPS = %w[codex audit commit harness compare].freeze
abort 'usage: s6_t.rb codex|audit|commit|harness|compare --n N [--round 1|2] [--a DIR]' unless STEPS.include?(step) && opts[:n]
ROUND = ROUNDS.fetch(opts[:round]) { abort "unknown round #{opts[:round]}" }
abort 'audit is a round-2 step (design §14)' if step == 'audit' && opts[:round] < 2
S6 = File.join(REPO, ROUND[:s6])
GIVEN = File.join(S6, 'given')
RUNS_LOG = File.join(REPO, ROUND[:runs_log])
SOURCE_SHA256 = ROUND[:source_sha256]

n = opts[:n]
container = "#{ROUND[:container]}_#{n}"
image = "#{ROUND[:image]}:#{n}"
# A retried step writes beside the stopped one, which is kept as it was.
out = File.join(S6, opts[:attempt] ? "#{step}_#{n}_attempt#{opts[:attempt]}" : "#{step}_#{n}")
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

when 'audit'
  # Design §14: read every command Codex recorded and list those that touch
  # the network. Allowed: a version-pinned `gem install` (rubygems.org).
  # Codex's own model-API traffic is not a recorded command. Anything else
  # voids this build's pair. This is after the fact, not a block.
  events = File.join(S6, "codex_#{n}", 'events.jsonl')
  abort "#{events} missing" unless File.file?(events)
  commands = []
  File.foreach(events) do |line|
    ev = JSON.parse(line) rescue next
    JSON.generate(ev).scan(/"command":"((?:[^"\\]|\\.)*)"/) { |m| commands << JSON.parse(%("#{m[0]}")) }
  end
  commands.uniq!
  network = /\b(curl|wget|git\s+(clone|fetch|pull|ls-remote|remote)|gem\s+(install|fetch|sources|update)|bundle|pip3?|apt(-get)?|npm|ssh|scp|rsync|nc|telnet|ruby\s+-e.*(Net::HTTP|open-uri|URI\.open))\b|https?:\/\//
  allowed = /\Agem\s+install\s+[A-Za-z0-9_.\-]+\s+-v\s+[0-9][0-9A-Za-z.\-]*(\s+--no-document)?(\s+--ignore-dependencies)?\z/
  inner = lambda do |c|
    c.sub(%r{\A/bin/(ba)?sh\s+-l?c\s+'(.*)'\z}m, '\2').sub(%r{\Apython3\s+/build/record_command\.py\s+}, '').strip
  end
  touching = commands.select { |c| c.match?(network) }
  flagged = touching.reject { |c| inner.call(c).match?(allowed) }
  audit = { 'events' => events.delete_prefix("#{REPO}/"), 'events_sha256' => Digest::SHA256.file(events).hexdigest,
            'commands' => commands.size, 'network_touching' => touching.size,
            'allowed_gem_installs' => touching.size - flagged.size, 'flagged' => flagged,
            'blinding_held' => flagged.empty?,
            'rule' => 'design §14: only `gem install <name> -v <version>` may touch the network; the check reads ' \
                      'recorded commands only and cannot see what the model already knew' }
  write_json(File.join(out, 'audit.json'), audit)
  meta['audit'] = audit.except('flagged').merge('flagged_count' => flagged.size)

when 'commit'
  must('docker', 'container', 'inspect', container)
  File.write(File.join(out, 'docker_diff.txt'), must('docker', 'diff', container))
  _, _, code = sh('docker', 'cp', "#{container}:/build/BUILD_RECORD.md", File.join(out, 'BUILD_RECORD.md'))
  meta['build_record_copied'] = code.zero?
  if sh('docker', 'image', 'inspect', image)[2].zero?
    # Committed from this container by an earlier run of this step that stopped
    # at the credential search (2026-10-03: the old pattern "*.codex*" matched
    # the empty tmpfs mount point /root/.codex itself).
    meta['image_id'] = must('docker', 'image', 'inspect', image, '--format', '{{.Id}}').strip
    meta['image_committed_by_earlier_run'] = true
  else
    meta['image_id'] = must('docker', 'commit', container, image).strip
  end
  # Nothing of the credentials may survive into the image: no file named
  # auth.json, nothing inside any .codex directory (the tmpfs mount point
  # itself stays as an empty directory), no token-shaped string where Codex worked.
  leak = must('docker', 'run', '--rm', '--network', 'none', image, 'bash', '-c',
              'find / -xdev \( -name auth.json -o -path "*/.codex/*" \) -print 2>/dev/null; ' \
              'grep -rIl -E "refresh_token|\"access_token\"|id_token" /build /root /tmp 2>/dev/null; true')
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
            'source_tree' => "#{ROUND[:source_tree]} (#{ROUND[:source_note]})",
            'out' => report.delete_prefix("#{REPO}/") }
  log_run(entry)
  meta['ddc_runs_entry'] = entry
  o, e, code = sh(RbConfig.ruby, File.join(__dir__, 'ddc_compare.rb'), '--a', a, '--t', t,
                  '--source-tree', File.join(REPO, ROUND[:source_tree]), '--out', report)
  File.write(File.join(out, 'stdout.txt'), o)
  meta['exit'] = code
  meta['stderr'] = e[0, 4000]
end

meta['finished_at'] = now
write_json(File.join(out, 'meta.json'), meta)
puts JSON.pretty_generate(meta.except('gem_list_in_image', 'docker_run'))
