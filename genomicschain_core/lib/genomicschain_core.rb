# frozen_string_literal: true

# genomicschain_core — shared substrate for GenomicsChain SkillSet split (design v0.4.1).
# Synoptis-only domain recording; no KairosChain operational chain writes on submit.
require_relative 'genomicschain_core/manifest'
require_relative 'genomicschain_core/manifest/signer'
require_relative 'genomicschain_core/tip_source'
require_relative 'genomicschain_core/proof_lookup'
require_relative 'genomicschain_core/config'
require_relative 'genomicschain_core/b1_manifest_hash'
require_relative 'genomicschain_core/report_content_hash'
require_relative 'genomicschain_core/verdict_spec/tier3'
require_relative 'genomicschain_core/verdict_spec/tier1'
require_relative 'genomicschain_core/verdict_spec/tier2'
require_relative 'genomicschain_core/submit_core'
require_relative 'genomicschain_core/tier3_submit'
require_relative 'genomicschain_core/tier1_submit'
require_relative 'genomicschain_core/tier2_submit'
require_relative 'genomicschain_core/attestation/synoptis_attestor'
require_relative 'genomicschain_core/anchor_profile_registration'
