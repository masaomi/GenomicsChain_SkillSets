#!/usr/bin/env ruby
# frozen_string_literal: true

# Phase 2-A: stamp report_content_hash into the survey_v1_1 corpus before submit.
#
# gc_tier1_submit does not accept a report without this field: Tier1VerdictSpec
# #claimed_digest raises DigestMismatch when it is absent, and #recompute_digest!
# then re-derives the value server-side and compares. The two must agree, so this
# script deliberately does NOT reimplement the digest -- it loads the very module
# the anchor will run (genomicschain_core/report_content_hash.rb) and calls it.
# A second implementation here would be a hash that agrees today and diverges the
# first time the canonical form is touched.
#
# The digest excludes report_content_hash itself and manifest.chain_record, so
# stamping is idempotent and the chain record can still be filled in after submit.
#
# Usage:
#   ruby add_report_content_hash.rb            # dry-run (default)
#   ruby add_report_content_hash.rb --apply    # write the field into each report
#   ruby add_report_content_hash.rb --verify   # exit 1 unless every stored value recomputes
#
# Env:
#   COLLECTION  collection dir relative to this file (default survey_v1_1/collection)
#   CORE_LIB    genomicschain_core lib dir (default ../../genomicschain_core/lib — this repo's core)
require 'json'

ROOT = File.dirname(File.expand_path(__FILE__))
COLLECTION = File.join(ROOT, ENV.fetch('COLLECTION', 'survey_v1_1/collection'))
GLOB = File.join(COLLECTION, 'by_paper', '*', '*stage1*v0.2.5.json')
AUDIT_PATH = File.join(COLLECTION, 'report_content_hash_2026_08_02.json')

CORE_LIB = ENV.fetch(
  'CORE_LIB',
  File.expand_path('../../genomicschain_core/lib', ROOT)
)
CORE = File.join(CORE_LIB, 'genomicschain_core')
abort "genomicschain_core lib not found at #{CORE_LIB}" unless Dir.exist?(CORE)

require File.join(CORE, 'manifest')
require File.join(CORE, 'report_content_hash')
require File.join(CORE, 'b1_manifest_hash')

RCH = KairosMcp::SkillSets::GenomicschainCore::ReportContentHash
B1 = KairosMcp::SkillSets::GenomicschainCore::B1ManifestHash

apply = ARGV.include?('--apply')
verify_only = ARGV.include?('--verify')

# Insert the key next to the other identity fields rather than appending, so a
# re-run produces byte-identical files and a diff shows only real changes.
ANCHOR_KEY = 'assessed_at'

def with_content_hash(report, hash)
  out = {}
  placed = false
  report.each do |k, v|
    next if k == 'report_content_hash'

    out[k] = v
    if k == ANCHOR_KEY
      out['report_content_hash'] = hash
      placed = true
    end
  end
  out['report_content_hash'] = hash unless placed
  out
end

files = Dir.glob(GLOB).sort
abort "no reports under #{COLLECTION}" if files.empty?

stamped = []      # newly written or pending
already_ok = []   # stored value already recomputes
mismatched = []   # stored value present but wrong
b1_failures = []  # submit would reject before reaching the digest
census = []       # every report and the digest it should carry, re-run or not

files.each do |path|
  report = JSON.parse(File.read(path))
  rel = path.start_with?(ROOT + '/') ? path[(ROOT.length + 1)..] : path
  cid = report.dig('canonical_id', 'value')

  # gc_tier1_submit runs this immediately before recomputing the digest; a report
  # that fails here cannot be submitted no matter what we stamp into it.
  unless B1.matches?(report)
    b1_failures << { file: rel, canonical_id: cid,
                     stored: B1.stored(report), recomputed: B1.compute(report) }
  end

  computed = RCH.compute(report)
  stored = report['report_content_hash']
  census << { file: rel, canonical_id: cid, report_content_hash: computed }

  if stored.nil? || stored.to_s.empty?
    stamped << { file: rel, canonical_id: cid, report_content_hash: computed }
  elsif stored == computed
    already_ok << rel
    next
  else
    mismatched << { file: rel, canonical_id: cid, stored: stored, recomputed: computed }
  end

  next unless apply

  File.write(path, JSON.pretty_generate(with_content_hash(report, computed)) + "\n")
end

mode = apply ? 'APPLY' : verify_only ? 'VERIFY' : 'DRY-RUN'

unless verify_only
  # The census -- every report and the digest it must carry -- is the record, not
  # the per-run delta. An idempotent re-run has an empty delta, and writing only
  # the delta would erase the evidence that the corpus was ever stamped.
  prior = File.exist?(AUDIT_PATH) ? JSON.parse(File.read(AUDIT_PATH)) : nil
  first_stamped_at = prior&.dig('first_stamped_at') || (apply ? '2026-08-02' : nil)

  audit = {
    first_stamped_at: first_stamped_at,
    phase: 'Phase 2-A (pre-submit digest stamping)',
    digest: 'canonical_json_sha256(report minus report_content_hash minus manifest.chain_record)',
    implementation: 'genomicschain_core/lib/genomicschain_core/report_content_hash.rb (loaded, not reimplemented)',
    collection: COLLECTION,
    last_run_mode: mode,
    total_reports: files.size,
    already_canonical: already_ok.size,
    stamped_this_run: apply ? stamped.size : 0,
    pending_stamp: apply ? 0 : stamped.size,
    mismatched: mismatched,
    b1_manifest_hash_failures: b1_failures,
    delta_this_run: stamped,
    census: census
  }
  File.write(AUDIT_PATH, JSON.pretty_generate(audit) + "\n")
end

puts "report_content_hash stamping — #{mode}"
puts "collection : #{COLLECTION}"
puts "core lib   : #{CORE_LIB}"
puts "total      : #{files.size}"
puts "canonical  : #{already_ok.size}"
puts "to stamp   : #{stamped.size}"
puts "mismatched : #{mismatched.size}"
puts "b1 failures: #{b1_failures.size}"
puts "audit log  : #{AUDIT_PATH}" unless verify_only

if b1_failures.any?
  puts
  puts 'b1_manifest_hash does not recompute for these reports; gc_tier1_submit'
  puts 'rejects them before the content digest is ever read:'
  b1_failures.first(5).each { |f| puts "  #{f[:canonical_id]}" }
  puts "  (#{b1_failures.size - 5} more)" if b1_failures.size > 5
end

if mismatched.any?
  puts
  puts 'Stored report_content_hash disagrees with recomputation (report edited after stamping):'
  mismatched.first(5).each do |m|
    puts "  #{m[:canonical_id]}  #{m[:stored].to_s[0, 16]}… -> #{m[:recomputed][0, 16]}…"
  end
  puts "  (#{mismatched.size - 5} more)" if mismatched.size > 5
end

if verify_only
  bad = mismatched.size + stamped.size
  if bad.positive?
    warn "VERIFY FAILED: #{stamped.size} missing, #{mismatched.size} mismatched"
    exit 1
  end
  if b1_failures.any?
    warn "VERIFY FAILED: #{b1_failures.size} report(s) fail the b1_manifest_hash precondition"
    exit 1
  end
  puts 'VERIFY OK — every report carries a report_content_hash that recomputes'
  exit 0
end

if stamped.any? && !apply
  puts
  puts 'Sample pending (first 5):'
  stamped.first(5).each { |c| puts "  #{c[:canonical_id]}  #{c[:report_content_hash][0, 16]}…" }
  puts "  (#{stamped.size - 5} more in audit log)" if stamped.size > 5
  puts
  puts 'Re-run with --apply to write the field.'
end

exit 0
