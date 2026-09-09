# frozen_string_literal: true

require 'json'
require_relative 'submit_core'
require_relative 'verdict_spec/tier2'

module KairosMcp
  module SkillSets
    module GenomicschainCore
      # Tier2Submit — thin adapter over SubmitCore + Tier2 VerdictSpec.
      # Same recording path as Tier-1 and Tier-3 (Synoptis proof on the anchor).
      class Tier2Submit
        SubmitError = SubmitCore::SubmitError
        DigestMismatch = SubmitCore::DigestMismatch
        BearerBindingError = SubmitCore::BearerBindingError
        TrustTierError = SubmitCore::TrustTierError
        UnsignedModeError = SubmitCore::UnsignedModeError
        IdentityMismatch = SubmitCore::IdentityMismatch
        EvidenceTooLarge = SubmitCore::EvidenceTooLarge

        SIGNED_IDENTITY_FIELDS = VerdictSpec::Tier2::SIGNED_IDENTITY_FIELDS

        def self.submit(adjudication:, identity:, operator:, bearer_pubkey_hash:, tip_source:, attestor:,
                        repository: nil, registry: nil)
          spec = VerdictSpec::Tier2.new(adjudication: adjudication, identity: identity, repository: repository)
          registry ||= attestor.registry
          SubmitCore.submit(
            spec: spec, operator: operator, bearer_pubkey_hash: bearer_pubkey_hash,
            tip_source: tip_source, registry: registry, attestor: attestor
          )
        end

        # What the operator signs. Derived, never typed: the same adjudication
        # always yields the same params, and the server derives them again.
        def self.signed_params_for(adjudication, repository = nil)
          VerdictSpec::Tier2.identity_for(adjudication, repository)
        end

        def self.adjudication_digest(adjudication)
          VerdictSpec::Tier2.adjudication_digest(
            adjudication.is_a?(String) ? JSON.parse(adjudication) : JSON.parse(JSON.generate(adjudication))
          )
        end
      end
    end
  end
end
