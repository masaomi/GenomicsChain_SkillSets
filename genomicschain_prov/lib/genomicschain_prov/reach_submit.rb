# frozen_string_literal: true

require 'genomicschain_core'
require_relative 'verdict_spec/reach'

module GenomicsChainProv
  # ReachSubmit — the reachability observation through core's SubmitCore,
  # the same recording path as every other record (a Synoptis proof on the
  # anchor). Anchor-side only.
  class ReachSubmit
    SubmitCore = KairosMcp::SkillSets::GenomicschainCore::SubmitCore

    # @return [Hash] SubmitCore's result, plus :item_results when the
    #   observation ran in this call (never on recovery: they are not kept)
    def self.submit(bundle:, identity:, prov_proof_id:, operator:, bearer_pubkey_hash:, tip_source:, attestor:,
                    prober:, registry: nil, budget: nil, admission: nil)
      registry ||= attestor.registry
      spec = VerdictSpec::Reach.new(bundle: bundle, identity: identity, prov_proof_id: prov_proof_id,
                                    registry: registry, prober: prober, budget: budget, admission: admission)
      result = SubmitCore.submit(spec: spec, operator: operator, bearer_pubkey_hash: bearer_pubkey_hash,
                                 tip_source: tip_source, registry: registry, attestor: attestor)
      # A recovery never reaches server_set_fields, so it has none to return.
      spec.item_results ? result.merge(item_results: spec.item_results) : result
    end
  end
end
