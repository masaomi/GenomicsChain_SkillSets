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
# The parts that do touch something are required where they are used:
# `Writer::Environment` / `Writer::NextflowRun` (the machine), `ZkVerifier`
# (runs the gc_zk_verify binary), `VerdictSpec::Prov` / `ProvSubmit` and
# `PlaceExtension` (the anchor, through core and Synoptis).
require_relative 'genomicschain_prov/normalized'
require_relative 'genomicschain_prov/adapters/bco'
require_relative 'genomicschain_prov/predicate'
require_relative 'genomicschain_prov/writer'
require_relative 'genomicschain_prov/identity'

module GenomicsChainProv
  VERSION = '0.2.0'

  # Part of the signed identity (`adapter_version`, design §6): the same bundle
  # under a different adapter version may normalise differently, so the record
  # names the adapter that produced the grade. The constant lives with the
  # adapter; this is its public name.
  ADAPTER_BCO_VERSION = Adapters::Bco::VERSION
  # The writer names itself in the bundles it produces, so this one reaches the
  # record too — as `producer_name` / `producer_version` (§6), the bundle's own
  # statement of what wrote it. `Writer::Environment` and
  # `Writer::NextflowRun` touch the machine and are required on demand, not
  # here: the anchor loads this file and has no business shelling out.
  WRITER_VERSION = Writer::VERSION
end
