#!/usr/bin/env ruby
# frozen_string_literal: true
#
# gc_prov_write — writes a provenance bundle, and fills in one that was
# written thin (design v0.1 §4.1, §9 U1b, §13.4-1).
#
# Two faces, one tool:
#
#   producer   --plan plan.json
#              A computation's stages, described by whoever ran it, become a
#              BioCompute Object. Shell, R, Python, a Tier-3 executor — the
#              adapter reads the FORMAT, not Nextflow, so nothing here is tied
#              to one engine. Versions, image digests and file checksums are
#              collected from this machine; what cannot be collected is left
#              out and the grade falls, which is the whole point of the scale.
#
#   enricher   --from-nextflow-run <launch_dir>
#              nf-prov 1.7.0 writes no tool versions, no containers and no
#              checksums (U0, design §13) — a bundle that grades `absent`. All
#              of it is still in the run directory: versions.yml, each task's
#              .command.run, the image digests, the files. This reads them
#              back and writes them where the adapter looks.
#
# Lives in bin/, not tools/: `Skillset#load!` requires every `tools/*.rb` on
# every node, so a CLI's option parsing would run when the anchor starts
# (design §7, review round 3). The logic is in lib/ and is callable from a
# Tier-3 executor without this file.
#
# Usage
#   ruby genomicschain_prov/bin/gc_prov_write.rb --plan plan.json --out bco.json
#   ruby genomicschain_prov/bin/gc_prov_write.rb --plan plan.json --no-checksums
#   ruby genomicschain_prov/bin/gc_prov_write.rb --from-nextflow-run /tmp/run \
#        --container-digests digests.txt --out bco.json
#
# The bundle goes to --out (or stdout). What was and was not collected goes to
# stderr, always: a bundle is worth what was gathered into it, and the one
# moment to see the gaps is before it is signed.

require 'json'
require 'optparse'

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'genomicschain_prov'
require 'genomicschain_prov/writer/environment'
require 'genomicschain_prov/writer/nextflow_run'

module GcProvWrite
  W = GenomicsChainProv::Writer
  Bco = GenomicsChainProv::Adapters::Bco
  Predicate = GenomicsChainProv::Predicate

  module_function

  def options(argv)
    opts = { checksums: true, docker: true, run_version_commands: false, grade: true }
    parser = OptionParser.new do |o|
      o.banner = 'Usage: gc_prov_write.rb --plan PLAN | --from-nextflow-run DIR [options]'
      o.on('--plan PATH', 'a plan (JSON or YAML) naming the stages of a computation') { |v| opts[:plan] = v }
      o.on('--from-nextflow-run DIR', 'a Nextflow launch directory to read back') { |v| opts[:launch] = v }
      o.on('--out PATH', 'where to write the bundle (default: stdout)') { |v| opts[:out] = v }
      o.on('--base-dir DIR', 'where the plan\'s relative locators point (default: the plan\'s directory)') { |v| opts[:base] = v }
      o.on('--bco PATH', 'the bundle to enrich (default: <launch_dir>/bco.json)') { |v| opts[:bco] = v }
      o.on('--versions PATH', 'a *_versions.yml (default: found under the launch directory)') { |v| opts[:versions] = v }
      o.on('--trace PATH', 'an execution trace carrying a container column') { |v| opts[:trace] = v }
      o.on('--work-dir NAME', 'the work directory under the launch dir (default: work)') { |v| opts[:work] = v }
      o.on('--container-digests PATH', 'a `docker images --digests` capture, for when Docker is not running') { |v| opts[:digests] = v }
      o.on('--script PATH', 'the workflow script, to checksum against the locator the bundle names') { |v| opts[:script] = v }
      o.on('--nextflow-jar PATH', 'the framework jar, when it is not where it is normally installed') { |v| opts[:jar] = v }
      o.on('--object-id ID', 'fix the object_id instead of generating one') { |v| opts[:object_id] = v }
      o.on('--created TIME', 'fix the created/modified timestamp') { |v| opts[:created] = v }
      o.on('--no-checksums', 'collect no checksums (nothing can then grade above floating)') { opts[:checksums] = false }
      o.on('--no-docker', 'do not ask Docker for image digests') { opts[:docker] = false }
      o.on('--run-version-commands', 'run the version_command lines the plan declares') { opts[:run_version_commands] = true }
      o.on('--no-grade', 'do not print the grade of what was written') { opts[:grade] = false }
      # (a description must not start with "--": OptionParser reads it as another switch)
      o.on('--no-platform', 'with a plan: do not record this machine\'s cpu architecture and OS') { opts[:platform] = false }
      o.on('--platform-of-this-machine',
           'with a Nextflow run: record this machine\'s cpu architecture and OS (off by default: ' \
           'the tasks may have run elsewhere)') { opts[:platform] = true }
      o.on('--zk-receipts PATH', 'a JSON array of {receipt, image_id, zkvm_version, step_number, input, output}; ' \
                                 'receipt paths are relative to that file') { |v| opts[:zk] = v }
      o.on('-h', '--help') { puts o; exit 0 }
    end
    parser.parse!(argv)
    opts
  end

  def run(argv)
    opts = options(argv)
    abort 'give exactly one of --plan PATH or --from-nextflow-run DIR' unless opts[:plan].nil? ^ opts[:launch].nil?

    result = opts[:plan] ? from_plan(opts) : from_nextflow(opts)
    emit(result['bco'], opts[:out])
    report(result['bco'], result['notes'], opts)
    0
  rescue W::PlanError, Bco::FormatError => e
    abort "gc_prov_write: #{e.message}"
  rescue Errno::ENOENT => e
    abort "gc_prov_write: #{e.message}"
  end

  def from_plan(opts)
    plan = W.normalise_plan(W.load_plan(File.read(opts[:plan])))
    base = opts[:base] || File.dirname(File.expand_path(opts[:plan]))
    digest_map = opts[:digests] ? GenomicsChainProv::Writer::NextflowRun.digests_from(File.read(opts[:digests])) : {}
    resolved = W::Environment.resolve!(plan, base_dir: base, checksums: opts[:checksums],
                                             run_version_commands: opts[:run_version_commands],
                                             docker: opts[:docker], digest_map: digest_map)
    # The plan's own statement of the platform wins; otherwise this machine,
    # which for --plan is normally the one that ran the stages (design
    # v0.1.12 §6.1). --no-platform leaves it out.
    platform = plan['platform'] || (opts[:platform] == false ? nil : W::Environment.platform)
    zk = W::Environment.zk_declarations(plan['zk_receipts'], base_dir: base)
    extra = zk_from_file(opts)
    { 'bco' => W.build(plan, checksums: resolved['checksums'],
                             object_id: opts[:object_id], created: opts[:created],
                             platform: platform, zk_receipts: zk['zk_receipts'] + extra['zk_receipts']),
      'notes' => resolved['notes'] + zk['notes'] + extra['notes'] }
  end

  def from_nextflow(opts)
    launch = opts[:launch]
    path = opts[:bco] || File.join(launch, 'bco.json')
    bco = JSON.parse(File.read(path))
    digest_map = opts[:digests] ? GenomicsChainProv::Writer::NextflowRun.digests_from(File.read(opts[:digests])) : {}
    extra = zk_from_file(opts)
    out = GenomicsChainProv::Writer::NextflowRun.read(
      launch, bco: bco, versions_path: opts[:versions], trace_path: opts[:trace],
      work_root: opts[:work] || 'work', digest_map: digest_map, script_path: opts[:script],
      jar_path: opts[:jar], checksums: opts[:checksums], docker: opts[:docker],
      platform: opts[:platform] == true ? W::Environment.platform : nil,
      zk_receipts: extra['zk_receipts']
    )
    out['notes'] += extra['notes']
    out['notes'] << 'no platform recorded: pass --platform-of-this-machine if the tasks ran here' unless opts[:platform] == true
    out
  end

  # --zk-receipts: the same entries a plan's `zk_receipts` holds, in a file of
  # their own so a Nextflow run can declare them too.
  def zk_from_file(opts)
    return { 'zk_receipts' => [], 'notes' => [] } unless opts[:zk]

    entries = W.normalise_zk_receipts(JSON.parse(File.read(opts[:zk])))
    W::Environment.zk_declarations(entries, base_dir: File.dirname(File.expand_path(opts[:zk])))
  rescue JSON::ParserError
    raise W::PlanError, '--zk-receipts is not valid JSON'
  end

  def emit(bco, out)
    text = JSON.pretty_generate(bco)
    out ? File.write(out, "#{text}\n") : puts(text)
  end

  # The grade is printed beside the notes because the two answer one question
  # together: what is in this bundle, and what did leaving the rest out cost.
  # It is this machine's reading, under this adapter and this predicate — the
  # anchor re-derives it from the bundle's own bytes and signs its own answer
  # (§6), and a version mismatch between the two is a refusal with the three
  # versions attached, not a silent difference.
  def report(bco, notes, opts)
    notes.each { |n| warn "  - #{n}" }
    return unless opts[:grade]

    np = Bco.parse(bco)
    graded = Predicate.grade(np)
    counts = graded['counts']
    warn "grade: #{graded['grade_overall']}  (coverage #{graded['coverage']} stages with their own environment)"
    warn "  by category: #{graded['grades'].map { |k, v| "#{k}=#{v}" }.join(' ')}"
    warn "  inputs #{counts['inputs_with_checksum']}/#{counts['inputs_total']} with a checksum, " \
         "#{counts['inputs_internal']} internal; software #{counts['software_total']}, " \
         "containers #{counts['containers_total']}; params #{counts['params_count']}/#{counts['params_total']}"
    # The anchor issues a Tier 2.5 record only at `immutable` (design v0.1.12
    # §6.1); saying so here is the cheapest place for the customer to learn it.
    unless graded['grade_overall'] == 'immutable'
      warn '  Tier 2.5 records only bundles graded immutable; this one would be refused'
    end
    warn "  platform: #{np.platform ? np.platform.values.compact.join(' ') : 'not recorded'}"
    Array(np.zk_receipts).each do |r|
      state = r['defects'].empty? ? 'declared' : "unusable (#{r['defects'].join(', ')})"
      warn "  zk receipt for stage #{r['stage'] || '?'}: #{state}"
    end
  end
end

exit GcProvWrite.run(ARGV) if $PROGRAM_NAME == __FILE__
