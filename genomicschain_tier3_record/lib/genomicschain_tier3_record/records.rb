# frozen_string_literal: true

require 'genomicschain_core'
require 'genomicschain_prov'
require 'genomicschain_prov/verdict_spec/prov'

module KairosMcp
  module SkillSets
    module GenomicschainTier3Record
      # Records — the names Tier 3 v0.1 (docs/design/tier3_design_v0_1.md)
      # shares between the anchor-side tool, the wording verifier and the
      # executor-side tool in genomicschain_tier3, which depends on this
      # package: two record types laid beside record 0.3, which stays as it
      # was (§5). This package is the anchor's; the anchor never loads tier3
      # (§3.2〔実装〕, operator 2026-10-21 question 5).
      #
      #   tier3_declaration  signed by the executor before building (§3.3)
      #   tier3_attestation  signed by the same key after the attempts (§4.1)
      #
      # Every refusal is a SubmitError, so nothing is recorded, and names the
      # condition only: no proof_id, no key, no fingerprint of a key.
      module Records
        SubmitCore = GenomicschainCore::SubmitCore

        DECLARATION = 'tier3_declaration'
        ATTESTATION = 'tier3_attestation'
        RECORD_VERSION = '0.1'
        MCP_TOOL = 'gc_tier3_record_submit'
        # A dated observation must outlive the engine's 24 hours (05 C1); the
        # same 100 years as the provenance record it may point at.
        PROOF_TTL = ::GenomicsChainProv::VerdictSpec::Prov::PROOF_TTL
        JOB_IDENTITY_RULE = 'gc-job-identity-0.3'
        PROCESS_FORMAT = 'gc-t3-process-0.1'

        # §4.1: the one binding list. Required in both records and equal field
        # by field; `commitment` joins it when fingerprint_form = salted.
        BINDING_FIELDS = %w[subject_ref job_identity inputs_commitment targets comparator tolerance
                            build_plan_digest route_ref fingerprint_form data_class].freeze
        # §4.1 table, last row. Fixed here because the executor signs them.
        NOT_CHECKED = %w[ran_as_stated inputs_are_the_real_data runs_outside_the_record machine
                         route_a_targets_complete].freeze
        SCORED_ITEMS = %w[rebuild rerun reproduce].freeze

        # §6.2 lines 360 and 362, verbatim (09:30, 09:31): both go in every
        # verifier output.
        STATEMENTS = [
          'ZK 証明（Tier 2.5 の任意の添付）: 証明が示すのは、指定した段の計算が、記録された入力から' \
          '正しく行われたことだけ。対象は指定した段だけで、入力が本当にその生データであるかは示さない。',
          'Tier 3: 保証するのは私たちの手順と記録まで。Tier 3 の記録は「その日、宣言どおりの結果になった」' \
          'という日付つきの観察であり、将来も再現することの約束ではない。'
        ].freeze
        # §6.2 line 364, verbatim.
        RECORD_TIMES_LINE = '記録にあるのは、宣言が anchor の時刻 T_d に、attestation が T_a に記録されたことと、' \
                            '実行者がそう申告したことである。組んだ時刻も走った時刻も記録に無い。'
        # §9-5 (design line 417): what a declaration without its attestation reads.
        NOT_ATTESTED_LINE = '宣言されたが attestation されていない'

        # Field form (§4.4 (1)): schema, required and unknown fields, the
        # salted-only commitment, a cannot_build row with ② ③ fields.
        class FormRejected < SubmitCore::SubmitError; end
        # §3.2: llm_extracted and operator_supplied targets.
        class SourceRefused < SubmitCore::SubmitError; end
        # §2.5: human data until the anchor enables it.
        class HumanDataRefused < SubmitCore::SubmitError; end
        # §3.3: route B's route_ref does not resolve to the Tier-2.5 record.
        class RouteRefUnresolved < SubmitCore::SubmitError; end
        # Operator, question 7 (1): the declared rows do not recount.
        class OutputsDigestMismatch < SubmitCore::SubmitError; end
        # Operator, question 3: an option-2 record under an unsalted declaration.
        class SaltRequired < SubmitCore::SubmitError; end
        class DeclarationNotFound < SubmitCore::SubmitError; end
        # §4.1: attested means under the declaration's signing key.
        class SignerMismatch < SubmitCore::IdentityMismatch; end
        class BindingMismatch < SubmitCore::IdentityMismatch; end
        # §3.4: one attestation per declaration_ref, by this tool's own check
        # (SubmitCore's idempotency key refuses nothing, 36:63–71).
        class AlreadyAttested < SubmitCore::SubmitError; end
        # §3.4: 1 ≤ attempts ≤ attempts_max.
        class AttemptsOutOfRange < SubmitCore::SubmitError; end

        HEX64 = /\A[0-9a-f]{64}\z/

        module_function

        # The record's own schema (prov_reachability precedent, 27:198–205):
        # `fragment` selects the signed params, nil the whole record.
        def validate(schema_path, obj, fragment: nil)
          require 'json-schema'
          @schemas ||= {}
          schema = (@schemas[schema_path] ||= JSON.parse(File.read(schema_path)))
          opts = { errors_as_objects: true, version: :draft4 }
          opts[:fragment] = fragment if fragment
          JSON::Validator.fully_validate(schema, obj, **opts).map { |e| e[:message] }
        end

        # The records of one type this anchor's own tool wrote (review r1 H2):
        # the manifest names gc_tier3_record_submit and the Synoptis envelope's
        # submitter is the manifest's operator (SynoptisAttestor.build sets it
        # from the operator pubkey). Any other proof carrying a Tier 3
        # record_type neither stands in for a declaration nor blocks an
        # attestation. A manifest that does not parse is no record at all.
        def anchor_written(registry, record_type)
          registry.read(:proofs).filter_map do |r|
            m = GenomicschainCore::ProofLookup.parse_manifest_from_record(r)
            m if m && m['record_type'] == record_type && written_here?(r, m)
          end
        end

        # The F2 writer rule for one stored proof record and its manifest.
        def written_here?(record, manifest)
          return false unless manifest.is_a?(Hash) && [DECLARATION, ATTESTATION].include?(manifest['record_type'])
          return false unless manifest['mcp_tool_name'] == MCP_TOOL

          submitter = record[:submitter_pubkey] || record['submitter_pubkey']
          !submitter.nil? && submitter == operator_pubkey(manifest)
        end

        # A stored manifest's operator pubkey, nil when `operator` is not an
        # object: one malformed record must stop nothing (review r3).
        def operator_pubkey(manifest)
          operator = manifest.is_a?(Hash) ? manifest['operator'] : nil
          operator.is_a?(Hash) ? operator['pubkey'] : nil
        end

        def recorded_at(clock) = clock.call.utc.strftime('%Y-%m-%dT%H:%M:%SZ')

        # The Predicate rule (33:416–428) over [name, algorithm, hex] rows. One
        # output per row hands outputs_digest exactly the rows it sorts, so a
        # name carried by two outputs recounts as it was counted.
        def rows_outputs_digest(rows)
          ::GenomicsChainProv::Predicate.outputs_digest(
            Array(rows).map { |name, algo, hex| { 'name' => name, 'checksum' => { algo => hex } } }
          )
        end
      end
    end
  end
end
