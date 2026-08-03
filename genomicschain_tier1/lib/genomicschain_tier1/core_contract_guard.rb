# frozen_string_literal: true

module KairosMcp
  module SkillSets
    module GenomicschainTier1
      # §6.1 tier-side guard — fail loud if core is missing or version-skewed.
      module CoreContractGuard
        REQUIRED_CORE = 'genomicschain_core'
        REQUIRED_VERSION = '>= 0.2.0'

        module_function

        def verify!
          unless defined?(KairosMcp::SkillSets::GenomicschainCore)
            raise LoadError, 'genomicschain_tier1 requires genomicschain_core to be loaded first'
          end
          unless KairosMcp::SkillSets::GenomicschainCore.const_defined?(:SubmitCore)
            raise LoadError, 'genomicschain_core contract incomplete (SubmitCore missing)'
          end
          true
        end
      end
    end
  end
end
