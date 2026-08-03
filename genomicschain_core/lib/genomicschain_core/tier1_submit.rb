# frozen_string_literal: true

require 'json'
require_relative 'submit_core'
require_relative 'verdict_spec/tier1'

module KairosMcp
  module SkillSets
    module GenomicschainCore
      # Tier1Submit — thin adapter over SubmitCore + Tier1 VerdictSpec.
      class Tier1Submit
        SubmitError = SubmitCore::SubmitError
        DigestMismatch = SubmitCore::DigestMismatch
        BearerBindingError = SubmitCore::BearerBindingError
        TrustTierError = SubmitCore::TrustTierError
        UnsignedModeError = SubmitCore::UnsignedModeError
        IdentityMismatch = SubmitCore::IdentityMismatch
        EvidenceTooLarge = SubmitCore::EvidenceTooLarge

        def self.submit(report_json:, operator:, bearer_pubkey_hash:, tip_source:, attestor:, registry: nil)
          spec = VerdictSpec::Tier1.new(report_json: report_json, operator: operator)
          registry ||= attestor.registry
          SubmitCore.submit(
            spec: spec, operator: operator, bearer_pubkey_hash: bearer_pubkey_hash,
            tip_source: tip_source, registry: registry, attestor: attestor
          )
        end

        def self.parse_report(report_json)
          VerdictSpec::Tier1.new(report_json: report_json, operator: { 'mode' => 'signed' })
                             .tap(&:parse_digest_subject!)
        end

        def self.recompute_content_hash(report)
          ReportContentHash.compute(report)
        end

        def self.signed_params_for(report, content_hash = nil)
          content_hash ||= ReportContentHash.compute(report)
          VerdictSpec::Tier1.signed_params_for(report, content_hash)
        end
      end
    end
  end
end
