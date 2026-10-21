# frozen_string_literal: true

require 'json'
require 'time'
require 'genomicschain_prov/adapters/bco'
require_relative '../records'

module KairosMcp
  module SkillSets
    module GenomicschainTier3Record
      module VerdictSpec
        # Declaration — SubmitCore hooks for tier3_declaration 0.1 (design
        # §3.3, §9-1). The digest subject is the signed params themselves; the
        # record carries them verbatim. SubmitCore's order gives two halves:
        #
        #   ① apply_gates! reads the params only: field form, §3.2 sources,
        #     §2.5 human data. No registry.
        #   ② the Bearer   ③ recovery (submission_key)   ④ the signature
        #   ⑤ server_set_fields: route B only, the Tier-2.5 record is read by
        #     its proof_id (prov_manifest!, 37:229–243), the declared rows are
        #     recounted (33:420) and option 2 requires salt (question 3)
        #
        # So an unsigned call, a wrong Bearer or a resend never looks up a
        # proof_id. The route B proof_id comes beside the params, unsigned;
        # route_ref is its SHA-256 (18:33–41). The proof_id is held for this
        # one submission and reaches no record and no message.
        class Declaration
          R = Records
          Core = GenomicschainCore
          SubmitCore = Core::SubmitCore
          Prov = ::GenomicsChainProv::VerdictSpec::Prov

          MCP_TOOL = R::MCP_TOOL
          RECORD_TYPE = R::DECLARATION
          SCHEMA_PATH = File.expand_path('../../../schemas/tier3_declaration_v0_1.schema.json', __dir__)
          ROUTE_A_FIELDS = %w[source source_citation validated_by].freeze
          TARGET_KIND = { 'A' => 'paper_declared', 'B' => 'tier2_5_bundle' }.freeze
          REFUSED_SOURCES = %w[llm_extracted operator_supplied].freeze

          # @param registry [#find_proof, #revoked?] the Synoptis registry
          # @param config [Hash, nil] the core configuration; nil reads
          #   genomicschain_core.yml when a human-data declaration needs it
          def initialize(declaration:, registry:, route_proof_id: nil, config: nil, clock: -> { Time.now.utc })
            @raw = declaration
            @params = nil
            @registry = registry
            @route_proof_id = route_proof_id
            @config = config
            @clock = clock
          end

          def proof_ttl = R::PROOF_TTL
          def subject_ref = @params['subject_ref'].to_s
          def trust_tier_gate!; end

          # The house gates (10:151–158), before any other work: size, depth,
          # ASCII keys, no U+2028 / U+2029. Their errors propagate as raised.
          # Once passed, the gated params are kept.
          def parse_digest_subject!
            return @params if @params

            KairosMcp::Manifest.dos_gate!(@raw)
            KairosMcp::Manifest.restricted_subset!(@raw)
            raise R::FormRejected, 'declaration must be a JSON object' unless @raw.is_a?(Hash)

            @params = JSON.parse(JSON.generate(@raw))
          end

          # ①, before the signature.
          def apply_gates!(params)
            form!(params)
            if REFUSED_SOURCES.include?(params['source'])
              raise R::SourceRefused, "source #{params['source']} is refused: a target is the subject's own " \
                                      'declaration (§3.2)'
            end
            return unless params['data_class'] == 'human' && !human_data_records?

            raise R::HumanDataRefused, 'data_class human is refused until the anchor enables ' \
                                       'genomicschain.tier3.human_data_records (§2.5)'
          end

          def recompute_digest!(params) = KairosMcp::Manifest.canonical_json_sha256(params)
          def claimed_digest = declaration_digest
          def signed_identity_params = @params

          # The signature covers the params verbatim (Signer re-serialises
          # them), so nothing is re-derived and compared here.
          def assert_submitted_matches_signed!; end

          # The schema refuses every field the params may not hold, the
          # server-set ones included.
          def reject_client_server_set_fields!(_params); end

          # ⑤, after the signature. T_d is the anchor's clock (18:15–16).
          def server_set_fields(_pubkey)
            backing = { 'vocabulary' => Core::Backing::VERSION, 'recorded_at' => 'anchor_observed',
                        'declaration' => 'customer_signed' }
            if @params['route'] == 'B'
              route_b!
              backing.merge!('route_ref' => 'procedure_checked', 'outputs_digest' => 'procedure_checked')
            else
              # §3.3, §8: route A's route_ref is carried and signed, never resolved.
              backing['route_ref'] = 'not_checked'
            end
            { 'declaration_digest' => declaration_digest, 'recorded_at' => R.recorded_at(@clock), 'backing' => backing }
          end

          def build_manifest(operator:, submission_key:, server_fields:)
            record = {
              'record_type' => RECORD_TYPE, 'record_version' => R::RECORD_VERSION, 'mcp_tool_name' => MCP_TOOL,
              'mcp_tool_version' => defined?(KairosMcp::VERSION) ? KairosMcp::VERSION.to_s : 'unknown'
            }.merge(@params).merge(server_fields).merge(
              'submission_key' => submission_key, 'operator' => KairosMcp::Manifest::Builder.build_operator(operator, {})
            )
            errors = R.validate(SCHEMA_PATH, record)
            raise KairosMcp::Manifest::SchemaViolation, "tier3_declaration schema violation: #{errors.first}" unless errors.empty?

            record
          end

          # 05 C10 (10:140–142 shape): type, version, digest, submission_key.
          # No result: a declaration has none.
          def claim_for(submission_key:)
            "tier3-declaration:#{R::RECORD_VERSION}:#{declaration_digest}:#{submission_key}"
          end

          private

          def declaration_digest
            @declaration_digest ||= KairosMcp::Manifest.canonical_json_sha256(@params)
          end

          # §4.1: every binding field is required; `commitment` iff salted.
          # The route decides the target kind and the route A fields (§3).
          def form!(params)
            errors = R.validate(SCHEMA_PATH, params, fragment: '#/definitions/params')
            raise R::FormRejected, "tier3_declaration form: #{errors.first}" unless errors.empty?

            salted = params['fingerprint_form'] == 'salted'
            unless salted == params.key?('commitment')
              raise R::FormRejected, salted ? 'commitment is required when fingerprint_form is salted' :
                                              'commitment is a salted-only field; fingerprint_form is plain'
            end
            route = params['route']
            unless params.dig('targets', 'kind') == TARGET_KIND[route]
              raise R::FormRejected, "targets.kind must be #{TARGET_KIND[route]} for route #{route}"
            end
            ROUTE_A_FIELDS.each do |f|
              raise R::FormRejected, "#{f} is required for route A" if route == 'A' && !params.key?(f)
              raise R::FormRejected, "#{f} is a route A field; route B carries none" if route == 'B' && params.key?(f)
            end
          end

          # §2.5, the prov S4 precedent: true only for a literal `true`.
          def human_data_records?
            cfg = @config || Core::Config.load || {}
            cfg.dig('genomicschain', 'tier3', 'human_data_records') == true
          rescue StandardError
            false
          end

          # §3.3 resolution, then the recount (question 7 (1)), then the salt
          # rule (question 3). The record is read once, here.
          def route_b!
            prov = prov_manifest!
            targets = @params['targets']
            recount = R.rows_outputs_digest(targets['rows'])
            unless recount == prov['outputs_digest']
              raise R::OutputsDigestMismatch, 'the declared rows do not recount to the Tier-2.5 record\'s outputs_digest'
            end
            unless targets['outputs_digest'] == recount
              raise R::OutputsDigestMismatch, 'targets.outputs_digest is not the recount of the declared rows'
            end
            return unless option_2?(prov) && @params['fingerprint_form'] != 'salted'

            raise R::SaltRequired, 'the Tier-2.5 record is option 2 (gc-zk-journal-0.2); the declaration must be ' \
                                   'fingerprint_form salted'
          end

          # prov_manifest! (37:229–243) with the route_ref link first, and the
          # writer rule F2 applies to the Tier 3 types (pre-flight r2 §2.1): only
          # a record gc_prov_submit wrote under its operator's key resolves, so a
          # planted look-alike without its 0.2 receipt cannot pass as "not option
          # 2". The messages name the condition only, never the proof_id.
          def prov_manifest!
            if @route_proof_id.to_s.empty?
              raise R::RouteRefUnresolved, 'route B needs the proof_id of the Tier-2.5 record beside the declaration'
            end
            unless Core::ProvProofRef.for(@route_proof_id) == @params['route_ref']
              raise R::RouteRefUnresolved, 'route_ref is not the SHA-256 of the given proof_id'
            end

            envelope = @registry.find_proof(@route_proof_id)
            raise R::RouteRefUnresolved, 'no Tier-2.5 record under the given proof_id' unless envelope
            raise R::RouteRefUnresolved, 'the Tier-2.5 record is revoked' if @registry.revoked?(@route_proof_id)

            manifest = Core::ProofLookup.parse_evidence(envelope.evidence)&.dig('manifest')
            unless manifest.is_a?(Hash) && manifest['record_type'] == Prov::RECORD_TYPE
              raise R::RouteRefUnresolved, 'the proof_id names no Tier-2.5 record'
            end
            submitter = envelope.submitter_pubkey
            unless manifest['mcp_tool_name'] == Prov::MCP_TOOL && !submitter.nil? &&
                   submitter == R.operator_pubkey(manifest)
              raise R::RouteRefUnresolved, 'the Tier-2.5 record was not written by gc_prov_submit under its operator\'s key'
            end
            unless manifest['bundle_digest'] == @params.dig('targets', 'bundle_digest')
              raise R::RouteRefUnresolved, 'the Tier-2.5 record is of another bundle'
            end

            manifest
          end

          # Option 2 is read where prov stores it: the signed receipts' journal
          # convention (〔実装の読み〕).
          def option_2?(prov)
            Array(prov['zk_receipts']).any? do |r|
              r.is_a?(Hash) && r['journal_convention'] == ::GenomicsChainProv::Adapters::Bco::JOURNAL_V02
            end
          end
        end
      end
    end
  end
end
