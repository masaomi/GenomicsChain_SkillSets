# frozen_string_literal: true

# genomicschain_prov — service (2.5) provenance anchoring, the half that runs
# off the anchor (design v0.1, docs/design/prov_anchoring_design_v0_1.md).
#
# A customer's pipeline emits a provenance bundle (a BioCompute Object today,
# a Workflow Run RO-Crate in v0.2). This package reads the bundle into the
# seven conditions `warranty-scope` says get recorded — input data, code,
# libraries/tools, reference genome, parameters, random seed, runtime version
# — and grades how far a third party holding only the bundle could rebuild
# from it. The bundle itself is the digest subject and never leaves the
# customer; what the anchor records is identities and counts (§6).
#
# Reads only. No network, no subprocess, no file resolution: a locator is a
# string here, and whether it still resolves is `not_checked` on the record.
require_relative 'genomicschain_prov/normalized'
require_relative 'genomicschain_prov/adapters/bco'
require_relative 'genomicschain_prov/predicate'

module GenomicsChainProv
  VERSION = '0.1.0'

  # Part of the signed identity (`adapter_version`, design §6): the same bundle
  # under a different adapter version may normalise differently, so the record
  # names the adapter that produced the grade.
  ADAPTER_BCO_VERSION = 'prov-adapter-bco-0.2.0'
end
