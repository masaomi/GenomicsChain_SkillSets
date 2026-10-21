# frozen_string_literal: true

require 'json'
require 'set'
require 'strscan'
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
    #   producer:    {name, version}
    #   checksums:   [{uri, sha256 | hmac_sha256}]   joined to inputs/outputs by exact locator
    #   commitment:  {rule, key_id}                           (design v0.1.16 §6.1)
    #   platform:    {cpu_architecture, os_name, os_release}   (design v0.1.12 §6.1)
    #   zk_receipts: [{sha256, image_id, zkvm{name,version}, step_number,
    #                  journal, input_uri, output_uri}]          (same)
    # because the standard's own checksum field is SHA-1 and the record wants
    # SHA-256 beside it, and because the standard has no field for the machine
    # or for a proof. The extension_schema URL is fixed (design §10-1).
    #
    # Option 2 (design v0.1.16 §6.1, S2). A bundle that declares a
    # gc-zk-journal-0.2 receipt is an option-2 bundle: every checksums[] item
    # is exactly {uri, hmac_sha256} and no `sha1_checksum` appears anywhere.
    # `hmac_sha256` (gc-commitment-0.1) is read as a content-fixing fingerprint
    # exactly like `sha256` — the predicate is unchanged and grades on its
    # presence. What this adapter refuses is reported in `refusals` (codes,
    # never values) and refused by the anchor; it reads no configuration.
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
      # 0.4.0 (design v0.1.12): reads `platform` and `zk_receipts`.
      # 0.5.0 (design v0.1.16): reads `hmac_sha256` as a fingerprint and
      # `commitment`; the option-2 refusals (§6.1, S2).
      VERSION = 'prov-adapter-bco-0.5.0'

      # ZK receipts this version can name (design §6.1). Anything else is a
      # declaration defect, which the anchor refuses rather than records.
      ZK_VM_NAME = 'risc0-zkvm'
      JOURNAL_V01 = 'gc-zk-journal-0.1'
      JOURNAL_V02 = 'gc-zk-journal-0.2'
      ZK_JOURNALS = [JOURNAL_V01, JOURNAL_V02].freeze
      COMMITMENT_RULE = 'gc-commitment-0.1'
      # The two fingerprint fields a checksums[] item may carry, one of them.
      FINGERPRINT_FIELDS = %w[sha256 hmac_sha256].freeze
      # An option-2 item: these keys and no other (design §6.1, an allow-list).
      OPTION2_ITEM_KEYS = %w[hmac_sha256 uri].freeze
      HMAC_HEX = /\A[0-9a-f]{64}\z/
      PLATFORM_KEYS = %w[cpu_architecture os_name os_release].freeze

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
        # The option-2 shape rule reads the bundle as written: normalisation
        # empties or drops what it cannot read (a list where an object
        # belongs, a list element that is not an object), and a fingerprint
        # hidden there must still be refused (round-1 implementation review,
        # Codex H1: `platform: [{sha1_checksum}]` was accepted). Its objects
        # remember a repeated key, which the parse itself drops (round-2 M1).
        # The text itself is kept for the comment scan (round-3 C1): a bundle
        # given as an object is re-serialised and cannot carry a comment.
        text = bundle.is_a?(String) ? bundle : JSON.generate(bundle)
        as_written = parse_as_written(text)
        notes = []
        ed = bco['execution_domain']
        steps = ordered_steps(bco)
        params = Array(bco['parametric_domain']).select { |p| p.is_a?(Hash) }
        extension = genomicschain_extension(bco)
        fp_by_locator = checksums_from(extension, notes)
        commitment = commitment_of(bco)
        notes << 'a checksum field that is not a hex digest was ignored' if malformed_checksum?(bco, extension)

        runtime = runtime_of(ed, notes, fp_by_locator)
        software = software_of(ed, steps, runtime, fp_by_locator)
        # An unreadable entry might have been an image, so it weakens the
        # container route as well as the package route (round 7, codex,
        # reproduced): with it in the package route only, replacing an honestly
        # declared `docker://b:latest` with an unreadable element left the
        # container route holding the strong image alone and LIFTED the stage,
        # because the stage takes the stronger of the two routes (§5, §10-8).
        containers = software.select { |s| oci_ref?(s['locator']) || (s['name'].nil? && s['locator'].nil?) }
                             .map { |s| { 'ref' => s['locator'], 'name' => s['name'], 'stage' => s['stage'] } }
        inputs = inputs_of(bco['io_domain'], internal_locators(steps).to_set, fp_by_locator)
        outputs = outputs_of(bco['io_domain'], fp_by_locator)
        recorded = params.reject { |p| unset?(p['value']) }
        producer = producer_of(extension)
        platform = platform_of(extension, notes)

        notes << 'bundle names no producer' if producer.nil?
        notes << 'bundle names no platform (cpu architecture, OS)' if platform.nil?
        notes << 'no tool besides the runtime in software_prerequisites' if software.empty?
        notes << 'no container reference anywhere in the bundle' if containers.empty?
        notes << 'no checksum on any input' if inputs.any? && inputs.none? { |i| i['checksum'] }
        notes << 'no checksum on any output' if outputs.any? && outputs.none? { |o| o['checksum'] }

        NormalizedProvenance.new(
          format: 'bco',
          format_version: bco['spec_version'].to_s,
          producer: producer,
          workflow: workflow_of(bco, ed, fp_by_locator, notes),
          runtime: runtime,
          software: software,
          containers: containers,
          stages: stages_of(steps, fp_by_locator),
          inputs: inputs,
          outputs: outputs,
          params_total: params.length,
          params_count: recorded.length,
          seed_recorded: recorded.any? { |p| p['param'].to_s =~ SEED },
          platform: platform,
          zk_receipts: zk_receipts_of(extension, steps, fp_by_locator),
          commitment: commitment,
          refusals: refusals_of(as_written, extension, text),
          notes: notes
        )
      end

      # --- option 2 (design v0.1.16 §6.1, S2, S3 (vii)) --------------------------

      # The journal conventions the bundle's receipt declarations name, as
      # written (an unknown one is a declaration defect, reported elsewhere).
      def declared_journals(extension)
        Array(extension['zk_receipts']).map { |d| blank_to_nil(readable(d)['journal']) }
      end

      # What the anchor refuses this bundle for, before any receipt is
      # looked at. Codes only, in a fixed order; [] when nothing.
      #
      #   mixed_journal_conventions            0.1 and 0.2 receipts in one bundle (S2)
      #   plain_fingerprint_in_option2_bundle  an option-2 bundle with a checksums[]
      #                                        item other than exactly {uri, hmac_sha256}
      #                                        (two strings), a sha1_checksum anywhere, or
      #                                        an extension_domain element / genomicschain_extension
      #                                        value that is not an object — its items are not
      #                                        read, so it cannot be shown free of plain
      #                                        fingerprints (§6.1; pre-flight r2); or one whose
      #                                        bytes cannot be shown free of them either:
      #                                        any object anywhere that repeats a key (the
      #                                        parse keeps only the last value; round-2 M1),
      #                                        or a `checksums` key anywhere other than the
      #                                        top level of a genomicschain_extension block
      #                                        in a top-level extension_domain element —
      #                                        another extension's, a sibling key, a nested
      #                                        extension_domain, a zk declaration (round-2 M2);
      #                                        or a comment anywhere in the text (the parse
      #                                        drops it; round-3 C1)
      #   commitment_outside_option2           hmac_sha256 or commitment in a bundle
      #                                        that declares no 0.2 receipt (§6.1, S3 (vii))
      #
      # The design names the third `commitment_outside_option2`; the review
      # queue (r2 N6) floated `salted_fingerprint_outside_option2`. The frozen
      # design's name is the one used.
      #
      # @param as_written [Hash] the bundle as parsed by `parse_as_written`,
      #   BEFORE normalisation: the items, the sha1_checksum and checksums
      #   scans and the repeated-key check are read there, so nothing
      #   normalisation or the parse drops escapes
      # @param extension [Hash] the normalised extension (for the journals)
      # @param text [String] the bundle text the two parses read (for the comment scan)
      def refusals_of(as_written, extension, text)
        journals = declared_journals(extension)
        items = extension_blocks(as_written).flat_map { |b| Array(b['checksums']) }
        out = []
        if journals.include?(JOURNAL_V02)
          out << 'mixed_journal_conventions' if journals.include?(JOURNAL_V01)
          plain = items.any? { |c| !option2_item?(c) } || key_anywhere?(as_written, 'sha1_checksum') ||
                  !unshaped_extension_elements(as_written).zero? || key_repeated?(as_written) ||
                  checksums_outside_blocks?(as_written) || comment?(text)
          out << 'plain_fingerprint_in_option2_bundle' if plain
        elsif items.any? { |c| c.is_a?(Hash) && c.key?('hmac_sha256') } ||
              extension_blocks(as_written).any? { |b| b.key?('commitment') }
          out << 'commitment_outside_option2'
        end
        out
      end

      # Exactly {uri, hmac_sha256}, both strings: an object under either key
      # could carry a plain fingerprint inside it (round-1 review, F1).
      def option2_item?(c)
        c.is_a?(Hash) && c.keys.sort == OPTION2_ITEM_KEYS && c['uri'].is_a?(String) && c['hmac_sha256'].is_a?(String)
      end

      # An object that remembers whether a key was written into it twice.
      # json 2.9.1 builds an `object_class` object with `[]=` once per member,
      # in document order (checked 2026-10-20: `{"a":1,"a":2}` calls `[]=`
      # twice), and keeps the last value; this records that it happened.
      class KeyRepeatHash < Hash
        def []=(key, value)
          @repeated = true if key?(key)
          super
        end

        def repeated? = @repeated == true
      end

      # The bundle as written, for the option-2 scans only: plain Hash
      # behaviour, plus the repeated-key mark. Same limits as `load`.
      def parse_as_written(text)
        JSON.parse(text, object_class: KeyRepeatHash)
      end

      # Whether the text holds a JSON comment. json 2.9.1 accepts /* */ and //
      # comments and has no option to refuse them (round-3 C1, checked
      # 2026-10-20). Standard JSON allows a '/' only inside a string token, so
      # a '/' outside one is a comment. Walks the text tracking string state:
      # outside a string, the next '"' opens one and a '/' is a comment; inside,
      # a backslash takes the byte after it, and the next other '"' closes it.
      # Called on text the parser accepted, so every string closes; one that
      # did not would leave the text unshown, and is counted as a comment.
      def comment?(text)
        sc = StringScanner.new(text.b)
        while sc.skip_until(%r{["/]}n)
          return true if sc.matched == '/'

          loop do
            return true if sc.skip_until(/["\\]/n).nil?
            break if sc.matched == '"'

            sc.getch
          end
        end
        false
      end

      def key_repeated?(node)
        case node
        when Hash then (node.respond_to?(:repeated?) && node.repeated?) || node.each_value.any? { |v| key_repeated?(v) }
        when Array then node.any? { |v| key_repeated?(v) }
        else false
        end
      end

      # A `checksums` key in any object other than a block `extension_blocks`
      # reads (by identity: the same content elsewhere is still elsewhere).
      def checksums_outside_blocks?(bco)
        # identity before insertion: two equal blocks are two blocks
        read = Set.new.compare_by_identity.merge(extension_blocks(bco))
        walk = lambda do |node|
          case node
          when Hash then (node.key?('checksums') && !read.include?(node)) || node.each_value.any?(&walk)
          when Array then node.any?(&walk)
          else false
          end
        end
        walk.call(bco)
      end

      def key_anywhere?(node, key)
        case node
        when Hash then node.key?(key) || node.each_value.any? { |v| key_anywhere?(v, key) }
        when Array then node.any? { |v| key_anywhere?(v, key) }
        else false
        end
      end

      # extension_domain elements whose shape hides any items they carry: an
      # element that is not an object, or an object whose genomicschain_extension
      # is present and not an object (a list wrapping a block, the block as a
      # list). Read only in option 2; option 1 ignores them as before.
      def unshaped_extension_elements(bco)
        Array(bco['extension_domain']).count do |x|
          !x.is_a?(Hash) || (x.key?('genomicschain_extension') && !x['genomicschain_extension'].is_a?(Hash))
        end
      end

      def extension_blocks(bco)
        Array(bco['extension_domain']).filter_map do |x|
          x['genomicschain_extension'] if x.is_a?(Hash) && x['genomicschain_extension'].is_a?(Hash)
        end
      end

      # The bundle's `commitment`, read once over every extension block (§6.1).
      # Two blocks that disagree are the bundle saying two things, so neither
      # is taken — the rule `producer` and `platform` follow — and the 0.2
      # receipts then fail ⑤ with `commitment_declared_twice`.
      #
      # @return [Hash] {'state' => 'none'|'ok'|'unreadable'|'conflict', 'key_id' => hex or nil}
      def commitment_of(bco)
        declared = extension_blocks(bco).select { |b| b.key?('commitment') }.map { |b| b['commitment'] }.uniq
        return { 'state' => 'none', 'key_id' => nil } if declared.empty?
        return { 'state' => 'conflict', 'key_id' => nil } if declared.length > 1

        c = declared.first
        ok = c.is_a?(Hash) && c.keys.sort == %w[key_id rule] && c['rule'] == COMMITMENT_RULE &&
             c['key_id'].is_a?(String) && c['key_id'] =~ HMAC_HEX
        ok ? { 'state' => 'ok', 'key_id' => c['key_id'] } : { 'state' => 'unreadable', 'key_id' => nil }
      end

      def load(bundle)
        bco = bundle.is_a?(String) ? JSON.parse(bundle) : JSON.parse(JSON.generate(bundle))
        raise FormatError, 'bundle is not a JSON object' unless bco.is_a?(Hash)

        spec = bco['spec_version'].to_s
        raise FormatError, 'spec_version does not name an IEEE 2791 BCO' unless spec =~ SPEC_MARK

        %w[description_domain execution_domain io_domain].each do |k|
          raise FormatError, "BCO missing required domain #{k}" unless bco[k].is_a?(Hash)
        end
        normalise_lists(bco)
      rescue JSON::ParserError
        # cause: nil — the parser's message quotes the offending bytes, and a
        # full exception rendering would print the cause (round 4, codex).
        raise FormatError, 'bundle is not valid JSON', cause: nil
      end

      # Rounds 5–7 found one defect class four times — a producer who wrote an
      # element this adapter could not read outgraded one who wrote an honest
      # entry — and twice the fix was applied site by site, leaving the sites
      # nobody had enumerated (round 6: the lists; round 7: the SCM blocks, the
      # parameters, the runtime's own scan of the same array). The rule is
      # therefore applied ONCE, here, where the bundle enters: after this, no
      # list in the bundle holds an element that is not an object, so no site
      # downstream can forget. `load` works on a private re-parse, and the
      # digest subject is the ORIGINAL bytes (§4), so nothing signed is touched.
      #
      # `script[]` is the one list whose bare STRING is a legitimate producer
      # shape — nf-prov 1.7.0 writes exactly that (U0, the fixture) — so a
      # string is lifted into the object form the rest of the list uses, and
      # only a non-string non-object becomes empty. That distinction is stated
      # in §5; round 7 found the design text claiming the opposite.
      def normalise_lists(bco)
        # PRESENCE, not truthiness (round 8, opus5 + codex): a JSON `false`
        # slipped past `if bco[k]` and reached the readers as the string
        # "false", so `"script": false` — naming no script at all — signed
        # `scripts_total: 1` and graded the workflow one level above a bundle
        # that declared nothing.
        ed = bco['execution_domain']
        normalise!(ed, 'script') { |e| e.is_a?(String) ? { 'uri' => { 'uri' => e } } : readable(e) }
        normalise!(ed, 'software_prerequisites')
        dd = bco['description_domain']
        (dd.key?('pipeline_steps') ? as_list(dd['pipeline_steps'], 'pipeline_steps') : []).each do |st|
          next unless st.is_a?(Hash)

          # `input_list` / `output_list` are the evidence §13.4-3 reads to
          # decide which inputs a step produced before reading them; written as
          # an object, `Array()` turned them into pair-arrays and the site
          # dropped them, which HID a weak input and raised the grade (round 8,
          # codex, reproduced).
          %w[prerequisite input_list output_list].each { |k| normalise!(st, k) }
        end
        %w[input_subdomain output_subdomain].each { |k| normalise!(bco['io_domain'], k) }
        normalise!(bco, 'parametric_domain')
        normalise!(bco, 'extension_domain') do |e|
          x = readable(e)
          # An `scm_extension` that is not an object is NOT a declaration, so
          # it is removed rather than emptied (round 8, cursor): emptied, it
          # entered `workflow_of`'s weakest-declaration scan as a rank-0 SCM
          # and beat a valid commit hash in another block. The boundary rule
          # keeps an unreadable element where it feeds a denominator or a
          # stage's own declaration; an absent SCM block feeds neither.
          x.delete('scm_extension') if x.key?('scm_extension') && !x['scm_extension'].is_a?(Hash)
          x['genomicschain_extension'] = normalise_extension(x['genomicschain_extension']) if x['genomicschain_extension'].is_a?(Hash)
          x
        end
        bco
      end

      def normalise!(holder, key, &block)
        return unless holder.is_a?(Hash) && holder.key?(key)

        holder[key] = as_list(holder[key], key).map { |e| block ? block.call(e) : readable(e) }
      end

      # `zk_receipts[]` gets the list rule like `checksums[]`; a `platform` that
      # is not an object says nothing and is removed, the rule for a field
      # where an object belongs (§5 boundary, design v0.1.12 §6.1).
      def normalise_extension(ext)
        normalise!(ext, 'checksums')
        normalise!(ext, 'zk_receipts')
        ext.delete('platform') if ext.key?('platform') && !ext['platform'].is_a?(Hash)
        ext
      end

      # A field the standard defines as an array, written as an object or a
      # scalar, is a structural error and not something to guess at: `Array()`
      # turns a Hash into pair-arrays, which would then be counted as entries
      # and inflate a signed denominator with nonsense (round 7, opus5). The
      # message carries the field name and nothing from the bundle (§6).
      def as_list(value, field)
        return value if value.is_a?(Array)

        raise FormatError, "BCO field #{field} is not an array"
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

      def workflow_of(bco, ed, fp_by_locator = {}, notes = [])
        pd = bco['provenance_domain'].is_a?(Hash) ? bco['provenance_domain'] : {}
        # A block that names nothing is not a declaration and does not enter
        # the weakest-declaration scan (round 8, cursor): as an empty object it
        # ranked 0 and beat a valid commit hash in another block, so adding an
        # empty enrichment block LOWERED an honest workflow grade.
        scms = Array(bco['extension_domain']).filter_map { |e| e.is_a?(Hash) ? e['scm_extension'] : nil }
                                             .select { |s| s.is_a?(Hash) }
                                             .reject { |s| %w[scm_repository scm_commit scm_path].all? { |k| blank_to_nil(s[k]).nil? } }
        # Two SCM declarations are two declarations and the weaker one decides,
        # the rule script[] and the runtime already follow (round 5): reading
        # the first let the order of two extension entries choose the signed
        # grade — a commit hash first and a branch name second graded
        # `immutable`, and swapping them graded `floating`.
        rank = lambda do |s|
          c = blank_to_nil(s['scm_commit'])
          c.nil? ? 0 : (c =~ COMMIT_HASH ? 2 : 1)
        end
        weakest = scms.group_by { |s| rank.call(s) }.min_by { |r, _| r }&.last || []
        scm = weakest.first
        # Two declarations of the SAME rank that disagree are a bundle saying
        # two things, and which one is recorded must not be the array's order
        # (round 7, opus5) — the rule `genomicschain_extension` already follows
        # for a producer and `checksums_from` for a digest: record neither.
        if weakest.uniq { |s| s.values_at('scm_repository', 'scm_commit', 'scm_path').map { |v| blank_to_nil(v) } }.length > 1
          notes << 'the bundle gives more than one SCM declaration of equal strength and they disagree; none is recorded'
          scm = nil
        end
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
        all_pinned = !scripts.empty? && scripts.all? { |l| l && fp_by_locator[l] }
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
          'scripts_with_checksum' => scripts.count { |l| l && fp_by_locator[l] },
          # extension checksums[] joined by every script locator (rounds 4–5):
          # the first script's digest, present only when all scripts have one
          'checksum' => all_pinned ? fp_by_locator[script].dup : nil
        }
      end

      # The runtime is the engine `script_driver` names; its version is the
      # software_prerequisites entry of the same name, when there is one.
      def runtime_of(ed, notes, fp_by_locator = {})
        engine = blank_to_nil(ed['script_driver'])
        return nil if engine.nil?

        entries = Array(ed['software_prerequisites']).select { |s| s.is_a?(Hash) && s['name'].to_s.casecmp?(engine) }
        notes << 'runtime has no version entry in software_prerequisites' if entries.empty?
        notes << 'runtime declared more than once; the weakest declaration is taken' if entries.length > 1
        # Two entries naming the engine are two declarations; the weaker one
        # decides, like every other category (round 4: `find` took the first
        # and the order of two lines chose the signed grade).
        se = weakest_runtime_entry(entries, fp_by_locator)
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
      def software_of(ed, steps, runtime, fp_by_locator = {})
        top = Array(ed['software_prerequisites']).filter_map { |s| software_entry(s, nil, fp_by_locator) }
        top = top.reject { |s| runtime && s['name'].to_s.casecmp?(runtime['engine'].to_s) }
        per_step = steps.flat_map do |pos, st|
          Array(st['prerequisite']).filter_map { |s| software_entry(s, pos, fp_by_locator) }
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
      def software_entry(entry, stage, fp_by_locator = {})
        entry = readable(entry)
        uri = entry['uri'].is_a?(Hash) ? entry['uri'] : { 'uri' => entry['uri'] }
        name = blank_to_nil(entry['name'])
        locator = blank_to_nil(uri['uri'])

        { 'name' => name || locator, 'version' => blank_to_nil(entry['version']), 'locator' => locator,
          'checksum' => checksum_of(uri, locator, fp_by_locator), 'stage' => stage.nil? ? nil : stage.to_i }
      end

      def stages_of(steps, fp_by_locator = {})
        steps.map do |pos, s|
          sw = Array(s['prerequisite']).filter_map { |p| software_entry(p, pos, fp_by_locator) }
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
      def inputs_of(io, internal, fp_by_locator)
        Array(io['input_subdomain']).map do |raw|
          i = readable(raw)
          uri = i['uri'].is_a?(Hash) ? i['uri'] : { 'uri' => i['uri'] }
          locator = blank_to_nil(uri['uri'])
          name = blank_to_nil(uri['filename']) || locator
          name = basename(name) unless name.nil?
          { 'name' => name, 'locator' => locator,
            'checksum' => checksum_of(uri, locator, fp_by_locator),
            'internal' => locator ? internal.include?(locator) : false,
            'reference_hint' => name.to_s =~ REFERENCE_HINT ? true : false }
        end
      end

      def outputs_of(io, fp_by_locator)
        Array(io['output_subdomain']).map do |raw|
          o = readable(raw)
          uri = o['uri'].is_a?(Hash) ? o['uri'] : { 'uri' => o['uri'] }
          locator = blank_to_nil(uri['uri'])

          name = blank_to_nil(uri['filename']) || locator
          { 'name' => name.nil? ? nil : basename(name), 'locator' => locator,
            'checksum' => checksum_of(uri, locator, fp_by_locator),
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

        merged = { 'checksums' => blocks.flat_map { |b| Array(b['checksums']) },
                   'zk_receipts' => blocks.flat_map { |b| Array(b['zk_receipts']) } }
        producers = blocks.filter_map { |b| b['producer'] }.uniq
        merged['producer'] = producers.first if producers.length == 1
        # The same rule for the machine as for the producer: two blocks naming
        # different platforms is the bundle saying two things (v0.1.12).
        platforms = blocks.filter_map { |b| platform_values(b['platform']) }.uniq
        merged['platform'] = platforms.first if platforms.length == 1
        merged['platform_conflict'] = true if platforms.length > 1
        merged
      end

      # design v0.1.12 §6.1 (2): what the producer says the computation ran on.
      # Self-reported, never checked (`platform_as_written` on the record).
      def platform_of(extension, notes)
        if extension['platform_conflict']
          notes << 'the extension blocks name different platforms; neither is recorded'
          return nil
        end
        platform_values(extension['platform'])
      end

      def platform_values(raw)
        return nil unless raw.is_a?(Hash)

        h = PLATFORM_KEYS.to_h { |k| [k, blank_to_nil(raw[k])] }
        h.values.all?(&:nil?) ? nil : h
      end

      # design v0.1.12 §6.1 (3): each declared receipt, read as far as the
      # bundle alone allows — the step it names, the input and output its
      # journal binds, and their recorded SHA-256s — plus the defects that make
      # the declaration unusable. Nothing is dropped or repaired: a defective
      # declaration is reported (gc_prov_check) and refused (the anchor), never
      # quietly left out of the record. Defect codes are names, not values (§6).
      def zk_receipts_of(extension, steps, fp_by_locator)
        decls = Array(extension['zk_receipts'])
        by_number = steps.to_h { |pos, st| [st['step_number'].to_i, [pos, st]] }
        shas = decls.map { |d| hex64(readable(d)['sha256']) }
        decls.each_with_index.map do |raw, i|
          d = readable(raw)
          zkvm = d['zkvm'].is_a?(Hash) ? d['zkvm'] : {}
          # the integer rule `ordered_steps` applies to the steps themselves
          number = d['step_number'].to_s =~ /\A-?\d+\z/ ? d['step_number'].to_i : nil
          pos, st = number.nil? ? nil : by_number[number]
          input_uri = blank_to_nil(d['input_uri'])
          output_uri = blank_to_nil(d['output_uri'])
          r = {
            'receipt_sha256' => shas[i],
            'image_id' => hex64(d['image_id']),
            'zkvm_name' => blank_to_nil(zkvm['name']),
            'zkvm_version' => blank_to_nil(zkvm['version']),
            'step_number' => number,
            'stage' => pos,
            'journal_convention' => blank_to_nil(d['journal']),
            'input_uri' => input_uri,
            'output_uri' => output_uri,
            'input_sha256' => input_uri && fp_by_locator.dig(input_uri, 'sha256'),
            'output_sha256' => output_uri && fp_by_locator.dig(output_uri, 'sha256'),
            # v0.1.16: what a gc-zk-journal-0.2 receipt is compared with (③④)
            'input_hmac_sha256' => input_uri && fp_by_locator.dig(input_uri, 'hmac_sha256'),
            'output_hmac_sha256' => output_uri && fp_by_locator.dig(output_uri, 'hmac_sha256')
          }
          r['defects'] = zk_defects(r, st, shas)
          r
        end
      end

      def zk_defects(r, step, shas)
        out = []
        out << 'receipt_sha256_not_hex' unless r['receipt_sha256']
        out << 'receipt_declared_twice' if r['receipt_sha256'] && shas.count(r['receipt_sha256']) > 1
        out << 'image_id_not_hex' unless r['image_id']
        out << 'zkvm_not_supported' unless r['zkvm_name'] == ZK_VM_NAME && r['zkvm_version']
        out << 'journal_convention_unknown' unless ZK_JOURNALS.include?(r['journal_convention'])
        if step.nil?
          out << 'step_not_in_bundle'
        else
          out << 'input_not_in_step' unless r['input_uri'] && uris_of(step['input_list']).include?(r['input_uri'])
          out << 'output_not_in_step' unless r['output_uri'] && uris_of(step['output_list']).include?(r['output_uri'])
        end
        # The fingerprint the journal is compared with is the convention's own:
        # a plain SHA-256 for 0.1, a gc-commitment-0.1 fingerprint for 0.2.
        if r['journal_convention'] == JOURNAL_V02
          out << 'input_has_no_hmac_sha256' unless r['input_hmac_sha256']
          out << 'output_has_no_hmac_sha256' unless r['output_hmac_sha256']
        else
          out << 'input_has_no_sha256' unless r['input_sha256']
          out << 'output_has_no_sha256' unless r['output_sha256']
        end
        out
      end

      def hex64(v)
        v.is_a?(String) && v =~ SHA256_HEX ? v.downcase : nil
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
      def weakest_runtime_entry(entries, fp_by_locator)
        pred = GenomicsChainProv::Predicate
        ses = entries.filter_map { |e| software_entry(e, nil, fp_by_locator) }
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
      # A `sha256` field that is present but not 64 hex is a FAILED declaration,
      # not a missing one (round 7, opus5): skipping it before the disagreement
      # test meant a good digest plus an unreadable one kept the pin while two
      # readable disagreeing digests lost it — writing nonsense outranked
      # writing something checkable. A locator with no fingerprint field at all
      # says nothing about the digest and is ignored.
      #
      # v0.1.16 §6.1: an item carries `sha256` or `hmac_sha256` (gc-commitment-0.1),
      # and either one fixes the bytes behind the locator. The value is
      # {field => hex}, so the predicate's rows name the field (§6.1
      # outputs_digest). An item carrying both says two things and pins
      # nothing, as does a locator given a `sha256` in one item and an
      # `hmac_sha256` in another. An `hmac_sha256` must be lowercase hex: the
      # rule's own output form, so two spellings of one value cannot disagree.
      def checksums_from(extension, notes = [])
        by_locator = Array(extension['checksums']).each_with_object({}) do |c, acc|
          # PRESENCE of the field, not a usable value (round 8, codex): a
          # `sha256` written as null, "" or whitespace was skipped before the
          # disagreement test, so a good digest beside a blank one kept the pin
          # while a good digest beside "?" lost it.
          next unless c.is_a?(Hash) && blank_to_nil(c['uri'])

          present = FINGERPRINT_FIELDS.select { |f| c.key?(f) }
          next if present.empty?

          (acc[c['uri'].to_s] ||= []) << (present.length == 1 ? fingerprint(present.first, c[present.first]) : nil)
        end
        pinned = by_locator.filter_map { |k, v| [k, v.first.dup] if v.uniq.length == 1 && v.first }.to_h
        if pinned.length < by_locator.length
          notes << 'the extension gives one locator more than one checksum, or an unreadable one; that locator is not pinned'
        end
        pinned
      end

      # {field => lowercase hex}, or nil for a value the field cannot hold.
      def fingerprint(field, value)
        v = blank_to_nil(value).to_s
        ok = field == 'hmac_sha256' ? v =~ HMAC_HEX : v =~ SHA256_HEX
        ok ? { field => v.downcase } : nil
      end

      def malformed_checksum?(bco, extension)
        ext_bad = Array(extension['checksums']).any? do |c|
          c.is_a?(Hash) && FINGERPRINT_FIELDS.any? { |f| blank_to_nil(c[f]) && fingerprint(f, c[f]).nil? }
        end
        io = bco['io_domain']
        io_bad = (Array(io['input_subdomain']) + Array(io['output_subdomain'])).any? do |i|
          u = i.is_a?(Hash) && i['uri'].is_a?(Hash) ? i['uri'] : {}
          blank_to_nil(u['sha1_checksum']) && u['sha1_checksum'].to_s !~ SHA1_HEX
        end
        ext_bad || io_bad
      end

      def checksum_of(uri, locator, fp_by_locator)
        h = {}
        sha1 = blank_to_nil(uri['sha1_checksum'])
        sha1 = nil if sha1 && sha1 !~ SHA1_HEX
        h['sha1'] = sha1.downcase if sha1
        fp = locator && fp_by_locator[locator]
        h.merge!(fp) if fp
        h.empty? ? nil : h
      end

      def basename(locator)
        s = locator.to_s.sub(/[?#].*\z/, '')
        s.split('/').reject(&:empty?).last || s
      end

      # Only a string or a number is a value here (round 8, opus5). `to_s` on
      # anything else put Ruby's own rendering into the signed identity and the
      # signed grade — and `Hash#inspect` changed format in Ruby 3.4, so the
      # same bundle bytes graded `floating` on one interpreter and `ranged` on
      # another, and `workflow_commit` signed as two different strings. The
      # identity has to come from the bundle and the named procedure versions,
      # nothing else (§6).
      def blank_to_nil(v)
        return nil unless v.is_a?(String) || v.is_a?(Numeric)

        v.to_s.strip.empty? ? nil : v.to_s
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
      # locator here — the standard's entries are objects, and guessing would
      # be the producer's string choosing the route. `script[]` is the one
      # exception, handled in `normalise_lists`: the real nf-prov bundle writes
      # that list as bare strings, so there a string is a readable declaration.
      def readable(entry)
        entry.is_a?(Hash) ? entry : {}
      end

      def unset?(v)
        v.nil? || UNSET_VALUES.include?(v.to_s.strip)
      end
    end
  end
end
