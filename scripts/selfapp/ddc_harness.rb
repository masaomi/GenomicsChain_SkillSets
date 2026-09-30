#!/usr/bin/env ruby
# frozen_string_literal: true

# The self-application DDC harness (design §6.4–§6.5, unit S4). Runs the
# checker found under --checker-root on the frozen inputs and writes one
# comparison body per Tier and variant, so the same script run on A (the
# installed checker) and on T (the checker rebuilt from source by another
# builder) yields two directories that `sha256sum` can compare.
#
#   ruby scripts/selfapp/ddc_harness.rb --checker-root DIR --inputs DIR --out DIR
#
# --checker-root holds the packages as directories (genomicschain_core/lib, …):
# `.kairos/skillsets` for A, the unpacked source archive for T.
# --inputs holds inputs_manifest.json and the files it names; every file is
# checked against the manifest before anything runs, and a difference stops
# the harness. Nothing here executes a subject: Tier 1 is replayed from a
# recorded LLM exchange, Tier 3 compares frozen output directories.
#
# Writes to --out: bodies/<kind>__<variant>.json (canonical bytes; the file's
# sha256 is the body digest), tier1_requests.json, loaded_files.txt,
# environment.json, errors.json. Exits 1 when any item failed; the items that
# did not fail are still written.

require 'fileutils'
require 'json'
require 'optparse'
require_relative 'ddc_common'

opts = {}
OptionParser.new do |o|
  o.on('--checker-root DIR') { |v| opts[:root] = v }
  o.on('--inputs DIR') { |v| opts[:inputs] = v }
  o.on('--out DIR') { |v| opts[:out] = v }
end.parse!
abort 'usage: ddc_harness.rb --checker-root DIR --inputs DIR --out DIR' unless opts.values_at(:root, :inputs, :out).all?
abort "#{opts[:out]} exists" if File.exist?(opts[:out])

ROOT = File.realpath(opts[:root])
INPUTS = File.realpath(opts[:inputs])
abort 'inputs must not lie inside the checker root' if INPUTS.start_with?("#{ROOT}/")

# The files the checker reads without requiring them (rubric, schemas) belong
# to what was loaded as much as its Ruby files do. Paths passed to IO's class
# methods read, binread, readlines, foreach and open (File inherits them) are
# noted (Pathname#read goes through File.read). Other reads are not — for
# example File.new, Kernel#open, IO.copy_stream, load, and reads inside C
# extensions. Only paths under the checker root are kept.
READS = []
module ReadTracker
  %i[read binread readlines foreach open].each do |m|
    define_method(m) do |*args, **kw, &blk|
      path = args.first
      READS << File.expand_path(path.to_path) if path.respond_to?(:to_path)
      READS << File.expand_path(path) if path.is_a?(String)
      super(*args, **kw, &blk)
    end
  end
end
IO.singleton_class.prepend(ReadTracker)

manifest = JSON.parse(File.read(File.join(INPUTS, 'inputs_manifest.json')))
actual = DdcCommon.tree_files(INPUTS).reject { |rel, _| rel == 'inputs_manifest.json' }
unless actual == manifest.fetch('files')
  diff = (actual.to_a - manifest['files'].to_a) + (manifest['files'].to_a - actual.to_a)
  abort "inputs differ from inputs_manifest.json: #{diff.map(&:first).uniq.first(10).join(', ')}"
end

DdcCommon::PACKAGES.each { |p| $LOAD_PATH.unshift(File.join(ROOT, p, 'lib')) }
require 'genomicschain_core'
require 'genomicschain_core/comparison_body'
require 'genomicschain_tier1'
require 'genomicschain_tier2'
require 'genomicschain_tier3'
require 'genomicschain_prov'

CB = KairosMcp::SkillSets::GenomicschainCore::ComparisonBody
out = opts[:out]
FileUtils.mkdir_p(File.join(out, 'bodies'))
errors = []
input = ->(rel) { File.join(INPUTS, rel) }
read_json = ->(rel) { JSON.parse(File.read(input.call(rel), encoding: 'UTF-8')) }
# One item failing is recorded and the rest still run: a body that could not
# be produced is a finding of the comparison, not a reason to hide the others.
def attempt(errors, name)
  yield
rescue StandardError => e
  errors << { 'item' => name, 'error' => "#{e.class}: #{e.message}" }
  nil
end

def write_body(out, errors, kind, variant, record)
  attempt(errors, "#{kind}__#{variant}") do
    File.binwrite(File.join(out, 'bodies', "#{kind}__#{variant}.json"), CB.digest(kind, record)['canonical'])
  end
end
canonical_sha = ->(obj) { KairosMcp::Manifest::CanonicalJson.sha256(JSON.parse(JSON.generate(obj))) }

reports = {}
requests = []
manifest.fetch('tier1', []).each do |t1|
  v = t1.fetch('variant')
  attempt(errors, "tier1_report__#{v}") do
    exchange = read_json.call(t1.fetch('exchange'))
    sent = nil
    llm = lambda do |req|
      sent = req
      exchange.fetch('response')
    end
    run = KairosMcp::SkillSets::GenomicschainTier1::Assess::Assessor.new(llm: llm).run(read_json.call(t1.fetch('args')))
    reports[v] = JSON.parse(run.fetch('report_json'))
    requests << { 'variant' => v, 'recorded_request_sha256' => canonical_sha.call(exchange.fetch('request')),
                  'replayed_request_sha256' => canonical_sha.call(sent.compact) }
  end
  write_body(out, errors, 'tier1_report', v, reports[v]) if reports[v]
end

scans = {}
manifest.fetch('tier2_scan', []).each do |t2|
  v = t2.fetch('variant')
  scans[v] = attempt(errors, "tier2_scan__#{v}") { GenomicsChainTier2::Scanner.new(input.call(t2.fetch('repo'))).scan }
  write_body(out, errors, 'tier2_scan', v, scans[v]) if scans[v]
end

if (adj = manifest['tier2_adjudication'])
  record = attempt(errors, "tier2_adjudication__#{adj.fetch('variant')}") do
    GenomicsChainTier2::Adjudicator.new(reports.fetch(adj.fetch('tier1')), scans.fetch(adj.fetch('scan'))).adjudicate
  end
  write_body(out, errors, 'tier2_adjudication', adj['variant'], record) if record
end

manifest.fetch('tier25', []).each do |t25|
  v = t25.fetch('variant')
  graded = attempt(errors, "tier25_grade__#{v}") do
    GenomicsChainProv::Predicate.grade(GenomicsChainProv::Adapters::Bco.parse(read_json.call(t25.fetch('bco'))))
  end
  write_body(out, errors, 'tier25_grade', v, graded) if graded
end

manifest.fetch('tier3', []).each do |t3|
  v = t3.fetch('variant')
  compared = attempt(errors, "tier3_compare__#{v}") do
    KairosMcp::SkillSets::GenomicschainTier3::Tier3Executor.compare_frozen(
      workdirs: t3.fetch('workdirs').map { |d| input.call(d) }, expected_output: t3['expected_output']
    )
  end
  write_body(out, errors, 'tier3_compare', v, compared) if compared
end

real = ->(p) { File.exist?(p) ? File.realpath(p) : p }
in_package = ->(p) { DdcCommon::PACKAGES.any? { |pkg| p.start_with?("#{ROOT}/#{pkg}/") } }
loaded = ($LOADED_FEATURES + READS).map(&real).select { |p| in_package.call(p) && File.file?(p) }.uniq.sort_by(&:b)
File.write(File.join(out, 'loaded_files.txt'),
           loaded.map { |p| "#{Digest::SHA256.file(p).hexdigest}  #{p.delete_prefix("#{ROOT}/")}\n" }.join)

# Gems whose files were actually required, not every gem a bundle activated.
# A default gem (json, psych) is loaded from Ruby's own library directory and
# lists its files relative to it; json's version is the one §6.4 needs most.
features = $LOADED_FEATURES.map(&real)
libdirs = RbConfig::CONFIG.values_at('rubylibdir', 'archdir').map(&real)
gems = Gem.loaded_specs.values.select do |spec|
  spec.full_require_paths.map(&real).any? { |rp| features.any? { |f| f.start_with?("#{rp}/") } } ||
    (spec.default_gem? && spec.files.any? { |f| libdirs.any? { |d| features.include?(File.join(d, f)) } })
end
env = {
  'ruby' => RUBY_VERSION, 'ruby_platform' => RUBY_PLATFORM,
  'gems_loaded' => gems.to_h { |s| [s.name, s.version.to_s] }.sort.to_h,
  'checker_packages_tree_sha256' => DdcCommon.tree_sha256(DdcCommon.package_files(ROOT)),
  'comparison_body_version' => CB::VERSION,
  'inputs_manifest_sha256' => Digest::SHA256.file(File.join(INPUTS, 'inputs_manifest.json')).hexdigest,
  'harness_sha256' => Digest::SHA256.file(__FILE__).hexdigest
}
File.write(File.join(out, 'environment.json'), "#{JSON.pretty_generate(env)}\n")
File.write(File.join(out, 'tier1_requests.json'), "#{JSON.pretty_generate(requests)}\n")
File.write(File.join(out, 'errors.json'), "#{JSON.pretty_generate(errors)}\n")

puts "bodies #{Dir.children(File.join(out, 'bodies')).size}, errors #{errors.size}, loaded files #{loaded.size}"
exit(errors.empty? ? 0 : 1)
