#!/usr/bin/env ruby
# frozen_string_literal: true

# Compare two ddc_harness.rb outputs (design §6.5 step 4, §6.1's counting
# rule, INV-S9). Writes a report and prints the table; decides nothing else.
#
#   ruby scripts/selfapp/ddc_compare.rb --a OUT_A --t OUT_T [--source-tree DIR] --out report.json
#
# --source-tree is the unpacked archive of commit C, the source T was given.
# With it, INV-S9 is checked: T's checker packages hash to the archive's, and
# every file T loaded is in the archive with the same sha256.

require 'digest'
require 'json'
require 'optparse'
require_relative 'ddc_common'

opts = {}
OptionParser.new do |o|
  o.on('--a DIR') { |v| opts[:a] = v }
  o.on('--t DIR') { |v| opts[:t] = v }
  o.on('--source-tree DIR') { |v| opts[:source] = v }
  o.on('--out PATH') { |v| opts[:out] = v }
end.parse!
abort 'usage: ddc_compare.rb --a DIR --t DIR [--source-tree DIR] --out report.json' unless opts.values_at(:a, :t, :out).all?
abort "#{opts[:out]} exists" if File.exist?(opts[:out])

side = lambda do |dir|
  bodies = File.join(dir, 'bodies')
  { 'bodies' => Dir.exist?(bodies) ? Dir.children(bodies).sort.to_h { |f| [f, Digest::SHA256.file(File.join(bodies, f)).hexdigest] } : {},
    'env' => JSON.parse(File.read(File.join(dir, 'environment.json'))),
    'requests' => JSON.parse(File.read(File.join(dir, 'tier1_requests.json'))).to_h { |r| [r['variant'], r] },
    'errors' => JSON.parse(File.read(File.join(dir, 'errors.json'))),
    'loaded' => File.readlines(File.join(dir, 'loaded_files.txt'), chomp: true).to_h { |l| l.split('  ', 2).reverse } }
end
a = side.call(opts[:a])
t = side.call(opts[:t])

# A body present on one side only is not agreement.
bodies = (a['bodies'].keys | t['bodies'].keys).sort.map do |name|
  sa = a['bodies'][name]
  st = t['bodies'][name]
  { 'body' => name, 'sha256_A' => sa, 'sha256_T' => st, 'match' => !sa.nil? && sa == st }
end

requests = (a['requests'].keys | t['requests'].keys).sort.map do |v|
  ra = a['requests'][v] || {}
  rt = t['requests'][v] || {}
  shas = [ra['recorded_request_sha256'], ra['replayed_request_sha256'], rt['replayed_request_sha256']]
  { 'variant' => v, 'recorded' => shas[0], 'replayed_A' => shas[1], 'replayed_T' => shas[2],
    'match' => shas.none?(&:nil?) && shas.uniq.size == 1 && ra['recorded_request_sha256'] == rt['recorded_request_sha256'] }
end

# §6.1: a pair counts only when Ruby and every gem either side loaded agree
# in name and version. Platform strings differ by construction and are not read.
gems = (a['env']['gems_loaded'].keys | t['env']['gems_loaded'].keys).sort
gem_diff = gems.reject { |g| a['env']['gems_loaded'][g] == t['env']['gems_loaded'][g] }
                .to_h { |g| [g, [a['env']['gems_loaded'][g], t['env']['gems_loaded'][g]]] }
counted = a['env']['ruby'] == t['env']['ruby'] && gem_diff.empty?

loaded_diff = (a['loaded'].keys | t['loaded'].keys).sort.reject { |p| a['loaded'][p] == t['loaded'][p] }

inv_s9 = nil
if opts[:source]
  source = DdcCommon.package_files(File.realpath(opts[:source]))
  not_in_source = t['loaded'].reject { |path, sha| source[path] == sha }.keys
  inv_s9 = { 'source_packages_tree_sha256' => DdcCommon.tree_sha256(source),
             'T_packages_tree_sha256' => t['env']['checker_packages_tree_sha256'],
             'T_loaded_not_in_source' => not_in_source }
  inv_s9['holds'] = inv_s9['source_packages_tree_sha256'] == inv_s9['T_packages_tree_sha256'] && not_in_source.empty?
end

report = {
  'counted' => counted, 'ruby' => [a['env']['ruby'], t['env']['ruby']], 'gem_differences' => gem_diff,
  'platforms_not_compared' => [a['env']['ruby_platform'], t['env']['ruby_platform']],
  'bodies_total' => bodies.size, 'bodies_matching' => bodies.count { |b| b['match'] }, 'bodies' => bodies,
  'tier1_requests' => requests, 'loaded_files_differing' => loaded_diff,
  'errors' => { 'A' => a['errors'], 'T' => t['errors'] }, 'inv_s9' => inv_s9,
  'inputs_manifest_sha256' => [a['env']['inputs_manifest_sha256'], t['env']['inputs_manifest_sha256']],
  'comparison_body_version' => [a['env']['comparison_body_version'], t['env']['comparison_body_version']]
}
File.write(opts[:out], "#{JSON.pretty_generate(report)}\n")

puts "counted: #{counted}  bodies matching: #{report['bodies_matching']}/#{report['bodies_total']}  " \
     "loaded files differing: #{loaded_diff.size}  INV-S9: #{inv_s9 ? inv_s9['holds'] : 'not checked'}"
bodies.each { |b| puts format('%-5s %-40s %s %s', b['match'] ? 'same' : 'DIFF', b['body'], b['sha256_A']&.slice(0, 12), b['sha256_T']&.slice(0, 12)) }
