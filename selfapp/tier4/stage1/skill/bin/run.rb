#!/usr/bin/env ruby
# frozen_string_literal: true

# SYNTHETIC -- FICTIONAL STUDY. Part of the GenomicsChain self-application
# demonstration. The subject is a generated RNA-seq study with planted
# defects (variants V0-V8); it is not real data and not a real study.
#
# Body of the Tier-4 stage-1 Skill. Applies GenomicsChain's deterministic
# Tiers to a frozen input bundle and writes results/verdict_table.tsv in the
# working directory, by running the vendored copies of ddc_harness.rb and
# verdict_table.rb with the arguments the source computation gave them.
#
#   ruby skill/bin/run.rb --checker-root DIR --params FILE
#
# Run it from the working directory. It writes there and only there:
# harness_out/, results/verdict_table.tsv, skill_record.json. It writes
# nothing into the bundle, the generator, the variant spec, make_variants.rb
# or the checker root.
#
# Parameter 1 (generator, variant spec, make_variants.rb) never reaches the
# harness or the table script. It is identified by hash and read against the
# bundle after the table is written; what that reading finds goes into
# skill_record.json and does not change the exit status.
#
# Exit status: 0 table written; 2 stopped before anything ran; otherwise the
# failing step's own exit status (harness or table script).

require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'optparse'
require 'rbconfig'
require 'securerandom'
require_relative '../vendor/ddc_common'

PKG = File.expand_path('..', __dir__)
VENDOR = File.join(PKG, 'vendor')
HARNESS_OUT = 'harness_out'
TABLE = 'results/verdict_table.tsv'
RECORD = 'skill_record.json'
NOTICE = 'SYNTHETIC -- FICTIONAL STUDY. GenomicsChain self-application demonstration; ' \
         'not real data, not a real study.'

def stop(msg)
  warn "tier4-stage1 skill: #{msg} -- nothing run"
  exit 2
end

# --- arguments and parameter file -------------------------------------------

opts = {}
OptionParser.new do |o|
  o.on('--checker-root DIR') { |v| opts[:root] = v }
  o.on('--params FILE') { |v| opts[:params] = v }
end.parse!
stop 'usage: run.rb --checker-root DIR --params FILE' unless opts[:root] && opts[:params]
stop "checker root #{opts[:root]} is not a directory" unless File.directory?(opts[:root])
stop "parameter file #{opts[:params]} is not a file" unless File.file?(opts[:params])

# Mirrors params.schema.json by hand (standard library only): exactly the two
# parameters, parameter 1 exactly its three paths, every value a non-empty
# string. Relative paths resolve against the parameter file's directory.
params = begin
  JSON.parse(File.read(opts[:params]))
rescue JSON::ParserError => e
  stop "parameter file is not JSON: #{e.message}"
end
stop 'parameter file must hold exactly subject_generation and input_bundle' unless
  params.is_a?(Hash) && params.keys.sort == %w[input_bundle subject_generation]
gen = params['subject_generation']
stop 'subject_generation must hold exactly generator_dir, variant_spec, make_variants' unless
  gen.is_a?(Hash) && gen.keys.sort == %w[generator_dir make_variants variant_spec]
[gen['generator_dir'], gen['variant_spec'], gen['make_variants'], params['input_bundle']].each do |v|
  stop 'every parameter path must be a non-empty string' unless v.is_a?(String) && !v.empty?
end
base = File.dirname(File.expand_path(opts[:params]))
resolve = ->(p) { File.expand_path(p, base) }
generator_dir = resolve.call(gen['generator_dir'])
spec_path = resolve.call(gen['variant_spec'])
make_variants = resolve.call(gen['make_variants'])
bundle = resolve.call(params['input_bundle'])
stop "generator_dir #{generator_dir} is not a directory" unless File.directory?(generator_dir)
stop "variant_spec #{spec_path} is not a file" unless File.file?(spec_path)
stop "make_variants #{make_variants} is not a file" unless File.file?(make_variants)
stop "input_bundle #{bundle} has no inputs_manifest.json" unless File.file?(File.join(bundle, 'inputs_manifest.json'))
spec = begin
  JSON.parse(File.read(spec_path))
rescue JSON::ParserError => e
  stop "variant spec is not JSON: #{e.message}"
end
stop 'variant spec lacks base.id, base.tree_sha256 or variants[].id' unless
  spec.is_a?(Hash) && spec.dig('base', 'id') && spec.dig('base', 'tree_sha256') &&
  spec['variants'].is_a?(Array) && spec['variants'].all? { |v| v.is_a?(Hash) && v['id'] }

# --- preconditions on the package and the working directory -----------------

provenance = JSON.parse(File.read(File.join(PKG, 'provenance.json')))
provenance.fetch('copies').each do |c|
  got = Digest::SHA256.file(File.join(PKG, c.fetch('package_path'))).hexdigest
  stop "#{c['package_path']} has sha256 #{got}, provenance.json says #{c['sha256']}" unless got == c.fetch('sha256')
end

[HARNESS_OUT, TABLE, RECORD].each { |p| stop "#{p} already exists in the working directory" if File.exist?(p) }
cwd = File.realpath(Dir.pwd)
{ 'input bundle' => bundle, 'generator' => generator_dir, 'checker root' => opts[:root] }.each do |name, dir|
  real = File.realpath(dir)
  stop "the working directory lies inside the #{name}" if cwd == real || cwd.start_with?("#{real}/")
end

checker_tree = begin
  DdcCommon.tree_sha256(DdcCommon.package_files(File.realpath(opts[:root])))
rescue ArgumentError => e
  stop e.message
end
generator_files = DdcCommon.tree_files(generator_dir)

record = {
  'notice' => NOTICE,
  'skill' => provenance.fetch('skill').slice('name', 'version'),
  'environment' => {
    'ruby' => RUBY_VERSION, 'ruby_platform' => RUBY_PLATFORM, 'ruby_executable' => RbConfig.ruby,
    'checker_root' => File.realpath(opts[:root]), 'checker_packages_tree_sha256' => checker_tree
  },
  'parameters' => {
    'subject_generation' => {
      'generator_dir' => generator_dir,
      'generator_tree_sha256' => DdcCommon.tree_sha256(generator_files),
      'generator_file_count' => generator_files.size,
      'variant_spec' => spec_path,
      'variant_spec_sha256' => Digest::SHA256.file(spec_path).hexdigest,
      'variant_spec_version' => spec['spec_version'],
      'variant_spec_base' => spec['base'].slice('id', 'tree_sha256'),
      'variant_spec_ids' => spec['variants'].map { |v| v['id'] },
      'make_variants' => make_variants,
      'make_variants_sha256' => Digest::SHA256.file(make_variants).hexdigest
    },
    'input_bundle' => {
      'dir' => bundle,
      'inputs_manifest_sha256' => Digest::SHA256.file(File.join(bundle, 'inputs_manifest.json')).hexdigest
    }
  },
  'steps' => []
}

def write_record(record)
  File.write(RECORD, "#{JSON.pretty_generate(record)}\n")
end

# --- the computation: the source command, run step by step ------------------
# ruby ddc_harness.rb --checker-root ROOT --inputs BUNDLE --out harness_out
#   && mkdir -p results && ruby verdict_table.rb harness_out results/verdict_table.tsv

steps = [
  [File.join(VENDOR, 'ddc_harness.rb'), '--checker-root', opts[:root], '--inputs', bundle, '--out', HARNESS_OUT],
  [File.join(VENDOR, 'verdict_table.rb'), HARNESS_OUT, TABLE]
]
steps.each_with_index do |argv, i|
  FileUtils.mkdir_p(File.dirname(TABLE)) if i == 1
  system(RbConfig.ruby, *argv)
  status = $?.exitstatus || 1
  record['steps'] << { 'script' => File.basename(argv.first), 'args' => argv.drop(1), 'exit' => status }
  next if status.zero?

  record['observations'] = 'not run: a step of the computation failed'
  write_record(record)
  exit status
end
record['table'] = { 'path' => TABLE, 'sha256_as_written' => Digest::SHA256.file(TABLE).hexdigest }

# --- parameter 1 read against parameter 2 (record only) ---------------------
# Runs after the table exists and reads only; nothing here can change it.

# Every directory that holds a file of the map, "" for the root.
def dirs_of(map)
  map.keys.flat_map { |rel| parts = rel.split('/')[0...-1]; (0..parts.size).map { |i| parts[0, i].join('/') } }.uniq
end

def subtree(map, dir)
  pre = dir.empty? ? '' : "#{dir}/"
  map.select { |rel, _| rel.start_with?(pre) }.map { |rel, sha| [rel.delete_prefix(pre), sha] }.sort_by { |r, _| r.b }
end

def observe(bundle, spec, generator_sha, make_variants, pkg)
  manifest = JSON.parse(File.read(File.join(bundle, 'inputs_manifest.json')))
  files = manifest.fetch('files') # verified against the bytes by the harness that just succeeded
  obs = { 'source_of_bundle_hashes' => 'inputs_manifest.json files, as the harness verified them in this run' }

  entries = %w[tier1 tier2_scan tier25 tier3].flat_map { |k| Array(manifest[k]).map { |e| [k, e] } }
  entries << ['tier2_adjudication', manifest['tier2_adjudication']] if manifest['tier2_adjudication']
  labels = entries.map { |_, e| e['variant'] }.compact.uniq.sort_by(&:b)
  spec_ids = [spec['base']['id']] + spec['variants'].map { |v| v['id'] }
  obs['variant_labels'] = {
    'in_bundle' => labels,
    'declared_by_spec' => labels & spec_ids,
    'variant_form_not_declared_by_spec' => labels.grep(/\AV\d+\z/) - spec_ids,
    'other_labels' => labels.grep_v(/\AV\d+\z/)
  }

  obs['generator_manifests_in_bundle'] = files.keys.select { |r| File.basename(r) == 'generator_manifest.json' }
                                              .sort_by(&:b).map do |rel|
    stated = JSON.parse(File.read(File.join(bundle, rel))).dig('generator', 'tree_sha256')
    { 'path' => rel, 'generator_tree_sha256' => stated, 'equals_parameter' => stated == generator_sha }
  end

  dirs_by_tree = dirs_of(files).sort_by(&:b).group_by { |d| DdcCommon.tree_sha256(subtree(files, d)) }
  base_dirs = dirs_by_tree.fetch(spec['base']['tree_sha256'], [])
  obs['spec_base_found_at'] = base_dirs
  if base_dirs.empty?
    obs['variant_plan'] = 'not run: no bundle directory has the spec base tree_sha256'
    return obs
  end

  # make_variants.rb plans (never writes) each variant from the base found in
  # the bundle. Execution records are dropped from the in-memory spec: they
  # name repository paths outside the bundle and are not part of a variant tree.
  planned_spec = JSON.parse(JSON.generate(spec))
  planned_spec['base']['path'] = base_dirs.first
  planned_spec['output_root'] = ".tier4_stage1_never_written_#{SecureRandom.hex(8)}"
  planned_spec['variants'].each { |v| v.delete('execution_record') }
  out, err, st = Open3.capture3(RbConfig.ruby, File.join(pkg, 'bin', 'plan_variants.rb'), make_variants, bundle,
                                stdin_data: JSON.generate(planned_spec))
  unless st.success?
    obs['variant_plan'] = "not run: make_variants.rb planning failed: #{err.strip.lines.last}"
    return obs
  end
  obs['variant_plan'] = "planned from #{base_dirs.first} (execution_record entries dropped in memory)"

  base_map = subtree(files, base_dirs.first).to_h
  trees = { spec['base']['id'] => base_map }
  JSON.parse(out).each { |id, changed| trees[id] = base_map.merge(changed) }
  dir_index = Hash.new { |h, k| h[k] = [] }
  file_index = Hash.new { |h, k| h[k] = [] }
  trees.each do |id, map|
    dirs_of(map).each { |d| dir_index[DdcCommon.tree_sha256(subtree(map, d))] << "#{id}:#{d.empty? ? '.' : d}" }
    map.each { |rel, sha| file_index[sha] << "#{id}:#{rel}" }
  end
  # Each planned variant, whole, against every directory of the bundle.
  obs['variant_trees'] = trees.transform_values do |m|
    sha = DdcCommon.tree_sha256(m.sort_by { |r, _| r.b })
    { 'tree_sha256' => sha, 'bundle_dirs_byte_identical' => dirs_by_tree.fetch(sha, []) }
  end

  # Each path the harness reads, against the planned variant trees. Paths that
  # are not part of a subject (recorded exchanges, BCOs, frozen run
  # directories) are expected to match nothing.
  path_fields = { 'tier1' => %w[exchange args], 'tier2_scan' => %w[repo], 'tier25' => %w[bco], 'tier3' => %w[workdirs] }
  obs['harness_inputs_vs_variant_trees'] = entries.flat_map do |kind, e|
    path_fields.fetch(kind, []).flat_map { |f| Array(e[f]).map { |p| [f, p] } }.map do |field, rel|
      rel = rel.delete_suffix('/')
      matches = files.key?(rel) ? file_index[files[rel]] : dir_index[DdcCommon.tree_sha256(subtree(files, rel))]
      { 'kind' => kind, 'variant' => e['variant'], 'field' => field, 'path' => rel,
        'byte_identical_to' => matches.sort_by(&:b),
        'same_label_among_them' => matches.any? { |m| m.start_with?("#{e['variant']}:") } }
    end
  end
  obs
end

record['observations'] = begin
  observe(bundle, spec, record.dig('parameters', 'subject_generation', 'generator_tree_sha256'), make_variants, PKG)
rescue StandardError => e
  { 'error' => "#{e.class}: #{e.message}" }
end
write_record(record)
puts "table #{TABLE} sha256 #{record['table']['sha256_as_written']}; record #{RECORD}"
