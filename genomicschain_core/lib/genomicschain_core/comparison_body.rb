# frozen_string_literal: true

require 'digest'
require 'json'
require_relative 'manifest'

# ComparisonBody — what the self-application DDC compares between the
# checker we run (A) and the one rebuilt from source by someone else (T)
# (self-application design §6.4, INV-S10).
#
# Each kind names every top-level field of its record: a field is either
# compared or excluded, and a field in neither list stops extraction, so a
# field added later cannot slip into or out of the comparison unnoticed.
# Only fields that change for the same input are excluded — a time, an
# unsigned sign-off, a hash that covers a time, an absolute path, the
# platform string. Required fields are the verdicts the expectation table
# refers to; a record missing one, or holding null there, yields no body
# rather than an empty one, so two broken records cannot count as a match.
#
# The body is canonical JSON with recursively sorted keys (Manifest::
# CanonicalJson), and its sha256 is what the two sides compare.
module KairosMcp
  module SkillSets
    module GenomicschainCore
      module ComparisonBody
        VERSION = 'comparison-body-0.1.0'

        class Incomplete < StandardError; end

        SPECS = {
          # gc_tier1_assess's report (report_json), replayed from a recorded
          # LLM response with assessed_at fixed by the input.
          'tier1_report' => {
            compared: %w[rubric_version metric_semantics_version rubric_hash canonical_id paper_type
                         reproduction_target step_source granularity_note assessor_id assessed_at
                         funnel_stage stage2_candidate capture_claim steps counts headline levers gaps
                         liveness assessable contested_corrected assessor_stack manifest],
            excluded: [%w[human_signoff], %w[report_content_hash], %w[assessor_stack llm invoked_at]],
            required: [%w[headline], %w[counts], %w[steps], %w[gaps], %w[rubric_hash], %w[manifest b1_manifest_hash]]
          },
          # Scanner#scan.
          'tier2_scan' => {
            compared: %w[target counts_by_pin counts_by_kind counts_in_fixtures findings declarations
                         prose_locators rules],
            excluded: [%w[target root], %w[target toolchain ruby_platform]],
            required: [%w[target evidence_digest], %w[target toolchain ruby], %w[counts_by_pin], %w[declarations]]
          },
          # Adjudicator#adjudicate, fed the replayed Tier-1 report.
          'tier2_adjudication' => {
            compared: %w[adjudication_rubric_version rubric_source subject stage_transition resource_classes
                         step_dispositions levers discrepancies counts ambiguous_links limits],
            excluded: [%w[subject tier1_report_content_hash], %w[subject codescan_toolchain ruby_platform],
                       %w[subject adjudication_toolchain ruby_platform]],
            required: [%w[subject codescan_evidence_digest], %w[step_dispositions], %w[counts]]
          },
          # GenomicsChainProv::Predicate.grade of a frozen BCO.
          'tier25_grade' => {
            compared: %w[predicate_version pin_strength_version outputs_digest_rule grade_overall grades
                         coverage stages reference workflow_ref seed counts items],
            excluded: [],
            required: [%w[grade_overall], %w[grades], %w[counts]]
          },
          # Tier3Executor.compare_frozen.
          'tier3_compare' => {
            compared: %w[run_count result_hash output_files comparison_verdict comparator_id
                         comparator_version first_divergence self_consistency],
            excluded: [],
            required: [%w[run_count], %w[result_hash], %w[output_files], %w[comparison_verdict]]
          }
        }.freeze

        module_function

        # @return [Hash] the record with the excluded fields removed
        def extract(kind, record)
          spec = SPECS.fetch(kind) { raise ArgumentError, "unknown comparison-body kind: #{kind}" }
          raise Incomplete, "#{kind}: record is not an object" unless record.is_a?(Hash)

          top_excluded = spec[:excluded].select { |p| p.length == 1 }.map(&:first)
          unknown = record.keys.map(&:to_s) - spec[:compared] - top_excluded
          raise Incomplete, "#{kind}: field(s) in neither list: #{unknown.sort.join(', ')}" unless unknown.empty?

          missing = spec[:required].select { |path| record.dig(*path).nil? }
          raise Incomplete, "#{kind}: required field(s) missing or null: #{missing.map { |p| p.join('.') }.join(', ')}" unless missing.empty?

          body = JSON.parse(JSON.generate(record))
          spec[:excluded].each { |path| drop(body, path) }
          body
        end

        # @return [Hash] {'kind', 'body_version', 'sha256', 'canonical'}
        def digest(kind, record)
          body = extract(kind, record)
          canonical = KairosMcp::Manifest::CanonicalJson.serialize(body)
          { 'kind' => kind, 'body_version' => VERSION,
            'sha256' => Digest::SHA256.hexdigest(canonical), 'canonical' => canonical }
        end

        def drop(obj, path)
          *parents, leaf = path
          holder = parents.empty? ? obj : obj.dig(*parents)
          holder.delete(leaf) if holder.is_a?(Hash)
        end
      end
    end
  end
end
