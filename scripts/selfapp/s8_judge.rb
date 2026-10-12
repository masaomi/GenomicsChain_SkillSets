#!/usr/bin/env ruby
# frozen_string_literal: true

# S8, Tier 4 stage 1 (selfapp/tier4_acceptance_v1.json stage_1): the
# declaration record and the two Tier-3 judgments, written by the context
# that is not the stage-1 distiller (INV-S4).
#
#   ruby scripts/selfapp/s8_judge.rb declare   # record the draft's declaration
#   ruby scripts/selfapp/s8_judge.rb declared  # Tier 3 on the declared computation (the precondition)
#   ruby scripts/selfapp/s8_judge.rb skill     # Tier 3 on the distilled Skill (reversion check)
#
# Both Tier-3 runs execute ddc_harness.rb, so each is entered in
# log/selfapp/ddc_runs.jsonl as a harness_A run before it starts
# (expected_v1.json rules.ddc_counting); with no harness_T partner they are
# reported as unpaired and change no DDC pair.

require 'digest'
require 'fileutils'
require 'json'
require 'time'
require_relative 'ddc_common'

REPO = File.realpath(File.join(__dir__, '..', '..'))
# Round 2 (design §14, added after round 2's fixing): the same judgments on A'.
# It reads round 1's declaration, Skill digest and invocation from
# log/selfapp/s8 and writes work, args, launches and its runs-log entries
# under log/selfapp/r2/. `declare` is round 1 only.
#   ruby scripts/selfapp/s8_judge.rb declared|skill --round 2
if (i = ARGV.index('--round'))
  ROUND = Integer(ARGV[i + 1])
  ARGV.slice!(i, 2)
else
  ROUND = 1
end
abort "unknown round #{ROUND}" unless [1, 2].include?(ROUND)
S8_R1 = File.join(REPO, 'log/selfapp/s8')
S8 = ROUND == 1 ? S8_R1 : File.join(REPO, 'log/selfapp/r2/s8')
DRAFT = File.join(REPO, 'docs/preprint/genomicschain_tiers_preprint_20261003_v0_2/preprint.md')
DECLARATION = File.join(S8_R1, 'declaration.json')
BUNDLE = File.join(REPO, 'log/selfapp/ddc_inputs_v1')
CHECKER = File.join(REPO, '.kairos/skillsets')
RUNS_LOG = File.join(REPO, ROUND == 1 ? 'log/selfapp/ddc_runs.jsonl' : 'log/selfapp/r2/ddc_runs.jsonl')
TABLE = 'results/verdict_table.tsv'
TABLE_SHA256 = 'cb670b07de56c9da7ea4818257cd87a7ae8b5e365eadb93f76b10e31a6cb6105'
CITATION = 'GenomicsChain tiers preprint, working draft v0.2 (2026-10-03), section 8.4, Table 8.4'
SKILL = File.join(REPO, 'selfapp/tier4/stage1/skill')

def now = Time.now.utc.iso8601(3)
def write_json(path, obj) = File.write(path, "#{JSON.pretty_generate(obj)}\n")
def tree(dir) = DdcCommon.tree_sha256(DdcCommon.tree_files(dir))

def launch(label, args, command_note)
  work = args['workdir']
  abort "#{work} exists" if File.exist?(work)
  FileUtils.mkdir_p(work)
  yield work if block_given?
  args_path = File.join(S8, 'args', "#{label}.json")
  abort "#{args_path} exists" if File.exist?(args_path)
  FileUtils.mkdir_p(File.dirname(args_path))
  write_json(args_path, args)
  File.open(RUNS_LOG, 'a') do |f|
    f.flock(File::LOCK_EX)
    f.write("#{JSON.generate('utc' => now, 'kind' => 'harness_A', 'checker_root' => CHECKER,
                             'inputs_manifest_sha256' => Digest::SHA256.file(File.join(BUNDLE, 'inputs_manifest.json')).hexdigest,
                             'out' => File.join(work, 'harness_out').delete_prefix("#{REPO}/"),
                             'resolution' => 'host rubygems, no bundler', 'note' => command_note)}\n")
  end
  exec(RbConfig.ruby, File.join(__dir__, 's4c_launch.rb'), '--tool', 'gc_tier3_execute', '--args', args_path,
       '--label', label, '--out-root', File.join(S8, 'launches'), '--log', File.join(S8, 'launches.jsonl'), '--timeout', '3600')
end

def tier3_args(subject_ref, work, command)
  {
    'subject_ref' => subject_ref, 'backend' => 'local',
    'pipeline' => { 'command' => ['bash', '-c', command], 'workdir' => work, 'step_source' => 'prose-methods' },
    'env' => { 'ruby' => RUBY_VERSION, 'checker_packages_tree_sha256' => DdcCommon.tree_sha256(DdcCommon.package_files(CHECKER)),
               'note' => 'host Ruby and gems as the operator installed them; the draft names Ruby 3.4.10 and the checker tree' },
    'expected_output' => { 'target' => "file:#{TABLE}", 'sha256' => TABLE_SHA256, 'source' => 'paper_declared',
                           'source_citation' => CITATION },
    'comparator_id' => 'exact_sha256', 'inputs_provenance' => 'operator_supplied',
    'environment_provenance' => 'authored_by_operator', 'runs' => 1, 'workdir' => work
  }
end

case ARGV.first
when 'declare'
  abort "declare is round 1 only; round 2 uses round 1's declaration" unless ROUND == 1
  abort "#{DECLARATION} exists" if File.exist?(DECLARATION)
  text = File.read(DRAFT)
  abort 'the draft does not declare the table sha256' unless text.include?(TABLE_SHA256) && text.include?('### 8.4 ')
  write_json(DECLARATION, {
               'what' => 'Tier 4 stage 1: the computation the draft declares (tier4_acceptance_v1.json stage_1.reversion_check)',
               'declared_at' => now, 'draft' => DRAFT.delete_prefix("#{REPO}/"), 'draft_sha256' => Digest::SHA256.file(DRAFT).hexdigest,
               'section' => '8.4', 'citation' => CITATION, 'target' => "file:#{TABLE}", 'table_sha256' => TABLE_SHA256,
               'computation' => { 'harness' => 'scripts/selfapp/ddc_harness.rb at 549accc', 'table' => 'scripts/selfapp/verdict_table.rb at 15d0656',
                                  'bundle_inputs_manifest_sha256' => Digest::SHA256.file(File.join(BUNDLE, 'inputs_manifest.json')).hexdigest,
                                  'checker_packages_tree_sha256' => DdcCommon.tree_sha256(DdcCommon.package_files(CHECKER)) },
               'declared_by' => 'main context (not the stage-1 distiller)'
             })
  puts File.read(DECLARATION)

when 'declared'
  abort 'no declaration recorded' unless File.exist?(DECLARATION)
  work = File.join(S8, 'tier3_work', 'declared')
  command = "ruby #{REPO}/scripts/selfapp/ddc_harness.rb --checker-root #{CHECKER} --inputs #{BUNDLE} --out harness_out && " \
            "mkdir -p results && ruby #{REPO}/scripts/selfapp/verdict_table.rb harness_out #{TABLE}"
  launch('declared_computation', tier3_args('selfapp://tier4/stage1/declared_computation', work, command),
         'S8 precondition: the declared computation under Tier 3')

when 'skill'
  record = JSON.parse(File.read(File.join(S8_R1, 'package_digest.json')))
  abort 'stage-1 Skill differs from its recorded digest' unless tree(SKILL) == record['package_digest']
  invocation = JSON.parse(File.read(File.join(S8_R1, 'skill_invocation.json')))
  work = File.join(S8, 'tier3_work', 'skill')
  launch('skill_reversion', tier3_args('selfapp://tier4/stage1/skill', work, invocation.fetch('command')),
         'S8 reversion check: the distilled stage-1 Skill under Tier 3') do |dir|
    FileUtils.cp_r(SKILL, File.join(dir, 'skill'))
    Array(invocation['files']).each { |name, content| File.write(File.join(dir, name), content) }
  end

else
  abort 'usage: s8_judge.rb declare|declared|skill'
end
