# frozen_string_literal: true

require 'json'
require 'digest'
require 'rbconfig'

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

    # Tier-2 executed-R verdict record (design v0.3 §7.3'). A DISTINCT record
    # type from job_manifest — assembled + validated on its own path so a
    # metadata-only (hashes-only) submit does not fail-close against the
    # job_manifest required/minItems constraints.
    def self.build_tier2_verdict(data)
      Tier2Builder.build(data)
    end

    def self.validate_tier2!(record)
      Tier2Validator.validate!(record)
    end

    def self.build_tier1_report(data)
      Tier1Builder.build(data)
    end

    def self.validate_tier1!(record)
      Tier1Validator.validate!(record)
    end

    def self.validate_report_body!(report)
      ReportBodyValidator.validate!(report)
    end

    # Canonical Tier-2 result hash over the sorted list
    # [{relative_path, sha256, size_bytes}] of fetched outputs (design v0.3
    # §1a'). Avoids the basename-collision of the legacy dir hash.
    def self.tier2_result_hash(output_files)
      Tier2Builder.compute_result_hash(output_files)
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
            v = obj[k] || obj[k.to_sym]
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

    module Tier2Validator
      SCHEMA_PATH = File.expand_path('../../schemas/tier2_verdict.schema.json', __dir__)

      def self.validate!(record)
        require 'json-schema'
        errors = JSON::Validator.fully_validate(
          schema, record,
          errors_as_objects: true,
          version: :draft4
        )
        return true if errors.empty?
        raise SchemaViolation, "tier2_verdict schema violation: #{errors.first[:message]}"
      end

      def self.schema
        @schema ||= JSON.parse(File.read(SCHEMA_PATH))
      end
    end

    module Tier2Builder
      TIER2_RECORD_VERSION = '0.2'

      # Assemble a tier2_verdict record from gc_tier2_execute output.
      # @param data [Hash] verdict identity + operator + expected_output +
      #                    optional hashes-only input/output files. String or
      #                    symbol keys accepted.
      def self.build(data)
        d = data.transform_keys(&:to_s)

        operator_in = d['operator']
        raise ManifestError, "operator field is required for tier2_verdict" if operator_in.nil?

        output_files = normalize_hash_files(d['output_files'])
        result_hash = d['result_hash']
        if result_hash.nil? && output_files && !output_files.empty?
          result_hash = compute_result_hash(output_files)
        end
        raise ManifestError, "result_hash or non-empty output_files required" if result_hash.nil?

        expected = (d['expected_output'] || {}).transform_keys(&:to_s)
        raise ManifestError, "expected_output.sha256 required" if expected['sha256'].nil?

        record = {
          'record_type'            => 'tier2_verdict',
          'record_version'         => TIER2_RECORD_VERSION,
          'mcp_tool_name'          => 'gc_tier2_submit',
          'mcp_tool_version'       => KairosMcp::VERSION,
          'subject_ref'            => d['subject_ref'],
          'jobspec_digest'         => d['jobspec_digest'],
          'verdict'                => d['verdict'],
          'trust_tier'             => d['trust_tier'] || 'self_reported',
          'result_hash'            => result_hash,
          'expected_output'        => expected,
          'expected_output_sha256' => expected['sha256'],
          'comparator_id'          => d['comparator_id'],
          'comparator_version'     => d['comparator_version'],
          'backend_id'             => d['backend_id'],
          'started_at'             => d['started_at'] || Time.now.utc.iso8601,
          'elapsed_seconds'        => d['elapsed_seconds'] || 0,
          'operator'               => Builder.build_operator(operator_in, d)
        }
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
