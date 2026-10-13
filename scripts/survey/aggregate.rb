#!/usr/bin/env ruby
# Validate all Stage-1 calibration reports against report_schema_v0_2_5.json,
# build registry_calibration.csv, and compute the n=40 aggregate under TWO
# Stage-2 positive-gate definitions (current vs tightened).
require 'json'
ROOT = File.dirname(__FILE__)
SCHEMA = JSON.parse(File.read(File.expand_path('../reproducibility_framework/report_schema_v0_2_5.json', ROOT)))
# COLLECTION defaults to the 2026-07-23 calibration; the pre-registered survey passes
# COLLECTION=survey_v1_1/collection. Validation logic is identical for both.
COLLECTION = File.join(ROOT, ENV.fetch('COLLECTION', 'collection'))
REGISTRY_NAME = ENV.fetch('REGISTRY', 'registry_calibration.csv')
files = Dir.glob(File.join(COLLECTION, 'by_paper', '*', '*stage1*v0.2.5.json')).sort
abort "no stage-1 reports under #{COLLECTION}/by_paper" if files.empty?

# Frame-level exclusions (pre-registration v1.0 §3). Excluded reports are still schema-validated --
# they stay on disk as evidence -- but they leave the analysis denominator. §3 requires they be
# "recorded as counts, not as silence", so the count is printed and the registry keeps an
# `excluded` column. Absent file => no exclusions.
excl_path = File.join(COLLECTION, ENV.fetch('EXCLUSIONS', 'exclusions.json'))
EXCL = File.exist?(excl_path) ? JSON.parse(File.read(excl_path))['excluded'].to_a : []
EXCL_IDS = EXCL.map { |e| e['canonical_id'] }

VVERD = %w[R RI NI X OOS]; VCLASS = %w[A_verified_in_code B_pin_prose_only C_mutable_latest n/a]
LOCK_CLAIMS = %w[env_lock_claimed container_digest_claimed release_snapshot] # tightened gate (can reach R*)
PARTIAL = 'exact_pins_partial'

rows = []; errs = []
files.each do |f|
  r = JSON.parse(File.read(f))
  sid = File.basename(File.dirname(f))
  (SCHEMA['required'] || []).each { |k| errs << "#{sid}: missing #{k}" unless r.key?(k) }
  errs << "#{sid}: rubric_version" unless r['rubric_version'] == '0.2.5'
  errs << "#{sid}: rubric_hash" unless r['rubric_hash'] == '4024d4d8817abb0feb76ca9e91effcb11fcea53b1caae2a2ee4efc985e4ca3b1'
  errs << "#{sid}: funnel_stage" unless r['funnel_stage'] == 'stage1-prose-only'
  cC = r['steps'].count { |s| s['layer'] == 'C' }
  c = r['counts']
  errs << "#{sid}: S!=C(#{c['S']}/#{cC})" unless c['S'] == cC
  errs << "#{sid}: nR!=0" unless c['n_R'] == 0
  errs << "#{sid}: sum!=S" unless c['n_R'] + c['n_RI'] + c['n_NI'] + c['n_X'] == c['S']
  r['steps'].each do |s|
    errs << "#{sid}/#{s['step_id']}: verdict" unless VVERD.include?(s['verdict'])
    errs << "#{sid}/#{s['step_id']}: R* at stage1" if s['verdict'] == 'R'
    errs << "#{sid}/#{s['step_id']}: env_class" if s['env_capture_class'] && !VCLASS.include?(s['env_capture_class'])
  end
  rows << {
    id: r.dig('canonical_id', 'value'), excluded: EXCL_IDS.include?(r.dig('canonical_id', 'value')),
    type: r['paper_type'], claim: r['capture_claim'],
    s2_current: r['stage2_candidate'], s2_tight: LOCK_CLAIMS.include?(r['capture_claim']),
    assessable: r.dig('assessable', 'is_assessable'), S: c['S'], W: c['W'],
    lever_sw: r.dig('levers', 'software_env_lock'), lever_db: r.dig('levers', 'in_code_db_pin_classA')
  }
end

all_rows = rows
rows = all_rows.reject { |r| r[:excluded] }   # analysis denominator
n = rows.size
pct = ->(k) { "#{rows.count { |r| r[k] }}/#{n} (#{(100.0 * rows.count { |r| r[k] } / n).round}%)" }
dist = ->(k) { rows.group_by { |r| r[k] }.transform_values(&:size).sort_by { |_, v| -v }.to_h }

# registry -- carries every report, excluded ones flagged rather than dropped
reg = File.join(COLLECTION, REGISTRY_NAME)
File.write(reg, (['canonical_id,paper_type,capture_claim,stage2_current,stage2_tightened,assessable,S,W,excluded'] +
  all_rows.map { |r| "#{r[:id]},#{r[:type]},#{r[:claim]},#{r[:s2_current]},#{r[:s2_tight]},#{r[:assessable]},#{r[:S]},#{r[:W]},#{r[:excluded]}" }).join("\n") + "\n")

puts errs.empty? ? "ALL #{all_rows.size} STAGE-1 REPORTS SCHEMA-VALID ✓" : "SCHEMA ERRORS (#{errs.size}):\n" + errs.first(20).join("\n")
puts
unless EXCL.empty?
  puts "EXCLUDED from the denominator (pre-registration v1.0 §3, reports retained on disk):"
  EXCL.each { |e| puts "  #{e['canonical_id']}  reason=#{e['reason']}  backfilled_by=#{e['backfilled_by'] || 'none'}  chain=##{e['chain_block']}" }
  puts "  #{all_rows.size} reports on disk - #{EXCL.size} excluded = #{n} in the denominator"
  puts
end
puts "== Stage-1 aggregate over #{COLLECTION} (n=#{n}) =="
puts "assessable            #{pct.call(:assessable)}"
puts "paper_type dist       #{dist.call(:type).to_json}"
puts "capture_claim dist    #{dist.call(:claim).to_json}"
puts
puts "Stage-2 candidates (CURRENT gate: incl exact_pins_partial)   #{pct.call(:s2_current)}"
puts "Stage-2 candidates (TIGHTENED gate: lock/container/release)  #{pct.call(:s2_tight)}"
puts
puts "-> exact_pins_partial papers: #{rows.count { |r| r[:claim] == PARTIAL }} (these CANNOT reach R* under Δ2 without env closure; a prose read caps them at version=1 -> no code-check needed except the 10% audit)"
puts "wrote #{reg}"
