# frozen_string_literal: true

# genomicschain_tier2 — the code-reading tier, static half.
#
# Tier-1 reads the paper, Tier-2 reads the code, Tier-3 executes: one numbering
# everywhere since 2026-09-09, in package, tool, schema and claim names alike.
# Before that this package was genomicschain_codescan and the execute package
# carried the number 2. `trust_tier` on a record is a guarantee level, not a
# tier index.
require 'set'
require_relative 'genomicschain_tier2/pin_strength'
require_relative 'genomicschain_tier2/parsers'
require_relative 'genomicschain_tier2/scanner'
require_relative 'genomicschain_tier2/adjudicator'

module GenomicsChainTier2
  VERSION = '0.4.0'
  RUBRIC_VERSION = 'codescan-static-0.1.0'
end
