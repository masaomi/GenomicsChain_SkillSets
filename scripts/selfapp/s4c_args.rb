#!/usr/bin/env ruby
# frozen_string_literal: true

# S4c of the self-application design: write the argument files for every
# launch, from the bytes of the frozen subjects, so no argument is retyped.
# Also creates the Tier-3 working directories: one fresh copy of the
# variant's synthetic_repo/ per run, with results/ removed (expected_v1.json
# rules.tier3.working_directory, OP-6). Refuses to overwrite anything.
#
#   ruby scripts/selfapp/s4c_args.rb [--out log/selfapp/s4c]
#
# Choices fixed here (run sheet log/selfapp/s4c/run_sheet.md):
#   Tier 1  rules.tier1_k run_inputs; llm claude_code / claude-opus-5-5 (operator
#           2026-10-03; effort xhigh and sandbox_mode come from llm_client.yml,
#           which gc_tier1_assess does not override); source ref is the neutral
#           "synthetic_manuscript.md" because ref is shown to the LLM
#           (prompts.rb:38) and a path would name the variant.
#   Tier 2  path = the frozen variant's synthetic_repo/, declarations and
#           fixtures included (expected_v1.json tiers.T2.entry_points).
#   Tier 3  local backend, the author's command from S2 run through bash -c so
#           "$PWD" is the run's own workdir (OP-11), exact_sha256 against the
#           variant's declared S1 (rules.tier3.declared_output).

require 'digest'
require 'fileutils'
require 'json'
require 'optparse'
require_relative 'ddc_common'

opts = { out: 'log/selfapp/s4c' }
OptionParser.new { |o| o.on('--out DIR') { |v| opts[:out] = v } }.parse!
abort 'run from the repository root' unless File.directory?('.git')

REPO = File.realpath('.')
FIXED = JSON.parse(File.read('selfapp/fixed_set_v1.json'))
SUBJECTS = FIXED.dig('subject', 'frozen_subjects')
ASSESSED_AT = '2026-10-03'
LLM = { 'provider' => 'claude_code', 'model' => 'claude-opus-5-5' }.freeze
AUTHOR_COMMAND = 'docker run --rm --platform linux/amd64 -v "$PWD":/work -w /work ' \
                 'synthetic-rnaseq:1.0 snakemake --cores 1' # log/selfapp/s3/calibration_record.json .command
IMAGE = { 'container_image' => 'synthetic-rnaseq:1.0',
          'container_image_id' => 'sha256:004c13e8611f445b5be24dcac9749edd0a38a0aa136a0642a88c9ee7ee236504' }.freeze
S1 = 'results/synthetic_supplementary_table_S1.tsv'
T3_RUNS = { 'V0' => 2, 'V4' => 1, 'V5' => 2, 'V7' => 2 }.freeze # rules.tier3.runs

args_dir = File.join(opts[:out], 'args')
work_root = File.join(REPO, opts[:out], 'tier3_work')
abort "#{args_dir} exists" if File.exist?(args_dir)
abort "#{work_root} exists" if File.exist?(work_root)

# The subjects must still be the fixed ones before anything is derived from them.
SUBJECTS.each do |v, s|
  actual = DdcCommon.tree_sha256(DdcCommon.tree_files(s['path']))
  abort "#{v} differs from the fixed set: #{actual}" unless actual == s['tree_sha256']
end

files = {}
put = lambda do |name, obj|
  path = File.join(args_dir, name)
  bytes = "#{JSON.pretty_generate(obj)}\n"
  File.write(path, bytes)
  files[name] = Digest::SHA256.hexdigest(bytes)
end
FileUtils.mkdir_p(args_dir)

%w[V0 V1].each do |v|
  text = File.binread(File.join(SUBJECTS.fetch(v)['path'], 'synthetic_manuscript.md')).force_encoding('UTF-8')
  abort "#{v} manuscript is not valid UTF-8" unless text.valid_encoding?
  live = {
    'canonical_id' => { 'kind' => 'text_sha256', 'value' => Digest::SHA256.hexdigest(text) },
    'sources' => [{ 'kind' => 'paper_text', 'ref' => 'synthetic_manuscript.md', 'content' => text }],
    'funnel_stage' => 'stage1-prose-only',
    'assessor_id' => 'genomicschain_tier1 0.2.3',
    'operator_id' => 'masaomi',
    'assessed_at' => ASSESSED_AT,
    'llm' => LLM,
    'record_llm_exchange' => true
  }
  put.call("t1_#{v}.json", live)
  put.call("t1_#{v}_dry.json", live.merge('dry_run' => true))
end

SUBJECTS.each_key.sort.each do |v|
  put.call("t2_#{v}.json", { 'path' => File.join(REPO, SUBJECTS[v]['path'], 'synthetic_repo'),
                             'include_declarations' => true, 'include_fixtures' => true })
end

T3_RUNS.each do |v, n|
  repo = File.join(SUBJECTS.fetch(v)['path'], 'synthetic_repo')
  declared = Digest::SHA256.file(File.join(repo, S1)).hexdigest
  workdirs = (1..n).map do |i|
    dir = File.join(work_root, "#{v}_run#{i}")
    FileUtils.mkdir_p(File.dirname(dir))
    FileUtils.cp_r(repo, dir)
    FileUtils.rm_rf(File.join(dir, 'results'))
    dir
  end
  args = {
    'subject_ref' => "selfapp://synthetic_rnaseq_v1/#{v}",
    'backend' => 'local',
    'pipeline' => { 'command' => ['bash', '-c', AUTHOR_COMMAND], 'workdir' => workdirs.first, 'step_source' => 'snakefile' },
    'env' => IMAGE,
    'expected_output' => { 'target' => "file:#{S1}", 'sha256' => declared, 'source' => 'paper_declared',
                           'source_citation' => 'supplementary table S1' },
    'comparator_id' => 'exact_sha256',
    'inputs_provenance' => 'operator_supplied',
    'environment_provenance' => 'declared_container',
    'runs' => n
  }
  args.merge!('run_workdirs' => workdirs, 'variation' => 'same_environment') if n > 1
  args['workdir'] = workdirs.first if n == 1
  put.call("t3_#{v}.json", args)
end

put.call('llm_precheck.json', {
           'messages' => [{ 'role' => 'user', 'content' => 'Reply with the single word OK.' }],
           'model' => LLM['model'], 'provider_override' => LLM['provider']
         })

File.write(File.join(opts[:out], 'args_manifest.json'),
           "#{JSON.pretty_generate('written_by' => 'scripts/selfapp/s4c_args.rb',
                                   'script_sha256' => Digest::SHA256.file(__FILE__).hexdigest,
                                   'files' => files.sort.to_h,
                                   'tier3_workdirs' => Dir.children(work_root).sort.to_h do |d|
                                     [d, DdcCommon.tree_sha256(DdcCommon.tree_files(File.join(work_root, d)))]
                                   end)}\n")
puts files.map { |n, h| "#{h[0, 12]}  #{n}" }
