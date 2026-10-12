#!/usr/bin/env ruby
# frozen_string_literal: true

# Assemble the fixed set of self-application round 2 (L2
# handoff_selfapp_round2_plan_20261012, step 2): every component named by path
# and a sha256 computed here from the bytes on disk or in commit C', never
# copied from another record. The sha256 of the written file is what gets the
# external timestamp. Writing it fixes nothing by itself; the timestamp does.
#
#   ruby scripts/selfapp/fixed_set_r2.rb --out selfapp/round2/fixed_set.json
#
# Launches no checker: it reads files, runs `git archive` / `git show`, and
# hashes bytes.

require 'digest'
require 'json'
require 'optparse'
require 'tmpdir'
require_relative 'ddc_common'

opts = {}
OptionParser.new { |o| o.on('--out PATH') { |v| opts[:out] = v } }.parse!
abort 'usage: fixed_set_r2.rb --out PATH' unless opts[:out]
abort "#{opts[:out]} exists" if File.exist?(opts[:out])

REPO = File.expand_path('../..', __dir__)
C_PRIME = '809151618f2b4e06bdd279be2ee6537c8e8e016c'

def file_entry(rel)
  path = File.join(REPO, rel)
  abort "missing: #{rel}" unless File.file?(path)
  { 'path' => rel, 'sha256' => Digest::SHA256.file(path).hexdigest, 'bytes' => File.size(path) }
end

# The tree rule of round 1 (DdcCommon, the S−1 rule).
def tree_entry(rel)
  dir = File.join(REPO, rel)
  abort "missing: #{rel}" unless File.directory?(dir)
  files = DdcCommon.tree_files(dir)
  { 'path' => rel, 'tree_sha256' => DdcCommon.tree_sha256(files), 'files' => files.size }
end

# A file as it is in commit C', so the set names the procedure that will run.
def blob_at_c_prime(rel)
  out = IO.popen(['git', '-C', REPO, 'show', "#{C_PRIME}:#{rel}"], 'rb', &:read)
  abort "git show #{C_PRIME}:#{rel} failed" unless $?.success?
  { 'path' => rel, 'commit' => C_PRIME, 'sha256' => Digest::SHA256.hexdigest(out), 'bytes' => out.bytesize }
end

archive = IO.popen(['git', '-C', REPO, 'archive', C_PRIME], 'rb', &:read)
abort 'git archive failed' unless $?.success?
package_tree = Dir.mktmpdir do |d|
  IO.popen(['tar', '-x', '-C', d], 'wb') { |io| io.write(archive) }
  abort 'tar failed' unless $?.success?
  files = DdcCommon.package_files(d)
  { 'tree_sha256' => DdcCommon.tree_sha256(files), 'files' => files.size }
end

set = {
  'fixed_set' => 'self-application round 2 fixed set (expected-r2-v1)',
  'built_by' => file_entry('scripts/selfapp/fixed_set_r2.rb'),
  'expectations' => file_entry('selfapp/round2/expected.json'),
  'commit_c_prime' => { 'commit' => C_PRIME, 'git_archive_sha256' => Digest::SHA256.hexdigest(archive),
                        'git_archive_bytes' => archive.bytesize, 'package_tree' => package_tree },
  'frozen_inputs' => { 'manifest' => file_entry('log/selfapp/ddc_inputs_v1/inputs_manifest.json'),
                       'tree' => tree_entry('log/selfapp/ddc_inputs_v1') },
  'round1' => {
    'fixed_set' => file_entry('selfapp/fixed_set_v1.json'),
    'fixed_set_ots' => file_entry('selfapp/fixed_set_v1.json.ots'),
    'expected' => file_entry('selfapp/expected_v1.json'),
    'tier4_acceptance' => file_entry('selfapp/tier4_acceptance_v1.json'),
    'verdict_tables' => %w[log/selfapp/s8/verdict_table_from_S5.tsv log/selfapp/s8/verdict_table_from_S6_T.tsv].map { |r| file_entry(r) },
    'tier25_grade_bodies' => %w[V0 V6].map { |v| file_entry("log/selfapp/s5/harness_A_1/bodies/tier25_grade__#{v}.json") }
  },
  'procedures_at_c_prime' => %w[
    scripts/selfapp/ddc_common.rb scripts/selfapp/ddc_harness.rb scripts/selfapp/ddc_compare.rb
    scripts/selfapp/verdict_table.rb scripts/selfapp/s4b_reinstall.rb scripts/selfapp/s6_t.rb
    scripts/selfapp/s7_judge.rb scripts/selfapp/s8_judge.rb
    scripts/gc_submit_client.rb genomicschain_prov/bin/gc_prov_verify.rb
  ].map { |r| blob_at_c_prime(r) },
  'procedure_notes' => 's4b_reinstall.rb, s6_t.rb, s7_judge.rb and s8_judge.rb are hard-wired to C and to round-1 directories; their ' \
                       'round-2 parameterisation is written after this set and reported as such, with a diff against ' \
                       'the blobs named here.',
  'local_anchor_procedure' => file_entry('log/tier25_gate_withdrawn_20261012/up.sh'),
  'tier4' => {
    'stage0_skill' => tree_entry('selfapp/tier4/stage0/skill'),
    'stage1_skill' => tree_entry('selfapp/tier4/stage1/skill'),
    'records' => %w[log/selfapp/s7/package_digest.json log/selfapp/s7/reference.json log/selfapp/s7/subject2_record.json
                    log/selfapp/s8/package_digest.json log/selfapp/s8/declaration.json].map { |r| file_entry(r) }
  },
  'statement' => "No checker of commit C' was launched against selfapp/ or log/selfapp/ddc_inputs_v1/ before this " \
                 'set was written; the exceptions are listed in the expectations file under observed_before_fixing. ' \
                 'This is the orchestrator statement; it is not an independent check.'
}

File.write(opts[:out], "#{JSON.pretty_generate(set)}\n")
puts "#{Digest::SHA256.file(opts[:out]).hexdigest}  #{opts[:out]}"
