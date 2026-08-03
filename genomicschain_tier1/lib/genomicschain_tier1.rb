# frozen_string_literal: true

# genomicschain_tier1 — Tier-1 assessment assets (design v0.4.1 Step 4).
# Submit path lives in genomicschain_core (gc_tier1_submit); this package holds
# schema, rubric knowledge, and the core-contract guard.
require 'genomicschain_core'
require_relative 'genomicschain_tier1/core_contract_guard'

KairosMcp::SkillSets::GenomicschainTier1::CoreContractGuard.verify!

module KairosMcp
  module SkillSets
    module GenomicschainTier1
      SCHEMA_V0_2_6 = File.expand_path('../../assets/report_schema_v0_2_6.json', __dir__)
    end
  end
end
