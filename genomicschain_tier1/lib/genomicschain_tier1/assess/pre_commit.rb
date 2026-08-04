# frozen_string_literal: true

require 'digest'
require 'time'

module KairosMcp
  module SkillSets
    module GenomicschainTier1
      module Assess
        # Phase 1 of gc_tier1_assess (spec v0.2 §2).
        #
        # Everything here is computed BEFORE the assessor LLM runs, and none of it
        # may come from the LLM:
        #
        #   rubric_hash       — the digest of the rubric file THIS process loaded.
        #                       A self-reported hash witnesses nothing.
        #   b1_manifest_hash  — a pre-commitment. If it were emitted alongside the
        #                       scores it would no longer precede them.
        #
        # The b1 string format is owned by GenomicschainCore::B1ManifestHash; this
        # module only fixes its inputs and then asks core to compute it, so the two
        # cannot drift apart.
        module PreCommit
          STAGE1 = 'stage1-prose-only'
          STAGE2 = 'stage2-code-verified'
          STAGES = [STAGE1, STAGE2].freeze

          # The rubric the assessor scores against. Hashed whole, frontmatter
          # included — that is what the 201-report corpus pinned.
          RUBRIC_PATH = File.expand_path('../../../knowledge/repro_tier1_guide.md', __dir__)

          # Corpus-pinned value; a mismatch means the rubric moved under us.
          KNOWN_RUBRIC_HASH = '4024d4d8817abb0feb76ca9e91effcb11fcea53b1caae2a2ee4efc985e4ca3b1'

          class PreCommitError < StandardError; end

          module_function

          def rubric_text(path = RUBRIC_PATH)
            raise PreCommitError, "rubric not found: #{path}" unless File.exist?(path)

            File.read(path)
          end

          def rubric_hash(path = RUBRIC_PATH)
            Digest::SHA256.hexdigest(rubric_text(path))
          end

          # @return [Hash] the fields the report inherits from phase 1
          def build(canonical_id:, assessor_id:, funnel_stage:, assessed_at: nil, rubric_path: RUBRIC_PATH)
            unless STAGES.include?(funnel_stage.to_s)
              raise PreCommitError, "funnel_stage must be one of #{STAGES.join(', ')} (got #{funnel_stage.inspect})"
            end

            value = canonical_id.is_a?(Hash) ? (canonical_id['value'] || canonical_id[:value]) : canonical_id
            raise PreCommitError, 'canonical_id.value is required' if value.nil? || value.to_s.strip.empty?
            raise PreCommitError, 'assessor_id is required' if assessor_id.nil? || assessor_id.to_s.strip.empty?

            at = resolve_assessed_at(assessed_at)
            hash = rubric_hash(rubric_path)

            # Build the exact subject core will re-derive at submit, then let core
            # compute the digest. Never reimplement the pipe format here.
            subject = {
              'canonical_id' => { 'value' => value.to_s },
              'rubric_hash' => hash,
              'assessor_id' => assessor_id.to_s,
              'assessed_at' => at,
              'funnel_stage' => funnel_stage.to_s
            }

            {
              'rubric_hash' => hash,
              'assessed_at' => at,
              'funnel_stage' => funnel_stage.to_s,
              'b1_manifest_hash' => GenomicschainCore::B1ManifestHash.compute(subject),
              'rubric_hash_matches_corpus' => hash == KNOWN_RUBRIC_HASH
            }
          end

          # Date, not datetime — that is what b1 hashes and what the corpus carries.
          def resolve_assessed_at(value)
            return Time.now.utc.strftime('%Y-%m-%d') if value.nil? || value.to_s.strip.empty?

            text = value.to_s.strip
            unless text.match?(/\A\d{4}-\d{2}-\d{2}\z/)
              raise PreCommitError, "assessed_at must be YYYY-MM-DD (got #{value.inspect})"
            end

            text
          end
        end
      end
    end
  end
end
