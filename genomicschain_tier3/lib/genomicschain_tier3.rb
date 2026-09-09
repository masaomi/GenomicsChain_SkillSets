# frozen_string_literal: true

# genomicschain_tier3 — Tier-3 execute-only package (design v0.4.1 Step 2).
# Manifest / Signer live in genomicschain_core.
require 'genomicschain_core'
require_relative 'genomicschain_tier3/execution/backend'
require_relative 'genomicschain_tier3/execution/local_backend'
require_relative 'genomicschain_tier3/execution/thoa_backend'
require_relative 'genomicschain_tier3/execution/comparator'
require_relative 'genomicschain_tier3/tier3_executor'
