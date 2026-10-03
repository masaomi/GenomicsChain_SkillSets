#!/usr/bin/env ruby
# frozen_string_literal: true

# The verdict table of the self-application (design §7.2 stage 1, unit S8):
# one row per comparison body a ddc_harness.rb run wrote, so the table is
# what "the deterministic Tiers applied to V0–V8 give". LLM scoring is not in
# it: Tier 1 enters only as the replay of recorded responses.
#
#   ruby scripts/selfapp/verdict_table.rb HARNESS_OUT TABLE.tsv
#
# Columns: tier, variant, headline, body_sha256. Rows sorted bytewise by
# body file name. The headline is a short reading of the body, fixed per kind
# below; body_sha256 is the sha256 of the body file, so the table pins every
# compared field, not only the headline. Tab-separated, "\n" line ends,
# nothing that depends on time, host or path.

require 'digest'
require 'json'

HEADLINE = {
  'tier1_report' => lambda do |b|
    c = b.fetch('counts')
    "n_R=#{c['n_R']} n_RI=#{c['n_RI']} n_NI=#{c['n_NI']} n_X=#{c['n_X']} gaps=#{Array(b['gaps']).size}"
  end,
  'tier2_scan' => lambda do |b|
    codes = Array(b['findings']).map { |f| f['code'] }.sort.uniq
    "floating=#{b.fetch('counts_by_pin').fetch('floating', 0)} findings=#{codes.empty? ? '-' : codes.join(',')}"
  end,
  'tier2_adjudication' => lambda do |b|
    codes = Array(b['discrepancies']).map { |d| d['code'] }.sort.uniq
    "discrepancies=#{codes.empty? ? '-' : codes.join(',')} proposed_demotions=#{b.dig('counts', 'proposed_demotions')}"
  end,
  'tier25_grade' => ->(b) { "grade_overall=#{b.fetch('grade_overall')}" },
  'tier3_compare' => lambda do |b|
    sc = b['self_consistency']
    "comparison=#{b.fetch('comparison_verdict')} runs=#{b.fetch('run_count')} " \
      "all_identical=#{sc.nil? ? '-' : sc.fetch('all_identical')}"
  end
}.freeze

out_dir, table = ARGV
abort 'usage: verdict_table.rb HARNESS_OUT TABLE.tsv' unless out_dir && table
abort "#{table} exists" if File.exist?(table)

bodies = File.join(out_dir, 'bodies')
rows = Dir.children(bodies).select { |f| f.end_with?('.json') }.sort_by(&:b).map do |file|
  kind, variant = File.basename(file, '.json').split('__', 2)
  path = File.join(bodies, file)
  headline = HEADLINE.fetch(kind) { abort "unknown body kind #{kind}" }.call(JSON.parse(File.read(path, encoding: 'UTF-8')))
  [kind, variant, headline, Digest::SHA256.file(path).hexdigest].join("\t")
end
abort 'no bodies' if rows.empty?

File.binwrite(table, (["tier\tvariant\theadline\tbody_sha256"] + rows).map { |r| "#{r}\n" }.join)
puts "#{rows.size} rows, sha256 #{Digest::SHA256.file(table).hexdigest}"
