# frozen_string_literal: true

require 'json'
require 'digest'
require 'genomicschain_core'
require_relative '../lib/genomicschain_prov/reach_submit'

module KairosMcp
  module SkillSets
    module GenomicschainProv
      module Tools
        # gc_prov_reach — the anchor asks the places a bundle names for its
        # environment whether they still answer, and records the dated counts
        # over the bundle's prov record (design v0.1.15 §6.3). Anchor profile
        # only, like gc_prov_submit.
        #
        # The bundle travels verbatim, is held in memory for the one
        # observation and dropped; the prov record's proof_id comes outside
        # the signature and only its SHA-256 is recorded. What leaves this
        # tool is counts, buckets and codes: no locator, no address, no host
        # name, no answer, and the per-item results only to the submitter.
        class GcProvReach < KairosMcp::Tools::BaseTool
          Spec = ::GenomicsChainProv::VerdictSpec::Reach
          ReachSubmit = ::GenomicsChainProv::ReachSubmit
          Core = KairosMcp::SkillSets::GenomicschainCore

          def name
            'gc_prov_reach'
          end

          def description
            'Observe from the anchor whether the places a provenance bundle names for its environment (workflow ' \
              'repository and commit, runtime, container images, other software) still answer, and record the dated ' \
              'counts as a Synoptis proof over the bundle\'s Tier-2.5 record (anchor profile). Nothing is fetched; ' \
              'answers are the places\' own. The record holds counts per category only; per-item results come back ' \
              'to the submitter in this response. Use dry_run to obtain the params to sign; it asks nothing outside.'
          end

          def category
            :chain
          end

          def usecase_tags
            %w[tier2_5 provenance reachability submit attestation signed synoptis]
          end

          def related_tools
            %w[gc_prov_submit token_manage attestation_verify]
          end

          def input_schema
            {
              type: 'object',
              properties: {
                bundle: { type: %w[object string], description: 'The provenance bundle (bco.json), verbatim.' },
                prov_proof_id: { type: 'string',
                                 description: 'The proof_id of the bundle\'s Tier-2.5 record. Not signed and not ' \
                                              'recorded; the record carries its SHA-256.' },
                identity: { type: 'object',
                            description: 'The signed identity params (dry_run gives them; add a new 32-byte hex ' \
                                         'observation_nonce for every submission).' },
                operator: { type: 'object', description: 'Signed operator envelope with proofs-chain tip in chain_tip_hash.' },
                dry_run: { type: 'boolean', description: 'Read the bundle only: counts and params to sign. Asks nothing ' \
                                                         'outside and looks up no proof_id. Default false.' }
              },
              required: %w[bundle prov_proof_id operator]
            }
          end

          def call(arguments)
            unless Core::Config.anchor_profile?
              return text_content('Error: gc_prov_reach requires genomicschain.anchor_profile: true (anchor node only).')
            end

            args = arguments.transform_keys(&:to_s)
            identity = hashify(args['identity'])
            operator = hashify(args['operator'])
            prober = ::GenomicsChainProv::Reach::Prober.new(gate: gate_options)
            if args['dry_run']
              return text_content(JSON.pretty_generate(dry_run(args['bundle'], identity, args['prov_proof_id'], prober)))
            end

            bearer_pubkey_hash = resolve_bearer_pubkey_hash
            if bearer_pubkey_hash.nil?
              return text_content("Error: no pubkey-bound Bearer (transport: #{transport}).\n" \
                                  'Signed submit requires HTTP Bearer with pubkey_hash. Use dry_run over stdio.')
            end

            registry, tip_source = build_synoptis_context
            KairosMcp::Manifest::Signer.bootstrap_seen_list!(tip_source: tip_source)
            attestor = Core::Attestation::SynoptisAttestor.build(
              operator_pubkey: (operator['pubkey'] || operator[:pubkey]).to_s, safety: @safety, registry: registry
            )
            result = ReachSubmit.submit(
              bundle: args['bundle'], identity: identity, prov_proof_id: args['prov_proof_id'], operator: operator,
              bearer_pubkey_hash: bearer_pubkey_hash, tip_source: tip_source, attestor: attestor, registry: registry,
              prober: prober
            )
            text_content(JSON.pretty_generate(render(result, registry)))
          rescue Spec::RuleVersionMismatch => e
            text_content(JSON.pretty_generate('status' => 'rejected', 'error' => 'RuleVersionMismatch',
                                              'message' => e.message, 'versions' => Spec.versions))
          rescue Core::SubmitCore::SubmitError, KairosMcp::Manifest::ManifestError,
                 KairosMcp::Manifest::Signer::SignerError, Core::Attestation::SynoptisAttestor::AttestorError,
                 ArgumentError => e
            text_content("Error: #{e.class.name.split('::').last}: #{e.message}")
          rescue StandardError => e
            # The class only: an unexpected message may quote a locator.
            text_content("Error: gc_prov_reach failed — #{e.class}")
          end

          private

          # The anchor's own names and addresses and the operator's denylist
          # for the gate (§6.3 (5) step 2), from genomicschain_core.yml:
          #   genomicschain: { reach: { own_names: [], own_addresses: [], denylist: [] } }
          # An address entry that is not an IP address or a CIDR stops the call
          # here, before anything is observed: inside the gate it would turn
          # every answer into an error in a signed record (review r1).
          def gate_options
            cfg = Core::Config.load || {}
            r = cfg.dig('genomicschain', 'reach') || {}
            out = { own_names: Array(r['own_names']).map(&:to_s), own_addresses: Array(r['own_addresses']).map(&:to_s),
                    denylist: Array(r['denylist']).map(&:to_s) }
            (out[:own_addresses] + out[:denylist]).each { |a| IPAddr.new(a) }
            out
          rescue IPAddr::Error
            raise ArgumentError, 'genomicschain.reach: an own_addresses or denylist entry is not an IP address or ' \
                                 'CIDR; nothing observed', cause: nil
          end

          def build_synoptis_context
            data_dir = File.join(KairosMcp.data_dir, 'synoptis_data')
            registry = ::Synoptis::Registry::FileRegistry.new(data_dir: data_dir)
            [registry, Core::TipSource.new(registry: registry)]
          end

          def dry_run(bundle, identity, prov_proof_id, prober)
            spec = Spec.new(bundle: bundle, identity: identity, prov_proof_id: prov_proof_id, registry: nil, prober: prober)
            { 'status' => 'dry_run', 'recorded' => false, 'versions' => Spec.versions }.merge(spec.dry_run).merge(
              'note' => 'Nothing was asked outside and no proof_id was looked up. Sign signed_params with a new ' \
                        'observation_nonce (with mcp_tool_name, nonce, chain_tip_hash) and pass them back as identity.'
            )
          rescue Core::SubmitCore::SubmitError, KairosMcp::Manifest::ManifestError => e
            { 'status' => 'dry_run', 'recorded' => false, 'versions' => Spec.versions,
              'rejected' => "#{e.class.name.split('::').last}: #{e.message}" }
          end

          def render(result, registry)
            out = { 'status' => result[:status].to_s, 'claim' => result[:claim], 'submission_key' => result[:submission_key],
                    'synoptis_proof_id' => result[:synoptis_proof_id], 'idempotency_key' => result[:idempotency_key],
                    'recovered' => result[:recovered] || false }
            out['message'] = result[:message] if result[:message]
            out['counts'] = counts_of(registry, result[:synoptis_proof_id]) if result[:status].to_s == 'recorded'
            if result[:item_results]
              out['item_results'] = result[:item_results]
            elsif result[:recovered]
              out['item_results_note'] = 'A recovered record: per-item results are not kept, so only the recorded ' \
                                         'counts come back. Submit with a new observation_nonce to observe again.'
            end
            out['note'] = 'A dated observation from the anchor, recorded as a Synoptis proof over the Tier-2.5 record; ' \
                          'nothing was fetched and the answers are the places\' own. Per-item results are positions ' \
                          'in each category\'s list as the adapter reads the bundle (for software, the list ' \
                          'without the container images), and are in this response only.'
            out
          end

          def counts_of(registry, proof_id)
            envelope = proof_id && registry.find_proof(proof_id)
            envelope && Core::ProofLookup.parse_evidence(envelope.evidence)&.dig('manifest', 'counts')
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
