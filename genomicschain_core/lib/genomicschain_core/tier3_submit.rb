# frozen_string_literal: true

require 'json'
require_relative 'submit_core'
require_relative 'verdict_spec/tier3'

module KairosMcp
  module SkillSets
    module GenomicschainCore
      # Tier3Submit — thin adapter over SubmitCore + Tier3 VerdictSpec.
      class Tier3Submit
        SubmitError = SubmitCore::SubmitError
        JobSpecMismatch = SubmitCore::DigestMismatch
        BearerBindingError = SubmitCore::BearerBindingError
        TrustTierError = SubmitCore::TrustTierError
        UnsignedModeError = SubmitCore::UnsignedModeError
        IdentityMismatch = SubmitCore::IdentityMismatch
        EvidenceTooLarge = SubmitCore::EvidenceTooLarge

        SIGNED_IDENTITY_FIELDS = VerdictSpec::Tier3::SIGNED_IDENTITY_FIELDS

        def self.submit(verdict_result:, operator:, jobspec_json:, bearer_pubkey_hash:,
                        tip_source:, attestor:, expected_output:, registry: nil)
          spec = VerdictSpec::Tier3.new(
            verdict_result: verdict_result, jobspec_json: jobspec_json, expected_output: expected_output
          )
          registry ||= attestor.registry
          SubmitCore.submit(
            spec: spec, operator: operator, bearer_pubkey_hash: bearer_pubkey_hash,
            tip_source: tip_source, registry: registry, attestor: attestor
          )
        end

        def self.leaderboard_eligible?(vr, _submitter_pubkey)
          spec = VerdictSpec::Tier3.new(
            verdict_result: vr, jobspec_json: '{}', expected_output: vr.expected_output
          )
          spec.send(:leaderboard_eligible?, nil)
        end

        def self.assert_expected_output_matches_signed!(expected_output, vr)
          VerdictSpec::Tier3.new(
            verdict_result: vr, jobspec_json: '{}', expected_output: expected_output
          ).assert_submitted_matches_signed!
        end

        def self.parse_jobspec(jobspec_json)
          JSON.parse(jobspec_json)
        rescue JSON::ParserError => e
          raise JobSpecMismatch, "jobspec_json is not valid JSON: #{e.message}"
        end
      end
    end
  end
end
