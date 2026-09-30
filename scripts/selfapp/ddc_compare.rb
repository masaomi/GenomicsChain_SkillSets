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

gems = (a['env']['gems_loaded'].keys | t['env']['gems_loaded'].keys).sort
gem_diff = gems.reject { |g| a['env']['gems_loaded'][g] == t['env']['gems_loaded'][g] }
                .to_h { |g| [g, [a['env']['gems_loaded'][g], t['env']['gems_loaded'][g]]] }

loaded_diff = (a['loaded'].keys | t['loaded'].keys).sort.reject { |p| a['loaded'][p] == t['loaded'][p] }

# INV-S9 must not hold over nothing: every package has to be in the source and
# among the files T loaded (package_files stops on a package missing from a tree).
inv_s9 = nil
if opts[:source]
  source = DdcCommon.package_files(File.realpath(opts[:source]))
  not_in_source = t['loaded'].reject { |path, sha| source[path] == sha }.keys
  not_loaded = DdcCommon::PACKAGES.reject { |pkg| t['loaded'].keys.any? { |path| path.start_with?("#{pkg}/") } }
  inv_s9 = { 'source_packages_tree_sha256' => DdcCommon.tree_sha256(source),
             'T_packages_tree_sha256' => t['env']['checker_packages_tree_sha256'],
             'T_loaded_not_in_source' => not_in_source, 'T_packages_not_loaded' => not_loaded }
  inv_s9['holds'] = inv_s9['source_packages_tree_sha256'] == inv_s9['T_packages_tree_sha256'] &&
                    not_in_source.empty? && not_loaded.empty?
end

# §6.1: a pair counts only when INV-S9 holds and Ruby and every gem either side
# loaded agree in name and version; platform strings differ by construction and
# are not read. It must also be one harness on one set of frozen inputs, and an
# item that failed on either side is a missing result, not agreement — two sides
# failing alike leave no body to compare. Every reason not to count is reported.
not_counted = []
not_counted << 'ruby version differs' unless a['env']['ruby'] == t['env']['ruby']
not_counted << "gem versions differ: #{gem_diff.keys.join(', ')}" unless gem_diff.empty?
not_counted << (inv_s9 ? 'INV-S9 does not hold' : 'INV-S9 not checked (no --source-tree)') unless inv_s9&.fetch('holds')
%w[inputs_manifest_sha256 harness_sha256].each { |k| not_counted << "#{k} differs" unless a['env'][k] == t['env'][k] }
{ 'A' => a, 'T' => t }.each { |s, d| not_counted << "#{d['errors'].size} item(s) failed on #{s}" unless d['errors'].empty? }
counted = not_counted.empty?

report = {
  'counted' => counted, 'not_counted_because' => not_counted,
  'ruby' => [a['env']['ruby'], t['env']['ruby']], 'gem_differences' => gem_diff,
  'platforms_not_compared' => [a['env']['ruby_platform'], t['env']['ruby_platform']],
  'bodies_total' => bodies.size, 'bodies_matching' => bodies.count { |b| b['match'] }, 'bodies' => bodies,
  'tier1_requests' => requests, 'loaded_files_differing' => loaded_diff,
  'errors' => { 'A' => a['errors'], 'T' => t['errors'] }, 'inv_s9' => inv_s9,
  'inputs_manifest_sha256' => [a['env']['inputs_manifest_sha256'], t['env']['inputs_manifest_sha256']],
  'comparison_body_version' => [a['env']['comparison_body_version'], t['env']['comparison_body_version']]
}
File.write(opts[:out], "#{JSON.pretty_generate(report)}\n")

puts "counted: #{counted}  bodies matching: #{report['bodies_matching']}/#{report['bodies_total']}  " \
     "errors: A #{a['errors'].size}, T #{t['errors'].size}  " \
     "loaded files differing: #{loaded_diff.size}  INV-S9: #{inv_s9 ? inv_s9['holds'] : 'not checked'}"
not_counted.each { |r| puts "not counted: #{r}" }
bodies.each { |b| puts format('%-5s %-40s %s %s', b['match'] ? 'same' : 'DIFF', b['body'], b['sha256_A']&.slice(0, 12), b['sha256_T']&.slice(0, 12)) }
