# frozen_string_literal: true

# §3.2 anchor-profile tool registration (design v0.4.1 Step 5 / P1 C4).
#
# Submit tools are listed in skillset.json under anchor_profile_tool_classes,
# not tool_classes. They register only when genomicschain.anchor_profile is true.
module KairosMcp
  module SkillSets
    module GenomicschainCore
      module AnchorProfileRegistration
        SKILLSET_NAME = 'genomicschain_core'

        module_function

        def install!
          return if defined?(@@installed) && @@installed

          unless defined?(KairosMcp::Skillset)
            begin
              require 'kairos_mcp/skillset'
            rescue LoadError
              return
            end
          end

          KairosMcp::Skillset.class_eval do
            unless method_defined?(:tool_class_names_without_gc_anchor)
              alias_method :tool_class_names_without_gc_anchor, :tool_class_names

              define_method(:tool_class_names) do
                AnchorProfileRegistration.install!
                return tool_class_names_without_gc_anchor unless name == AnchorProfileRegistration::SKILLSET_NAME

                anchor_tools = @metadata['anchor_profile_tool_classes'] || []
                if KairosMcp::SkillSets::GenomicschainCore::Config.anchor_profile?
                  (tool_class_names_without_gc_anchor + anchor_tools).uniq
                else
                  tool_class_names_without_gc_anchor - anchor_tools
                end
              end
            end
          end
          @@installed = true
        end

        def installed?
          defined?(@@installed) && @@installed
        end
      end
    end
  end
end

KairosMcp::SkillSets::GenomicschainCore::AnchorProfileRegistration.install!
