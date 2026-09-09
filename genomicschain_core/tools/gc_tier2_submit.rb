# frozen_string_literal: true

require 'json'
require 'digest'
require 'genomicschain_core'

module KairosMcp
  module SkillSets
    module GenomicschainCore
      module Tools
        # gc_tier2_submit — MCP skin over SubmitCore for Tier-2 adjudications.
        #
        # The third submit tool, built on the same path as gc_tier1_submit and
        # gc_tier3_submit: signed operator envelope, pubkey-bound Bearer,
        # Synoptis proof on the anchor, no operational chain write. Nothing is
        # added to the chain layer for Tier-2; only the record type is new.
        class GcTier2Submit < KairosMcp::Tools::BaseTool
          def name
            'gc_tier2_submit'
          end

          def description
            'Sign and record a Tier-2 code-reading adjudication (gc_tier2_adjudicate output) as a Synoptis ' \
              'proof (anchor profile). The adjudication is submitted verbatim; the server recomputes its digest ' \
              'and re-derives every signed field from it. Records a self_reported proposal — it does not apply ' \
              'the stage transition. Use dry_run to validate and to obtain the params to sign.'
          end

          def category
            :chain
          end

          def usecase_tags
            %w[tier2 reproducibility submit codescan adjudication attestation signed synoptis]
          end

          def related_tools
            %w[gc_tier2_scan gc_tier2_adjudicate gc_tier1_submit token_manage attestation_verify]
          end

          def input_schema
            {
              type: 'object',
              properties: {
                adjudication: {
                  type: %w[object string],
                  description: 'gc_tier2_adjudicate output, verbatim (object or JSON string). Its canonical ' \
                               'sha256 is the digest subject.'
                },
                identity: {
                  type: 'object',
                  description: 'The signed identity params (from dry_run.signed_params). Every field is ' \
                               're-derived from the adjudication server-side; a mismatch is rejected.'
                },
                repository: {
                  type: 'object',
                  description: 'Optional {url, commit} of the checkout that was scanned. The scanner records ' \
                               'no commit, so this is the operator\'s statement and is signed as such.'
                },
                operator: {
                  type: 'object',
                  description: 'Signed operator envelope with proofs-chain tip in chain_tip_hash.'
                },
                dry_run: {
                  type: 'boolean',
                  description: 'Validate only; no admission, no Synoptis store. Returns signed_params. Default false.'
                }
              },
              required: %w[adjudication operator]
            }
          end

          def call(arguments)
            unless Config.anchor_profile?
              return text_content(
                'Error: gc_tier2_submit requires genomicschain.anchor_profile: true (anchor node only).'
              )
            end

            args = arguments.transform_keys(&:to_s)
            adjudication = args['adjudication']
            identity = hashify(args['identity'])
            repository = hashify(args['repository'])
            operator = hashify(args['operator'])

            return text_content(JSON.pretty_generate(dry_run(adjudication, identity, repository, operator))) if args['dry_run']

            bearer_pubkey_hash = resolve_bearer_pubkey_hash
            if bearer_pubkey_hash.nil?
              return text_content(
                "Error: no pubkey-bound Bearer (transport: #{transport}).\n" \
                'Signed submit requires HTTP Bearer with pubkey_hash. Use dry_run over stdio.'
              )
            end

            registry, tip_source = build_synoptis_context
            KairosMcp::Manifest::Signer.bootstrap_seen_list!(tip_source: tip_source)

            attestor = Attestation::SynoptisAttestor.build(
              operator_pubkey: (operator['pubkey'] || operator[:pubkey]).to_s,
              safety: @safety,
              registry: registry
            )

            result = Tier2Submit.submit(
              adjudication: adjudication, identity: identity, repository: repository, operator: operator,
              bearer_pubkey_hash: bearer_pubkey_hash, tip_source: tip_source,
              attestor: attestor, registry: registry
            )

            text_content(JSON.pretty_generate(render(result, adjudication, repository)))
          rescue Tier2Submit::SubmitError,
                 KairosMcp::Manifest::ManifestError,
                 KairosMcp::Manifest::Signer::SignerError,
                 Attestation::SynoptisAttestor::AttestorError,
                 ArgumentError => e
            text_content("Error: #{e.class.name.split('::').last}: #{e.message}")
          rescue StandardError => e
            text_content("Error: gc_tier2_submit failed — #{e.class}: #{e.message}")
          end

          private

          def build_synoptis_context
            data_dir = File.join(KairosMcp.data_dir, 'synoptis_data')
            registry = ::Synoptis::Registry::FileRegistry.new(data_dir: data_dir)
            [registry, TipSource.new(registry: registry)]
          end

          # Validates everything the real path validates except admission and
          # the store, and returns the params the operator has to sign. With no
          # identity supplied it reports what WOULD be signed; with one, it
          # checks it field by field.
          def dry_run(adjudication, identity, repository, operator)
            checks = {}
            spec = VerdictSpec::Tier2.new(adjudication: adjudication, identity: identity, repository: repository)
            parsed = spec.parse_digest_subject!
            spec.apply_gates!(parsed)
            checks['gates'] = 'ok'

            recomputed = spec.recompute_digest!(parsed)
            derived = spec.signed_identity_params
            checks['adjudication_digest_recompute'] =
              if identity.empty?
                "no identity supplied; would sign digest #{recomputed}"
              elsif recomputed == identity['adjudication_digest']
                'ok'
              else
                "MISMATCH (claimed #{identity['adjudication_digest']}, recomputed #{recomputed})"
              end

            checks['identity_matches_derived'] =
              if identity.empty?
                'no identity supplied (see signed_params)'
              else
                begin
                  spec.assert_submitted_matches_signed!
                  'ok'
                rescue Tier2Submit::IdentityMismatch => e
                  "MISMATCH: #{e.message}"
                end
              end

            begin
              spec.reject_client_server_set_fields!(parsed)
              checks['trust_tier'] = 'ok (server-set self_reported)'
            rescue Tier2Submit::TrustTierError => e
              checks['trust_tier'] = "REJECTED: #{e.message}"
            end

            checks['operator_mode'] =
              (operator['mode'] || operator[:mode]).to_s == 'signed' ? 'ok (signed)' : 'REJECTED (must be signed)'

            pubkey = (operator['pubkey'] || operator[:pubkey]).to_s
            bearer = resolve_bearer_pubkey_hash
            checks['bearer_binding'] =
              if bearer.nil?
                "would FAIL-CLOSE (no Bearer on #{transport}); expected #{Digest::SHA256.hexdigest(pubkey)}"
              elsif Digest::SHA256.hexdigest(pubkey) == bearer
                'ok'
              else
                'MISMATCH'
              end

            begin
              record = spec.build_manifest(
                operator: operator,
                submission_key: '0' * 64, # schema requires 64 hex; a prose placeholder made every dry_run report INVALID
                server_fields: { 'trust_tier' => 'self_reported' }
              )
              checks['record_schema'] = 'ok'
              checks['would_record'] = {
                'subject_ref' => record['subject_ref'],
                'adjudication_digest' => record['adjudication_digest'],
                'codescan_evidence_digest' => record['codescan_evidence_digest'],
                'levers' => record['levers'],
                'counts' => record['counts'],
                'claim_prefix' => "tier2:#{VerdictSpec::Tier2.lock_state(derived)}:" \
                                  "#{derived['proposed_demotions']}:#{recomputed}:<submission_key>"
              }
            rescue KairosMcp::Manifest::ManifestError => e
              checks['record_schema'] = "INVALID: #{e.message}"
            end

            checks['attestor'] = Attestation::SynoptisAttestor.available? ? 'ok (synoptis loaded)' : 'UNAVAILABLE'

            { 'status' => 'dry_run', 'recorded' => false, 'checks' => checks,
              'signed_params' => derived,
              'note' => 'No admission, no Synoptis store. Sign signed_params (with mcp_tool_name, nonce, ' \
                        'chain_tip_hash) and pass them back as identity. Real submit uses proofs-chain tip.' }
          rescue Tier2Submit::SubmitError, KairosMcp::Manifest::ManifestError => e
            { 'status' => 'dry_run', 'recorded' => false,
              'checks' => checks.merge('rejected' => "#{e.class.name.split('::').last}: #{e.message}") }
          end

          def render(result, adjudication, repository)
            derived = VerdictSpec::Tier2.identity_for(adjudication, repository)
            base = {
              'subject_ref' => derived['subject_ref'],
              'adjudication_digest' => derived['adjudication_digest'],
              'codescan_evidence_digest' => derived['codescan_evidence_digest'],
              'lock_state' => VerdictSpec::Tier2.lock_state(derived),
              'proposed_demotions' => derived['proposed_demotions'],
              'claim' => result[:claim],
              'submission_key' => result[:submission_key],
              'synoptis_proof_id' => result[:synoptis_proof_id],
              'idempotency_key' => result[:idempotency_key],
              'recovered' => result[:recovered] || false
            }
            base['status'] = result[:status].to_s
            base['message'] = result[:message] if result[:message]
            base['note'] = 'Domain record is a Synoptis proof only; no operational chain write. ' \
                           'The record is a self_reported proposal; stage_transition.applied stays false.'
            base
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
