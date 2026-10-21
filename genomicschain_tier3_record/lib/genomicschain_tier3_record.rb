# frozen_string_literal: true

# genomicschain_tier3_record — the record side of Tier 3 v0.1 (design
# docs/design/tier3_design_v0_1.md §3.2〔実装〕): the two record types, their
# SubmitCore specs, the anchor library and the wording reader. The anchor
# installs core + prov + this package and never genomicschain_tier3, so
# nothing here loads tier3 (operator 2026-10-21, question 5).
require 'genomicschain_core'
require 'genomicschain_prov'
require_relative 'genomicschain_tier3_record/records'
require_relative 'genomicschain_tier3_record/verdict_spec/declaration'
require_relative 'genomicschain_tier3_record/verdict_spec/attestation'
require_relative 'genomicschain_tier3_record/record_submit'
require_relative 'genomicschain_tier3_record/wording'
