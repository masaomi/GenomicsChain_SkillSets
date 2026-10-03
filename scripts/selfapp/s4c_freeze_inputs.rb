#!/usr/bin/env ruby
# frozen_string_literal: true

# S4c, last step (design §6.5 step 1, §10 S4c): freeze the DDC inputs into one
# directory with inputs_manifest.json in the format ddc_harness.rb reads.
#
#   ruby scripts/selfapp/s4c_freeze_inputs.rb [--out log/selfapp/ddc_inputs_v1]
#
# Contents, each checked against its source of truth before it is copied:
#   subjects/<V>/        the frozen subjects V0–V8 (tree hash = fixed set)
#   genomicschain_c/     `git archive C` unpacked (archive sha256 = fixed set);
#                        scanned by Tier 2 as the extra input of design §6.1
#   tier1/<V>/           args.json + exchange.json of the run OP-5 names: the
#                        first counted live run of the variant that returned
#                        "assessed" (expected_v1.json rules.tier1_replay)
#   bco/                 the two S2 BCOs (sha256 = tiers.T2_5.inputs)
#   tier3/<V>/run<i>/    the S4c Tier-3 working directories after their run
#
# Tier-1 args.json is the run's argument file without record_llm_exchange:
# gc_tier1_assess deletes that key before Assessor#run sees the arguments
# (gc_tier1_assess.rb:116-118), and the replay calls Assessor#run.
# No verdict record goes in (INV-S8): no report, scan output, grade or
# Tier-3 verdict from S4c, only what the checker reads.
#
# The bundle's absolute path is part of what both sides must reproduce
# (design §6.4, Tier 3), so it is printed and recorded.

require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'optparse'
require 'time'
require 'tmpdir'
require_relative 'ddc_common'

opts = { out: 'log/selfapp/ddc_inputs_v1', launch_log: 'log/selfapp/s4c/launches.jsonl' }
OptionParser.new { |o| o.on('--out DIR') { |v| opts[:out] = v } }.parse!
abort 'run from the repository root' unless File.directory?('.git')
abort "#{opts[:out]} exists" if File.exist?(opts[:out])

FIXED = JSON.parse(File.read('selfapp/fixed_set_v1.json'))
EXPECTED = JSON.parse(File.read('selfapp/expected_v1.json'))
SUBJECTS = FIXED.dig('subject', 'frozen_subjects')
C = FIXED.dig('commit_c', 'commit')
C_ARCHIVE_SHA256 = FIXED.dig('commit_c', 'git_archive_sha256')
K = EXPECTED.dig('rules', 'tier1_k', 'k')
T3_RUNS = { 'V0' => 2, 'V4' => 1, 'V5' => 2, 'V7' => 2 }.freeze
S1 = 'results/synthetic_supplementary_table_S1.tsv'
BOUNDARY = Time.utc(2026, 10, 1, 10, 28, 11) # latest of the four attested block times (b8bb63c)

tree = ->(dir) { DdcCommon.tree_sha256(DdcCommon.tree_files(dir)) }
copy_dir = lambda do |src, dst|
  FileUtils.mkdir_p(File.dirname(dst))
  FileUtils.cp_r(src, dst, preserve: true)
  abort "copy of #{src} differs" unless tree.call(src) == tree.call(dst)
end

# Which Tier-1 runs count, from the launch log alone (rules.tier1_k).
log = File.readlines(opts[:launch_log]).map { |l| JSON.parse(l) }
ends = log.select { |e| e['event'] == 'end' }.to_h { |e| [e['seq'], e] }
tier1_pick = %w[V0 V1].to_h do |v|
  live = log.select do |e|
    next false unless e['event'] == 'start' && e['kind'] == 'gc_tier1_assess' && Time.parse(e['utc']) > BOUNDARY

    args = JSON.parse(File.read(File.join(e['out'], 'args.json')))
    args['dry_run'] != true && args.dig('sources', 0, 'content') ==
      File.read(File.join(SUBJECTS.fetch(v)['path'], 'synthetic_manuscript.md'))
  end
  counted = live.first(K)
  abort "#{v}: #{counted.size} counted runs, k = #{K}" unless counted.size == K
  pick = counted.find do |e|
    ends.dig(e['seq'], 'status') == 'ok' &&
      JSON.parse(File.read(File.join(e['out'], 'result.txt')))['status'] == 'assessed'
  end
  [v, { 'counted_seq' => counted.map { |e| e['seq'] }, 'replayed_seq' => pick && pick['seq'], 'start' => pick }]
end

out = File.join(File.realpath('.'), opts[:out])
FileUtils.mkdir_p(out)
manifest = { 'tier1' => [], 'tier2_scan' => [], 'tier25' => [], 'tier3' => [] }

SUBJECTS.each_key.sort.each do |v|
  src = SUBJECTS[v]['path']
  abort "#{v} differs from the fixed set" unless tree.call(src) == SUBJECTS[v]['tree_sha256']
  copy_dir.call(src, File.join(out, 'subjects', v))
  manifest['tier2_scan'] << { 'variant' => v, 'repo' => "subjects/#{v}/synthetic_repo" }
end

archive, err, st = Open3.capture3('git', 'archive', C, binmode: true)
abort "git archive failed: #{err}" unless st.success?
abort 'archive of C differs from the fixed set' unless Digest::SHA256.hexdigest(archive) == C_ARCHIVE_SHA256
FileUtils.mkdir_p(File.join(out, 'genomicschain_c'))
_, err, st = Open3.capture3('tar', '-x', '-C', File.join(out, 'genomicschain_c'), stdin_data: archive, binmode: true)
abort "tar failed: #{err}" unless st.success?
manifest['tier2_scan'] << { 'variant' => 'genomicschain_C', 'repo' => 'genomicschain_c' }

tier1_pick.each do |v, pick|
  if pick['start'].nil?
    warn "#{v}: no counted run returned assessed; no Tier-1 item (OP-5)"
    next
  end
  run = pick['start']['out']
  args = JSON.parse(File.read(File.join(run, 'args.json')))
  args.delete('record_llm_exchange')
  exchange = JSON.parse(File.read(File.join(run, 'result.txt'))).fetch('llm_exchange')
  dir = File.join(out, 'tier1', v)
  FileUtils.mkdir_p(dir)
  File.write(File.join(dir, 'args.json'), "#{JSON.pretty_generate(args)}\n")
  File.write(File.join(dir, 'exchange.json'), "#{JSON.pretty_generate(exchange)}\n")
  manifest['tier1'] << { 'variant' => v, 'args' => "tier1/#{v}/args.json", 'exchange' => "tier1/#{v}/exchange.json" }
end
manifest['tier2_adjudication'] = { 'variant' => 'V0', 'tier1' => 'V0', 'scan' => 'V0' } if manifest['tier1'].any? { |t| t['variant'] == 'V0' }

EXPECTED.dig('tiers', 'T2_5', 'inputs').each do |v, inp|
  abort "BCO #{v} differs" unless Digest::SHA256.file(inp['path']).hexdigest == inp['sha256']
  FileUtils.mkdir_p(File.join(out, 'bco'))
  FileUtils.cp(inp['path'], File.join(out, 'bco', "#{v.downcase}.json"))
  manifest['tier25'] << { 'variant' => v, 'bco' => "bco/#{v.downcase}.json" }
end

T3_RUNS.each do |v, n|
  dirs = (1..n).map do |i|
    src = File.join('log/selfapp/s4c/tier3_work', "#{v}_run#{i}")
    abort "#{src} has no #{S1}" unless File.file?(File.join(src, S1))
    copy_dir.call(src, File.join(out, 'tier3', v, "run#{i}"))
    "tier3/#{v}/run#{i}"
  end
  declared = Digest::SHA256.file(File.join(SUBJECTS.fetch(v)['path'], 'synthetic_repo', S1)).hexdigest
  manifest['tier3'] << { 'variant' => v, 'workdirs' => dirs,
                         'expected_output' => { 'target' => "file:#{S1}", 'sha256' => declared,
                                                'source' => 'paper_declared', 'source_citation' => 'supplementary table S1' } }
end

manifest['files'] = DdcCommon.tree_files(out)
File.write(File.join(out, 'inputs_manifest.json'), JSON.generate(manifest))

record = {
  'record' => 'self_application S4c — DDC inputs frozen',
  'bundle' => out, 'written_at' => Time.now.utc.iso8601,
  'inputs_manifest_sha256' => Digest::SHA256.file(File.join(out, 'inputs_manifest.json')).hexdigest,
  'file_count' => manifest['files'].size, 'tree_sha256_without_manifest' => DdcCommon.tree_sha256(manifest['files']),
  'tier1' => tier1_pick.transform_values { |p| p.except('start') },
  'commit_c' => C, 'script_sha256' => Digest::SHA256.file(__FILE__).hexdigest
}
File.write('log/selfapp/s4c/freeze_record.json', "#{JSON.pretty_generate(record)}\n")
puts JSON.pretty_generate(record)
