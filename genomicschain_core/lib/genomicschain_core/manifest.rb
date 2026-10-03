# frozen_string_literal: true

require 'json'
require 'digest'
require 'rbconfig'
require 'time'

module KairosMcp
  # Manifest — Reproducibility Manifest for GenomicsChain job blocks.
  #
  # Design reference: .work/drafts/b1_implementation_design_v0_4.md
  # Schema:           schemas/job_manifest.schema.json
  #
  # Top-level entry: Manifest.build(args, exec_result)
  #
  # Internal modules (per design §6):
  #   - Builder      — assembles the manifest hash from args + execution result
  #   - CanonicalJson — sort_keys-style canonical serialization + sha256
  #   - Validator    — JSON Schema validation (wraps json-schema gem)
  #   - FileHasher   — per-file content SHA256 walker (no basename mixing)
  #
  # All public callsites use Manifest.build / Manifest.validate! /
  # Manifest.canonical_json / Manifest.walk_files. Internal modules are
  # documented for code review but kept implementation-private.
  module Manifest
    MANIFEST_VERSION = '0.1'

    # Pre-validation DoS gate thresholds (design §2 I7, §4 step 1.5).
    PARAMS_MAX_SERIALIZED_BYTES = 64 * 1024
    PARAMS_MAX_NESTING_DEPTH    = 16

    # Restricted JSON subset rejection patterns (design §7, Guardian PA-M-1).
    # U+2028 (line separator), U+2029 (paragraph separator) must be rejected
    # because Ruby and JS encoders handle them differently.
    LINE_SEPARATOR_BYTES      = " ".bytes.freeze
    PARAGRAPH_SEPARATOR_BYTES = " ".bytes.freeze

    class ManifestError < StandardError; end
    class SchemaViolation < ManifestError; end
    class DoSGateTripped < ManifestError; end
    class RestrictedSubsetViolation < ManifestError; end

    # Top-level builder. See design §4.
    #
    # @param args [Hash] gc_run_fastqc arguments (input_dir, output_dir, paired,
    #                    cores, backend, operator). The :operator object is the
    #                    3-mode oneOf structure from design §2 I3.
    # @param exec [Hash] execution result with keys:
    #                    :input_files, :output_dir, :container_image, :container_digest,
    #                    :container_digest_provenance, :tool_versions, :started_at,
    #                    :elapsed_seconds, :reproducer_cmd, :anonymous_id (when
    #                    operator.mode == 'anonymous'), :backend_metadata (optional).
    # @return [Hash] the assembled manifest, ready for validate! and signing.
    def self.build(args, exec)
      Builder.build(args, exec)
    end

    def self.canonical_json(obj)
      CanonicalJson.serialize(obj)
    end

    def self.canonical_json_sha256(obj)
      CanonicalJson.sha256(obj)
    end

    # Raises SchemaViolation if the manifest does not satisfy the JSON Schema.
    def self.validate!(manifest)
      Validator.validate!(manifest)
    end

    # Returns array of { sha256:, relative_path:, size_bytes: } for every
    # regular file under dir. Content-only SHA256 (no basename mixing).
    def self.walk_files(dir, exclude: [])
      FileHasher.walk(dir, exclude: exclude)
    end

    # Tier-3 executed-R verdict record (design v0.3 §7.3'). A DISTINCT record
    # type from job_manifest — assembled + validated on its own path so a
    # metadata-only (hashes-only) submit does not fail-close against the
    # job_manifest required/minItems constraints.
    def self.build_tier3_verdict(data)
      Tier3Builder.build(data)
    end

    def self.validate_tier3!(record)
      Tier3Validator.validate!(record)
    end

    def self.build_tier1_report(data)
      Tier1Builder.build(data)
    end

    # Tier-2 code-reading adjudication record: same recording path as the
    # other two, its own record type and schema.
    def self.build_tier2_adjudication(data)
      Tier2Builder.build(data)
    end

    def self.validate_tier2!(record)
      Tier2Validator.validate!(record)
    end

    # Tier-4 distillation record (self-application design §7.3, O-2 (a)):
    # a Skill's package digest with the Tier-3 judgments of that Skill.
    # Not deployed to production in v0.1; no tool registers it.
    def self.build_tier4_distillation(data)
      Tier4Builder.build(data)
    end

    def self.validate_tier4!(record)
      Tier4Validator.validate!(record)
    end

    def self.validate_tier1!(record)
      Tier1Validator.validate!(record)
    end

    def self.validate_report_body!(report)
      ReportBodyValidator.validate!(report)
    end

    # Canonical Tier-3 result hash over the sorted list
    # [{relative_path, sha256, size_bytes}] of fetched outputs (design v0.3
    # §1a'). Avoids the basename-collision of the legacy dir hash.
    def self.tier3_result_hash(output_files)
      Tier3Builder.compute_result_hash(output_files)
    end

    # DoS gate. Call before any expensive operation that touches params.
    def self.dos_gate!(params)
      DoSGate.check!(params)
    end

    # Restricted JSON subset enforcement (design §7, Guardian PA-M-1).
    def self.restricted_subset!(params)
      RestrictedSubset.check!(params)
    end

    # ----------------------------------------------------------------------
    # Internal modules
    # ----------------------------------------------------------------------

    module DoSGate
      def self.check!(params)
        serialized = JSON.generate(params)
        if serialized.bytesize > PARAMS_MAX_SERIALIZED_BYTES
          raise DoSGateTripped,
                "params serialized size #{serialized.bytesize} bytes exceeds gate #{PARAMS_MAX_SERIALIZED_BYTES}"
        end
        depth = compute_depth(params)
        if depth > PARAMS_MAX_NESTING_DEPTH
          raise DoSGateTripped,
                "params nesting depth #{depth} exceeds gate #{PARAMS_MAX_NESTING_DEPTH}"
        end
        true
      end

      def self.compute_depth(obj, current = 0)
        case obj
        when Hash
          return current if obj.empty?
          obj.values.map { |v| compute_depth(v, current + 1) }.max
        when Array
          return current if obj.empty?
          obj.map { |v| compute_depth(v, current + 1) }.max
        else
          current
        end
      end
    end

    module RestrictedSubset
      def self.check!(params)
        walk(params)
        true
      end

      def self.walk(obj)
        case obj
        when Hash
          obj.each do |k, v|
            check_key!(k)
            walk(v)
          end
        when Array
          obj.each { |v| walk(v) }
        when Float
          if obj.nan? || obj.infinite?
            raise RestrictedSubsetViolation, "NaN/Infinity not allowed in params"
          end
          # -0.0 detection: 1.0/-0.0 == -Infinity
          if obj == 0.0 && (1.0 / obj).negative?
            raise RestrictedSubsetViolation, "-0.0 not allowed in params"
          end
        when String
          check_string!(obj)
        end
      end

      def self.check_key!(key)
        s = key.to_s
        # ASCII keys only (design §7)
        return if s.bytes.all? { |b| b < 128 }
        raise RestrictedSubsetViolation, "non-ASCII key not allowed: #{s.inspect}"
      end

      def self.check_string!(s)
        # U+2028 and U+2029 must be rejected (Guardian PA-M-1)
        if s.include?(" ") || s.include?(" ")
          raise RestrictedSubsetViolation,
                "U+2028/U+2029 in string values not allowed; encoders disagree on encoding"
        end
      end
    end

    module CanonicalJson
      # Canonical JSON for Beta: JSON.generate with recursively sorted keys.
      # Full RFC 8785 (JCS) deferred to a future manifest_version bump (I5).
      def self.serialize(obj)
        JSON.generate(sort_recursive(obj))
      end

      def self.sha256(obj)
        Digest::SHA256.hexdigest(serialize(obj))
      end

      def self.sort_recursive(obj)
        case obj
        when Hash
          obj.keys.map(&:to_s).sort.each_with_object({}) do |k, acc|
            # key? not ||: `false || obj[k.to_sym]` is nil, so every false in a
            # signed payload, a digest subject or a stored evidence envelope
            # used to serialise as null (found 2026-09-09 when the Tier-2
            # record's lever booleans came back null; the same path had been
            # nulling tier3's leaderboard_eligible and all_identical, and the
            # corpus report_content_hash covers levers that are false).
            v = obj.key?(k) ? obj[k] : obj[k.to_sym]
            acc[k] = sort_recursive(v)
          end
        when Array
          obj.map { |v| sort_recursive(v) }
        else
          obj
        end
      end
    end

    module FileHasher
      def self.walk(dir, exclude: [])
        return [] unless Dir.exist?(dir)
        results = []
        excluded = exclude.map { |e| File.expand_path(e, dir) }
        Dir.glob(File.join(dir, '**', '*')).sort.each do |path|
          next unless File.file?(path)
          abs = File.expand_path(path)
          next if excluded.include?(abs)
          results << {
            sha256: Digest::SHA256.file(path).hexdigest,
            relative_path: relative_to(path, dir),
            size_bytes: File.size(path)
          }
        end
        results
      end

      def self.relative_to(path, base)
        Pathname.new(path).relative_path_from(Pathname.new(base)).to_s
      end
    end

    module Validator
      SCHEMA_PATH = File.expand_path('../../schemas/job_manifest.schema.json', __dir__)

      def self.validate!(manifest)
        require 'json-schema'
        errors = JSON::Validator.fully_validate(
          schema, manifest,
          errors_as_objects: true,
          version: :draft4
        )
        return true if errors.empty?
        raise SchemaViolation, "manifest schema violation: #{errors.first[:message]}"
      end

      def self.schema_path
        SCHEMA_PATH
      end

      # Cached parsed schema. The json-schema gem accepts a Hash (parsed) or a
      # raw JSON string; both bypass the URI-based loader that mishandles
      # absolute paths starting with `/`.
      def self.schema
        @schema ||= JSON.parse(File.read(SCHEMA_PATH))
      end
    end

    module Tier3Validator
      SCHEMA_PATH = File.expand_path('../../schemas/tier3_verdict.schema.json', __dir__)

      def self.validate!(record)
        require 'json-schema'
        errors = JSON::Validator.fully_validate(
          schema, record,
          errors_as_objects: true,
          version: :draft4
        )
        return true if errors.empty?
        raise SchemaViolation, "tier3_verdict schema violation: #{errors.first[:message]}"
      end

      def self.schema
        @schema ||= JSON.parse(File.read(SCHEMA_PATH))
      end
    end

    module Tier3Builder
      TIER3_RECORD_VERSION = '0.3'

      EXECUTION_VERDICTS  = %w[completed env_failed data_blocked outputs_unusable].freeze
      COMPARISON_VERDICTS = %w[no_target_declared match_exact match_normalized mismatch not_attempted].freeze

      # Assemble a tier3_verdict record from gc_tier3_execute output.
      #
      # Record 0.3 carries TWO verdict axes instead of one. "Did it run" and
      # "did it match" are independent questions, and the 2026-08-14 corpus
      # survey found 0/5 gate-passing papers declaring any comparison target —
      # so "ran, nothing to compare against" is the COMMON outcome and needs a
      # word of its own rather than being filed as an inconclusive comparison.
      #
      # expected_output is therefore OPTIONAL. environment_provenance and
      # inputs_provenance are REQUIRED and never defaulted: a record that does
      # not say whose environment ran cannot be turned into an honest
      # certificate, and silently guessing is the exact failure this split
      # exists to prevent.
      #
      # @param data [Hash] verdict identity + operator + optional expected_output
      #                    + optional hashes-only input/output files. String or
      #                    symbol keys accepted.
      def self.build(data)
        d = data.transform_keys(&:to_s)

        operator_in = d['operator']
        raise ManifestError, "operator field is required for tier3_verdict" if operator_in.nil?

        output_files = normalize_hash_files(d['output_files'])
        result_hash = d['result_hash']
        if result_hash.nil? && output_files && !output_files.empty?
          result_hash = compute_result_hash(output_files)
        end
        raise ManifestError, "result_hash or non-empty output_files required" if result_hash.nil?

        exec_verdict = d['execution_verdict']
        cmp_verdict  = d['comparison_verdict']
        unless EXECUTION_VERDICTS.include?(exec_verdict)
          raise ManifestError,
                "execution_verdict must be one of #{EXECUTION_VERDICTS.join(', ')} (got #{exec_verdict.inspect})"
        end
        unless COMPARISON_VERDICTS.include?(cmp_verdict)
          raise ManifestError,
                "comparison_verdict must be one of #{COMPARISON_VERDICTS.join(', ')} (got #{cmp_verdict.inspect})"
        end

        env_prov = d['environment_provenance']
        in_prov  = d['inputs_provenance']
        raise ManifestError, 'environment_provenance is required (never defaulted)' if env_prov.nil?
        raise ManifestError, 'inputs_provenance is required (use "unknown" if undetermined)' if in_prov.nil?

        run_count = (d['run_count'] || 1).to_i
        raise ManifestError, "run_count must be >= 1 (got #{run_count})" if run_count < 1

        expected = d['expected_output'] && d['expected_output'].transform_keys(&:to_s)
        if cmp_verdict == 'no_target_declared' && expected && expected['sha256']
          raise ManifestError,
                'comparison_verdict=no_target_declared contradicts a supplied expected_output.sha256'
        end

        record = {
          'record_type'            => 'tier3_verdict',
          'record_version'         => TIER3_RECORD_VERSION,
          'mcp_tool_name'          => 'gc_tier3_submit',
          'mcp_tool_version'       => KairosMcp::VERSION,
          'subject_ref'            => d['subject_ref'],
          'jobspec_digest'         => d['jobspec_digest'],
          'execution_verdict'      => exec_verdict,
          'comparison_verdict'     => cmp_verdict,
          'environment_provenance' => env_prov,
          'inputs_provenance'      => in_prov,
          'run_count'              => run_count,
          'trust_tier'             => d['trust_tier'] || 'self_reported',
          'result_hash'            => result_hash,
          'backend_id'             => d['backend_id'],
          'started_at'             => d['started_at'] || Time.now.utc.iso8601,
          'elapsed_seconds'        => d['elapsed_seconds'] || 0,
          'operator'               => Builder.build_operator(operator_in, d)
        }
        if expected && expected['sha256']
          record['expected_output']        = expected
          record['expected_output_sha256'] = expected['sha256']
        end
        record['comparator_id']       = d['comparator_id'] if d['comparator_id']
        record['comparator_version']  = d['comparator_version'] if d['comparator_version']
        record['self_consistency']    = normalize_self_consistency(d['self_consistency']) if run_count > 1
        record['backend_result_hash'] = d['backend_result_hash'] if d['backend_result_hash']
        record['input_files']         = normalize_hash_files(d['input_files']) if d['input_files']
        record['output_files']        = output_files if output_files
        record['container_digest']    = d['container_digest'] if d['container_digest']
        record['result_evidence_sha256'] = d['result_evidence_sha256'] if d['result_evidence_sha256']
        record['evidence_sha256']        = d['evidence_sha256'] if d['evidence_sha256']
        record['submission_key']         = d['submission_key'] if d['submission_key']
        record['leaderboard_eligible'] = d['leaderboard_eligible'] unless d['leaderboard_eligible'].nil?
        record['backend_metadata']    = d['backend_metadata'] if d['backend_metadata']
        record
      end

      # Canonical result hash over sorted [{relative_path, sha256, size_bytes}]
      # (design v0.3 §1a'). Content is hashed via canonical JSON of the sorted
      # list, so duplicate basenames in different dirs no longer collide.
      def self.compute_result_hash(output_files)
        norm = normalize_hash_files(output_files) || []
        sorted = norm.sort_by { |f| f['relative_path'].to_s }
        Digest::SHA256.hexdigest(CanonicalJson.serialize(sorted))
      end

      def self.normalize_hash_files(files)
        return nil if files.nil?
        files.map do |f|
          h = f.transform_keys(&:to_s)
          out = { 'sha256' => h['sha256'] }
          out['relative_path'] = h['relative_path'] if h['relative_path']
          out['size_bytes']    = h['size_bytes']    if h['size_bytes']
          out
        end
      end

      # self_consistency is what run_count > 1 actually buys. It reports the
      # NUMBER of runs and whether they agreed; it never asserts "stable" or
      # "deterministic", because how much N agreeing runs are worth depends on
      # the pipeline (a tool that picks one of two answers at random agrees
      # with itself half the time at N=2) and that judgement belongs to the
      # reader, not to this record.
      def self.normalize_self_consistency(raw)
        h = (raw || {}).transform_keys(&:to_s)
        runs = (h['runs'] || 0).to_i
        raise ManifestError, 'self_consistency.runs must be >= 2' if runs < 2
        if h['all_identical'].nil?
          raise ManifestError, 'self_consistency.all_identical is required'
        end

        out = {
          'runs' => runs,
          'all_identical' => h['all_identical'] ? true : false,
          'comparator_id' => (h['comparator_id'] || 'exact_sha256').to_s
        }
        out['run_result_hashes'] = Array(h['run_result_hashes']).map(&:to_s) if h['run_result_hashes']
        out['first_divergence']  = h['first_divergence'] if h['first_divergence']
        out['variation']         = h['variation'] if h['variation']
        out
      end
    end

    module Tier1Validator
      SCHEMA_PATH = File.expand_path('../../schemas/tier1_report.schema.json', __dir__)

      def self.validate!(record)
        require 'json-schema'
        errors = JSON::Validator.fully_validate(
          schema, record,
          errors_as_objects: true,
          version: :draft4
        )
        return true if errors.empty?
        raise SchemaViolation, "tier1_report schema violation: #{errors.first[:message]}"
      end

      def self.schema
        @schema ||= JSON.parse(File.read(SCHEMA_PATH))
      end
    end

    # Draft-04 admission gate for Tier-1 report_json (v0.2.6 required set).
    module ReportBodyValidator
      SCHEMA_PATH = File.expand_path('../../schemas/report_schema_v0_2_6.submit_gate.json', __dir__)

      def self.validate!(report)
        require 'json-schema'
        errors = JSON::Validator.fully_validate(
          schema, report,
          errors_as_objects: true,
          version: :draft4
        )
        return true if errors.empty?
        raise SchemaViolation, "report_schema_v0_2_6 violation: #{errors.first[:message]}"
      end

      def self.schema
        @schema ||= JSON.parse(File.read(SCHEMA_PATH))
      end
    end

    module Tier2Validator
      SCHEMA_PATH = File.expand_path('../../schemas/tier2_adjudication.schema.json', __dir__)

      def self.validate!(record)
        require 'json-schema'
        errors = JSON::Validator.fully_validate(
          schema, record,
          errors_as_objects: true,
          version: :draft4
        )
        return true if errors.empty?
        raise SchemaViolation, "tier2_adjudication schema violation: #{errors.first[:message]}"
      end

      def self.schema
        @schema ||= JSON.parse(File.read(SCHEMA_PATH))
      end
    end

    # Assembles a tier2_adjudication record. Identities and counts only: the
    # adjudication body and the scan stay with the operator and are bound by
    # adjudication_digest / codescan_evidence_digest. stage_transition.applied
    # is forced false — the rubric's human sign-off applies a transition, a
    # signed proposal does not.
    module Tier2Builder
      TIER2_RECORD_VERSION = '0.1'

      def self.build(data)
        d = data.transform_keys(&:to_s)
        operator_in = d['operator']
        raise ManifestError, 'operator field is required for tier2_adjudication' if operator_in.nil?

        levers = (d['levers'] || {}).transform_keys(&:to_s)
        counts = (d['counts'] || {}).transform_keys(&:to_s)
        st = (d['stage_transition'] || {}).transform_keys(&:to_s)

        record = {
          'record_type' => 'tier2_adjudication',
          'record_version' => TIER2_RECORD_VERSION,
          'mcp_tool_name' => 'gc_tier2_submit',
          'mcp_tool_version' => KairosMcp::VERSION,
          'subject_ref' => d['subject_ref'],
          'canonical_id_value' => d['canonical_id_value'],
          'tier1_report_content_hash' => d['tier1_report_content_hash'],
          'tier1_rubric_version' => d['tier1_rubric_version'],
          'tier1_funnel_stage' => d['tier1_funnel_stage'],
          'codescan_evidence_digest' => d['codescan_evidence_digest'],
          'codescan_rubric_version' => d['codescan_rubric_version'],
          'adjudication_rubric_version' => d['adjudication_rubric_version'],
          'adjudication_digest' => d['adjudication_digest'],
          'levers' => {
            'declared_lock' => levers['declared_lock'] ? true : false,
            'byte_fixed_lock' => levers['byte_fixed_lock'] ? true : false,
            'in_code_db_pin_classA' => levers['in_code_db_pin_classA'] ? true : false,
            'headline' => levers['headline']
          },
          'counts' => {
            'rules_in_code' => counts['rules_in_code'],
            'rules_unique' => counts['rules_unique'],
            'tier1_steps' => counts['tier1_steps'],
            'steps_linked' => counts['steps_linked'],
            'steps_unlinked' => counts['steps_unlinked'],
            'proposed_demotions' => counts['proposed_demotions'],
            'demotion_proposal_is_a_lower_bound' => true
          },
          'ambiguous_links' => d['ambiguous_links'].to_i,
          'discrepancy_codes' => Array(d['discrepancy_codes']).map(&:to_s),
          'toolchain' => (d['toolchain'] || {}).transform_keys(&:to_s),
          'stage_transition' => { 'from' => st['from'], 'to' => st['to'], 'applied' => false },
          'trust_tier' => d['trust_tier'] || 'self_reported',
          'operator' => Builder.build_operator(operator_in, d)
        }
        record['adjudication_toolchain'] = d['adjudication_toolchain'].transform_keys(&:to_s) if d['adjudication_toolchain']
        record['repository'] = d['repository'].transform_keys(&:to_s) if d['repository']
        record['submission_key'] = d['submission_key'] if d['submission_key']
        record
      end
    end

    module Tier4Validator
      SCHEMA_PATH = File.expand_path('../../schemas/tier4_distillation.schema.json', __dir__)

      def self.validate!(record)
        require 'json-schema'
        errors = JSON::Validator.fully_validate(
          schema, record,
          errors_as_objects: true,
          version: :draft4
        )
        return true if errors.empty?
        raise SchemaViolation, "tier4_distillation schema violation: #{errors.first[:message]}"
      end

      def self.schema
        @schema ||= JSON.parse(File.read(SCHEMA_PATH))
      end
    end

    # Tier-4 distillation record 0.1 (self-application design §7.1, §7.3).
    #
    # Tier 4 authors and Tier 3 judges (INV-S4). So the record carries the
    # Skill's identity and the Tier-3 verdicts that judged it, and the two pass
    # flags are DERIVED here from those verdicts; a caller that supplies them
    # is refused, because a distiller that could write its own pass flag would
    # be judging its own Skill.
    #
    # The order INV-S4 requires — package digest recorded, then the second
    # seed drawn, then the reference fixed — is checked on the recorded times.
    # Those times are self-reported; what makes them evidence is an external
    # timestamp, not this check. The check only refuses a record that
    # contradicts itself.
    #
    # Until the Tier-3 records exist (S9), the cited Tier-3 runs are named by
    # execution identity (jobspec_digest + result_hash) and tier3_record_ref
    # is null (§7.3).
    module Tier4Builder
      TIER4_RECORD_VERSION = '0.1'
      PASS_EXECUTION = 'completed'
      PASS_COMPARISON = 'match_exact'
      DERIVED_FIELDS = %w[reversion_passed other_data_passed leaderboard_eligible].freeze

      # The S-1 tree rule: sha256 over "<sha256>  <relative path>\n" lines,
      # sorted bytewise by path (scripts/selfapp/ddc_common.rb).
      def self.package_digest(package_files)
        lines = package_files.map { |f| f.transform_keys(&:to_s) }
                             .sort_by { |f| f['relative_path'].b }
                             .map { |f| "#{f['sha256']}  #{f['relative_path']}\n" }
        Digest::SHA256.hexdigest(lines.join)
      end

      def self.build(data)
        d = deep_strings(data)
        raise ManifestError, 'operator field is required for tier4_distillation' if d['operator'].nil?

        supplied = DERIVED_FIELDS & d.keys
        unless supplied.empty?
          raise ManifestError, "#{supplied.join(', ')} are derived, not supplied (INV-S4)"
        end

        files = Array(d['package_files']).map { |f| { 'relative_path' => f['relative_path'], 'sha256' => f['sha256'] } }
                                         .sort_by { |f| f['relative_path'].to_s.b }
        raise ManifestError, 'package_files is required' if files.empty?
        recomputed = package_digest(files)
        unless recomputed == d['package_digest']
          raise ManifestError, "package_digest #{d['package_digest'].inspect} does not match package_files (#{recomputed})"
        end

        reversion = d['reversion'] || raise(ManifestError, 'reversion is required')
        other = d['other_data'] || raise(ManifestError, 'other_data is required (performed: false with a reason when not done)')
        check_order!(d['package_digest_recorded_at'], other)

        record = {
          'record_type' => 'tier4_distillation',
          'record_version' => TIER4_RECORD_VERSION,
          'mcp_tool_name' => 'gc_tier4_submit',
          'mcp_tool_version' => KairosMcp::VERSION,
          'subject_ref' => d['subject_ref'],
          'stage' => d['stage'],
          'package_digest' => recomputed,
          'package_files' => files,
          'package_digest_recorded_at' => d['package_digest_recorded_at'],
          'distiller' => d['distiller'],
          'acceptance' => d['acceptance'],
          'source' => d['source'],
          'reversion' => reversion,
          'other_data' => other,
          'reversion_passed' => passed?(reversion),
          'other_data_passed' => other['performed'] == true ? passed?(other) : nil,
          'trust_tier' => d['trust_tier'] || 'self_reported',
          'leaderboard_eligible' => false,
          'recorded_at' => d['recorded_at'] || Time.now.utc.iso8601,
          'operator' => Builder.build_operator(d['operator'], d)
        }
        record['submission_key'] = d['submission_key'] if d['submission_key']
        record
      end

      def self.passed?(check)
        check['execution_verdict'] == PASS_EXECUTION && check['comparison_verdict'] == PASS_COMPARISON
      end

      def self.check_order!(digest_at, other)
        return unless other['performed'] == true

        times = [['package_digest_recorded_at', digest_at], ['seed_drawn_at', other['seed_drawn_at']],
                 ['reference_fixed_at', other['reference_fixed_at']]]
        parsed = times.map do |name, t|
          Time.iso8601(t.to_s)
        rescue ArgumentError
          raise ManifestError, "#{name} is not an ISO 8601 time (#{t.inspect})"
        end
        return if parsed.each_cons(2).all? { |a, b| a < b }

        raise ManifestError, 'INV-S4 order violated: the package digest must be recorded before the seed is ' \
                             "drawn, and the seed drawn before the reference is fixed (#{times.map(&:last).join(' / ')})"
      end

      def self.deep_strings(obj)
        case obj
        when Hash then obj.each_with_object({}) { |(k, v), h| h[k.to_s] = deep_strings(v) }
        when Array then obj.map { |v| deep_strings(v) }
        else obj
        end
      end
    end

    module Tier1Builder
      TIER1_RECORD_VERSION = '0.1'

      def self.build(data)
        d = data.transform_keys(&:to_s)
        operator_in = d['operator']
        raise ManifestError, 'operator field is required for tier1_report' if operator_in.nil?

        headline = (d['headline'] || {}).transform_keys(&:to_s)
        stack = (d['assessor_stack'] || {}).transform_keys(&:to_s)
        llm = (stack['llm'] || {}).transform_keys(&:to_s)

        record = {
          'record_type' => 'tier1_report',
          'record_version' => TIER1_RECORD_VERSION,
          'mcp_tool_name' => 'gc_tier1_submit',
          'mcp_tool_version' => KairosMcp::VERSION,
          'subject_ref' => d['subject_ref'],
          'report_content_hash' => d['report_content_hash'],
          'canonical_id_value' => d['canonical_id_value'],
          'rubric_version' => d['rubric_version'],
          'rubric_hash' => d['rubric_hash'],
          'headline' => { 'static_readiness' => headline['static_readiness'] },
          'funnel_stage' => d['funnel_stage'],
          'assessor_stack' => {
            'operator_id' => stack['operator_id'],
            'stage' => stack['stage'],
            'llm' => {
              'provider' => llm['provider'],
              'model' => llm['model'],
              'invoked_at' => llm['invoked_at']
            }
          },
          'assessor_id' => d['assessor_id'],
          'trust_tier' => d['trust_tier'] || 'self_reported',
          'operator' => Builder.build_operator(operator_in, d)
        }
        record['manifest_b1_hash'] = d['manifest_b1_hash'] if d['manifest_b1_hash']
        record['manifest_supersedes'] = d['manifest_supersedes'] if d.key?('manifest_supersedes')
        record['submission_key'] = d['submission_key'] if d['submission_key']
        record
      end
    end

    module Builder
      def self.build(args, exec)
        # 1. DoS gate + restricted subset check (before any expensive work).
        params = (args['params'] || args[:params] || {
          'paired' => args['paired'] || args[:paired] || false,
          'cores'  => args['cores']  || args[:cores]  || 4
        }).then { |h| h.transform_keys(&:to_s) }

        Manifest.dos_gate!(params)
        Manifest.restricted_subset!(params)

        # 2. Per-file walks (input + output). gc_metadata.json sidecar is gone
        #    (B1: §3 R7), so no exclude needed.
        input_dir  = args['input_dir']  || args[:input_dir]
        output_dir = args['output_dir'] || args[:output_dir] || exec[:output_dir]

        input_files = Manifest.walk_files(input_dir).map do |f|
          { 'sha256' => f[:sha256],
            'original_name' => f[:relative_path],
            'size_bytes' => f[:size_bytes] }
        end
        output_files = Manifest.walk_files(output_dir).map do |f|
          { 'sha256' => f[:sha256],
            'relative_path' => f[:relative_path],
            'size_bytes' => f[:size_bytes] }
        end

        # 3. params_sha256 over canonical form.
        params_sha256 = Manifest.canonical_json_sha256(params)

        # 4. Runtime.
        runtime = {
          'os' => RbConfig::CONFIG['host_os'] || 'unknown',
          'arch' => RbConfig::CONFIG['host_cpu'] || 'unknown'
        }
        # host_anonymized is server-set or omitted; never client-supplied.
        if exec[:host_anonymized]
          runtime['host_anonymized'] = exec[:host_anonymized].to_s
        end

        # 5. Reproducer (Beta: docker only).
        reproducer = nil
        if exec[:reproducer_cmd]
          reproducer = {
            'docker' => {
              'image' => exec[:container_image] || '',
              'cmd' => placeholder_substitute(exec[:reproducer_cmd], input_dir, output_dir)
            }
          }
        end

        # 6. Operator (3-mode oneOf — design §2 I3, schema operator.oneOf).
        operator_in = args['operator'] || args[:operator]
        raise ManifestError, "operator field is required (design §4 F1; field omission is rejected on all transports)" if operator_in.nil?
        operator_out = build_operator(operator_in, exec)

        manifest = {
          'manifest_version' => MANIFEST_VERSION,
          'mcp_tool_name'    => (args['mcp_tool_name'] || args[:mcp_tool_name] || 'gc_run_fastqc').to_s,
          'mcp_tool_version' => (args['mcp_tool_version'] || args[:mcp_tool_version] || KairosMcp::VERSION).to_s,
          'backend'          => (args['backend'] || args[:backend] || 'local').to_s,
          'input_files'      => input_files,
          'params'           => params,
          'params_sha256'    => params_sha256,
          'container_image'  => exec[:container_image] || '',
          'container_digest' => exec[:container_digest] || ('sha256:' + ('0' * 64)),
          'container_digest_provenance' => exec[:container_digest_provenance] || 'unavailable',
          'tool_versions'    => (exec[:tool_versions] || {}).transform_keys(&:to_s),
          'runtime'          => runtime,
          'output_files'     => output_files,
          'started_at'       => exec[:started_at] || Time.now.utc.iso8601,
          'elapsed_seconds'  => exec[:elapsed_seconds] || 0,
          'operator'         => operator_out
        }
        manifest['reproducer'] = reproducer if reproducer
        if exec[:backend_metadata]
          manifest['backend_metadata'] = exec[:backend_metadata]
        end

        manifest
      end

      # Builds the operator sub-object per mode.
      # In `signed` mode, signature verification is the caller's responsibility
      # (Manifest::Signer.verify_admission_request!) — Builder records what the
      # caller submitted.
      def self.build_operator(op, exec)
        mode = (op['mode'] || op[:mode]).to_s
        case mode
        when 'signed'
          pubkey = op['pubkey'] || op[:pubkey]
          sig    = op['signature'] || op[:signature]
          raise ManifestError, "signed operator requires pubkey and signature" if pubkey.nil? || sig.nil?
          { 'mode' => 'signed',
            'pubkey' => pubkey.to_s,
            'signature' => normalize_signature_envelope(sig) }
        when 'anonymous'
          anonymous_id = exec[:anonymous_id] || op['anonymous_id'] || op[:anonymous_id]
          if anonymous_id.nil?
            anonymous_id = generate_anonymous_id
          end
          { 'mode' => 'anonymous', 'anonymous_id' => anonymous_id.to_s }
        when 'alpha_legacy'
          { 'mode' => 'alpha_legacy', 'legacy' => true }
        else
          raise ManifestError, "unknown operator mode: #{mode.inspect}"
        end
      end

      # Produces the anonymous_id per design Q7: "anonymous-" + 16 hex from CSPRNG.
      def self.generate_anonymous_id
        require 'securerandom'
        'anonymous-' + SecureRandom.hex(8)
      end

      def self.normalize_signature_envelope(sig)
        # Canonicalize the signature envelope keys. The inner bytes field is
        # named `value` (v0.4 F5 rename, not `signature`).
        s = sig.transform_keys(&:to_s)
        {
          'algorithm'      => s['algorithm'] || 'ed25519',
          'signed_fields'  => s['signed_fields'] || %w[mcp_tool_name params nonce chain_tip_hash],
          'value'          => s['value'] || s['signature'], # accept legacy key during admission for safety, but never emit
          'nonce'          => s['nonce'],
          'chain_tip_hash' => s['chain_tip_hash']
        }
      end

      def self.placeholder_substitute(cmd, input_dir, output_dir)
        return [] if cmd.nil?
        tokens = cmd.is_a?(Array) ? cmd : cmd.to_s.split(/\s+/)
        tokens.map do |t|
          replaced = t.to_s
          replaced = replaced.gsub(input_dir.to_s, '<INPUT_DIR>') if input_dir
          replaced = replaced.gsub(output_dir.to_s, '<OUTPUT_DIR>') if output_dir
          replaced
        end
      end
    end
  end
end

require 'pathname'
