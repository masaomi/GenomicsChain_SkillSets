# frozen_string_literal: true

require 'json'
require_relative '../normalized'

module GenomicsChainProv
  module Adapters
    # Bco — IEEE 2791-2020 BioCompute Object → NormalizedProvenance.
    #
    # Reads the standard's fields, not one producer's habits:
    # `execution_domain.software_prerequisites` and `script_driver`, the
    # `pipeline_steps[].prerequisite` lists, `io_domain`, `parametric_domain`,
    # and the SCM extension. Measured against nf-prov 1.7.0 (U0, 2026-09-20,
    # fixture nfcore_demo_1_2_0): that producer fills the SCM extension, the
    # runtime line, the URIs and the parameters — and nothing else. No
    # checksums, no tools, no containers. The adapter reports those as absent
    # instead of guessing; `gc_prov_write --from-nextflow-run` is the place that
    # fills them (design §13).
    #
    # Deterministic: the same bundle bytes give the same structure. No network,
    # no subprocess, no file access — a locator is a string here.
    #
    # One extension of the standard is read: an `extension_domain` entry holding
    # `genomicschain_extension` (written by the enricher) may carry
    #   producer:  {name, version}
    #   checksums: [{uri, sha256}]   joined to inputs/outputs by exact locator
    # because the standard's own checksum field is SHA-1 and the record wants
    # SHA-256 beside it. The extension_schema URL is fixed (design §10-1).
    #
    # Stage identity (review round 2): a stage is its POSITION after sorting
    # the steps on `step_number`, and every per-stage item carries that
    # position. Step numbers 10, 20, 30 are stages 1, 2, 3. A duplicated or
    # non-integer `step_number` is a FormatError — two steps sharing a number
    # would share a stage and pool their declarations, and a grade must not
    # rest on that.
    module Bco
      class FormatError < StandardError; end

      SPEC_MARK   = /2791|biocompute/i
      # A full SHA-1 or SHA-256 hash names the tree by its own hash. Shorter
      # hex — an abbreviation, or a calendar tag such as 20240601 that happens
      # to be hex — is a name, and is left symbolic (review round 1).
      COMMIT_HASH = /\A(?:[0-9a-f]{40}|[0-9a-f]{64})\z/i
      URL_SCHEME  = %r{\A(?:https?|ftp|s3|gs|file)://}i
      OCI_SCHEME  = %r{\A(?:docker|oci|shub)://}i
      OCI_DIGEST  = /@sha256:[0-9a-f]{64}/i
      # registry[:port]/repo[/repo]:tag. An untagged, unschemed name ("biocontainers/fastqc")
      # is indistinguishable from a path and is NOT taken as an image; write docker:// for those.
      OCI_TAGGED  = %r{\A(?:[a-z0-9.-]+(?::[0-9]+)?/)?[a-z0-9._-]+(?:/[a-z0-9._-]+)*:[A-Za-z0-9._-]+\z}
      SEED        = /seed/i
      # A guess by name, and recorded as one (`reference_detection: heuristic`, §5).
      REFERENCE_HINT = /genome|reference|\.fa(?:sta)?(?:\.gz)?\z|\.fai\z|\.dict\z|\.gtf|\.gff3?|index/i
      UNSET_VALUES = ['', 'null'].freeze

      module_function

      # @param bundle [Hash, String] the BCO, verbatim (object or JSON text)
      # @return [NormalizedProvenance]
      # @raise [FormatError] when the input is not a BCO
      def parse(bundle)
        bco = load(bundle)
        notes = []
        ed = bco['execution_domain']
        steps = ordered_steps(bco)
        params = Array(bco['parametric_domain']).select { |p| p.is_a?(Hash) }
        extension = genomicschain_extension(bco)
        sha256_by_locator = checksums_from(extension)

        runtime = runtime_of(ed, notes)
        software = software_of(ed, steps, runtime)
        containers = software.select { |s| oci_ref?(s['locator']) }
                             .map { |s| { 'ref' => s['locator'], 'name' => s['name'], 'stage' => s['stage'] } }
        inputs = inputs_of(bco['io_domain'], internal_locators(steps), sha256_by_locator)
        outputs = outputs_of(bco['io_domain'], sha256_by_locator)
        recorded = params.reject { |p| unset?(p['value']) }
        producer = producer_of(extension)

        notes << 'bundle names no producer' if producer.nil?
        notes << 'no tool besides the runtime in software_prerequisites' if software.empty?
        notes << 'no container reference anywhere in the bundle' if containers.empty?
        notes << 'no checksum on any input' if inputs.any? && inputs.none? { |i| i['checksum'] }
        notes << 'no checksum on any output' if outputs.any? && outputs.none? { |o| o['checksum'] }

        NormalizedProvenance.new(
          format: 'bco',
          format_version: bco['spec_version'].to_s,
          producer: producer,
          workflow: workflow_of(bco, ed),
          runtime: runtime,
          software: software,
          containers: containers,
          stages: stages_of(steps),
          inputs: inputs,
          outputs: outputs,
          params_total: params.length,
          params_count: recorded.length,
          seed_recorded: recorded.any? { |p| p['param'].to_s =~ SEED },
          notes: notes
        )
      end

      def load(bundle)
        bco = bundle.is_a?(String) ? JSON.parse(bundle) : JSON.parse(JSON.generate(bundle))
        raise FormatError, 'bundle is not a JSON object' unless bco.is_a?(Hash)

        spec = bco['spec_version'].to_s
        raise FormatError, "spec_version #{spec.inspect} does not name an IEEE 2791 BCO" unless spec =~ SPEC_MARK

        %w[description_domain execution_domain io_domain].each do |k|
          raise FormatError, "BCO missing required domain #{k}" unless bco[k].is_a?(Hash)
        end
        bco
      rescue JSON::ParserError => e
        raise FormatError, "bundle is not valid JSON: #{e.message}"
      end

      # [[position, step], ...] sorted on step_number. Position is the stage id.
      def ordered_steps(bco)
        raw = Array(bco.dig('description_domain', 'pipeline_steps')).select { |st| st.is_a?(Hash) }
        bad = raw.reject { |st| st['step_number'].to_s =~ /\A-?\d+\z/ }
        unless bad.empty?
          raise FormatError, "#{bad.length} pipeline step(s) without an integer step_number"
        end

        dup = raw.map { |st| st['step_number'].to_i }.tally.select { |_, n| n > 1 }.keys.sort
        raise FormatError, "duplicate step_number #{dup.inspect}" unless dup.empty?

        raw.sort_by { |st| st['step_number'].to_i }.each_with_index.map { |st, i| [i + 1, st] }
      end

      # --- the seven conditions -------------------------------------------------

      def workflow_of(bco, ed)
        pd = bco['provenance_domain'].is_a?(Hash) ? bco['provenance_domain'] : {}
        scm = Array(bco['extension_domain']).filter_map { |e| e.is_a?(Hash) ? e['scm_extension'] : nil }
                                            .find { |s| s.is_a?(Hash) }
        commit = scm && blank_to_nil(scm['scm_commit'])
        {
          'name' => blank_to_nil(pd['name']),
          'version' => blank_to_nil(pd['version']),
          'repository' => scm && blank_to_nil(scm['scm_repository']),
          'commit' => commit,
          # A hash is a commit; anything else the SCM extension calls a commit
          # (a tag, a branch) cannot be told apart here and is left symbolic.
          'ref_kind' => commit.nil? ? nil : (commit =~ COMMIT_HASH ? 'commit' : 'symbolic'),
          'path' => scm && blank_to_nil(scm['scm_path']),
          'script' => blank_to_nil(Array(ed['script']).first)
        }
      end

      # The runtime is the engine `script_driver` names; its version is the
      # software_prerequisites entry of the same name, when there is one.
      def runtime_of(ed, notes)
        engine = blank_to_nil(ed['script_driver'])
        return nil if engine.nil?

        entry = Array(ed['software_prerequisites']).find { |s| s.is_a?(Hash) && s['name'].to_s.casecmp?(engine) }
        notes << "runtime #{engine} has no version entry in software_prerequisites" if entry.nil?
        se = entry && software_entry(entry, nil)
        # locator and checksum are what would let the runtime grade above
        # `versioned` (a digest-pinned engine image, a checksummed launcher);
        # nf-prov writes a release-tag URL and no checksum.
        { 'engine' => engine, 'version' => se && se['version'],
          'locator' => se && se['locator'], 'checksum' => se && se['checksum'] }
      end

      # Workflow-level prerequisites (runtime excluded) plus every step's
      # prerequisites. De-duplicated on (name, version, locator, stage): the
      # same entry repeated within one level is counted once, but a tool a
      # step declares is kept for that step even when the workflow level names
      # it too, and a tool two steps declare is two items — the per-stage
      # coverage the claim carries is counted from these (review round 2: a
      # key without the stage collapsed every per-step entry into the
      # workflow-level one, and the enriched fixture graded `absent` 4/8).
      def software_of(ed, steps, runtime)
        top = Array(ed['software_prerequisites']).filter_map { |s| software_entry(s, nil) }
        top = top.reject { |s| runtime && s['name'].casecmp?(runtime['engine']) }
        per_step = steps.flat_map do |pos, st|
          Array(st['prerequisite']).filter_map { |s| software_entry(s, pos) }
        end
        (top + per_step).uniq { |s| [s['name'], s['version'], s['locator'], s['stage']] }
      end

      def software_entry(entry, stage)
        return nil unless entry.is_a?(Hash)

        uri = entry['uri'].is_a?(Hash) ? entry['uri'] : { 'uri' => entry['uri'] }
        name = blank_to_nil(entry['name'])
        locator = blank_to_nil(uri['uri'])
        return nil if name.nil? && locator.nil?

        { 'name' => name || locator, 'version' => blank_to_nil(entry['version']), 'locator' => locator,
          'checksum' => checksum_of(uri, nil, {}), 'stage' => stage.nil? ? nil : stage.to_i }
      end

      def stages_of(steps)
        steps.map do |pos, s|
          sw = Array(s['prerequisite']).filter_map { |p| software_entry(p, pos) }
          {
            'id' => pos,
            'step_number' => s['step_number'].to_i,
            'name' => blank_to_nil(s['name']),
            'description' => blank_to_nil(s['description']),
            'inputs' => Array(s['input_list']).length,
            'outputs' => Array(s['output_list']).length,
            'software' => sw,
            'container' => sw.map { |x| x['locator'] }.find { |l| oci_ref?(l) }
          }
        end
      end

      def inputs_of(io, internal, sha256_by_locator)
        Array(io['input_subdomain']).filter_map do |i|
          next nil unless i.is_a?(Hash)

          uri = i['uri'].is_a?(Hash) ? i['uri'] : { 'uri' => i['uri'] }
          locator = blank_to_nil(uri['uri'])
          next nil if locator.nil?

          name = basename(blank_to_nil(uri['filename']) || locator)
          { 'name' => name, 'locator' => locator,
            'checksum' => checksum_of(uri, locator, sha256_by_locator),
            'internal' => internal.include?(locator),
            'reference_hint' => name =~ REFERENCE_HINT ? true : false }
        end
      end

      def outputs_of(io, sha256_by_locator)
        Array(io['output_subdomain']).filter_map do |o|
          next nil unless o.is_a?(Hash)

          uri = o['uri'].is_a?(Hash) ? o['uri'] : { 'uri' => o['uri'] }
          locator = blank_to_nil(uri['uri'])
          next nil if locator.nil?

          { 'name' => basename(blank_to_nil(uri['filename']) || locator), 'locator' => locator,
            'checksum' => checksum_of(uri, locator, sha256_by_locator),
            'mediatype' => blank_to_nil(o['mediatype']) }
        end
      end

      # --- rules ------------------------------------------------------------------

      # Design §13.4-3, revised after review round 2 (2026-09-20). An input is
      # internal only when the bundle shows this run producing it BEFORE
      # reading it: the locator appears in some step's output_list at an
      # earlier position than in every step's input_list that names it. Only
      # `uri` is matched — a `filename` is a producer's caption for the entry,
      # not a location, and matching it let a label remove an input from the
      # grade (round 2). A published output (io_domain.output_subdomain) has no
      # step and so is not ordering evidence. Two cases stay external and are
      # graded: an input no step lists as read (the bundle gives no point at
      # which it was consumed), and an in-place overwrite, where one step
      # reads and writes the same locator — the bytes it read existed before
      # the run wrote them. A path prefix is never evidence: the work dir and
      # the outdir are values the producer chooses (round 1).
      # nf-prov's workflow inputs are "task inputs no task produced", so on
      # its bundles this marks nothing internal.
      def internal_locators(steps)
        produced = {}
        consumed = {}
        steps.each do |pos, st|
          uris_of(st['output_list']).each { |l| produced[l] = [produced[l], pos].compact.min }
          uris_of(st['input_list']).each { |l| consumed[l] = [consumed[l], pos].compact.min }
        end
        produced.keys.select { |l| consumed[l] && produced[l] < consumed[l] }
      end

      def uris_of(list)
        Array(list).filter_map do |o|
          next nil unless o.is_a?(Hash)

          uri = o['uri'].is_a?(Hash) ? o['uri'] : { 'uri' => o['uri'] }
          blank_to_nil(uri['uri'])
        end.uniq
      end

      def oci_ref?(locator)
        s = locator.to_s
        return false if s.empty? || s =~ URL_SCHEME
        return true if s =~ OCI_SCHEME || s =~ OCI_DIGEST

        s =~ OCI_TAGGED ? true : false
      end

      def genomicschain_extension(bco)
        e = Array(bco['extension_domain']).find { |x| x.is_a?(Hash) && x['genomicschain_extension'].is_a?(Hash) }
        e ? e['genomicschain_extension'] : {}
      end

      def producer_of(extension)
        p = extension['producer']
        return nil unless p.is_a?(Hash) && blank_to_nil(p['name'])

        { 'name' => p['name'].to_s, 'version' => blank_to_nil(p['version']) }
      end

      def checksums_from(extension)
        Array(extension['checksums']).each_with_object({}) do |c, acc|
          next unless c.is_a?(Hash) && blank_to_nil(c['uri']) && blank_to_nil(c['sha256'])

          acc[c['uri'].to_s] = c['sha256'].to_s.downcase
        end
      end

      def checksum_of(uri, locator, sha256_by_locator)
        h = {}
        sha1 = blank_to_nil(uri['sha1_checksum'])
        h['sha1'] = sha1.downcase if sha1
        sha256 = locator && sha256_by_locator[locator]
        h['sha256'] = sha256 if sha256
        h.empty? ? nil : h
      end

      def basename(locator)
        s = locator.to_s.sub(/[?#].*\z/, '')
        s.split('/').reject(&:empty?).last || s
      end

      def blank_to_nil(v)
        v.nil? || v.to_s.strip.empty? ? nil : v.to_s
      end

      def unset?(v)
        v.nil? || UNSET_VALUES.include?(v.to_s.strip)
      end
    end
  end
end
