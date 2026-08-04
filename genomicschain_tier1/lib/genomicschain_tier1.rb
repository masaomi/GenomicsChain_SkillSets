# frozen_string_literal: true

# genomicschain_tier1 — Tier-1 assessment (design v0.4.1 Step 4).
# Submit path lives in genomicschain_core (gc_tier1_submit); this package holds
# the schema, the rubric knowledge, the core-contract guard, and the assessment
# path behind gc_tier1_assess (spec: doc/gc_tier1_assess_spec_v0_2.md).
require 'genomicschain_core'
require_relative 'genomicschain_tier1/core_contract_guard'

KairosMcp::SkillSets::GenomicschainTier1::CoreContractGuard.verify!

module KairosMcp
  module SkillSets
    module GenomicschainTier1
      # __dir__ is <pkg>/lib, so the assets dir is one level up, not two.
      # The previous '../../assets/...' resolved outside the package entirely; it
      # went unnoticed because nothing loaded the schema until gc_tier1_assess.
      SCHEMA_V0_2_6 = File.expand_path('../assets/report_schema_v0_2_6.json', __dir__)
    end
  end
end

require_relative 'genomicschain_tier1/assess/pre_commit'
require_relative 'genomicschain_tier1/assess/derivation'
require_relative 'genomicschain_tier1/assess/prompts'
require_relative 'genomicschain_tier1/assess/validator'
require_relative 'genomicschain_tier1/assess/assessor'
