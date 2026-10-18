# frozen_string_literal: true

require 'json'
require 'digest'
require 'base64'
require 'genomicschain_core'
require_relative '../../genomicschain_prov'
require_relative '../identity'
require_relative '../zk_verifier'

module GenomicsChainProv
  module VerdictSpec
    # Prov — SubmitCore hooks for the Tier-2.5 provenance record (design v0.1
    # §6, §6.1 v0.1.12). Same shape as the Tier-2 spec:
    #
    #   Tier-2  digest subject = the adjudication   identity = derived from it
    #   prov    digest subject = the bundle          identity = derived from it
    #                                                (adapter + predicate)
    #
    # The bundle is submitted verbatim, its canonical digest recomputed, every
    # signed field derived again and compared with what the customer signed.
    # Nothing about the identity is taken on the client's word.
    #
    # Two things this spec adds over Tier-2, both from v0.1.12 §6.1:
    #
    #   the receipt gate — every declared ZK receipt must arrive, verify
    #   against its image ID and bind the step's recorded input and output
    #   (ZkVerifier ①–④). There is no grade gate: v0.1.13 withdrew the
    #   immutable requirement, so a record is issued at any grade and carries
    #   it as computed;
    #
    #   a lifetime — proof_ttl is 100 years, passed through core 0.6.0's
    #   store_proof!, where every other tier keeps the engine's 24 hours.
    #
    # The bundle, the predicate's per-item output and the receipt bytes are
    # held in memory for this one derivation and go nowhere else: not into an
    # exception message, not into a log, not into the response (§6). Messages
    # here carry field names, grades, counts and codes only.
    class Prov
      Core = KairosMcp::SkillSets::GenomicschainCore
      SubmitCore = Core::SubmitCore

      class ZkDeclarationInvalid < SubmitCore::SubmitError; end
      class ZkReceiptRejected < SubmitCore::SubmitError; end
      class ZkVerifierUnavailable < SubmitCore::SubmitError; end
      class FormatRejected < SubmitCore::SubmitError; end
      # A signed identity that differs from the anchor's derivation only in the
      # procedure versions is a version skew, not a forgery; it gets its own
      # class so the tool can return the anchor's versions (§6). A client
      # older than v0.1.14 signs no resources_rule_version and lands here too:
      # it is told what the anchor runs, and nothing is recorded (§6.2 (5)).
      class ProcedureVersionMismatch < SubmitCore::IdentityMismatch; end

      MCP_TOOL = 'gc_prov_submit'
      RECORD_TYPE = 'prov_attestation'
      BUNDLE_MAX_BYTES = 2 * 1024 * 1024    # Gate A (§6)
      BUNDLE_MAX_DEPTH = 32
      PROOF_TTL = 3_153_600_000             # 100 years (§6)
      VERSION_FIELDS = %w[adapter_version predicate_version pin_strength_version resources_rule_version].freeze
      SERVER_SET_FIELDS = %w[trust_tier not_checked admission_rule zk_verification toolchain seed].freeze
      # One schema per record_version (§6.2 (5)): the 0.3 file is the one 0.3
      # records were validated against, left byte for byte as it was.
      SCHEMA_PATHS = {
        '0.3' => File.expand_path('../../../schemas/prov_attestation.schema.json', __dir__),
        '0.4' => File.expand_path('../../../schemas/prov_attestation_v0_4.schema.json', __dir__)
      }.freeze
      SCHEMA_PATH = SCHEMA_PATHS.fetch(Identity::RECORD_VERSION)

      # @param bundle [String, Hash] the bundle, verbatim
      # @param identity [Hash] the signed identity the customer claims
      # @param zk_receipt_bytes [Hash, nil] receipt sha256 => base64 bytes
      # @param zk_verifier [ZkVerifier, nil] injected in tests
      def initialize(bundle:, identity:, zk_receipt_bytes: nil, zk_verifier: nil)
        @raw = bundle
        @identity = (identity || {}).transform_keys(&:to_s)
        @zk_b64 = zk_receipt_bytes || {}
        @zk_verifier = zk_verifier || ZkVerifier.new
        @text = nil
        @derived = nil
        @zk_result = nil
      end

      def self.versions
        { 'adapter' => Adapters::Bco::VERSION, 'predicate' => Predicate::PREDICATE_VERSION,
          'pin_strength' => Predicate::PIN_STRENGTH_VERSION, 'resources_rule' => Resources::RULE_VERSION }
      end

      def proof_ttl
        PROOF_TTL
      end

      def subject_ref
        derived['signed']['subject_ref']
      end

      def trust_tier_gate!
        # trust_tier is server-set; see reject_client_server_set_fields!.
      end

      def parse_digest_subject!
        @text = @raw.is_a?(String) ? @raw : JSON.generate(@raw)
        size = @text.bytesize
        if size > BUNDLE_MAX_BYTES
          raise SubmitCore::EvidenceTooLarge, "bundle size #{size} exceeds Gate A limit #{BUNDLE_MAX_BYTES}"
        end

        parsed = JSON.parse(@text)
        raise SubmitCore::DigestMismatch, 'bundle must be a JSON object' unless parsed.is_a?(Hash)

        parsed
      rescue JSON::ParserError
        # The parser's message quotes the offending bytes (§6): not passed on.
        raise SubmitCore::DigestMismatch, 'bundle is not valid JSON'
      end

      # Gate A, then the bundle's own reading, then admission (§6, §6.1).
      def apply_gates!(parsed)
        depth = KairosMcp::Manifest::DoSGate.compute_depth(parsed)
        raise SubmitCore::EvidenceTooLarge, "bundle nesting depth #{depth} exceeds #{BUNDLE_MAX_DEPTH}" if depth > BUNDLE_MAX_DEPTH

        KairosMcp::Manifest.restricted_subset!(parsed)
        admit!(admission)
      end

      # The bundle-side answer to "would the anchor issue a record?", for the
      # gate and for dry_run. Never contains bundle values.
      def admission
        Identity.admission(derived)
      end

      def recompute_digest!(_parsed)
        derived['bundle_digest']
      end

      def claimed_digest
        claimed = @identity['bundle_digest']
        raise SubmitCore::DigestMismatch, 'identity.bundle_digest missing' if claimed.nil? || claimed.to_s.empty?

        claimed.to_s
      end

      def signed_identity_params
        derived['signed']
      end

      def assert_submitted_matches_signed!
        expected = derived['signed']
        skewed = VERSION_FIELDS.reject { |k| @identity[k] == expected[k] }
        unless skewed.empty?
          raise ProcedureVersionMismatch,
                "procedure versions differ from the anchor's (#{skewed.join(', ')}); anchor runs " \
                "adapter #{expected['adapter_version']}, predicate #{expected['predicate_version']}, " \
                "pin_strength #{expected['pin_strength_version']}, resources rule #{expected['resources_rule_version']} " \
                "(record_version #{Identity::RECORD_VERSION})"
        end
        bad = expected.keys.reject { |k| @identity.key?(k) && @identity[k] == expected[k] }
        extra = @identity.keys - expected.keys
        return if bad.empty? && extra.empty?

        raise SubmitCore::IdentityMismatch,
              "identity does not match what the bundle yields (#{(bad + extra).first(5).join(', ')})"
      end

      def reject_client_server_set_fields!(parsed)
        offered = SERVER_SET_FIELDS & (@identity.keys + parsed.keys)
        return if offered.empty?

        raise SubmitCore::TrustTierError, "#{offered.join(', ')} is server-set; must not come from the client"
      end

      def server_set_fields(_pubkey)
        { 'trust_tier' => 'self_reported' }
      end

      def build_manifest(operator:, submission_key:, server_fields:)
        signed = derived['signed']
        record = {
          'record_type' => RECORD_TYPE,
          'record_version' => Identity::RECORD_VERSION,
          'mcp_tool_name' => MCP_TOOL,
          'mcp_tool_version' => defined?(KairosMcp::VERSION) ? KairosMcp::VERSION.to_s : 'unknown'
        }.merge(signed).merge(
          'trust_tier' => server_fields['trust_tier'],
          # The anchor's interpreter is outside the submitter's signature (the
          # bundle carries no grader interpreter, §6) but inside the anchor's.
          'toolchain' => { 'ruby' => RUBY_VERSION, 'ruby_platform' => RUBY_PLATFORM },
          'seed' => derived['graded']['seed'],
          'not_checked' => Identity::NOT_CHECKED,
          'admission_rule' => Identity::ADMISSION_RULE,
          'zk_verification' => zk_verification_field,
          'submission_key' => submission_key,
          'operator' => KairosMcp::Manifest::Builder.build_operator(operator, {})
        )
        self.class.validate!(record)
        record
      end

      def claim_for(submission_key:)
        Identity.claim(derived['signed'], submission_key)
      end

      def self.validate!(record)
        require 'json-schema'
        unless SCHEMA_PATHS.key?(record['record_version'])
          raise KairosMcp::Manifest::SchemaViolation, 'prov_attestation schema violation: unknown record_version'
        end

        errors = JSON::Validator.fully_validate(schema(record['record_version']), record,
                                                errors_as_objects: true, version: :draft4)
        return true if errors.empty?

        raise KairosMcp::Manifest::SchemaViolation, "prov_attestation schema violation: #{errors.first[:message]}"
      end

      def self.schema(record_version = Identity::RECORD_VERSION)
        @schemas ||= {}
        @schemas[record_version] ||= JSON.parse(File.read(SCHEMA_PATHS.fetch(record_version)))
      end

      private

      def derived
        @derived ||= begin
          parse_digest_subject! if @text.nil?
          Identity.derive(@text)
        rescue Adapters::Bco::FormatError => e
          raise FormatRejected, "bundle is not a readable BCO: #{e.message}"
        end
      end

      # §6.1 (3): the declarations first — cheapest — then the bytes. No grade
      # condition (v0.1.13).
      def admit!(adm)
        if adm['too_many_zk_receipts']
          raise ZkDeclarationInvalid,
                "#{adm['zk_receipts_declared']} zk receipts declared; at most #{Identity::MAX_ZK_RECEIPTS}"
        end
        unless adm['zk_defects'].empty?
          first = adm['zk_defects'].first
          raise ZkDeclarationInvalid,
                "zk receipt declaration for stage #{first['stage'] || '?'} unusable: #{first['defects'].join(', ')}"
        end
        verify_receipts!
      end

      def verify_receipts!
        declared = Array(derived['np'].zk_receipts)
        bytes = decode_receipt_bytes
        if declared.empty?
          raise ZkReceiptRejected, 'receipt bytes sent for a bundle that declares no receipt' unless bytes.empty?

          return
        end

        @zk_result = @zk_verifier.check(declared, bytes)
        raise ZkReceiptRejected, "#{@zk_result['undeclared']} receipt(s) sent that the bundle does not declare" if @zk_result['undeclared'].positive?

        failed = @zk_result['results'].find { |r| r['code'] != 'ok' }
        raise ZkReceiptRejected, "zk receipt for stage #{failed['stage']} rejected: #{failed['code']}" if failed
      rescue ZkVerifier::Unavailable => e
        raise ZkVerifierUnavailable, "zk receipts cannot be verified on this anchor (#{e.message}); nothing recorded"
      end

      def decode_receipt_bytes
        raise ZkReceiptRejected, 'zk_receipt_bytes must be an object' unless @zk_b64.is_a?(Hash)

        @zk_b64.each_with_object({}) do |(sha, b64), acc|
          raise ZkReceiptRejected, 'zk_receipt_bytes values must be base64 strings' unless b64.is_a?(String)

          acc[sha.to_s.downcase] = Base64.strict_decode64(b64)
        end
      rescue ArgumentError
        raise ZkReceiptRejected, 'zk_receipt_bytes holds a value that is not base64'
      end

      def zk_verification_field
        return nil if @zk_result.nil? || @zk_result['results'].empty?

        v = @zk_result['verifier'] || {}
        { 'verifier' => "#{v['tool']}-#{v['version']}", 'risc0_zkvm' => v['risc0_zkvm'],
          'journal_convention' => v['journal_convention'], 'receipts_verified' => @zk_result['results'].length }
      end
    end
  end
end
