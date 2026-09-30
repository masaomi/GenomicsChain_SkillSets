# frozen_string_literal: true

require 'json'
require 'genomicschain_tier1'

module KairosMcp
  module SkillSets
    module GenomicschainTier1
      module Tools
        # gc_tier1_assess — thin MCP skin over Assess::Assessor (spec v0.2).
        #
        # Produces a schema-valid Tier-1 report.json for one paper at a declared
        # funnel stage. It does NOT fetch, sign, record or attest:
        #
        #   - retrieval  the caller supplies resolved `sources` (DOI -> bioRxiv and
        #                PDF -> text live on the genomicschain.ch side)
        #   - signing    human_signoff.signed is always false; R5 requires a human
        #   - recording  gc_tier1_submit's job, on the anchor only
        class GcTier1Assess < KairosMcp::Tools::BaseTool
          def name
            'gc_tier1_assess'
          end

          def description
            'Assess one paper for Tier-1 computational-reproducibility READINESS and return a ' \
              'schema-valid report.json (v0.2.6) plus the derived counts, headline and levers. ' \
              'Stage 1 is prose-only and cannot reach R-star; stage 2 requires repo sources and a ' \
              'prior stage-1 report. Returns an UNSIGNED draft — human sign-off is required before ' \
              'gc_tier1_submit. Does not fetch, sign or record anything.'
          end

          def category
            :utility
          end

          def usecase_tags
            %w[tier1 reproducibility readiness assessment rubric stage1 stage2 report]
          end

          def related_tools
            %w[gc_tier1_submit llm_call knowledge_get]
          end

          # One LLM call per assessment, minutes long. No subprocess, no external
          # binary — the provider call goes through llm_call.
          def harness_requirement
            { tier: :core,
              reason: 'single LLM call via the llm_call tool; no subprocess, no network fetch of its own' }
          end

          def input_schema
            {
              type: 'object',
              properties: {
                canonical_id: {
                  type: 'object',
                  description: 'Paper identity. kind precedence: doi > pmid > pdf_sha256 > repo_url > text_sha256. ' \
                               'text_sha256 (a paper with no DOI) must be the sha256 of supplied paper_text content. ' \
                               '{value, kind, aliases}.'
                },
                sources: {
                  type: 'array',
                  description: 'Resolved evidence, at least one. Each {kind, ref, content?, sha256?}. ' \
                               'kind = paper_text | paper_pdf_text | landing_page | repo_file | repo_tree. ' \
                               'Only repo_file / repo_tree count as code evidence.',
                  items: { type: 'object' }
                },
                funnel_stage: {
                  type: 'string', enum: %w[stage1-prose-only stage2-code-verified],
                  description: 'stage1 is prose triage (no R-star possible). stage2 requires code sources ' \
                               'and prior_report_json.'
                },
                prior_report_json: {
                  type: 'string',
                  description: 'The stage-1 report this assessment revises. REQUIRED for stage2 — its ' \
                               'b1_manifest_hash becomes manifest.supersedes.'
                },
                assessor_id: { type: 'string', description: 'Free-text assessor identity; part of the b1 pre-commit.' },
                operator_id: { type: 'string', description: 'Human operator; becomes assessor_stack.operator_id.' },
                assessed_at: { type: 'string', description: 'YYYY-MM-DD. Defaults to today (UTC). Part of the b1 pre-commit.' },
                paper_type: {
                  type: 'string',
                  enum: %w[pure-computational mixed pure-wet-lab tool-methods hybrid],
                  description: 'Optional. Omitted means the assessor routes it (rubric Step 0).'
                },
                step_source: {
                  type: 'string',
                  enum: %w[snakefile cwl nextflow wdl makefile prose-methods shared-canonical],
                  description: 'Optional. Omitted means the assessor derives it (rubric Step 1).'
                },
                shared_step_list: {
                  type: 'array',
                  description: 'Optional canonical step list for inter-rater work. Passed through, not computed on.',
                  items: { type: 'object' }
                },
                llm: {
                  type: 'object',
                  description: 'Optional {provider, model, max_tokens}. Defaults to llm_client config.'
                },
                dry_run: {
                  type: 'boolean',
                  description: 'Run the gates and the b1 pre-commit only. No LLM call, no report.'
                }
              },
              required: %w[canonical_id sources funnel_stage assessor_id operator_id]
            }
          end

          def call(arguments)
            args = arguments.transform_keys(&:to_s)
            assessor = Assess::Assessor.new(llm: method(:call_llm))
            text_content(JSON.pretty_generate(assessor.run(args)))
          rescue Assess::Assessor::AssessError,
                 Assess::PreCommit::PreCommitError,
                 Assess::Derivation::DerivationError,
                 Assess::Validator::ValidationError,
                 GenomicschainCore::SubmitCore::DigestMismatch,
                 ArgumentError => e
            text_content("Error: #{e.class.name.split('::').last}: #{e.message}")
          rescue StandardError => e
            text_content("Error: gc_tier1_assess failed - #{e.class}: #{e.message}")
          end

          private

          # Routed through the ToolRegistry rather than by requiring llm_client's
          # files directly: that keeps the gate pipeline and invocation policy in
          # force, and avoids coupling this package to another SkillSet's layout.
          def call_llm(payload)
            raise Assess::Assessor::AssessError, 'gc_tier1_assess needs a ToolRegistry to reach llm_call' unless @registry

            result = invoke_tool('llm_call', payload.compact)
            parse_llm_result(result)
          end

          def parse_llm_result(result)
            text = result.is_a?(Array) ? result.first[:text] || result.first['text'] : result.to_s
            JSON.parse(text)
          rescue JSON::ParserError, NoMethodError
            { 'status' => 'error', 'error' => "llm_call returned an unreadable payload: #{result.inspect[0, 200]}" }
          end
        end
      end
    end
  end
end
