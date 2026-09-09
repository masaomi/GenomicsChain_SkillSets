# frozen_string_literal: true

module KairosMcp
  module SkillSets
    module GenomicschainTier3
      module Execution
        # Comparator — answers ONLY the second verdict axis: did the result
        # match a declared target? Whether the job ran is the executor's
        # question and is reported separately (record 0.3).
        #
        # The common answer is `no_target_declared`. In the 2026-08-14 survey
        # of the five papers that passed the Tier-1 gate, none published a
        # checksum or nominated an artifact to compare against, so a comparator
        # usually has nothing to do. Under record 0.2 that outcome was reported
        # as `executed_inconclusive_needs_tolerance`, which named a complete
        # result as an incomplete one; `no_target_declared` says what happened.
        #
        # Target semantics: expected_output.target selects WHAT the expected
        # sha256 refers to:
        #   - "file:<relative_path>" -> that single output file's sha256
        #   - anything else (default) -> the aggregate result_hash (sha256 over
        #     the sorted [{relative_path,sha256,size_bytes}] output tree).
        # A single-file paper checksum must NOT be compared against the aggregate.
        module Comparator
          Result = Struct.new(:match, :comparison_verdict, :first_divergence, :compared_mode,
                              :comparator_id, :comparator_version, keyword_init: true)

          # No target was declared. Not a failure and not an inconclusive
          # comparison — there was nothing to compare against.
          def self.no_target
            Result.new(
              match: nil,
              comparison_verdict: 'no_target_declared',
              first_divergence: nil,
              compared_mode: nil,
              comparator_id: nil,
              comparator_version: nil
            )
          end

          # Execution never reached the comparison step.
          def self.not_attempted
            Result.new(
              match: nil,
              comparison_verdict: 'not_attempted',
              first_divergence: nil,
              compared_mode: nil,
              comparator_id: nil,
              comparator_version: nil
            )
          end

          def self.target?(expected_output)
            eo = expected_output || {}
            sha = eo['sha256'] || eo[:sha256]
            !sha.nil? && !sha.to_s.empty?
          end

          module ExactSha256
            ID = 'exact_sha256'
            VERSION = '0.2.0'

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
                comparison_verdict: match ? 'match_exact' : 'mismatch',
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

          # Run-to-run agreement — what run_count > 1 buys. Deliberately a
          # separate entry point from the target comparison above: they answer
          # different questions and may legitimately use different comparators.
          #
          # KNOWN LIMITATION, measured 2026-08-14: exact_sha256 reports
          # disagreement for pipelines whose outputs are byte-identical inside
          # an archive container whose header carries a timestamp. Running
          # fastqc twice on one host produced 24/24 identical extracted files
          # and two different .zip digests. That verdict is not wrong — the
          # bytes did differ — but a `normalized_tree` comparator that unpacks
          # containers before hashing is the follow-up this measurement asks
          # for, and it is NOT implemented yet. Read `all_identical: false`
          # together with first_divergence before concluding a pipeline is
          # nondeterministic.
          def self.agreement(run_result_hashes:, comparator_id: ExactSha256::ID, variation: 'same_environment')
            hashes = Array(run_result_hashes).map(&:to_s)
            raise ArgumentError, 'agreement needs at least 2 runs' if hashes.length < 2

            first = hashes.first
            diverged_at = hashes.index { |h| h != first }

            out = {
              'runs' => hashes.length,
              'all_identical' => diverged_at.nil?,
              'comparator_id' => comparator_id,
              'run_result_hashes' => hashes,
              'variation' => variation
            }
            unless diverged_at.nil?
              out['first_divergence'] = {
                'kind' => 'run_to_run_mismatch',
                'run_index' => diverged_at,
                'first_run_hash' => first,
                'diverging_hash' => hashes[diverged_at]
              }
            end
            out
          end
        end
      end
    end
  end
end
