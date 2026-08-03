# frozen_string_literal: true

require 'fileutils'

SYNOPTIS_LIB = File.expand_path('../../synoptis/lib', __dir__)
$LOAD_PATH.unshift(SYNOPTIS_LIB) if File.directory?(SYNOPTIS_LIB)
require 'synoptis/proof_envelope'
require 'synoptis/verifier'
require 'synoptis/attestation_engine'
require 'synoptis/registry/file_registry'

GC_LIB = File.expand_path('../lib', __dir__)
$LOAD_PATH.unshift(GC_LIB)

GC_MONO_LIB = File.expand_path('../../genomicschain/lib', __dir__)
# Do not load monolith manifest — genomicschain_core owns Manifest for Step 1 tests.

module ProofsSandbox
  def self.context(dir)
    FileUtils.mkdir_p(dir)
    registry = ::Synoptis::Registry::FileRegistry.new(data_dir: dir)
    tip_source = KairosMcp::SkillSets::GenomicschainCore::TipSource.new(registry: registry)
    engine = ::Synoptis::AttestationEngine.new(registry: registry, config: { 'default_ttl' => 86_400 })
    [registry, tip_source, engine]
  end
end
