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
#   ruby genomicschain_prov/bin/gc_prov_write.rb --plan plan.json --resources measured.json
#
# Option 2 (design v0.1.16 §5, §6.1, §8): the customer's order is key →
# proof → bundle, so the key is made first, on its own, and kept apart from
# the bundle:
#   ruby genomicschain_prov/bin/gc_prov_write.rb --new-commitment-key ~/keys/run42.key
#   (prove each covered step with that key: the checker writes gc-zk-journal-0.2)
#   ruby genomicschain_prov/bin/gc_prov_write.rb --plan plan.json --commitment-key ~/keys/run42.key --out bco.json
# With --commitment-key every file fingerprint in the bundle is the salted
# gc-commitment-0.1 one (hmac_sha256), no sha1_checksum or plain SHA-256 is
# written, the key's name (key_id) is written once, and every receipt is
# declared gc-zk-journal-0.2. The key is read, checked to be 32 bytes, and
# never written into the bundle, a note or the terminal. One key per bundle.
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
require 'genomicschain_prov/writer/resources_input'
require 'genomicschain_prov/commitment'

module GcProvWrite
  W = GenomicsChainProv::Writer
  Bco = GenomicsChainProv::Adapters::Bco
  Predicate = GenomicsChainProv::Predicate
  Commitment = GenomicsChainProv::Commitment

  module_function

  def options(argv)
    opts = { checksums: true, docker: true, run_version_commands: false, grade: true, resources: [] }
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
      o.on('--no-machine', 'with a plan: do not record this machine\'s CPU, memory, disk and GPUs') { opts[:machine] = false }
      o.on('--machine-of-this-machine',
           'with a Nextflow run: record this machine\'s CPU, memory, disk and GPUs (off by default: ' \
           'the tasks may have run elsewhere)') { opts[:machine] = true }
      o.on('--resources PATH', 'a gc-resources-input-0.1 file of per-stage requested and observed values ' \
                               '(repeatable)') { |v| opts[:resources] << v }
      o.on('--new-commitment-key PATH', 'write a fresh 32-byte gc-commitment-0.1 key to PATH (owner-only, never ' \
                                         'overwritten) and stop; keep it apart from the bundle') { |v| opts[:new_key] = v }
      o.on('--commitment-key PATH', 'option 2: write salted fingerprints under the 32-byte key in PATH and declare ' \
                                     'the receipts gc-zk-journal-0.2') { |v| opts[:key] = v }
      o.on('-h', '--help') { puts o; exit 0 }
    end
    parser.parse!(argv)
    opts
  end

  def run(argv)
    opts = options(argv)
    return new_key(opts) if opts[:new_key]

    abort 'give exactly one of --plan PATH or --from-nextflow-run DIR' unless opts[:plan].nil? ^ opts[:launch].nil?

    opts[:commitment_key] = load_key(opts) if opts[:key]
    result = opts[:plan] ? from_plan(opts) : from_nextflow(opts)
    emit(result['bco'], opts[:out])
    report(result['bco'], result['notes'], opts)
    0
  rescue W::PlanError, Bco::FormatError, Commitment::KeyError => e
    abort "gc_prov_write: #{e.message}"
  rescue Errno::ENOENT => e
    abort "gc_prov_write: #{e.message}"
  end

  # Standalone: the key exists before the proof that uses it (§8).
  def new_key(opts)
    if opts[:plan] || opts[:launch]
      abort 'gc_prov_write: --new-commitment-key makes the key only; prove with it, then write the bundle with ' \
            '--commitment-key'
    end
    key = Commitment.generate_key
    Commitment.write_key_file(opts[:new_key], key)
    warn "wrote a new #{Commitment::RULE} key to #{opts[:new_key]} (owner-only). Keep it apart from the bundle and " \
         'take a copy: without it nobody can check the fingerprints, and GenomicsChain does not hold it.'
    0
  rescue Commitment::KeyError => e
    abort "gc_prov_write: #{e.message}"
  end

  # The key is read and checked here and passed on in memory only. An --out
  # that names the key file is refused before anything is written: the key
  # never travels with the bundle, and writing the bundle there would
  # truncate the key and orphan every fingerprint made under it. "Names" is
  # decided by the file system (same device and inode, File.identical?), not
  # by the path string, so a symlink, a hard link, a `.`/`..` spelling or a
  # case variant on a case-insensitive volume is caught too (round-1
  # implementation review, H3).
  def load_key(opts)
    if opts[:out] && (File.expand_path(opts[:out]) == File.expand_path(opts[:key]) ||
                      File.identical?(opts[:out], opts[:key]))
      raise Commitment::KeyError, "#{Commitment::RULE}: the key file and the bundle cannot be the same file"
    end
    Commitment.read_key_file(opts[:key])
  end

  def journal(opts)
    opts[:commitment_key] ? W::ZK_JOURNAL_V02 : W::ZK_JOURNAL
  end

  def commitment(opts)
    opts[:commitment_key] && Commitment.declaration(opts[:commitment_key])
  end

  def from_plan(opts)
    plan = W.normalise_plan(W.load_plan(File.read(opts[:plan])))
    base = opts[:base] || File.dirname(File.expand_path(opts[:plan]))
    digest_map = opts[:digests] ? GenomicsChainProv::Writer::NextflowRun.digests_from(File.read(opts[:digests])) : {}
    resolved = W::Environment.resolve!(plan, base_dir: base, checksums: opts[:checksums],
                                             run_version_commands: opts[:run_version_commands],
                                             docker: opts[:docker], digest_map: digest_map,
                                             commitment_key: opts[:commitment_key])
    # The plan's own statement of the platform wins; otherwise this machine,
    # which for --plan is normally the one that ran the stages (design
    # v0.1.12 §6.1). --no-platform leaves it out.
    platform = plan['platform'] || (opts[:platform] == false ? nil : W::Environment.platform)
    zk = W::Environment.zk_declarations(plan['zk_receipts'], base_dir: base, journal: journal(opts))
    extra = zk_from_file(opts)
    machine = plan_machine(plan, base, opts)
    inputs = resources_from_files(opts)
    resources = W.resources_block(machine: machine['machine'],
                                  steps: W.plan_resource_steps(plan) + inputs['steps'])
    { 'bco' => W.build(plan, checksums: resolved['checksums'],
                             object_id: opts[:object_id], created: opts[:created],
                             platform: platform, zk_receipts: zk['zk_receipts'] + extra['zk_receipts'],
                             resources: resources, commitment: commitment(opts)),
      'notes' => resolved['notes'] + zk['notes'] + extra['notes'] + machine['notes'] + inputs['notes'] }
  end

  # The plan's own statement of the machine wins, as with the platform;
  # otherwise this machine, which for --plan is normally the one that ran the
  # stages (design v0.1.14 §6.2 (4)). --no-machine leaves it out. A probe on
  # macOS of a run whose stages used containers (any form, Writer.plan_uses_containers?)
  # drops the GPU lines: a container there runs in a Linux virtual machine that
  # cannot use the host's GPU.
  def plan_machine(plan, base, opts)
    return { 'machine' => plan['machine'], 'notes' => [] } if plan['machine']
    return { 'machine' => nil, 'notes' => [] } if opts[:machine] == false

    probed = W::Environment.machine(work_dir: base)
    if W.plan_uses_containers?(plan) && Etc.uname[:sysname] == 'Darwin'
      probed['machine'] = W::Environment.without_host_gpus(probed['machine'], probed['notes'])
    end
    probed
  end

  def resources_from_files(opts)
    opts[:resources].each_with_object({ 'steps' => [], 'notes' => [] }) do |path, acc|
      r = W::ResourcesInput.read(File.read(path), name: File.basename(path))
      acc['steps'].concat(r['steps'])
      acc['notes'].concat(r['notes'])
    end
  end

  def from_nextflow(opts)
    launch = opts[:launch]
    path = opts[:bco] || File.join(launch, 'bco.json')
    bco = JSON.parse(File.read(path))
    digest_map = opts[:digests] ? GenomicsChainProv::Writer::NextflowRun.digests_from(File.read(opts[:digests])) : {}
    extra = zk_from_file(opts)
    inputs = resources_from_files(opts)
    machine = opts[:machine] == true ? W::Environment.machine(work_dir: launch) : { 'machine' => nil, 'notes' => [] }
    out = GenomicsChainProv::Writer::NextflowRun.read(
      launch, bco: bco, versions_path: opts[:versions], trace_path: opts[:trace],
      work_root: opts[:work] || 'work', digest_map: digest_map, script_path: opts[:script],
      jar_path: opts[:jar], checksums: opts[:checksums], docker: opts[:docker],
      platform: opts[:platform] == true ? W::Environment.platform : nil,
      zk_receipts: extra['zk_receipts'], machine: machine['machine'], resource_steps: inputs['steps'],
      commitment_key: opts[:commitment_key]
    )
    out['notes'] += extra['notes'] + machine['notes'] + inputs['notes']
    out['notes'] << 'no platform recorded: pass --platform-of-this-machine if the tasks ran here' unless opts[:platform] == true
    out['notes'] << 'no machine recorded: pass --machine-of-this-machine if the tasks ran here' unless opts[:machine] == true
    out
  end

  # --zk-receipts: the same entries a plan's `zk_receipts` holds, in a file of
  # their own so a Nextflow run can declare them too.
  def zk_from_file(opts)
    return { 'zk_receipts' => [], 'notes' => [] } unless opts[:zk]

    entries = W.normalise_zk_receipts(JSON.parse(File.read(opts[:zk])))
    W::Environment.zk_declarations(entries, base_dir: File.dirname(File.expand_path(opts[:zk])), journal: journal(opts))
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
    # Since v0.1.13 the anchor records a bundle at any grade and carries the
    # grade as computed; the line that said "immutable only" was left over
    # from v0.1.12 and is gone.
    warn "  platform: #{np.platform ? np.platform.values.compact.join(' ') : 'not recorded'}"
    res = GenomicsChainProv::Resources.derive(JSON.generate(bco), np.stages)
    r = res['signed']
    warn "  resources: #{r['grade_resources']} (not part of the grade above) — requested on " \
         "#{r['stages_with_requested_resources']}/#{counts['stages_total']} stages, observed on " \
         "#{r['stages_with_observed_resources']}/#{counts['stages_total']}; machine " \
         "#{r['machine_source'] || 'not recorded'}; GPUs #{r['gpus_total'].nil? ? 'not looked for' : r['gpus_total']}"
    res['notes'].each { |n| warn "  - #{n}" }
    Array(np.zk_receipts).each do |r|
      state = r['defects'].empty? ? 'declared' : "unusable (#{r['defects'].join(', ')})"
      warn "  zk receipt for stage #{r['stage'] || '?'}: #{state}"
    end
  end
end

exit GcProvWrite.run(ARGV) if $PROGRAM_NAME == __FILE__
