#!/usr/bin/env ruby
# frozen_string_literal: true

# S8: the Tier-4 distillation record's input for stage 1, assembled from the
# S8 records alone (not submitted; submission is S9). Builds and validates it
# with genomicschain_core's Tier4Builder / schema using a throw-away anonymous
# operator that is not written out. Stage 1 has no other-data check in v0.1.
#
#   ruby scripts/selfapp/s8_tier4_input.rb   # writes log/selfapp/s8/tier4_distillation_input.json

require 'digest'
require 'json'
REPO = File.realpath(File.join(__dir__, '..', '..'))
$LOAD_PATH.unshift(File.join(REPO, 'genomicschain_core/lib'))
require 'kairos_mcp/version'
require 'genomicschain_core/manifest'

S8 = File.join(REPO, 'log/selfapp/s8')
OUT = File.join(S8, 'tier4_distillation_input.json')
abort "#{OUT} exists" if File.exist?(OUT)

read = ->(p) { JSON.parse(File.read(File.join(REPO, p))) }
vr = ->(p) { read.call(p)['verdict_result'] }
digest = read.call('log/selfapp/s8/package_digest.json')
declaration = read.call('log/selfapp/s8/declaration.json')
src = vr.call('log/selfapp/s8/launches/001_declared_computation/result.txt')
rev = vr.call('log/selfapp/s8/launches/002_skill_reversion/result.txt')
abort 'the reversion check was not judged against the declared table' unless rev['expected_output_sha256'] == declaration['table_sha256']

input = {
  'subject_ref' => 'skill://selfapp/tier4/stage1/deterministic_tiers_verdict_table',
  'stage' => 'stage1',
  'package_digest' => digest['package_digest'],
  'package_files' => digest['files'].map { |path, sha| { 'relative_path' => path, 'sha256' => sha } },
  'package_digest_recorded_at' => digest['recorded_at'],
  'distiller' => { 'model' => 'claude-opus-5-5', 'context' => 'Claude Code subagent (general-purpose), separate from the declaring and judging context, 2026-10-03' },
  'acceptance' => { 'version' => 'tier4-acceptance-v1',
                    'sha256' => Digest::SHA256.file(File.join(REPO, 'selfapp/tier4_acceptance_v1.json')).hexdigest },
  'source' => { 'jobspec_digest' => src['jobspec_digest'], 'result_hash' => src['result_hash'], 'tier3_record_ref' => nil },
  'reversion' => { 'jobspec_digest' => rev['jobspec_digest'], 'result_hash' => rev['result_hash'],
                   'execution_verdict' => rev['execution_verdict'], 'comparison_verdict' => rev['comparison_verdict'],
                   'tier3_record_ref' => nil, 'expected_output_sha256' => rev['expected_output_sha256'],
                   'expected_output_source' => rev['expected_output_source'] },
  'other_data' => { 'performed' => false, 'reason' => 'not performed in v0.1 (design D11, O-11; tier4_acceptance_v1.json stage_1.other_data_check)' }
}
record = KairosMcp::Manifest.build_tier4_distillation(input.merge('operator' => { 'mode' => 'anonymous', 'anonymous_id' => 'anonymous-0000000000000000' }))
KairosMcp::Manifest.validate_tier4!(record)
File.write(OUT, "#{JSON.pretty_generate(input)}\n")
puts JSON.pretty_generate(record.slice('stage', 'package_digest', 'reversion_passed', 'other_data_passed', 'leaderboard_eligible').merge('validates' => true))
