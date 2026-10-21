# frozen_string_literal: true

require 'json'
require 'digest'
require 'time'
require_relative '../records'

module KairosMcp
  module SkillSets
    module GenomicschainTier3Record
      module VerdictSpec
        # Attestation — SubmitCore hooks for tier3_attestation 0.1 (design
        # §4.1, §9-2). The executor's per-attempt scores, signed under the
        # declaration's signing key. As in Declaration:
        #
        #   ① apply_gates! reads the params only: field form (a cannot_build
        #     row carries no ② ③ field, not_checked is the fixed list)
        #   ② the Bearer   ③ recovery   ④ the signature
        #   ⑤ server_set_fields re-reads the declaration: the same signing key,
        #     the §4.1 binding list field by field, one attestation per
        #     declaration_ref (§3.4), 1 ≤ attempts ≤ attempts_max
        #
        # An identical resend has this submission_key's proof already, so ③
        # returns it (36:63–71) before ⑤ runs; ⑤ therefore only ever meets
        # attestations under other submission_keys. env_digest and backend_id
        # are ① outputs per attempt and stay outside the equality (§3.1).
        class Attestation
          R = Records
          Core = GenomicschainCore

          MCP_TOOL = R::MCP_TOOL
          RECORD_TYPE = R::ATTESTATION
          SCHEMA_PATH = File.expand_path('../../../schemas/tier3_attestation_v0_1.schema.json', __dir__)
          # §4.1 札の言い方: what the anchor re-derived, its own clock, and the
          # executor's word. No procedure_checked on the comparator: which one
          # ran on the executor's machine the anchor cannot see.
          BACKING = { 'vocabulary' => Core::Backing::VERSION, 'recorded_at' => 'anchor_observed',
                      'signing_key' => 'procedure_checked', 'binding' => 'procedure_checked',
                      'attestation' => 'customer_signed', 'attempts' => 'customer_stated',
                      'comparator' => 'customer_stated' }.freeze

          def initialize(attestation:, registry:, clock: -> { Time.now.utc })
            @raw = attestation
            @params = nil
            @registry = registry
            @clock = clock
          end

          def proof_ttl = R::PROOF_TTL
          def subject_ref = @params['subject_ref'].to_s
          def trust_tier_gate!; end

          # The house gates (10:151–158), before any other work: size, depth,
          # ASCII keys, no U+2028 / U+2029. Their errors propagate as raised.
          # Once passed, the gated params are kept: lock_key reads them first.
          def parse_digest_subject!
            return @params if @params

            KairosMcp::Manifest.dos_gate!(@raw)
            KairosMcp::Manifest.restricted_subset!(@raw)
            raise R::FormRejected, 'attestation must be a JSON object' unless @raw.is_a?(Hash)

            @params = JSON.parse(JSON.generate(@raw))
          end

          # RecordSubmit's per-declaration_ref lock key: taken only from params
          # the gates accepted, and bounded by a digest.
          def lock_key
            Digest::SHA256.hexdigest(KairosMcp::Manifest.canonical_json(parse_digest_subject!['declaration_ref']))
          end

          # ①, before the signature.
          def apply_gates!(params)
            errors = R.validate(SCHEMA_PATH, params, fragment: '#/definitions/params')
            raise R::FormRejected, "tier3_attestation form: #{errors.first}" unless errors.empty?

            salted = params['fingerprint_form'] == 'salted'
            return if salted == params.key?('commitment')

            raise R::FormRejected, salted ? 'commitment is required when fingerprint_form is salted' :
                                            'commitment is a salted-only field; fingerprint_form is plain'
          end

          def recompute_digest!(params) = KairosMcp::Manifest.canonical_json_sha256(params)
          def claimed_digest = KairosMcp::Manifest.canonical_json_sha256(@params)
          def signed_identity_params = @params
          def assert_submitted_matches_signed!; end
          def reject_client_server_set_fields!(_params); end

          # ⑤, after the signature. T_a is the anchor's clock (18:15–16).
          def server_set_fields(pubkey)
            declaration = declaration!(pubkey)
            binding!(declaration)
            unless R.anchor_written(@registry, RECORD_TYPE).none? { |m| m['declaration_ref'] == declaration_ref }
              raise R::AlreadyAttested, 'this declaration_ref has its attestation already; one per declaration (§3.4)'
            end
            rows = @params['attempts'].length
            max = declaration['attempts_max'].to_i
            unless rows.between?(1, max)
              raise R::AttemptsOutOfRange, "attempts has #{rows} rows; the declaration allows 1 to #{max}"
            end

            { 'recorded_at' => R.recorded_at(@clock), 'backing' => BACKING }
          end

          def build_manifest(operator:, submission_key:, server_fields:)
            record = {
              'record_type' => RECORD_TYPE, 'record_version' => R::RECORD_VERSION, 'mcp_tool_name' => MCP_TOOL,
              'mcp_tool_version' => defined?(KairosMcp::VERSION) ? KairosMcp::VERSION.to_s : 'unknown'
            }.merge(@params).merge(server_fields).merge(
              'submission_key' => submission_key, 'operator' => KairosMcp::Manifest::Builder.build_operator(operator, {})
            )
            errors = R.validate(SCHEMA_PATH, record)
            raise KairosMcp::Manifest::SchemaViolation, "tier3_attestation schema violation: #{errors.first}" unless errors.empty?

            record
          end

          # 05 C10 shape; no headline (§3.2), so no result in the claim either.
          def claim_for(submission_key:)
            "tier3-attestation:#{R::RECORD_VERSION}:#{declaration_ref['declaration_digest']}:#{submission_key}"
          end

          private

          def declaration_ref = @params['declaration_ref']

          # The declaration this points at: its digest and T_d. Two keys could
          # declare byte-identical params in one second; the one under this
          # signing key is then the one meant.
          def declaration!(pubkey)
            found = R.anchor_written(@registry, R::DECLARATION).select do |m|
              m['declaration_digest'] == declaration_ref['declaration_digest'] &&
                m['recorded_at'] == declaration_ref['recorded_at']
            end
            raise R::DeclarationNotFound, 'no tier3_declaration has this declaration_ref' if found.empty?

            mine = found.find { |m| R.operator_pubkey(m) == pubkey }
            raise R::SignerMismatch, 'the attestation is not signed under the declaration\'s signing key' unless mine

            mine
          end

          # §4.1: names every field that differs, never a value.
          def binding!(declaration)
            differ = (R::BINDING_FIELDS + ['commitment']).reject { |f| @params[f] == declaration[f] }
            return if differ.empty?

            raise R::BindingMismatch, "binding fields differ from the declaration: #{differ.join(', ')}"
          end
        end
      end
    end
  end
end
