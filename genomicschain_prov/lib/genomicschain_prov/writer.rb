# frozen_string_literal: true

require 'json'
require 'digest'
require 'time'
require 'securerandom'

module GenomicsChainProv
  # Writer — the producer half of `gc_prov_write` (design v0.1 §4.1, §9 U1b):
  # a plan naming the stages of a computation becomes a BioCompute Object that
  # `Adapters::Bco` reads back.
  #
  # Why a producer at all. nf-prov is one way to get a bundle, and making it
  # the only way would put a third-party dependency — "write everything in
  # Nextflow" — between a customer and the anchor. The adapter reads the
  # FORMAT (IEEE 2791), not one producer's habits, so a shell, R or Python
  # computation can reach the same record through this writer. Tier-3's own
  # executors use it to describe what they ran.
  #
  # What it will not do: invent. A value that was not collected is left out,
  # and the grade falls accordingly — `absent` for a category with nothing in
  # it, `local_path` for a path with no checksum. That is the whole point of
  # §5's scale: the grade rises exactly as far as what was actually gathered,
  # and a producer that omits a field must never outgrade one that fills it.
  #
  # This module is pure: a plan and a map of checksums in, a Hash out. Reading
  # files, running `--version` and asking Docker for a digest are
  # `Writer::Environment`; reading a Nextflow launch directory is
  # `Writer::NextflowRun`. Keeping the build pure is what lets the test assert
  # a whole bundle without a filesystem.
  module Writer
    class PlanError < StandardError; end

    # Named in the bundle's own extension block and therefore in the signed
    # identity as `producer_version` (§6). A change in what this writer puts
    # in a bundle is a change in what the record says produced it.
    # 0.2.0 (design v0.1.12): writes `platform` and `zk_receipts[]`.
    VERSION = 'prov-writer-0.2.0'
    # The one zkVM and the one journal shape v0.1.12 can verify (§6.1).
    ZK_VM_NAME = 'risc0-zkvm'
    ZK_JOURNAL = 'gc-zk-journal-0.1'
    SPEC_VERSION = 'https://w3id.org/ieee/ieee-2791-schema/2791object.json'
    # Decided 2026-09-20 (design §10-1, §13.4-6). The schema file lands in
    # `genomicschain_core/schemas/` with the v0.1 implementation; publishing it
    # is tied to the anchor public key, before anything is sold.
    EXTENSION_SCHEMA = 'https://genomicschain.ch/schemas/bco_extension_genomicschain_v0_1.json'
    PRODUCER_NAME = 'gc_prov_write'

    module_function

    # @param plan [Hash] a plan already through `normalise_plan`
    # @param checksums [Hash] locator => {'sha1' =>, 'sha256' =>}, from Environment
    # @param object_id [String, nil] overrides the random id (design §13.4-5:
    #   re-running the writer gives a different bundle, and v0.1 does not ask
    #   for byte-identity — the digest names THIS file)
    # @param created [String, nil] overrides the timestamp, for the same reason
    # @param platform [Hash, nil] {cpu_architecture, os_name, os_release} — the
    #   plan's own statement, or this machine's (Environment.platform), or nil
    # @param zk_receipts [Array<Hash>] declarations from `zk_declaration`
    # @return [Hash] the BCO
    def build(plan, checksums: {}, object_id: nil, created: nil, platform: nil, zk_receipts: [])
      now = created || Time.now.utc.iso8601
      steps = plan['stages'].sort_by { |s| s['step_number'] }
      bco = {
        'object_id' => object_id || "urn:uuid:#{SecureRandom.uuid}",
        'spec_version' => SPEC_VERSION,
        'etag' => nil,
        'provenance_domain' => provenance_domain(plan, now),
        'usability_domain' => [plan['description'] || plan['name']],
        'extension_domain' => [extension_block(checksums, platform: platform, zk_receipts: zk_receipts)],
        'description_domain' => {
          'keywords' => plan['keywords'] || [],
          'pipeline_steps' => steps.map { |s| pipeline_step(s) }
        },
        'execution_domain' => execution_domain(plan),
        'parametric_domain' => plan['params'],
        'io_domain' => io_domain(plan, checksums),
        'error_domain' => {}
      }
      bco['etag'] = etag(bco)
      bco
    end

    # --- the domains ----------------------------------------------------------

    def provenance_domain(plan, now)
      {
        'name' => plan['name'],
        'version' => plan['version'] || '1.0',
        'license' => plan['license'] || 'UNLICENSED',
        'created' => now,
        'modified' => now,
        # Left empty when the plan names nobody. The standard wants a
        # contributor; inventing one would put a name in a signed record that
        # nobody put there.
        'contributors' => plan['contributors'] || [],
        'review' => []
      }
    end

    # The runtime, and ONLY the runtime, goes in `software_prerequisites`.
    # Per-stage tools go in each stage's `prerequisite[]` and nowhere else
    # (design §13.4-1, review round 2): copied up to the workflow level they
    # become a fallback that covers every stage, and the per-stage coverage the
    # claim carries — `stages_with_own_environment/stages_total` — stops
    # showing which stages actually declared anything. This writer and the
    # nf-prov enricher follow the same rule for the same reason.
    def execution_domain(plan)
      rt = plan['runtime']
      script = plan['script']
      {
        'script' => script ? [{ 'uri' => compact_h('uri' => script['uri'], 'filename' => script['filename']) }] : [],
        'script_driver' => rt && rt['engine'],
        'software_prerequisites' => rt ? [tool_ref(rt.merge('name' => rt['engine']))] : [],
        'external_data_endpoints' => [],
        'environment_variables' => {}
      }
    end

    def pipeline_step(stage)
      {
        'step_number' => stage['step_number'],
        'name' => stage['name'],
        'description' => stage['description'],
        # Always present, even empty: §13.4-3 decides which inputs this run
        # produced before reading them by comparing the positions at which a
        # locator appears in an output_list and an input_list. A missing list
        # is not "no evidence" to a reader that has to distinguish the two.
        'input_list' => stage['inputs'].map { |f| { 'uri' => f['uri'] } },
        'output_list' => stage['outputs'].map { |f| { 'uri' => f['uri'] } },
        'prerequisite' => stage['tools'].map { |t| tool_ref(t) }
      }.compact
    end

    def io_domain(plan, checksums)
      inputs = plan['inputs'] || dedupe(plan['stages'].flat_map { |s| s['inputs'] })
      outputs = plan['outputs'] || dedupe(plan['stages'].flat_map { |s| s['outputs'] })
      {
        'input_subdomain' => inputs.map { |f| io_entry(f, checksums) },
        'output_subdomain' => outputs.map { |f| io_entry(f, checksums).merge(compact_h('mediatype' => f['mediatype'])) }
      }
    end

    # The standard's checksum field is SHA-1, so that is what goes on the entry;
    # the SHA-256 of the same file goes in the extension's `checksums[]` keyed
    # by the same locator, which is the join the adapter reads (design §4, §13.4-1).
    def io_entry(file, checksums)
      sums = checksums[file['uri']] || {}
      { 'uri' => compact_h('uri' => file['uri'], 'filename' => file['filename'],
                           'sha1_checksum' => sums['sha1']) }
    end

    # `{name, version, uri}` — the shape `software_prerequisites` uses in the
    # standard, which the adapter also reads on a step's `prerequisite[]`
    # (design §13.4-1 writes a version there; the 2791 schema does not define
    # one on that field, and `bundle_schema_conformance` stays `not_checked`
    # on the record either way, §6).
    def tool_ref(tool)
      compact_h('name' => tool['name'], 'version' => tool['version'],
                'uri' => (tool['uri'] ? { 'uri' => tool['uri'] } : nil))
    end

    # One block, naming this writer as the producer and carrying every SHA-256
    # keyed by the locator of the thing it digests — inputs, outputs, tools,
    # the runtime and the workflow script alike. The adapter joins all of them
    # on the exact locator, which is why the key has to be the locator the
    # entry itself carries and not a path on this machine.
    #
    # `platform` and `zk_receipts` (design v0.1.12 §6.1) appear only when there
    # is something to say: a bundle with neither is the same shape a 0.1.0
    # writer produced, apart from the producer version.
    def extension_block(checksums, platform: nil, zk_receipts: [])
      rows = checksums.keys.sort.filter_map do |locator|
        sha256 = checksums[locator]['sha256']
        { 'uri' => locator, 'sha256' => sha256 } if sha256
      end
      ext = {
        'producer' => { 'name' => PRODUCER_NAME, 'version' => VERSION },
        'checksums' => rows
      }
      ext['platform'] = platform if platform
      ext['zk_receipts'] = zk_receipts unless zk_receipts.nil? || zk_receipts.empty?
      { 'extension_schema' => EXTENSION_SCHEMA, 'genomicschain_extension' => ext }
    end

    # One receipt declaration in the shape the adapter reads (§6.1). The
    # receipt's own SHA-256 is measured by Environment from the file; the rest
    # is the plan's statement. The journal convention is not a choice: it is
    # the only one the anchor can link to the bundle.
    def zk_declaration(entry, receipt_sha256)
      { 'sha256' => receipt_sha256,
        'image_id' => entry['image_id'],
        'zkvm' => { 'name' => ZK_VM_NAME, 'version' => entry['zkvm_version'] },
        'step_number' => entry['step_number'],
        'journal' => ZK_JOURNAL,
        'input_uri' => entry['input'],
        'output_uri' => entry['output'] }
    end

    # Not the bundle digest. §6's `bundle_digest` is the canonical-JSON SHA-256
    # of the whole file, taken by `gc_prov_check` and recomputed by the anchor;
    # this is the standard's own per-object field, and like nf-prov's it is a
    # producer's hash. Stated here so nobody later mistakes one for the other:
    # SHA-256 over `JSON.generate` of the object with `object_id` and `etag`
    # removed, keys in the order this writer emits them.
    def etag(bco)
      Digest::SHA256.hexdigest(JSON.generate(bco.reject { |k, _| %w[object_id etag].include?(k) }))
    end

    # --- the plan -------------------------------------------------------------

    # Accepts JSON or the flow-less YAML subset people actually write plans in.
    # YAML is tried second because a JSON document is also valid YAML but
    # Psych turns an unquoted `1.10` into the Float 1.1 — a version string
    # silently losing a digit is exactly the kind of drift a signed grade
    # must not inherit.
    def load_plan(text)
      JSON.parse(text)
    rescue JSON::ParserError
      require 'yaml'
      begin
        YAML.safe_load(text, permitted_classes: [], aliases: false)
      rescue StandardError
        raise PlanError, 'plan is neither JSON nor YAML'
      end
    end

    def normalise_plan(raw)
      raise PlanError, 'plan is not an object' unless raw.is_a?(Hash)

      name = str(raw['name'])
      raise PlanError, 'plan needs a name' if name.nil?

      stages = raw['stages']
      raise PlanError, 'plan needs a stages array with at least one stage' unless stages.is_a?(Array) && !stages.empty?

      plan = {
        'name' => name,
        'version' => str(raw['version']),
        'description' => str(raw['description']),
        'license' => str(raw['license']),
        'keywords' => Array(raw['keywords']).filter_map { |k| str(k) },
        'contributors' => raw['contributors'].is_a?(Array) ? raw['contributors'] : nil,
        'script' => raw['script'].nil? ? nil : normalise_file(raw['script'], 'script'),
        'runtime' => raw['runtime'].nil? ? nil : normalise_runtime(raw['runtime']),
        'params' => normalise_params(raw['params']),
        'stages' => stages.each_with_index.map { |s, i| normalise_stage(s, i) }
      }
      plan['inputs'] = normalise_files(raw['inputs'], 'inputs') if raw.key?('inputs')
      plan['outputs'] = normalise_files(raw['outputs'], 'outputs') if raw.key?('outputs')
      plan['platform'] = normalise_platform(raw['platform']) if raw.key?('platform')
      plan['zk_receipts'] = normalise_zk_receipts(raw['zk_receipts']) if raw.key?('zk_receipts')
      numbers = plan['stages'].map { |s| s['step_number'] }
      raise PlanError, 'two stages share a step_number' if numbers.uniq.length != numbers.length

      plan
    end

    def normalise_stage(raw, index)
      where = "stage #{index + 1}"
      raise PlanError, "#{where} is not an object" unless raw.is_a?(Hash)

      {
        'step_number' => raw.key?('step_number') ? integer(raw['step_number'], where) : index + 1,
        'name' => str(raw['name']) || "stage_#{index + 1}",
        'description' => str(raw['description']),
        'inputs' => normalise_files(raw['inputs'], "#{where} inputs"),
        'outputs' => normalise_files(raw['outputs'], "#{where} outputs"),
        'tools' => Array(raw['tools']).each_with_index.map { |t, j| normalise_tool(t, "#{where} tool #{j + 1}") }
      }
    end

    def normalise_files(raw, where)
      return [] if raw.nil?
      raise PlanError, "#{where} is not an array" unless raw.is_a?(Array)

      raw.each_with_index.map { |f, i| normalise_file(f, "#{where} entry #{i + 1}") }
    end

    # A bare string is the locator and, unless `path` says otherwise, also
    # where the file sits — the common case for a computation whose inputs are
    # files in the directory it ran in.
    def normalise_file(raw, where)
      return { 'uri' => raw, 'path' => raw } if raw.is_a?(String) && !raw.strip.empty?
      raise PlanError, "#{where} is neither a string nor an object" unless raw.is_a?(Hash)

      uri = str(raw['uri'])
      raise PlanError, "#{where} has no uri" if uri.nil?

      compact_h('uri' => uri, 'filename' => str(raw['filename']),
                'path' => str(raw['path']) || uri, 'mediatype' => str(raw['mediatype']))
    end

    def normalise_tool(raw, where)
      raise PlanError, "#{where} is not an object" unless raw.is_a?(Hash)

      # `path` defaults to the locator, exactly as it does for a file: a tool a
      # stage names by where it sits is a tool this machine can hash, and
      # Environment skips the locators it cannot (a remote scheme, an image).
      uri = str(raw['uri'])
      tool = compact_h('name' => str(raw['name']), 'version' => str(raw['version']),
                       'version_command' => str(raw['version_command']),
                       'uri' => uri, 'path' => str(raw['path']) || uri,
                       'image' => str(raw['image']))
      if tool['name'].nil? && tool['uri'].nil? && tool['image'].nil?
        raise PlanError, "#{where} names nothing — give it a name, a uri or an image"
      end

      tool
    end

    def normalise_runtime(raw)
      raise PlanError, 'runtime is not an object' unless raw.is_a?(Hash)

      engine = str(raw['engine'])
      raise PlanError, 'runtime has no engine' if engine.nil?

      uri = str(raw['uri'])
      compact_h('engine' => engine, 'version' => str(raw['version']),
                'version_command' => str(raw['version_command']),
                'uri' => uri, 'path' => str(raw['path']) || uri, 'image' => str(raw['image']))
    end

    # `{param, value, step}` as the standard has it. The record counts these
    # and never carries a value (§6): `params_total` and `params_count` say how
    # many were declared and how many carry a value, and nothing more.
    def normalise_params(raw)
      return [] if raw.nil?
      raise PlanError, 'params is not an array' unless raw.is_a?(Array)

      raw.each_with_index.map do |p, i|
        raise PlanError, "param #{i + 1} is not an object" unless p.is_a?(Hash)

        param = str(p['param'])
        raise PlanError, "param #{i + 1} has no name" if param.nil?

        compact_h('param' => param, 'value' => p['value'].nil? ? nil : p['value'].to_s,
                  'step' => p['step'].nil? ? nil : p['step'].to_i)
      end
    end

    # A plan may say what the computation ran on — for a run on another
    # machine than the one writing the bundle. Stated, it wins over measuring.
    def normalise_platform(raw)
      raise PlanError, 'platform is not an object' unless raw.is_a?(Hash)

      h = compact_h(%w[cpu_architecture os_name os_release].to_h { |k| [k, str(raw[k])] })
      raise PlanError, 'platform names nothing' if h.empty?

      h
    end

    # `[{receipt, image_id, zkvm_version, step_number, input, output}]` — the
    # receipt file, the guest it was proved for, and the step's input and
    # output whose digests the journal binds (§6.1). The shape is checked
    # here; whether the step, input and output exist in the bundle is the
    # adapter's reading, reported by gc_prov_check and refused by the anchor.
    def normalise_zk_receipts(raw)
      raise PlanError, 'zk_receipts is not an array' unless raw.is_a?(Array)

      raw.each_with_index.map do |e, i|
        where = "zk receipt #{i + 1}"
        raise PlanError, "#{where} is not an object" unless e.is_a?(Hash)

        r = { 'receipt' => str(e['receipt']), 'image_id' => str(e['image_id'])&.downcase,
              'zkvm_version' => str(e['zkvm_version']), 'input' => str(e['input']), 'output' => str(e['output']) }
        missing = r.select { |_, v| v.nil? }.keys
        raise PlanError, "#{where} has no #{missing.join(', ')}" unless missing.empty?
        raise PlanError, "#{where} image_id is not 64 hex" unless r['image_id'] =~ /\A[0-9a-f]{64}\z/

        r.merge('step_number' => integer(e['step_number'], where))
      end
    end

    # --- small helpers --------------------------------------------------------

    def dedupe(files)
      files.uniq { |f| f['uri'] }
    end

    def compact_h(hash)
      hash.reject { |_, v| v.nil? }
    end

    def str(value)
      return nil unless value.is_a?(String) || value.is_a?(Numeric)

      s = value.to_s.strip
      s.empty? ? nil : s
    end

    def integer(value, where)
      Integer(value)
    rescue TypeError, ArgumentError
      raise PlanError, "#{where} has a step_number that is not an integer"
    end
  end
end
