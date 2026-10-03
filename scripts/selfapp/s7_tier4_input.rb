#!/usr/bin/env ruby
# frozen_string_literal: true

# S7: the Tier-4 distillation record's input for stage 0, assembled from the
# S7 and S4c records alone (not submitted; submission is S9). Checks that it
# builds and validates with genomicschain_core's Tier4Builder / schema, using a
# throw-away anonymous operator that is not written out.
#
#   ruby scripts/selfapp/s7_tier4_input.rb   # writes log/selfapp/s7/tier4_distillation_input.json

require 'digest'
require 'json'
REPO = File.realpath(File.join(__dir__, '..', '..'))
$LOAD_PATH.unshift(File.join(REPO, 'genomicschain_core/lib'))
require 'kairos_mcp/version'
require 'genomicschain_core/manifest'

S7 = File.join(REPO, 'log/selfapp/s7')
OUT = File.join(S7, 'tier4_distillation_input.json')
abort "#{OUT} exists" if File.exist?(OUT)

read = ->(p) { JSON.parse(File.read(File.join(REPO, p))) }
vr = ->(p) { read.call(p)['verdict_result'] }
digest = read.call('log/selfapp/s7/package_digest.json')
seed = File.readlines(File.join(S7, 'seed_draws.jsonl')).map { |l| JSON.parse(l) }.first
ref = read.call('log/selfapp/s7/reference.json')
src = vr.call('log/selfapp/s4c/launches/021_V0_t3_exec/result.txt')
rev = vr.call('log/selfapp/s7/launches/001_tier4_V0_t3/result.txt')
oth = vr.call('log/selfapp/s7/launches/002_tier4_subject2_t3/result.txt')
t3 = ->(v) { { 'jobspec_digest' => v['jobspec_digest'], 'result_hash' => v['result_hash'],
               'execution_verdict' => v['execution_verdict'], 'comparison_verdict' => v['comparison_verdict'],
               'tier3_record_ref' => nil } }

input = {
  'subject_ref' => 'skill://selfapp/tier4/stage0/rnaseq_two_group_de',
  'stage' => 'stage0',
  'package_digest' => digest['package_digest'],
  'package_files' => digest['files'].map { |path, sha| { 'relative_path' => path, 'sha256' => sha } },
  'package_digest_recorded_at' => digest['recorded_at'],
  'distiller' => { 'model' => 'claude-opus-5-5', 'context' => 'Claude Code subagent (general-purpose), separate from the reference and judge context, 2026-10-03' },
  'acceptance' => { 'version' => 'tier4-acceptance-v1',
                    'sha256' => Digest::SHA256.file(File.join(REPO, 'selfapp/tier4_acceptance_v1.json')).hexdigest },
  'source' => { 'jobspec_digest' => src['jobspec_digest'], 'result_hash' => src['result_hash'], 'tier3_record_ref' => nil },
  'reversion' => t3.call(rev).merge('expected_output_sha256' => rev['expected_output_sha256'],
                                    'expected_output_source' => rev['expected_output_source']),
  'other_data' => t3.call(oth).merge('performed' => true, 'seed' => seed['seed'], 'seed_drawn_at' => seed['utc'],
                                     'reference_sha256' => ref['reference_sha256'], 'reference_fixed_at' => ref['fixed_at'])
}
abort 'reference sha differs from the judged expectation' unless oth['expected_output_sha256'] == ref['reference_sha256']

record = KairosMcp::Manifest.build_tier4_distillation(input.merge('operator' => { 'mode' => 'anonymous', 'anonymous_id' => 'anonymous-0000000000000000' }))
KairosMcp::Manifest.validate_tier4!(record)
File.write(OUT, "#{JSON.pretty_generate(input)}\n")
puts JSON.pretty_generate(record.slice('package_digest', 'reversion_passed', 'other_data_passed', 'leaderboard_eligible')
                                .merge('acceptance_sha256' => input['acceptance']['sha256'], 'validates' => true))
