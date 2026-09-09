#!/usr/bin/env ruby
# frozen_string_literal: true

# Phase 2-A: derive the gc_tier1_submit input set for the survey_v1_1 corpus.
#
# Ruling of 2026-08-02 (option A): reports the submit gate rejects are excluded
# from the submit set and recorded as counts, following pre-registration v1.0 §3
# ("recorded as counts, not as silence"). The reports stay on disk and stay in the
# analysis denominator -- this is a SUBMIT-level exclusion, not a frame-level one.
#
#   frame-level exclusion   collection/exclusions.json     removes from N (withdrawn work)
#   submit-level exclusion  this file's output             does NOT touch N
#
# Conflating the two would silently move published statistics, so both records
# state the distinction and this script never reads or writes exclusions.json.
#
# The pass/fail decision is not hand-maintained: it is produced by running the
# anchor's own admission path (Tier1VerdictSpec#apply_gates! plus the digest
# comparison) over every report. Re-run after any corpus or gate change.
#
# Usage:
#   ruby build_submit_set.rb            # write the manifest + exclusion record
#   ruby build_submit_set.rb --verify   # exit 1 if the on-disk records are stale
#
# Env:
#   COLLECTION  collection dir relative to this file (default survey_v1_1/collection)
#   CORE_LIB    genomicschain_core lib dir (default ../../genomicschain_core/lib — this repo's core)
require 'json'

ROOT = File.dirname(File.expand_path(__FILE__))
COLLECTION = File.join(ROOT, ENV.fetch('COLLECTION', 'survey_v1_1/collection'))
GLOB = File.join(COLLECTION, 'by_paper', '*', '*stage1*v0.2.5.json')
MANIFEST_PATH = File.join(COLLECTION, 'submit_manifest_2026_08_02.json')
EXCLUSIONS_PATH = File.join(COLLECTION, 'submit_exclusions_2026_08_02.json')
FRAME_EXCLUSIONS_PATH = File.join(COLLECTION, 'exclusions.json')

CORE_LIB = ENV.fetch(
  'CORE_LIB',
  File.expand_path('../../genomicschain_core/lib', ROOT)
)
abort "genomicschain_core lib not found at #{CORE_LIB}" unless Dir.exist?(CORE_LIB)
$LOAD_PATH.unshift(CORE_LIB)
require 'genomicschain_core'

Spec = KairosMcp::SkillSets::GenomicschainCore::VerdictSpec::Tier1

verify_only = ARGV.include?('--verify')

# Read-only: used to annotate, never to filter. A frame-excluded report is still
# submitted -- it is evidence, and §3 keeps it on disk deliberately.
frame_excluded =
  if File.exist?(FRAME_EXCLUSIONS_PATH)
    JSON.parse(File.read(FRAME_EXCLUSIONS_PATH))['excluded'].to_a.map { |e| e['canonical_id'] }
  else
    []
  end

files = Dir.glob(GLOB).sort
abort "no reports under #{COLLECTION}" if files.empty?

submittable = []
rejected = []

files.each do |path|
  rel = path.start_with?(ROOT + '/') ? path[(ROOT.length + 1)..] : path
  spec = Spec.new(report_json: File.read(path), operator: nil)

  begin
    parsed = spec.parse_digest_subject!
    spec.recompute_digest!(parsed)
    claimed = spec.claimed_digest
    recomputed = spec.instance_variable_get(:@content_hash)
    unless claimed == recomputed
      raise "report_content_hash mismatch: claimed #{claimed}, recomputed #{recomputed}"
    end

    spec.apply_gates!(spec.report)
    cid = spec.report.dig('canonical_id', 'value')

    submittable << {
      canonical_id: cid,
      subject_ref: spec.subject_ref,
      report_content_hash: claimed,
      file: rel,
      frame_excluded: frame_excluded.include?(cid)
    }
  rescue StandardError => e
    report = begin
      JSON.parse(File.read(path))
    rescue StandardError
      {}
    end
    rejected << {
      canonical_id: report.dig('canonical_id', 'value'),
      file: rel,
      gate: e.class.name.split('::').last,
      error: e.message,
      report_retained: true
    }
  end
end

manifest = {
  built_at: '2026-08-02',
  phase: 'Phase 2-A (submit set derivation)',
  ruling: 'option A (2026-08-02) — gate-rejected reports excluded from submit, recorded as counts',
  derivation: 'Tier1VerdictSpec#parse_digest_subject! -> #recompute_digest! -> #claimed_digest -> #apply_gates!',
  collection: COLLECTION,
  reports_on_disk: files.size,
  submittable: submittable.size,
  rejected: rejected.size,
  target_tool: 'gc_tier1_submit',
  target_anchor: 'meeting.genomicschain.io (sole anchor, anchor_profile: true)',
  note: 'One entry carries frame_excluded: true. It is submitted anyway — frame exclusion ' \
        'removes a work from the analysis denominator (pre-registration v1.0 §3), not from the record.',
  reports: submittable
}

exclusions = {
  recorded_at: '2026-08-02',
  scope: 'SUBMIT-LEVEL ONLY',
  effect_on_analysis: 'none — N stays 200, every statistic in stats_stage1.rb is unchanged',
  distinct_from: "#{File.basename(FRAME_EXCLUSIONS_PATH)} (frame-level, removes from the denominator)",
  preregistration_rule: "v1.0 §3 — exclusions are 'recorded as counts, not as silence'",
  ruling: 'option A, masaomi, 2026-08-02: exclude from submit rather than edit the assessment content',
  rationale: 'Each rejection would require rewriting what the assessor recorded (gaps shape, ' \
             'OOS axis values, step count), which changes report_content_hash. Editing an ' \
             'assessment to satisfy a transport gate is a content change, not a format change.',
  count: rejected.size,
  reopen_condition: 'schema v0.2.7 relaxing the OOS/gaps shapes, or a corpus correction ruled ' \
                    'separately, re-admits these; re-run build_submit_set.rb and they return.',
  excluded: rejected
}

if verify_only
  stale = []
  [[MANIFEST_PATH, manifest], [EXCLUSIONS_PATH, exclusions]].each do |path, current|
    unless File.exist?(path)
      stale << "#{File.basename(path)} missing"
      next
    end
    on_disk = JSON.parse(File.read(path))
    stale << "#{File.basename(path)} stale" unless on_disk == JSON.parse(JSON.generate(current))
  end

  puts "submit set — VERIFY"
  puts "reports on disk : #{files.size}"
  puts "submittable     : #{submittable.size}"
  puts "rejected        : #{rejected.size}"
  if stale.any?
    warn "VERIFY FAILED: #{stale.join(', ')}"
    exit 1
  end
  puts 'VERIFY OK — on-disk records match a fresh run of the admission path'
  exit 0
end

File.write(MANIFEST_PATH, JSON.pretty_generate(manifest) + "\n")
File.write(EXCLUSIONS_PATH, JSON.pretty_generate(exclusions) + "\n")

puts 'submit set — BUILD'
puts "collection      : #{COLLECTION}"
puts "reports on disk : #{files.size}"
puts "submittable     : #{submittable.size}"
puts "rejected        : #{rejected.size}"
puts "manifest        : #{MANIFEST_PATH}"
puts "exclusions      : #{EXCLUSIONS_PATH}"

if rejected.any?
  puts
  puts 'Excluded from submit (analysis denominator unaffected):'
  rejected.each { |r| puts "  #{r[:canonical_id]}  [#{r[:gate]}]\n    #{r[:error]}" }
end

exit 0
