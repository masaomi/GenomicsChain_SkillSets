# frozen_string_literal: true

require 'genomicschain_core'
require_relative 'verdict_spec/prov'

module GenomicsChainProv
  # ProvSubmit — thin adapter over core's SubmitCore and VerdictSpec::Prov,
  # the same recording path as Tier-1/2/3 (a Synoptis proof on the anchor).
  # Anchor-side only; the customer's half is Identity (via gc_prov_check).
  class ProvSubmit
    SubmitCore = KairosMcp::SkillSets::GenomicschainCore::SubmitCore

    # @param zk_receipt_bytes [Hash, nil] receipt sha256 => base64 bytes (§6.1)
    def self.submit(bundle:, identity:, operator:, bearer_pubkey_hash:, tip_source:, attestor:,
                    registry: nil, zk_receipt_bytes: nil, zk_verifier: nil)
      spec = VerdictSpec::Prov.new(bundle: bundle, identity: identity,
                                   zk_receipt_bytes: zk_receipt_bytes, zk_verifier: zk_verifier)
      SubmitCore.submit(
        spec: spec, operator: operator, bearer_pubkey_hash: bearer_pubkey_hash,
        tip_source: tip_source, registry: registry || attestor.registry, attestor: attestor
      )
    end

    # What the customer signs: derived from the bundle, never typed.
    def self.signed_params_for(bundle)
      Identity.derive(bundle)['signed']
    end
  end
end
