# frozen_string_literal: true

# Pre-scoring provenance digest for Tier-1 reports (Step 3 corpus convention).
# Stage-2 appends literal "stage2" as a fifth pipe field (design / assessor prompts).
require 'digest'

module KairosMcp
  module SkillSets
    module GenomicschainCore
      module B1ManifestHash
        DELIMITER = '|'
        STAGE2_TOKEN = 'stage2'
        STAGE2_STAGES = %w[stage2-code-verified].freeze

        module_function

        def stage2?(report)
          STAGE2_STAGES.include?(report['funnel_stage'].to_s) ||
            STAGE2_STAGES.include?(report.dig('assessor_stack', 'stage').to_s)
        end

        def precommit_string(report)
          parts = [
            report.dig('canonical_id', 'value'),
            report['rubric_hash'],
            report['assessor_id'],
            report['assessed_at']
          ]
          parts << STAGE2_TOKEN if stage2?(report)
          parts.join(DELIMITER)
        end

        def compute(report)
          Digest::SHA256.hexdigest(precommit_string(report))
        end

        def stored(report)
          report.dig('manifest', 'b1_manifest_hash')
        end

        def matches?(report)
          stored(report) == compute(report)
        end

        def assert_matches!(report)
          %w[assessor_id assessed_at].each do |k|
            if report[k].nil? || report[k].to_s.empty?
              raise SubmitCore::DigestMismatch, "b1_manifest_hash requires non-empty #{k}"
            end
          end
          return if matches?(report)

          raise SubmitCore::DigestMismatch,
                "b1_manifest_hash mismatch: stored #{stored(report).inspect}, " \
                "recomputed #{compute(report).inspect}"
        end
      end
    end
  end
end
