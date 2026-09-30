# frozen_string_literal: true

require 'json'
require 'digest'
require 'genomicschain_core'

module KairosMcp
  module SkillSets
    module GenomicschainCore
      module Tools
        # gc_tier1_submit — MCP skin over SubmitCore for Tier-1 reports (design v0.4.1).
        class GcTier1Submit < KairosMcp::Tools::BaseTool
          def name
            'gc_tier1_submit'
          end

          def description
            'Sign and record a Tier-1 readiness report as a Synoptis proof (anchor profile). ' \
              'Requires signed operator envelope, report_content_hash inside report_json, ' \
              'and pubkey-bound Bearer (HTTP transport). Use dry_run to validate without recording.'
          end

          def category
            :chain
          end

          def usecase_tags
            %w[tier1 reproducibility submit readiness attestation signed synoptis]
          end

          def related_tools
            %w[token_manage attestation_verify]
          end

          def input_schema
            {
              type: 'object',
              properties: {
                report_json: {
                  type: 'string',
                  description: 'Canonical report.json (v0.2.6+) with report_content_hash and assessor_stack.'
                },
                operator: {
                  type: 'object',
                  description: 'Signed operator envelope with proofs-chain tip in chain_tip_hash.'
                },
                dry_run: {
                  type: 'boolean',
                  description: 'Validate only; no admission, no Synoptis store. Default false.'
                }
              },
              required: %w[report_json operator]
            }
          end

          def call(arguments)
            unless Config.anchor_profile?
              return text_content(
                'Error: gc_tier1_submit requires genomicschain.anchor_profile: true (anchor node only).'
              )
            end

            args = arguments.transform_keys(&:to_s)
            report_json = args['report_json'].to_s
            operator = hashify(args['operator'])

            return text_content(JSON.pretty_generate(dry_run(report_json, operator))) if args['dry_run']

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

            result = Tier1Submit.submit(
              report_json: report_json, operator: operator,
              bearer_pubkey_hash: bearer_pubkey_hash, tip_source: tip_source,
              attestor: attestor, registry: registry
            )

            text_content(JSON.pretty_generate(render(result, report_json)))
          rescue Tier1Submit::SubmitError,
                 KairosMcp::Manifest::ManifestError,
                 KairosMcp::Manifest::Signer::SignerError,
                 Attestation::SynoptisAttestor::AttestorError,
                 ArgumentError => e
            text_content("Error: #{e.class.name.split('::').last}: #{e.message}")
          rescue StandardError => e
            text_content("Error: gc_tier1_submit failed — #{e.class}: #{e.message}")
          end

          private

          def build_synoptis_context
            data_dir = File.join(KairosMcp.data_dir, 'synoptis_data')
            registry = ::Synoptis::Registry::FileRegistry.new(data_dir: data_dir)
            [registry, TipSource.new(registry: registry)]
          end

          def dry_run(report_json, operator)
            checks = {}
            spec = VerdictSpec::Tier1.new(report_json: report_json, operator: operator)
            report = spec.parse_digest_subject!
            spec.apply_gates!(report)
            checks['gates'] = 'ok'

            recomputed = spec.recompute_digest!(report)
            checks['report_content_hash_recompute'] =
              recomputed == spec.claimed_digest ? 'ok' : "MISMATCH (claimed #{spec.claimed_digest}, recomputed #{recomputed})"
            checks['b1_manifest_hash'] = B1ManifestHash.matches?(report) ? 'ok' : 'MISMATCH'

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
                'report_content_hash' => record['report_content_hash'],
                'claim_prefix' => "tier1:#{report.dig('headline', 'static_readiness')}:#{recomputed}:<submission_key>"
              }
            rescue KairosMcp::Manifest::ManifestError => e
              checks['record_schema'] = "INVALID: #{e.message}"
            end

            checks['attestor'] = Attestation::SynoptisAttestor.available? ? 'ok (synoptis loaded)' : 'UNAVAILABLE'

            { 'status' => 'dry_run', 'recorded' => false, 'checks' => checks,
              'note' => 'No admission, no Synoptis store. Real submit uses proofs-chain tip.' }
          end

          def render(result, report_json)
            report = JSON.parse(report_json)
            base = {
              'subject_ref' => SubjectRef.for(report.dig('canonical_id', 'value'), report.dig('canonical_id', 'kind')),
              'report_content_hash' => report['report_content_hash'],
              'static_readiness' => report.dig('headline', 'static_readiness'),
              'claim' => result[:claim],
              'submission_key' => result[:submission_key],
              'synoptis_proof_id' => result[:synoptis_proof_id],
              'idempotency_key' => result[:idempotency_key],
              'recovered' => result[:recovered] || false
            }
            base['status'] = result[:status].to_s
            base['message'] = result[:message] if result[:message]
            base['note'] = 'Domain record is a Synoptis proof only (design v0.4.1); no operational chain write.'
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
