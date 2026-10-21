# frozen_string_literal: true

require_relative 'records'

module KairosMcp
  module SkillSets
    module GenomicschainTier3Record
      # Wording — the verifier's sentences over stored Tier 3 manifests
      # (design §6.2, §9-5). Read per record type: a declaration alone, with
      # its attestation, and with a record 0.3 beside them.
      #
      # Every reading carries both warranty sentences verbatim (09:28 asks for
      # them in every verifier output) and the T_d / T_a line. A declaration
      # without its attestation reads 「宣言されたが attestation されていない」.
      # Nothing here says 「検証済み」 or 「再現された」 (03 §10).
      module Wording
        R = Records

        # §7 時刻, §9-5: record 0.3's started_at is filled by the anchor at
        # submission when absent (20:392), and the 0.3 spec never passes one.
        STARTED_AT_LINE = '記録 0.3 の started_at は anchor が提出を記録したときの時計であり、走った時刻ではない。'

        module_function

        # @param declaration [Hash] a stored tier3_declaration manifest
        # @param attestation [Hash, nil] a stored tier3_attestation manifest
        # @param tier3_verdict [Hash, nil] a stored record 0.3 manifest
        def read(declaration:, attestation: nil, tier3_verdict: nil)
          attested = attested?(declaration, attestation)
          lines = [R::RECORD_TIMES_LINE]
          lines << R::NOT_ATTESTED_LINE unless attested
          lines << STARTED_AT_LINE if tier3_verdict
          times = { 'T_d' => declaration['recorded_at'] }
          times['T_a'] = attestation['recorded_at'] if attested
          { 'state' => attested ? 'attested' : 'declared_not_attested', 'statements' => R::STATEMENTS,
            'lines' => lines, 'times' => times }
        end

        # §4.1: attested = an attestation under the same signing key that
        # points at this declaration (its digest and T_d).
        def attested?(declaration, attestation)
          return false unless attestation.is_a?(Hash)

          ref = { 'declaration_digest' => declaration['declaration_digest'], 'recorded_at' => declaration['recorded_at'] }
          pubkey = R.operator_pubkey(declaration)
          attestation['declaration_ref'] == ref && !pubkey.nil? && R.operator_pubkey(attestation) == pubkey
        end
      end
    end
  end
end
