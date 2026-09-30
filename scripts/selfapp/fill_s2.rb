#!/usr/bin/env ruby
# frozen_string_literal: true

# Fill the manuscript's {{S2:…}} placeholders from the author's run (design
# §4.5, unit S2): every number comes from the run's own outputs — fastp's JSON
# reports, salmon's meta_info.json / lib_format_counts.json and Supplementary
# Table S1 — never from memory or from the answer key. Percentages are
# truncated, not rounded, so 99.999 % is never written as 100 %. Stops, writing
# nothing, when a placeholder has no value, a value has no placeholder, or the
# samples disagree on something the text states for every sample.
#
#   ruby scripts/selfapp/fill_s2.rb --run RUN_REPO --manuscript IN.md --out OUT.md
#
# RUN_REPO is the synthetic_repo copy the author's run was executed in.

require 'json'
require 'optparse'

opts = {}
OptionParser.new do |o|
  o.on('--run DIR') { |v| opts[:run] = v }
  o.on('--manuscript PATH') { |v| opts[:manuscript] = v }
  o.on('--out PATH') { |v| opts[:out] = v }
end.parse!
abort 'usage: fill_s2.rb --run RUN_REPO --manuscript IN.md --out OUT.md' unless opts.values_at(:run, :manuscript, :out).all?
abort "#{opts[:out]} exists" if File.exist?(opts[:out])

# Plain tab-separated files without quoting; csv is not a default gem from Ruby 3.4.
def tsv(path)
  rows = File.readlines(path, chomp: true, encoding: 'UTF-8').reject { |l| l.strip.empty? || l.start_with?('#') }
  header = rows.shift.split("\t")
  rows.map { |l| header.zip(l.split("\t")).to_h }
end

def thousands(n) = n.to_s.reverse.scan(/\d{1,3}/).join(',').reverse

def span(values, &fmt)
  lo, hi = values.minmax
  lo == hi ? fmt.call(lo) : "#{fmt.call(lo)}–#{fmt.call(hi)}"
end

run = opts[:run]
json = ->(rel) { JSON.parse(File.read(File.join(run, rel), encoding: 'UTF-8')) }
samples = tsv(File.join(run, 'config/samples.tsv')).map { |r| r['sample'] }
abort 'no samples' if samples.empty?

before = samples.map { |s| json.call(".work/fastp/#{s}.json").dig('summary', 'before_filtering', 'total_reads') }
after = samples.map { |s| json.call(".work/fastp/#{s}.json").dig('summary', 'after_filtering', 'total_reads') }
mapped = samples.map { |s| json.call(".work/salmon/#{s}/aux_info/meta_info.json")['percent_mapped'] }
libtypes = samples.map { |s| json.call(".work/salmon/#{s}/lib_format_counts.json")['expected_format'] }.uniq
abort "library type differs between samples: #{libtypes.inspect}" unless libtypes.size == 1

table = tsv(File.join(run, 'results/synthetic_supplementary_table_S1.tsv'))
num = ->(v) { v.nil? || v == 'NA' ? nil : Float(v) }
tested = table.reject { |r| num.call(r['padj']).nil? }
de = tested.select { |r| num.call(r['padj']) < 0.05 }
abort 'no differentially expressed gene; the Results text assumes some' if de.empty?
top = tested.sort_by { |r| [num.call(r['padj']), r['gene_id']] }.first(10)

rows = top.map do |r|
  format('| %<g>s | %<m>.1f | %<l>.2f | %<p>.2e | %<q>.3f |',
         g: r['gene_id'], m: num.call(r['baseMean']), l: num.call(r['log2FoldChange']),
         p: num.call(r['padj']), q: num.call(r['perm_pvalue']))
end
values = {
  'reads_per_sample_range' => span(before) { |v| thousands(v) },
  'reads_after_trim_range' => "#{span(before.zip(after).map { |b, a| (100.0 * a / b).floor(1) }) { |v| format('%.1f', v) }}%",
  'mapping_rate_range' => "#{span(mapped.map { |v| v.floor(2) }) { |v| format('%.2f', v) }}%",
  'library_type' => "`#{libtypes.first}`",
  'n_tested' => tested.size.to_s,
  'n_de' => de.size.to_s,
  'n_up' => de.count { |r| num.call(r['log2FoldChange']).positive? }.to_s,
  'n_down' => de.count { |r| num.call(r['log2FoldChange']).negative? }.to_s,
  'abs_lfc_range' => de.map { |r| num.call(r['log2FoldChange']).abs }.minmax.map { |v| format('%.2f', v) }.join(' to '),
  'n_de_perm_below_005' => de.count { |r| num.call(r['perm_pvalue']) < 0.05 }.to_s,
  'top10_table' => (['| Gene | Mean normalised count | log2 fold change | Adjusted p-value | Permutation p-value |',
                     '|---|---:|---:|---:|---:|'] + rows).join("\n")
}

text = File.read(opts[:manuscript], encoding: 'UTF-8')
found = text.scan(/\{\{S2:([a-z0-9_]+)\}\}/).flatten.uniq
abort "placeholders without a value: #{(found - values.keys).inspect}" unless (found - values.keys).empty?
abort "values without a placeholder: #{(values.keys - found).inspect}" unless (values.keys - found).empty?

File.write(opts[:out], text.gsub(/\{\{S2:([a-z0-9_]+)\}\}/) { values.fetch(Regexp.last_match(1)) })
puts JSON.pretty_generate(values.reject { |k, _| k == 'top10_table' })
