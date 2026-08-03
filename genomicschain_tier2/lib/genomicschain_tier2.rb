# frozen_string_literal: true

# genomicschain_tier2 — Tier-2 execute-only package (design v0.4.1 Step 2).
# Manifest / Signer live in genomicschain_core.
require 'genomicschain_core'
require_relative 'genomicschain_tier2/execution/backend'
require_relative 'genomicschain_tier2/execution/local_backend'
require_relative 'genomicschain_tier2/execution/thoa_backend'
require_relative 'genomicschain_tier2/execution/comparator'
require_relative 'genomicschain_tier2/tier2_executor'
