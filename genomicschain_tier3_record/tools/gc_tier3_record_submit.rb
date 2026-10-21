# frozen_string_literal: true

require 'json'
require 'genomicschain_core'
require 'genomicschain_tier3_record/record_submit'

module KairosMcp
  module SkillSets
    module GenomicschainTier3Record
      module Tools
        # gc_tier3_record_submit — the anchor's side of Tier 3 v0.1 (design
        # §3.2, §9-3): records the executor's signed declaration and
        # attestation as Synoptis proofs. Anchor profile only; listed in
        # genomicschain_tier3_record's anchor_profile_tool_classes. Not in core,
        # because it reads prov's outputs_digest rule and records (core → prov
        # would be a loop); not in tier3, because the anchor must not register
        # the execution tools (§3.2〔実装〕, review r1 H1).
        #
        # It neither builds nor compares, and never receives a key or an
        # output file. Its checks are the design's (§4.4): field form, route
        # B's route_ref and outputs_digest, the option-2 salt rule, human
        # data, refused sources, the same signing key and binding list, one
        # attestation per declaration and 1 ≤ attempts ≤ attempts_max.
        # Refusals name the condition, never a proof_id.
        class GcTier3RecordSubmit < KairosMcp::Tools::BaseTool
          Core = KairosMcp::SkillSets::GenomicschainCore
          ACTIONS = %w[declaration attestation].freeze

          def name
            'gc_tier3_record_submit'
          end

          def description
            'Record a Tier-3 declaration or attestation signed by gc_tier3_attest as a Synoptis proof (anchor ' \
              'profile). Route B declarations also take the Tier-2.5 record\'s proof_id, unsigned; the record keeps ' \
              'its SHA-256. A record is a dated observation of what the executor declared and stated, not a ' \
              'promise of future reproduction. Requires a signed operator envelope and a pubkey-bound Bearer.'
          end

          def category
            :chain
          end

          def usecase_tags
            %w[tier3 reproducibility declaration attestation submit signed synoptis]
          end

          def related_tools
            %w[gc_prov_submit token_manage attestation_verify]
          end

          def input_schema
            {
              type: 'object',
              properties: {
                action: { type: 'string', enum: ACTIONS, description: 'Which record the params are.' },
                declaration: { type: 'object', description: 'action declaration: the signed params, verbatim.' },
                attestation: { type: 'object', description: 'action attestation: the signed params, verbatim.' },
                operator: { type: 'object', description: 'Signed operator envelope with proofs-chain tip in chain_tip_hash.' },
                route_proof_id: { type: 'string',
                                  description: 'action declaration, route B: the Tier-2.5 record\'s proof_id. Not ' \
                                               'signed and not recorded.' }
              },
              required: %w[action operator]
            }
          end

          def call(arguments)
            unless Core::Config.anchor_profile?
              return text_content('Error: gc_tier3_record_submit requires genomicschain.anchor_profile: true ' \
                                  '(anchor node only).')
            end

            args = arguments.transform_keys(&:to_s)
            action = args['action'].to_s
            return text_content("Error: action must be one of #{ACTIONS.join(', ')}") unless ACTIONS.include?(action)

            operator = hashify(args['operator'])
            bearer_pubkey_hash = resolve_bearer_pubkey_hash
            if bearer_pubkey_hash.nil?
              return text_content("Error: no pubkey-bound Bearer (transport: #{transport}).\n" \
                                  'Signed submit requires HTTP Bearer with pubkey_hash.')
            end

            registry, tip_source = build_synoptis_context
            KairosMcp::Manifest::Signer.bootstrap_seen_list!(tip_source: tip_source)
            attestor = Core::Attestation::SynoptisAttestor.build(
              operator_pubkey: (operator['pubkey'] || operator[:pubkey]).to_s, safety: @safety, registry: registry
            )
            common = { operator: operator, bearer_pubkey_hash: bearer_pubkey_hash, tip_source: tip_source,
                       attestor: attestor, registry: registry }
            result =
              if action == 'declaration'
                RecordSubmit.declaration(declaration: args['declaration'], route_proof_id: args['route_proof_id'], **common)
              else
                RecordSubmit.attestation(attestation: args['attestation'], **common)
              end
            text_content(JSON.pretty_generate(render(result)))
          rescue Core::SubmitCore::SubmitError, KairosMcp::Manifest::ManifestError,
                 KairosMcp::Manifest::Signer::SignerError, Core::Attestation::SynoptisAttestor::AttestorError,
                 ArgumentError => e
            text_content("Error: #{e.class.name.split('::').last}: #{e.message}")
          rescue StandardError => e
            # The class only: an unexpected message could quote the proof_id.
            text_content("Error: gc_tier3_record_submit failed — #{e.class}")
          end

          private

          def render(result)
            out = { 'status' => result[:status].to_s, 'claim' => result[:claim], 'submission_key' => result[:submission_key],
                    'synoptis_proof_id' => result[:synoptis_proof_id], 'idempotency_key' => result[:idempotency_key],
                    'recovered' => result[:recovered] || false }
            out['declaration_ref'] = result[:declaration_ref] if result[:declaration_ref]
            out['message'] = result[:message] if result[:message]
            out
          end

          def build_synoptis_context
            data_dir = File.join(KairosMcp.data_dir, 'synoptis_data')
            registry = ::Synoptis::Registry::FileRegistry.new(data_dir: data_dir)
            [registry, Core::TipSource.new(registry: registry)]
          end

          def resolve_bearer_pubkey_hash
            value = @safety&.current_user&.dig(:pubkey_hash) || @safety&.current_user&.dig('pubkey_hash')
            value.nil? || value.to_s.empty? ? nil : value.to_s
          end

          def transport
            @safety&.current_user ? :http : :stdio
          end

          def hashify(value)
            return {} if value.nil?
            raise ArgumentError, 'expected a JSON object' unless value.is_a?(Hash)

            value.transform_keys(&:to_s)
          end
        end
      end
    end
  end
end
