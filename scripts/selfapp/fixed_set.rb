#!/usr/bin/env ruby
# frozen_string_literal: true

# Assemble the INV-S2 fixed set of the self-application demonstration (design
# §5, unit S3): every component named by path and a sha256 computed here from
# the bytes on disk, never copied from another record. The sha256 of the
# written file is what gets the external timestamp (O-9). Writing it fixes
# nothing by itself; the timestamp does.
#
#   ruby scripts/selfapp/fixed_set.rb --out selfapp/fixed_set_v1.json
#
# Launches no checker: it reads files and hashes them.

require 'digest'
require 'json'
require 'optparse'

opts = {}
OptionParser.new { |o| o.on('--out PATH') { |v| opts[:out] = v } }.parse!
abort 'usage: fixed_set.rb --out PATH' unless opts[:out]
abort "#{opts[:out]} exists" if File.exist?(opts[:out])

REPO = File.expand_path('../..', __dir__)
DESIGN_SHA256 = '270d4a82dccaba0161ffd7cc983c13a771b8111a8bdcd1779e48d827a4316129'
C = '549accc9b5b6016ccb906b613ea2ea8da73ad4a6'

def file_entry(rel)
  path = File.join(REPO, rel)
  abort "missing: #{rel}" unless File.file?(path)
  { 'path' => rel, 'sha256' => Digest::SHA256.file(path).hexdigest, 'bytes' => File.size(path) }
end

# The S−1 rule: every regular file incl. dot files, symlinks not followed,
# "<sha256>  <relpath>\n" sorted bytewise by path, sha256 of the concatenation.
def tree_entry(rel)
  dir = File.join(REPO, rel)
  abort "missing: #{rel}" unless File.directory?(dir)
  files = Dir.glob('**/*', File::FNM_DOTMATCH, base: dir)
             .select { |p| File.file?(File.join(dir, p)) && !File.symlink?(File.join(dir, p)) }.sort_by(&:b)
  lines = files.map { |p| "#{Digest::SHA256.file(File.join(dir, p)).hexdigest}  #{p}\n" }.join
  { 'path' => rel, 'tree_sha256' => Digest::SHA256.hexdigest(lines), 'files' => files.size }
end

# A file as it is in commit C, so the fixed set names what T is given.
def blob_at_c(rel)
  out = IO.popen(['git', '-C', REPO, 'show', "#{C}:#{rel}"], 'rb', &:read)
  abort "git show #{C}:#{rel} failed" unless $?.success?
  { 'path' => rel, 'commit' => C, 'sha256' => Digest::SHA256.hexdigest(out), 'bytes' => out.bytesize }
end

abort 'design sha256 differs' unless Digest::SHA256.file(File.join(REPO, 'docs/design/self_application_design_v0_1.md')).hexdigest == DESIGN_SHA256
archive = IO.popen(['git', '-C', REPO, 'archive', C], 'rb', &:read)
abort 'git archive failed' unless $?.success?

set = {
  'fixed_set' => 'self-application fixed set v1 (design §5 INV-S2)',
  'built_by' => file_entry('scripts/selfapp/fixed_set.rb'),
  'design' => { 'path' => 'docs/design/self_application_design_v0_1.md', 'version' => '0.1.5', 'sha256' => DESIGN_SHA256 },
  'commit_c' => { 'commit' => C, 'git_archive_sha256' => Digest::SHA256.hexdigest(archive), 'git_archive_bytes' => archive.bytesize },
  'expectation_table' => file_entry('selfapp/expected_v1.json'),
  'tier4_acceptance' => file_entry('selfapp/tier4_acceptance_v1.json'),
  'comparison_body_definition' => blob_at_c('genomicschain_core/lib/genomicschain_core/comparison_body.rb'),
  'ddc_counting_rule' => %w[scripts/selfapp/ddc_compare.rb scripts/selfapp/ddc_harness.rb scripts/selfapp/ddc_common.rb].map { |r| blob_at_c(r) },
  'subject' => {
    'generator' => tree_entry('selfapp/generator'),
    'seed' => JSON.parse(File.read(File.join(REPO, 'selfapp/synthetic_rnaseq_v1/generator_manifest.json')))['seed'],
    'pins' => [file_entry('selfapp/pins_v0.json'), file_entry('selfapp/pins_v0.lock')],
    'variant_spec' => [file_entry('selfapp/variants_v1.json'), file_entry('scripts/selfapp/make_variants.rb')],
    'frozen_subjects' => { 'V0' => tree_entry('selfapp/synthetic_rnaseq_v1') }
                           .merge((1..8).to_h { |n| ["V#{n}", tree_entry("selfapp/synthetic_rnaseq_v1_variants/V#{n}")] }),
    'answer_key' => file_entry('selfapp/synthetic_truth_v1.json')
  },
  'execution_records_s2' => { 'V0' => file_entry('log/selfapp/s2/synthetic_bco_v0.json'),
                              'V6' => file_entry('log/selfapp/s2/synthetic_bco_v6.json'),
                              's2_record' => file_entry('log/selfapp/s2/s2_record.json') },
  'calibration' => [file_entry('log/selfapp/s3/calibration_record.json'), file_entry('scripts/selfapp/calibrate_v0.rb')],
  'variants_record' => file_entry('log/selfapp/s3/variants_record.json'),
  'rules_located_in' => {
    'tier1_k_first_k_after_timestamp_and_replay' => 'expectation_table .rules',
    'stage0_second_seed_rule' => 'tier4_acceptance .stage_0',
    'ddc_counting_rule' => 'ddc_counting_rule (scripts at commit C) and expectation_table .rules'
  },
  'statement' => 'No checker was launched against selfapp/ before this set was written. This is the ' \
                 'orchestrator statement, matching the calibration and variant records; it is not an independent check.'
}

File.write(opts[:out], "#{JSON.pretty_generate(set)}\n")
puts "#{Digest::SHA256.file(opts[:out]).hexdigest}  #{opts[:out]}"
