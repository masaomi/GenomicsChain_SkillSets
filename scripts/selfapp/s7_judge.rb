#!/usr/bin/env ruby
# frozen_string_literal: true

# S7, steps 5–6 of Tier 4 stage 0 (selfapp/tier4_acceptance_v1.json): the
# judge's JobSpecs. Written by the context that is not the distiller (INV-S4).
# For V0 (reversion check) and for the second subject (other-data check) it
# builds a fresh working directory holding only the recorded Skill package,
# the subject's input data and a parameter file written here from the
# subject's own config/config.yaml, and writes the gc_tier3_execute args.
#
#   ruby scripts/selfapp/s7_judge.rb
#
# Refuses to run unless the package still has the recorded digest and the
# reference has been fixed; refuses to overwrite anything.

require 'digest'
require 'fileutils'
require 'json'
require 'yaml'
require_relative 'ddc_common'

REPO = File.realpath(File.join(__dir__, '..', '..'))
S7 = File.join(REPO, 'log/selfapp/s7')
PACKAGE = File.join(REPO, 'selfapp/tier4/stage0/skill')
DIGEST = JSON.parse(File.read(File.join(S7, 'package_digest.json')))
REFERENCE = JSON.parse(File.read(File.join(S7, 'reference.json')))
WORK = File.join(S7, 'tier3_work')
ARGS = File.join(S7, 'args')
S1 = 'results/synthetic_supplementary_table_S1.tsv'
V0_DECLARED = '22fe3ff699a91e4ded9a3f58fc0996b95c9bff817c294e0421f2fda68e02508a'
COMMAND = 'docker run --rm --platform linux/amd64 -v "$PWD":/work -w /work synthetic-rnaseq:1.0 ' \
          'snakemake --cores 1 --snakefile skill/Snakefile --configfile params.yaml' # SKILL.md "How to run it"
IMAGE = { 'container_image' => 'synthetic-rnaseq:1.0',
          'container_image_id' => 'sha256:004c13e8611f445b5be24dcac9749edd0a38a0aa136a0642a88c9ee7ee236504' }.freeze

tree = ->(dir) { DdcCommon.tree_sha256(DdcCommon.tree_files(dir)) }
abort 'package differs from the recorded digest' unless tree.call(PACKAGE) == DIGEST['package_digest']
abort 'reference not fixed: the other-data check is not performed' unless REFERENCE['fixed']
[WORK, ARGS].each { |d| abort "#{d} exists" if File.exist?(d) }

subjects = {
  'V0' => { repo: File.join(REPO, 'selfapp/synthetic_rnaseq_v1/synthetic_repo'),
            expected: { 'target' => "file:#{S1}", 'sha256' => V0_DECLARED, 'source' => 'paper_declared',
                        'source_citation' => 'supplementary table S1' } },
  'subject2' => { repo: File.join(S7, 'subject2/synthetic_rnaseq_v1/synthetic_repo'),
                  expected: { 'target' => "file:#{S1}", 'sha256' => REFERENCE['reference_sha256'],
                              'source' => 'operator_supplied',
                              'source_citation' => 'the reference record: original V0 pipeline applied to the second subject',
                              'validated_by' => nil } }
}

FileUtils.mkdir_p(ARGS)
record = {}
subjects.each do |name, s|
  cfg = YAML.safe_load(File.read(File.join(s[:repo], 'config/config.yaml')))
  dir = File.join(WORK, name)
  FileUtils.mkdir_p(File.join(dir, 'data'))
  FileUtils.cp_r(PACKAGE, File.join(dir, 'skill'))
  FileUtils.mkdir_p(File.join(dir, 'config'))
  FileUtils.cp(File.join(s[:repo], cfg.fetch('samples')), File.join(dir, 'config/samples.tsv'))
  %w[synthetic_reads synthetic_reference].each { |d| FileUtils.cp_r(File.join(s[:repo], 'data', d), File.join(dir, 'data', d)) }
  # The comparison is V0's: ~ condition, treated over control (scripts/deseq2.R:17-22 of the subject).
  params = <<~YAML
    # SYNTHETIC — FICTIONAL STUDY. Parameter file written by the S7 judge context from #{name}'s config/config.yaml.
    sample_table: config/samples.tsv
    reference:
      transcripts: #{cfg.fetch('transcripts')}
      tx2gene: #{cfg.fetch('tx2gene')}
    comparison:
      design: "~ condition"
      variable: condition
      numerator: treated
      denominator: control
    significance_threshold: #{cfg.fetch('padj_threshold')}
    permutation_seed: #{cfg.fetch('permutation_seed')}
    permutation_draws: #{cfg.fetch('permutation_draws')}
  YAML
  File.write(File.join(dir, 'params.yaml'), params)
  files = DdcCommon.tree_files(dir)
  abort "#{name}: a file has V0's declared S1 hash" if files.value?(V0_DECLARED)
  abort "#{name}: results/ present" if File.exist?(File.join(dir, 'results'))
  args = {
    'subject_ref' => "selfapp://tier4/stage0/#{name}",
    'backend' => 'local',
    'pipeline' => { 'command' => ['bash', '-c', COMMAND], 'workdir' => dir, 'step_source' => 'snakefile' },
    'env' => IMAGE,
    'expected_output' => s[:expected],
    'comparator_id' => 'exact_sha256',
    'inputs_provenance' => 'operator_supplied',
    'environment_provenance' => 'declared_container',
    'runs' => 1,
    'workdir' => dir
  }
  path = File.join(ARGS, "t3_tier4_#{name}.json")
  File.write(path, "#{JSON.pretty_generate(args)}\n")
  record[name] = { 'workdir_tree_sha256' => tree.call(dir), 'params_sha256' => Digest::SHA256.file(File.join(dir, 'params.yaml')).hexdigest,
                   'args_sha256' => Digest::SHA256.file(path).hexdigest, 'expected_sha256' => s[:expected]['sha256'] }
end
File.write(File.join(S7, 'judge_setup.json'), "#{JSON.pretty_generate('package_digest' => DIGEST['package_digest'],
                                                                      'reference_sha256' => REFERENCE['reference_sha256'],
                                                                      'script_sha256' => Digest::SHA256.file(__FILE__).hexdigest,
                                                                      'subjects' => record)}\n")
puts JSON.pretty_generate(record)
