# frozen_string_literal: true

require 'yaml'

module KairosMcp
  module SkillSets
    module GenomicschainCore
      # Reads genomicschain_core.yml for deployment profile flags.
      module Config
        class << self
          def load
            path = File.join(KairosMcp.skillsets_dir, 'genomicschain_core', 'config', 'genomicschain_core.yml')
            return {} unless File.exist?(path)

            YAML.safe_load(File.read(path)) || {}
          rescue StandardError
            {}
          end

          def anchor_profile?
            AnchorProfileRegistration.install!
            cfg = load
            !!(cfg.dig('genomicschain', 'anchor_profile') || cfg.dig(:genomicschain, :anchor_profile))
          end

          def max_evidence_size
            syn_path = File.join(KairosMcp.skillsets_dir, 'synoptis', 'config', 'synoptis.yml')
            return 65_536 unless File.exist?(syn_path)

            syn = YAML.safe_load(File.read(syn_path)) || {}
            att = syn['attestation'] || syn[:attestation] || {}
            (att['max_evidence_size'] || att[:max_evidence_size] || 65_536).to_i
          rescue StandardError
            65_536
          end
        end
      end
    end
  end
end
