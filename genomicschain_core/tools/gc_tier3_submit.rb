# frozen_string_literal: true

require 'json'
require 'digest'
require 'genomicschain_core'

module KairosMcp
  module SkillSets
    module GenomicschainCore
      module Tools
        # gc_tier3_submit — MCP skin over SubmitCore (design v0.4.1).
        # Synoptis-only recording; no KairosChain operational chain writes.
        class GcTier3Submit < KairosMcp::Tools::BaseTool
          # The value the submitted verdict_result is read into: the members and
          # keyword construction of genomicschain_tier3's
          # Tier3Executor::VerdictResult (tier3_executor.rb:25–34), held here so
          # the anchor records 0.3 without loading tier3, which it never installs
          # (Tier 3 design §5〔実装〕, operator 2026-10-21 question 7).
          VerdictResult = Struct.new(
            :subject_ref, :jobspec_digest, :execution_verdict, :comparison_verdict,
            :environment_provenance, :inputs_provenance, :run_count, :self_consistency,
            :trust_tier, :result_hash, :backend_result_hash, :container_digest,
            :expected_output, :expected_output_sha256,
            :expected_output_source, :expected_output_validated_by,
            :expected_output_source_citation, :expected_output_target,
            :comparator_id, :comparator_version, :backend_id, :output_files,
            :first_divergence, :receipt, :receipts, keyword_init: true
          )

          def name
            'gc_tier3_submit'
          end

          def description
            'Sign and record a Tier-3 executed-R verdict as a Synoptis proof (anchor profile). ' \
              'Requires signed operator envelope and pubkey-bound Bearer (HTTP transport). ' \
              'Use dry_run to validate without recording.'
          end

          def category
            :chain
          end

          def usecase_tags
            %w[tier3 reproducibility submit verdict attestation signed synoptis]
          end

          def related_tools
            %w[gc_tier3_execute token_manage attestation_verify]
          end

          def input_schema
            {
              type: 'object',
              properties: {
                verdict_result: {
                  type: 'object',
                  description: 'verdict_result from gc_tier3_execute (signed identity subset).'
                },
                jobspec_json: {
                  type: 'string',
                  description: 'Canonical jobspec_json; server recomputes digest.'
                },
                expected_output: {
                  type: 'object',
                  description: 'Full expected_output; must match signed provenance.'
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
              required: %w[verdict_result jobspec_json expected_output operator]
            }
          end

          def call(arguments)
            unless Config.anchor_profile?
              return text_content(
                'Error: gc_tier3_submit requires genomicschain.anchor_profile: true ' \
                '(anchor node only). Enable in config/genomicschain_core.yml.'
              )
            end

            args = arguments.transform_keys(&:to_s)
            vr = build_verdict_result(args['verdict_result'])
            expected_output = hashify(args['expected_output'])
            jobspec_json = args['jobspec_json'].to_s
            operator = hashify(args['operator'])

            return text_content(JSON.pretty_generate(dry_run(vr, jobspec_json, expected_output, operator))) if args['dry_run']

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

            result = Tier3Submit.submit(
              verdict_result: vr, operator: operator, jobspec_json: jobspec_json,
              bearer_pubkey_hash: bearer_pubkey_hash, tip_source: tip_source,
              attestor: attestor, expected_output: expected_output, registry: registry
            )

            text_content(JSON.pretty_generate(render(result, vr)))
          rescue Tier3Submit::SubmitError,
                 KairosMcp::Manifest::ManifestError,
                 KairosMcp::Manifest::Signer::SignerError,
                 Attestation::SynoptisAttestor::AttestorError,
                 ArgumentError => e
            text_content("Error: #{e.class.name.split('::').last}: #{e.message}")
          rescue StandardError => e
            text_content("Error: gc_tier3_submit failed — #{e.class}: #{e.message}")
          end

          private

          def build_synoptis_context
            data_dir = File.join(KairosMcp.data_dir, 'synoptis_data')
            registry = ::Synoptis::Registry::FileRegistry.new(data_dir: data_dir)
            [registry, TipSource.new(registry: registry)]
          end

          def dry_run(vr, jobspec_json, expected_output, operator)
            checks = {}
            parsed = Tier3Submit.parse_jobspec(jobspec_json)
            KairosMcp::Manifest.dos_gate!(parsed)
            KairosMcp::Manifest.restricted_subset!(parsed)
            KairosMcp::Manifest.dos_gate!(expected_output)
            KairosMcp::Manifest.restricted_subset!(expected_output)
            checks['gates'] = 'ok'

            recomputed = KairosMcp::Manifest.canonical_json_sha256(parsed)
            checks['jobspec_digest_recompute'] =
              recomputed == vr.jobspec_digest ? 'ok' : "MISMATCH (claimed #{vr.jobspec_digest}, recomputed #{recomputed})"

            begin
              Tier3Submit.assert_expected_output_matches_signed!(expected_output, vr)
              checks['expected_output_matches_signed'] = 'ok'
            rescue Tier3Submit::IdentityMismatch => e
              checks['expected_output_matches_signed'] = "MISMATCH: #{e.message}"
            end

            checks['operator_mode'] =
              (operator['mode'] || operator[:mode]).to_s == 'signed' ? 'ok (signed)' : 'REJECTED (must be signed)'
            checks['trust_tier'] =
              vr.trust_tier == 'self_reported' ? 'ok (self_reported)' : "REJECTED (#{vr.trust_tier.inspect})"

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

            result_bundle = {
              'backend_id' => vr.backend_id, 'backend_result_hash' => vr.backend_result_hash,
              'local_result_hash' => vr.result_hash, 'jobspec_digest' => vr.jobspec_digest,
              'output_files' => (vr.output_files || [])
            }.compact
            result_evidence_sha256 = Digest::SHA256.hexdigest(KairosMcp::Manifest.canonical_json(result_bundle))
            eligible = Tier3Submit.leaderboard_eligible?(vr, pubkey)

            begin
              record = KairosMcp::Manifest.build_tier3_verdict(
                'subject_ref' => vr.subject_ref, 'jobspec_digest' => vr.jobspec_digest,
                'execution_verdict' => vr.execution_verdict,
                'comparison_verdict' => vr.comparison_verdict,
                'environment_provenance' => vr.environment_provenance,
                'inputs_provenance' => vr.inputs_provenance,
                'run_count' => vr.run_count, 'self_consistency' => vr.self_consistency,
                'trust_tier' => vr.trust_tier, 'result_hash' => vr.result_hash,
                'backend_result_hash' => vr.backend_result_hash,
                'container_digest' => vr.container_digest,
                'expected_output' => (expected_output.nil? || expected_output.empty? ? nil : expected_output),
                'comparator_id' => vr.comparator_id, 'comparator_version' => vr.comparator_version,
                'backend_id' => vr.backend_id, 'output_files' => vr.output_files,
                'result_evidence_sha256' => result_evidence_sha256, 'leaderboard_eligible' => eligible,
                'operator' => operator
              )
              KairosMcp::Manifest.validate_tier3!(record)
              checks['record_schema'] = 'ok'
            rescue KairosMcp::Manifest::ManifestError => e
              checks['record_schema'] = "INVALID: #{e.message}"
            end

            checks['attestor'] = Attestation::SynoptisAttestor.available? ? 'ok (synoptis loaded)' : 'UNAVAILABLE'

            {
              'status' => 'dry_run',
              'recorded' => false,
              'checks' => checks,
              'would_record' => {
                'result_evidence_sha256' => result_evidence_sha256,
                'claim_prefix' => "tier3:#{vr.execution_verdict}:#{vr.comparison_verdict}:" \
                                  "#{vr.result_hash}:<submission_key>",
                'leaderboard_eligible' => eligible
              },
              'note' => 'No admission, no Synoptis store. Real submit uses proofs-chain tip (not operational chain).'
            }
          end

          def render(result, vr)
            base = {
              'subject_ref' => vr.subject_ref,
              'execution_verdict' => vr.execution_verdict,
              'comparison_verdict' => vr.comparison_verdict,
              'run_count' => vr.run_count,
              'trust_tier' => vr.trust_tier,
              'claim' => result[:claim],
              'submission_key' => result[:submission_key],
              'synoptis_proof_id' => result[:synoptis_proof_id],
              'leaderboard_eligible' => result[:leaderboard_eligible],
              'idempotency_key' => result[:idempotency_key],
              'recovered' => result[:recovered] || false
            }
            base['status'] = result[:status].to_s
            base['result_evidence_sha256'] = result[:result_evidence_sha256] if result[:result_evidence_sha256]
            base['message'] = result[:message] if result[:message]
            base['note'] = 'Domain record is a Synoptis proof only (design v0.4.1); no operational chain write.'
            base
          end

          def build_verdict_result(raw)
            h = hashify(raw)
            VerdictResult.new(
              subject_ref: h['subject_ref'], jobspec_digest: h['jobspec_digest'],
              execution_verdict: h['execution_verdict'], comparison_verdict: h['comparison_verdict'],
              environment_provenance: h['environment_provenance'],
              inputs_provenance: h['inputs_provenance'],
              run_count: h['run_count'] || 1, self_consistency: h['self_consistency'],
              trust_tier: h['trust_tier'],
              result_hash: h['result_hash'], backend_result_hash: h['backend_result_hash'],
              container_digest: h['container_digest'],
              expected_output: h['expected_output'],
              expected_output_sha256: h['expected_output_sha256'],
              expected_output_source: h['expected_output_source'],
              expected_output_validated_by: h['expected_output_validated_by'],
              expected_output_source_citation: h['expected_output_source_citation'],
              expected_output_target: h['expected_output_target'],
              comparator_id: h['comparator_id'], comparator_version: h['comparator_version'],
              backend_id: h['backend_id'], output_files: h['output_files'],
              first_divergence: nil, receipt: nil, receipts: nil
            )
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
