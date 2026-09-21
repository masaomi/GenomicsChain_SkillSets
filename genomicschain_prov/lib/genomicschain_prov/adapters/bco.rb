# frozen_string_literal: true

require 'json'
require 'set'
require_relative '../normalized'
# The adapter reduces duplicate declarations with the predicate's own rule,
# and reads image references with the predicate's own shape. Requiring it
# here rather than testing `defined?` makes the grade depend on the bundle's
# bytes instead of on which entry point happened to load first (round 5,
# opus5). No cycle: the predicate requires `normalized` and tier2 only.
require_relative '../predicate'

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
    # non-integer `step_number`, or a step that is not an object, is a
    # FormatError — two steps sharing a number would share a stage and pool
    # their declarations, and a dropped step would shrink `stages_total`.
    #
    # FormatError messages carry structural facts only — a field name, a
    # count, a position — never a value copied from the bundle: the anchor
    # may log an exception message, and §6 promises that no bundle content
    # reaches its disk or logs (review round 3).
    module Bco
      class FormatError < StandardError; end

      # Part of the signed identity (`adapter_version`, design §6): the same
      # bundle under a different adapter version may normalise differently.
      VERSION = 'prov-adapter-bco-0.3.5'

      SPEC_MARK   = /2791|biocompute/i
      # A full SHA-1 or SHA-256 hash names the tree by its own hash. Shorter
      # hex — an abbreviation, or a calendar tag such as 20240601 that happens
      # to be hex — is a name, and is left symbolic (review round 1).
      COMMIT_HASH = /\A(?:[0-9a-f]{40}|[0-9a-f]{64})\z/i
      URL_SCHEME  = %r{\A(?:https?|ftp|s3|gs|file)://}i
      OCI_SCHEME  = %r{\A(?:docker|oci|shub)://}i
      # An image reference carrying a digest. THE predicate's constant, not a
      # copy of it: the two shapes decide the same grade on two sides of the
      # same record, and a copy drifts silently (round 4 anchored the absolute
      # path; round 5, opus5, closed the repo-relative one — see
      # Predicate::OCI_IMAGE_DIGEST for the rule and its reasoning).
      OCI_DIGEST  = GenomicsChainProv::Predicate::OCI_IMAGE_DIGEST
      SHA1_HEX    = /\A[0-9a-f]{40}\z/i
      SHA256_HEX  = /\A[0-9a-f]{64}\z/i
      # registry[:port]/repo[/repo]:tag. An untagged, unschemed name ("biocontainers/fastqc")
      # is indistinguishable from a path and is NOT taken as an image; write docker:// for those.
      # The first character must be alphanumeric: "./x:1.0" and "../x:1.0" are
      # paths (round 5).
      OCI_TAGGED  = %r{\A(?:[a-z0-9][a-z0-9.-]*(?::[0-9]+)?/)?[a-z0-9][a-z0-9._-]*(?:/[a-z0-9._-]+)*:[A-Za-z0-9._-]+\z}
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
        sha256_by_locator = checksums_from(extension, notes)
        notes << 'a checksum field that is not a hex digest was ignored' if malformed_checksum?(bco, extension)

        runtime = runtime_of(ed, notes, sha256_by_locator)
        software = software_of(ed, steps, runtime, sha256_by_locator)
        containers = software.select { |s| oci_ref?(s['locator']) }
                             .map { |s| { 'ref' => s['locator'], 'name' => s['name'], 'stage' => s['stage'] } }
        inputs = inputs_of(bco['io_domain'], internal_locators(steps).to_set, sha256_by_locator)
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
          workflow: workflow_of(bco, ed, sha256_by_locator),
          runtime: runtime,
          software: software,
          containers: containers,
          stages: stages_of(steps, sha256_by_locator),
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
        raise FormatError, 'spec_version does not name an IEEE 2791 BCO' unless spec =~ SPEC_MARK

        %w[description_domain execution_domain io_domain].each do |k|
          raise FormatError, "BCO missing required domain #{k}" unless bco[k].is_a?(Hash)
        end
        bco
      rescue JSON::ParserError
        # cause: nil — the parser's message quotes the offending bytes, and a
        # full exception rendering would print the cause (round 4, codex).
        raise FormatError, 'bundle is not valid JSON', cause: nil
      end

      # [[position, step], ...] sorted on step_number. Position is the stage id.
      def ordered_steps(bco)
        listed = Array(bco.dig('description_domain', 'pipeline_steps'))
        raw = listed.select { |st| st.is_a?(Hash) }
        unless raw.length == listed.length
          raise FormatError, "#{listed.length - raw.length} pipeline step(s) are not objects"
        end

        bad = raw.reject { |st| st['step_number'].to_s =~ /\A-?\d+\z/ }
        unless bad.empty?
          raise FormatError, "#{bad.length} pipeline step(s) without an integer step_number"
        end

        dup = raw.map { |st| st['step_number'].to_i }.tally.count { |_, n| n > 1 }
        raise FormatError, "#{dup} step_number value(s) duplicated" if dup.positive?

        raw.sort_by { |st| st['step_number'].to_i }.each_with_index.map { |st, i| [i + 1, st] }
      end

      # --- the seven conditions -------------------------------------------------

      def workflow_of(bco, ed, sha256_by_locator = {})
        pd = bco['provenance_domain'].is_a?(Hash) ? bco['provenance_domain'] : {}
        scms = Array(bco['extension_domain']).filter_map { |e| e.is_a?(Hash) ? e['scm_extension'] : nil }
                                            .select { |s| s.is_a?(Hash) }
        # Two SCM declarations are two declarations and the weaker one decides,
        # the rule script[] and the runtime already follow (round 5): reading
        # the first let the order of two extension entries choose the signed
        # grade — a commit hash first and a branch name second graded
        # `immutable`, and swapping them graded `floating`.
        rank = lambda do |s|
          c = blank_to_nil(s['scm_commit'])
          c.nil? ? 0 : (c =~ COMMIT_HASH ? 2 : 1)
        end
        scm = scms.min_by { |s| rank.call(s) }
        commit = scm && blank_to_nil(scm['scm_commit'])
        # Every script[] entry counts (round 5, three seats): the workflow is
        # checksum-pinned only when ALL of them join a digest — reading the
        # first alone let the array order decide the signed grade.
        # Every element counts, including one with no readable locator (round
        # 6): pruning before the all-entries test evaluated "all" over a
        # shortened list, so omitting a script's uri signed `immutable` where
        # declaring it signed `floating`.
        scripts = Array(ed['script']).map do |e|
          blank_to_nil(e.is_a?(Hash) ? (e['uri'].is_a?(Hash) ? e['uri']['uri'] : e['uri']) : e)
        end
        script = scripts.compact.first
        all_pinned = !scripts.empty? && scripts.all? { |l| l && sha256_by_locator[l] }
        {
          'name' => blank_to_nil(pd['name']),
          'version' => blank_to_nil(pd['version']),
          'repository' => scm && blank_to_nil(scm['scm_repository']),
          'commit' => commit,
          # A hash is a commit; anything else the SCM extension calls a commit
          # (a tag, a branch) cannot be told apart here and is left symbolic.
          'ref_kind' => commit.nil? ? nil : (commit =~ COMMIT_HASH ? 'commit' : 'symbolic'),
          'path' => scm && blank_to_nil(scm['scm_path']),
          'script' => script,
          'scripts_total' => scripts.length,
          'scripts_with_checksum' => scripts.count { |l| l && sha256_by_locator[l] },
          # extension checksums[] joined by every script locator (rounds 4–5):
          # the first script's digest, present only when all scripts have one
          'checksum' => all_pinned ? { 'sha256' => sha256_by_locator[script] } : nil
        }
      end

      # The runtime is the engine `script_driver` names; its version is the
      # software_prerequisites entry of the same name, when there is one.
      def runtime_of(ed, notes, sha256_by_locator = {})
        engine = blank_to_nil(ed['script_driver'])
        return nil if engine.nil?

        entries = Array(ed['software_prerequisites']).select { |s| s.is_a?(Hash) && s['name'].to_s.casecmp?(engine) }
        notes << 'runtime has no version entry in software_prerequisites' if entries.empty?
        notes << 'runtime declared more than once; the weakest declaration is taken' if entries.length > 1
        # Two entries naming the engine are two declarations; the weaker one
        # decides, like every other category (round 4: `find` took the first
        # and the order of two lines chose the signed grade).
        se = weakest_runtime_entry(entries, sha256_by_locator)
        # locator and checksum are what would let the runtime grade above
        # `versioned` (a digest-pinned engine image, a checksummed launcher);
        # nf-prov writes a release-tag URL and no checksum. The enricher writes
        # the framework jar's sha256 into the GenomicsChain extension keyed by
        # this entry's locator (§13.4-1), which the join below picks up.
        { 'engine' => engine, 'version' => se && se['version'],
          'locator' => se && se['locator'], 'checksum' => se && se['checksum'] }
      end

      # Workflow-level prerequisites (runtime excluded) plus every step's
      # prerequisites. De-duplicated on (name, version, locator, checksum,
      # stage): the same entry repeated within one level is counted once, but
      # a tool a step declares is kept for that step even when the workflow
      # level names it too, and a tool two steps declare is two items — the
      # per-stage coverage the claim carries is counted from these (review
      # round 2: a key without the stage collapsed every per-step entry into
      # the workflow-level one, and the enriched fixture graded `absent` 4/8).
      # The checksum is in the key because it decides the grade: two entries
      # alike but for their checksum are two declarations, and the weaker one
      # must survive (round 3).
      def software_of(ed, steps, runtime, sha256_by_locator = {})
        top = Array(ed['software_prerequisites']).filter_map { |s| software_entry(s, nil, sha256_by_locator) }
        top = top.reject { |s| runtime && s['name'].to_s.casecmp?(runtime['engine'].to_s) }
        per_step = steps.flat_map do |pos, st|
          Array(st['prerequisite']).filter_map { |s| software_entry(s, pos, sha256_by_locator) }
        end
        (top + per_step).uniq { |s| [s['name'], s['version'], s['locator'], s['checksum'], s['stage']] }
      end

      # A tool's checksum comes from the standard's `sha1_checksum` on its uri
      # and from the GenomicsChain extension's `checksums[]` joined by exact
      # locator — the same join inputs and outputs use (round 3: the enricher
      # had nowhere to put a SHA-256 for a tool or the runtime that anything
      # read).
      # An entry that names nothing the bundle can resolve is KEPT and graded
      # `absent` by the predicate, not dropped (round 5, opus5): dropping it
      # let a stage whose only prerequisite was unreadable fall back to the
      # workflow-level items and grade above a stage that declared its weak
      # tool honestly. The same argument `ordered_steps` already makes for a
      # non-object step — a dropped entry shrinks a signed denominator.
      def software_entry(entry, stage, sha256_by_locator = {})
        entry = readable(entry)
        uri = entry['uri'].is_a?(Hash) ? entry['uri'] : { 'uri' => entry['uri'] }
        name = blank_to_nil(entry['name'])
        locator = blank_to_nil(uri['uri'])

        { 'name' => name || locator, 'version' => blank_to_nil(entry['version']), 'locator' => locator,
          'checksum' => checksum_of(uri, locator, sha256_by_locator), 'stage' => stage.nil? ? nil : stage.to_i }
      end

      def stages_of(steps, sha256_by_locator = {})
        steps.map do |pos, s|
          sw = Array(s['prerequisite']).filter_map { |p| software_entry(p, pos, sha256_by_locator) }
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

      # An entry with no readable locator is KEPT with `locator: nil` and
      # graded `absent` by the predicate (round 5, opus5). `inputs_total` and
      # `outputs_total` are signed counts: dropping the entry shortened the
      # denominator, so a bundle listing one checksummed input and one
      # locator-less input signed `inputs_with_checksum 1/1` and graded
      # `immutable`, while the same producer declaring that second input with
      # a path signed 1/2 and `local_path`. Omitting a field must never grade
      # above declaring it.
      def inputs_of(io, internal, sha256_by_locator)
        Array(io['input_subdomain']).map do |raw|
          i = readable(raw)
          uri = i['uri'].is_a?(Hash) ? i['uri'] : { 'uri' => i['uri'] }
          locator = blank_to_nil(uri['uri'])
          name = blank_to_nil(uri['filename']) || locator
          name = basename(name) unless name.nil?
          { 'name' => name, 'locator' => locator,
            'checksum' => checksum_of(uri, locator, sha256_by_locator),
            'internal' => locator ? internal.include?(locator) : false,
            'reference_hint' => name.to_s =~ REFERENCE_HINT ? true : false }
        end
      end

      def outputs_of(io, sha256_by_locator)
        Array(io['output_subdomain']).map do |raw|
          o = readable(raw)
          uri = o['uri'].is_a?(Hash) ? o['uri'] : { 'uri' => o['uri'] }
          locator = blank_to_nil(uri['uri'])

          name = blank_to_nil(uri['filename']) || locator
          { 'name' => name.nil? ? nil : basename(name), 'locator' => locator,
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

      # Every `genomicschain_extension` block, not the first (round 6, cursor):
      # with the enricher writing a block of its own beside a producer's, the
      # array order decided which checksums were read. The blocks are merged,
      # `checksums[]` by concatenation. Two blocks naming different producers
      # is a bundle saying two things, so neither is recorded — the order must
      # not choose.
      def genomicschain_extension(bco)
        blocks = Array(bco['extension_domain']).filter_map do |x|
          x['genomicschain_extension'] if x.is_a?(Hash) && x['genomicschain_extension'].is_a?(Hash)
        end
        return blocks.first || {} if blocks.length <= 1

        merged = { 'checksums' => blocks.flat_map { |b| Array(b['checksums']) } }
        producers = blocks.filter_map { |b| b['producer'] }.uniq
        merged['producer'] = producers.first if producers.length == 1
        merged
      end

      def producer_of(extension)
        p = extension['producer']
        return nil unless p.is_a?(Hash) && blank_to_nil(p['name'])

        { 'name' => p['name'].to_s, 'version' => blank_to_nil(p['version']) }
      end

      # Of several software_prerequisites entries naming the engine, the one
      # that grades weakest — under Predicate.runtime_grade itself, not under a
      # second copy of it. Round 5 (opus5): the adapter's own copy of the rule
      # was reached or skipped depending on whether the predicate happened to
      # be loaded, so two declarations reduced to different entries and the
      # signed grade depended on the entry point rather than on the bundle.
      # The levels come from the same constant for the same reason.
      def weakest_runtime_entry(entries, sha256_by_locator)
        pred = GenomicsChainProv::Predicate
        ses = entries.filter_map { |e| software_entry(e, nil, sha256_by_locator) }
        grade = lambda do |x|
          pred.runtime_grade('engine' => x['name'], 'version' => x['version'],
                             'locator' => x['locator'], 'checksum' => x['checksum']).first
        end
        ses.max_by { |x| pred::LEVELS.index(grade.call(x)) }
      end

      # checksums[] entries whose sha256 is not 64 hex are ignored — a checksum
      # field holds a digest or nothing (round 4: "x" graded immutable).
      # Two entries naming the same locator with different digests is a bundle
      # that says two things about one file; it has pinned nothing, and which
      # digest won must not depend on the array order (round 6). The locator is
      # dropped and the disagreement noted.
      def checksums_from(extension, notes = [])
        by_locator = Array(extension['checksums']).each_with_object({}) do |c, acc|
          next unless c.is_a?(Hash) && blank_to_nil(c['uri']) && c['sha256'].to_s =~ SHA256_HEX

          (acc[c['uri'].to_s] ||= []) << c['sha256'].to_s.downcase
        end
        conflicting = by_locator.count { |_, v| v.uniq.length > 1 }
        notes << 'the extension gives one locator more than one checksum; that locator is not pinned' if conflicting.positive?
        by_locator.filter_map { |k, v| [k, v.first] if v.uniq.length == 1 }.to_h
      end

      def malformed_checksum?(bco, extension)
        ext_bad = Array(extension['checksums']).any? { |c| c.is_a?(Hash) && blank_to_nil(c['sha256']) && c['sha256'].to_s !~ SHA256_HEX }
        io = bco['io_domain']
        io_bad = (Array(io['input_subdomain']) + Array(io['output_subdomain'])).any? do |i|
          u = i.is_a?(Hash) && i['uri'].is_a?(Hash) ? i['uri'] : {}
          blank_to_nil(u['sha1_checksum']) && u['sha1_checksum'].to_s !~ SHA1_HEX
        end
        ext_bad || io_bad
      end

      def checksum_of(uri, locator, sha256_by_locator)
        h = {}
        sha1 = blank_to_nil(uri['sha1_checksum'])
        sha1 = nil if sha1 && sha1 !~ SHA1_HEX
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

      # One rule at every site that reads a list of entries (round 6, three
      # seats concordant): an element this adapter cannot read is normalised to
      # an empty entry and KEPT, never dropped. Every such list feeds a signed
      # denominator — `inputs_total`, `outputs_total`, `software_total`,
      # `scripts_total` — or decides whether a stage declared an environment of
      # its own, so dropping an element let a producer who wrote a bare string
      # or a `null` grade above one who wrote an honest object. This is the
      # argument `ordered_steps` already makes for a non-object step, applied
      # to every other list in the same record. A bare string is not read as a
      # locator: the standard's entries are objects, and guessing would be the
      # producer's string choosing the route.
      def readable(entry)
        entry.is_a?(Hash) ? entry : {}
      end

      def unset?(v)
        v.nil? || UNSET_VALUES.include?(v.to_s.strip)
      end
    end
  end
end
