# frozen_string_literal: true

require 'json'
require 'genomicschain_core/backing'
require_relative '../identity'
require_relative 'rule'

module GenomicsChainProv
  module Reach
    # What the customer signs for an observation (design v0.1.15 §6.3 (6)):
    # derived from the bundle's bytes, the prov record's proof_id (hashed,
    # never signed itself) and a fresh nonce. The anchor re-derives it with
    # this same function; the client script calls it too, without loading
    # the anchor's submit path.
    module SignedParams
      SCOPE = 'environment'

      module_function

      def for(bundle, prov_proof_id, nonce)
        text = bundle.is_a?(String) ? bundle : JSON.generate(bundle)
        digest = GenomicsChainProv::Identity.bundle_digest(text)
        { 'subject_ref' => "prov-reach:sha256:#{digest}",
          'prov_proof_ref' => KairosMcp::SkillSets::GenomicschainCore::ProvProofRef.for(prov_proof_id),
          'bundle_digest' => digest, 'reachability_rule' => RULE_VERSION, 'scope' => SCOPE,
          'observation_nonce' => nonce }
      end
    end
  end
end
