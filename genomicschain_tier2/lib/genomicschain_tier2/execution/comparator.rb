# frozen_string_literal: true

module KairosMcp
  module SkillSets
    module GenomicschainTier2
      module Execution
        # Comparator (design v0.3 §4). Pluggable; first impl exact_sha256.
        #
        # For the C9 pilot exact_sha256 is a DIAGNOSTIC, not a verdict: genomics
        # output is rarely bit-identical, so a mismatch does NOT become a bare
        # `executed_mismatch` — it becomes `executed_inconclusive_needs_tolerance`
        # and captures a first-divergence record to drive the tolerance comparator.
        # Anti-downgrade rule (R2-9) applies once a stricter comparator ships.
        #
        # Target semantics (impl-review I7): expected_output.target selects WHAT the
        # expected sha256 refers to:
        #   - "file:<relative_path>"  -> compare that single output file's sha256
        #   - anything else (default) -> compare the aggregate result_hash (the sha256
        #     over the sorted [{relative_path,sha256,size_bytes}] output tree).
        # A single-file paper checksum must NOT be compared against the aggregate hash.
        module Comparator
          Result = Struct.new(:match, :verdict, :first_divergence, :compared_mode,
                              :comparator_id, :comparator_version, keyword_init: true)

          module ExactSha256
            ID = 'exact_sha256'
            VERSION = '0.1.0'

            def self.compare(result_hash:, output_files:, expected_output:)
              expected = expected_output['sha256'] || expected_output[:sha256]
              target = (expected_output['target'] || expected_output[:target]).to_s

              if target.start_with?('file:')
                rel = target.sub(/\Afile:/, '')
                file = (output_files || []).find { |f| (f['relative_path'] || f[:relative_path]) == rel }
                produced = file && (file['sha256'] || file[:sha256])
                mode = "file:#{rel}"
              else
                produced = result_hash
                mode = 'result_tree_sha256'
              end

              match = !expected.nil? && !produced.nil? && produced == expected
              Result.new(
                match: match,
                verdict: match ? 'executed_r' : 'executed_inconclusive_needs_tolerance',
                first_divergence: match ? nil : {
                  'kind' => 'sha256_mismatch',
                  'compared_mode' => mode,
                  'produced' => produced,
                  'expected_sha256' => expected
                },
                compared_mode: mode,
                comparator_id: ID,
                comparator_version: VERSION
              )
            end
          end

          REGISTRY = { ExactSha256::ID => ExactSha256 }.freeze

          def self.for(id)
            REGISTRY[id] or raise ArgumentError, "unknown comparator: #{id}"
          end
        end
      end
    end
  end
end
