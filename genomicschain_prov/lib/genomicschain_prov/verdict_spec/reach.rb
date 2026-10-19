# frozen_string_literal: true

require 'json'
require 'time'
require 'genomicschain_core'
require_relative '../../genomicschain_prov'
require_relative '../reach'
require_relative 'prov'

module GenomicsChainProv
  module VerdictSpec
    # Reach — SubmitCore hooks for the reachability observation (design
    # v0.1.15 §6.3), a record laid over an existing prov record. SubmitCore's
    # order is the design's (3):
    #
    #   ① apply_gates! and the identity check read the bundle only: Gate A,
    #     the adapter's locators, the digest. No network, no ledger.
    #   ② the Bearer   ③ recovery (submission_key)   ④ the signature
    #   ⑤ server_set_fields: the prov record is looked up by its proof_id,
    #     and only then are the places asked, inside the gate and the budgets
    #   ⑥ the record; the bundle and the locators are dropped
    #
    # So an unsigned call, a wrong Bearer, a resend of the same signature and
    # a dry run never ask anything outside and never look up a proof_id.
    #
    # The record carries counts and dates (§6.3 (6)). Locators, resolved
    # addresses, answers, host names, the prov proof_id and the per-item
    # results stay out of it, out of every message here, and out of any log;
    # the per-item results go to the submitting customer in the response only.
    class Reach
      Core = KairosMcp::SkillSets::GenomicschainCore
      SubmitCore = Core::SubmitCore
      R = GenomicsChainProv::Reach

      # Refusals of form (§6.3 (3)): nothing is recorded.
      class ProvRecordRejected < SubmitCore::SubmitError; end
      class ObservationRefused < SubmitCore::SubmitError; end
      # The customer signed another rule version than the anchor runs: told
      # which one the anchor runs, as prov's ProcedureVersionMismatch does.
      class RuleVersionMismatch < SubmitCore::IdentityMismatch; end

      MCP_TOOL = 'gc_prov_reach'
      TOOL_VERSION = 'gc_prov_reach-0.1.0'
      RECORD_TYPE = 'prov_reachability'
      RECORD_VERSION = '0.1'
      PROOF_TTL = Prov::PROOF_TTL
      NOT_CHECKED = %w[reachability_from_other_networks content_not_fetched answerer_independence buildability
                       future_reachability].freeze
      # gc-backing-0.1 per field: the counts and their date are the anchor's
      # own observation; the links to the bundle and the prov record are
      # re-derived by the procedure.
      BACKING = { 'vocabulary' => Core::Backing::VERSION, 'counts' => 'anchor_observed',
                  'observed_at' => 'anchor_observed', 'bundle_digest' => 'procedure_checked',
                  'prov_proof_ref' => 'procedure_checked', 'same_signer' => 'procedure_checked' }.freeze
      NONCE = /\A[0-9a-f]{64}\z/
      SCHEMA_PATH = File.expand_path('../../../schemas/prov_reachability_v0_1.schema.json', __dir__)

      # Anchor-wide limits (§6.3 (5)), one per process, made when the class
      # loads: built on first use, two first submissions on two threads could
      # each make their own (review r1).
      @admission = R::Admission.new

      def self.admission = @admission

      def self.versions
        { 'reachability_rule' => R::RULE_VERSION, 'tool' => TOOL_VERSION, 'adapter' => Adapters::Bco::VERSION,
          'record_version' => RECORD_VERSION }
      end

      # What the customer signs (Reach::SignedParams, shared with the client).
      def self.signed_params_for(bundle, prov_proof_id, nonce)
        R::SignedParams.for(bundle, prov_proof_id, nonce)
      end

      attr_reader :item_results

      # @param prober [#target, #ask] the anchor's Reach::Prober, or a test's
      # @param registry [#find_proof, #revoked?] the Synoptis registry
      def initialize(bundle:, identity:, prov_proof_id:, registry:, prober:, budget: nil, admission: nil,
                     clock: -> { Time.now.utc })
        @raw = bundle
        @identity = (identity || {}).transform_keys(&:to_s)
        @prov_proof_id = prov_proof_id.to_s
        @registry = registry
        @prober = prober
        @budget = budget
        @admission = admission || self.class.admission
        @clock = clock
        @text = nil
        @np = nil
        @item_results = nil
      end

      def proof_ttl = PROOF_TTL
      def subject_ref = expected['subject_ref']
      def trust_tier_gate!; end

      def parse_digest_subject!
        @text = @raw.is_a?(String) ? @raw : JSON.generate(@raw)
        size = @text.bytesize
        if size > Prov::BUNDLE_MAX_BYTES
          raise SubmitCore::EvidenceTooLarge, "bundle size #{size} exceeds Gate A limit #{Prov::BUNDLE_MAX_BYTES}"
        end

        parsed = JSON.parse(@text)
        raise SubmitCore::DigestMismatch, 'bundle must be a JSON object' unless parsed.is_a?(Hash)

        parsed
      rescue JSON::ParserError
        raise SubmitCore::DigestMismatch, 'bundle is not valid JSON', cause: nil
      end

      # ①: the bundle's own reading. The locators are taken here and asked
      # for in ⑤ only.
      def apply_gates!(parsed)
        depth = KairosMcp::Manifest::DoSGate.compute_depth(parsed)
        raise SubmitCore::EvidenceTooLarge, "bundle nesting depth #{depth} exceeds #{Prov::BUNDLE_MAX_DEPTH}" if depth > Prov::BUNDLE_MAX_DEPTH

        KairosMcp::Manifest.restricted_subset!(parsed)
        np
      end

      def recompute_digest!(_parsed) = expected['bundle_digest']

      def claimed_digest
        claimed = @identity['bundle_digest']
        raise SubmitCore::DigestMismatch, 'identity.bundle_digest missing' if claimed.nil? || claimed.to_s.empty?

        claimed.to_s
      end

      def signed_identity_params = expected

      def assert_submitted_matches_signed!
        unless @identity['reachability_rule'] == R::RULE_VERSION
          raise RuleVersionMismatch, "reachability rule differs from the anchor's; anchor runs #{R::RULE_VERSION}"
        end
        raise SubmitCore::IdentityMismatch, 'observation_nonce must be 32 random bytes in hex' unless NONCE.match?(@identity['observation_nonce'].to_s)

        want = expected
        bad = (want.keys | @identity.keys).reject { |k| @identity[k] == want[k] }
        return if bad.empty?

        # Names only the expected keys that differ; a key the identity may not
        # hold is counted, never echoed (it is the submitter's text, review r1).
        named = bad & want.keys
        extra = (bad - want.keys).length
        detail = named.join(', ') + (extra.positive? ? "#{named.empty? ? '' : '; '}#{extra} key(s) the identity may not hold" : '')
        raise SubmitCore::IdentityMismatch, "identity does not match the bundle and the prov record (#{detail})"
      end

      # The identity check above already refuses every key it does not
      # expect, the server-set ones included; nothing is left to refuse here.
      def reject_client_server_set_fields!(_parsed); end

      # ⑤: after the signature. The prov record first — a refusal here asks
      # nothing outside — then the observation, inside the anchor's limits.
      def server_set_fields(pubkey)
        prov = prov_manifest!
        result = @admission.hold(pubkey) do
          R::Observation.observe(np, prober: @prober, budget: @budget || R::Budget.new)
        end
        @item_results = result['items']
        { 'observer' => 'anchor', 'observed_at' => @clock.call.utc.iso8601,
          'checker' => { 'tool' => TOOL_VERSION, 'adapter' => Adapters::Bco::VERSION },
          'same_signer' => prov.dig('operator', 'pubkey') == pubkey, 'counts' => result['counts'] }
      rescue R::Admission::Busy => e
        raise ObservationRefused, "observation refused: the anchor's limit (#{e.reason}) is reached; nothing recorded"
      end

      def build_manifest(operator:, submission_key:, server_fields:)
        record = {
          'record_type' => RECORD_TYPE, 'record_version' => RECORD_VERSION, 'mcp_tool_name' => MCP_TOOL,
          'mcp_tool_version' => defined?(KairosMcp::VERSION) ? KairosMcp::VERSION.to_s : 'unknown'
        }.merge(expected).merge(server_fields).merge(
          'backing' => BACKING, 'not_checked' => NOT_CHECKED, 'submission_key' => submission_key,
          'operator' => KairosMcp::Manifest::Builder.build_operator(operator, {})
        )
        self.class.validate!(record)
        record
      end

      # Ends in submission_key, which the nonce changes, so two observations
      # of one bundle with the same counts stay two proofs (§6.3 (7)).
      def claim_for(submission_key:)
        "prov-reach:#{R::RULE_VERSION}:#{expected['bundle_digest']}:#{submission_key}"
      end

      # Design (3) dry run: what the bundle yields, the per-category numbers
      # and the locators refused on their face. No proof_id is looked up and
      # nothing outside is asked.
      def dry_run
        parse_digest_subject!.then { |parsed| apply_gates!(parsed) }
        { 'counts' => R::Observation.dry_run(np, prober: @prober),
          'signed_params' => expected.merge('observation_nonce' => '<32 random bytes, hex, new for every submission>') }
      end

      def self.validate!(record)
        require 'json-schema'
        @schema ||= JSON.parse(File.read(SCHEMA_PATH))
        errors = JSON::Validator.fully_validate(@schema, record, errors_as_objects: true, version: :draft4)
        return true if errors.empty?

        raise KairosMcp::Manifest::SchemaViolation, "prov_reachability schema violation: #{errors.first[:message]}"
      end

      private

      def np
        @np ||= begin
          parse_digest_subject! if @text.nil?
          Adapters::Bco.parse(@text)
        rescue Adapters::Bco::FormatError => e
          raise Prov::FormatRejected, "bundle is not a readable BCO: #{e.message}"
        end
      end

      # An empty proof_id stops in ProvProofRef.for (ArgumentError).
      def expected
        @expected ||= begin
          parse_digest_subject! if @text.nil?
          self.class.signed_params_for(@text, @prov_proof_id, @identity['observation_nonce'])
        end
      end

      # The prov record this observation is laid over: present, a provenance
      # record, not revoked (operator, 2026-10-18), and of this bundle. The
      # messages name the condition only, never the proof_id.
      def prov_manifest!
        envelope = @registry.find_proof(@prov_proof_id)
        raise ProvRecordRejected, 'no provenance record under the given proof_id' unless envelope
        raise ProvRecordRejected, 'the provenance record is revoked; nothing observed' if @registry.revoked?(@prov_proof_id)

        manifest = Core::ProofLookup.parse_evidence(envelope.evidence)&.dig('manifest')
        unless manifest.is_a?(Hash) && manifest['record_type'] == Prov::RECORD_TYPE
          raise ProvRecordRejected, 'the proof_id names no provenance record'
        end
        unless manifest['bundle_digest'] == expected['bundle_digest']
          raise ProvRecordRejected, 'the provenance record is of another bundle'
        end

        manifest
      end
    end
  end
end
