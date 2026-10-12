# frozen_string_literal: true

require 'json'
require 'digest'
require 'genomicschain_core'
require_relative '../lib/genomicschain_prov/prov_submit'

module KairosMcp
  module SkillSets
    module GenomicschainProv
      module Tools
        # gc_prov_submit — MCP skin over SubmitCore for Tier-2.5 provenance
        # bundles (design v0.1 §6–§7, v0.1.12 §6.1). Anchor profile only: it is
        # listed under anchor_profile_tool_classes, which core 0.6.0 reads from
        # any SkillSet.
        #
        # The same skeleton as gc_tier2_submit — signed operator envelope,
        # pubkey-bound Bearer, a Synoptis proof, no operational chain write —
        # with the bundle's own gates in front: Gate A (2 MB, depth 32) and the
        # ZK receipt checks. No grade gate since design v0.1.13: the record
        # carries the grade, whatever it is.
        #
        # What leaves this tool is the record's own vocabulary — grades,
        # counts, digests, codes. The bundle, the predicate's per-item output
        # and the receipt bytes are never logged and never echoed (§6).
        class GcProvSubmit < KairosMcp::Tools::BaseTool
          Prov = ::GenomicsChainProv::VerdictSpec::Prov
          ProvSubmit = ::GenomicsChainProv::ProvSubmit
          Core = KairosMcp::SkillSets::GenomicschainCore

          def name
            'gc_prov_submit'
          end

          def description
            'Sign and record a provenance bundle (BioCompute Object) as a Tier-2.5 Synoptis proof (anchor ' \
              'profile). The bundle is submitted verbatim; the server recomputes its digest and re-derives every ' \
              'signed field (grades, counts, platform, ZK receipt identities). A record is issued at any grade, ' \
              'which it carries, provided every declared ZK receipt verifies and binds its step. Records a ' \
              'self_reported record of identities and counts; the bundle stays with the customer. Use dry_run to ' \
              'validate and to obtain the params to sign.'
          end

          def category
            :chain
          end

          def usecase_tags
            %w[tier2_5 provenance bco submit attestation signed synoptis zk]
          end

          def related_tools
            %w[gc_tier2_submit token_manage attestation_verify]
          end

          def input_schema
            {
              type: 'object',
              properties: {
                bundle: {
                  type: %w[object string],
                  description: 'The provenance bundle (bco.json), verbatim. Its canonical sha256 is the digest subject.'
                },
                identity: {
                  type: 'object',
                  description: 'The signed identity params (gc_prov_check --json signed_params, or dry_run). ' \
                               'Every field is re-derived from the bundle server-side; a mismatch is rejected.'
                },
                zk_receipt_bytes: {
                  type: 'object',
                  description: 'Receipt sha256 => base64 of the receipt file, for every ZK receipt the bundle ' \
                               'declares. Verified on the anchor, held in memory only, never stored.'
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
              required: %w[bundle operator]
            }
          end

          def call(arguments)
            unless Core::Config.anchor_profile?
              return text_content('Error: gc_prov_submit requires genomicschain.anchor_profile: true (anchor node only).')
            end

            args = arguments.transform_keys(&:to_s)
            bundle = args['bundle']
            identity = hashify(args['identity'])
            operator = hashify(args['operator'])
            zk_bytes = args['zk_receipt_bytes']

            return text_content(JSON.pretty_generate(dry_run(bundle, identity, operator, zk_bytes))) if args['dry_run']

            bearer_pubkey_hash = resolve_bearer_pubkey_hash
            if bearer_pubkey_hash.nil?
              return text_content(
                "Error: no pubkey-bound Bearer (transport: #{transport}).\n" \
                'Signed submit requires HTTP Bearer with pubkey_hash. Use dry_run over stdio.'
              )
            end

            registry, tip_source = build_synoptis_context
            KairosMcp::Manifest::Signer.bootstrap_seen_list!(tip_source: tip_source)
            attestor = Core::Attestation::SynoptisAttestor.build(
              operator_pubkey: (operator['pubkey'] || operator[:pubkey]).to_s, safety: @safety, registry: registry
            )

            result = ProvSubmit.submit(
              bundle: bundle, identity: identity, operator: operator, bearer_pubkey_hash: bearer_pubkey_hash,
              tip_source: tip_source, attestor: attestor, registry: registry, zk_receipt_bytes: zk_bytes
            )
            text_content(JSON.pretty_generate(render(result)))
          rescue Prov::ProcedureVersionMismatch => e
            text_content(JSON.pretty_generate(
                           'status' => 'rejected', 'error' => 'ProcedureVersionMismatch', 'message' => e.message,
                           'versions' => Prov.versions,
                           'note' => 'Install the genomicschain_prov version the anchor runs, re-run gc_prov_check, sign again.'
                         ))
          rescue Core::SubmitCore::SubmitError,
                 KairosMcp::Manifest::ManifestError,
                 KairosMcp::Manifest::Signer::SignerError,
                 Core::Attestation::SynoptisAttestor::AttestorError,
                 ArgumentError => e
            text_content("Error: #{e.class.name.split('::').last}: #{e.message}")
          rescue StandardError => e
            # The class only: an unexpected exception's message may quote
            # whatever it was handed, and that may be the bundle (§6).
            text_content("Error: gc_prov_submit failed — #{e.class}")
          end

          private

          def build_synoptis_context
            data_dir = File.join(KairosMcp.data_dir, 'synoptis_data')
            registry = ::Synoptis::Registry::FileRegistry.new(data_dir: data_dir)
            [registry, Core::TipSource.new(registry: registry)]
          end

          # Everything the real path checks except admission and the store,
          # including Gate A and the ZK receipts — a dry run that
          # skipped them would tell the customer "ok" for a bundle the real
          # submit refuses.
          def dry_run(bundle, identity, operator, zk_bytes)
            checks = {}
            spec = Prov.new(bundle: bundle, identity: identity, zk_receipt_bytes: zk_bytes)
            parsed = spec.parse_digest_subject!
            # bundle-side admission first, so a refusal below still shows it;
            # apply_gates! then runs the same checks plus the receipt bytes
            checks['admission'] = spec.admission
            spec.apply_gates!(parsed)
            checks['gates'] = 'ok'
            derived = spec.signed_identity_params
            checks['identity_matches_derived'] =
              if identity.empty?
                'no identity supplied (see signed_params)'
              else
                begin
                  spec.assert_submitted_matches_signed!
                  'ok'
                rescue Core::SubmitCore::IdentityMismatch => e
                  "MISMATCH: #{e.message}"
                end
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
            checks['attestor'] = Core::Attestation::SynoptisAttestor.available? ? 'ok (synoptis loaded)' : 'UNAVAILABLE'
            { 'status' => 'dry_run', 'recorded' => false, 'checks' => checks, 'versions' => Prov.versions,
              'signed_params' => derived,
              'claim_prefix' => "prov:#{derived['predicate_version']}:#{derived['grade_overall']}:" \
                                "#{derived['stages_with_own_environment']}/#{derived['stages_total']}:" \
                                "#{derived['bundle_digest']}:<submission_key>",
              'note' => 'No admission, no Synoptis store. Sign signed_params (with mcp_tool_name, nonce, ' \
                        'chain_tip_hash) and pass them back as identity.' }
          rescue Core::SubmitCore::SubmitError, KairosMcp::Manifest::ManifestError => e
            { 'status' => 'dry_run', 'recorded' => false, 'versions' => Prov.versions,
              'checks' => checks.merge('rejected' => "#{e.class.name.split('::').last}: #{e.message}") }
          end

          def render(result)
            out = {
              'status' => result[:status].to_s,
              'claim' => result[:claim],
              'submission_key' => result[:submission_key],
              'synoptis_proof_id' => result[:synoptis_proof_id],
              'idempotency_key' => result[:idempotency_key],
              'recovered' => result[:recovered] || false
            }
            out['message'] = result[:message] if result[:message]
            out['note'] = 'Domain record is a Synoptis proof only; no operational chain write. A self_reported ' \
                          'record of identities and counts; the bundle stays with the customer. ' \
                          "Public read: /place/web/prov/proof/#{result[:synoptis_proof_id]}"
            out
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
