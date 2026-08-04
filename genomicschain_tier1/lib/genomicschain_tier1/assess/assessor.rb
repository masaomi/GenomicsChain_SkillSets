# frozen_string_literal: true

require 'json'
require 'time'

module KairosMcp
  module SkillSets
    module GenomicschainTier1
      module Assess
        # gc_tier1_assess orchestration (spec v0.2 §2).
        #
        #   phase 1 PreCommit  -> rubric_hash, assessed_at, b1_manifest_hash
        #   phase 2 LLM        -> steps, gaps, liveness, capture_claim, ...
        #   phase 3 Derivation -> guards, counts, headline, levers, stage2_candidate
        #   phase 4 Validator  -> schema, b1 recompute, 2 MiB ceiling
        #
        # The LLM is injected as a callable so this class stays testable without a
        # provider, and so the tool skin can route the call through the ToolRegistry
        # (preserving the gate pipeline) rather than reaching into another SkillSet's
        # files by relative path.
        class Assessor
          STAGE1 = PreCommit::STAGE1
          STAGE2 = PreCommit::STAGE2
          CODE_SOURCE_KINDS = %w[repo_file repo_tree].freeze
          SOURCE_KINDS = (%w[paper_text paper_pdf_text landing_page] + CODE_SOURCE_KINDS).freeze
          CANONICAL_ID_KINDS = %w[doi pmid pdf_sha256 repo_url].freeze

          # Tool-derived keys. If the assessor emits any of them they are dropped and
          # reported, never merged — the LLM must not be able to promote its own stage
          # or restate its own arithmetic.
          RESERVED = %w[
            counts headline levers stage2_candidate rubric_hash rubric_version
            metric_semantics_version manifest human_signoff assessor_stack funnel_stage
            report_content_hash assessed_at assessor_id canonical_id
          ].freeze

          class AssessError < StandardError; end

          def initialize(llm:, rubric_path: PreCommit::RUBRIC_PATH)
            @llm = llm
            @rubric_path = rubric_path
          end

          def run(args)
            input = normalise_input(args)
            gate!(input)

            pre = PreCommit.build(
              canonical_id: input['canonical_id'], assessor_id: input['assessor_id'],
              funnel_stage: input['funnel_stage'], assessed_at: input['assessed_at'],
              rubric_path: @rubric_path
            )
            return dry_run(input, pre) if input['dry_run']

            llm_fields, invoked_at, model, provider = score(input)
            overreach = llm_fields.keys & RESERVED
            llm_fields = llm_fields.reject { |k, _| RESERVED.include?(k) }

            derived = Derivation.apply(
              llm: llm_fields, funnel_stage: input['funnel_stage'],
              lock_cited_in_sources: lock_cited?(input, llm_fields)
            )

            report = build_report(input, pre, llm_fields, derived,
                                  provider: provider, model: model, invoked_at: invoked_at)
            report_json = JSON.pretty_generate(report)
            outcome = Validator.validate!(report_json, report)

            render(input, pre, report, report_json, derived, outcome, overreach)
          end

          private

          def normalise_input(args)
            input = args.transform_keys(&:to_s)
            input['sources'] = Array(input['sources']).map { |s| s.transform_keys(&:to_s) }
            input['canonical_id'] = (input['canonical_id'] || {}).transform_keys(&:to_s)
            input['llm'] = (input['llm'] || {}).transform_keys(&:to_s)
            input
          end

          # Spec §4. Every check here runs before the LLM call, and each one refuses
          # rather than degrading — a partial report is worse than no report, because
          # downstream it is indistinguishable from a complete one.
          def gate!(input)
            stage = input['funnel_stage'].to_s
            unless PreCommit::STAGES.include?(stage)
              raise AssessError, "funnel_stage must be one of #{PreCommit::STAGES.join(', ')}"
            end

            value = input.dig('canonical_id', 'value')
            raise AssessError, 'canonical_id.value is required' if value.to_s.strip.empty?

            kind = input.dig('canonical_id', 'kind').to_s
            unless CANONICAL_ID_KINDS.include?(kind)
              raise AssessError, "canonical_id.kind must be one of #{CANONICAL_ID_KINDS.join(', ')}"
            end

            raise AssessError, 'assessor_id is required' if input['assessor_id'].to_s.strip.empty?
            raise AssessError, 'operator_id is required' if input['operator_id'].to_s.strip.empty?

            sources = input['sources']
            raise AssessError, 'at least one source is required' if sources.empty?

            sources.each_with_index do |src, i|
              unless SOURCE_KINDS.include?(src['kind'].to_s)
                raise AssessError, "sources[#{i}].kind must be one of #{SOURCE_KINDS.join(', ')}"
              end
              if src['content'].to_s.empty? && src['sha256'].to_s.empty?
                raise AssessError, "sources[#{i}] has neither content nor sha256"
              end
            end

            return unless stage == STAGE2

            unless sources.any? { |s| CODE_SOURCE_KINDS.include?(s['kind'].to_s) }
              raise AssessError,
                    'stage2-code-verified requires at least one repo_file or repo_tree source ' \
                    '(rubric line 57: without the code check, A/B/C must not be assigned)'
            end

            prior = prior_report(input)
            raise AssessError, 'stage2-code-verified requires prior_report_json' if prior.nil?

            return if prior.dig('canonical_id', 'value').to_s == input.dig('canonical_id', 'value').to_s

            raise AssessError, 'prior_report_json is for a different canonical_id'
          end

          def prior_report(input)
            raw = input['prior_report_json']
            return nil if raw.nil? || raw.to_s.strip.empty?

            raw.is_a?(Hash) ? raw : JSON.parse(raw)
          rescue JSON::ParserError => e
            raise AssessError, "prior_report_json is not valid JSON: #{e.message}"
          end

          def score(input)
            stage = input['funnel_stage']
            invoked_at = Time.now.utc.iso8601
            response = @llm.call(
              'system' => Prompts.system_for(stage),
              'messages' => [{ 'role' => 'user',
                               'content' => Prompts.user_for(sources: input['sources'],
                                                             prior_report: prior_report(input)) }],
              'output_schema' => Prompts.output_schema(stage),
              'temperature' => 0,
              'model' => input.dig('llm', 'model'),
              'max_tokens' => input.dig('llm', 'max_tokens'),
              'provider_override' => input.dig('llm', 'provider')
            )
            fields = extract_fields(response)
            [fields, invoked_at, response['model'] || input.dig('llm', 'model') || 'unknown',
             response['provider'] || input.dig('llm', 'provider') || 'unknown']
          end

          def extract_fields(response)
            raise AssessError, "LLM call failed: #{response['error'] || 'no response'}" if response['status'] == 'error'

            body = response['fields'] || response['parsed'] || response['text'] || response['response']
            body = body['text'] if body.is_a?(Hash) && body.key?('text')
            return body.transform_keys(&:to_s) if body.is_a?(Hash)

            JSON.parse(body.to_s).transform_keys(&:to_s)
          rescue JSON::ParserError => e
            raise AssessError, "assessor returned non-conforming JSON: #{e.message}"
          end

          # A lock claim is only credited when its citation names a source the caller
          # actually supplied — otherwise the assessor is vouching for a file nobody
          # gave it.
          def lock_cited?(input, llm_fields)
            cite = llm_fields.dig('lever_evidence', 'lock_cite').to_s
            return false if cite.empty?

            input['sources'].any? do |src|
              next false unless CODE_SOURCE_KINDS.include?(src['kind'].to_s)

              ref = src['ref'].to_s
              !ref.empty? && (cite.include?(ref) || ref.include?(cite))
            end
          end

          def build_report(input, pre, llm, derived, provider:, model:, invoked_at:)
            {
              'rubric_version' => '0.2.5',
              'metric_semantics_version' => '0.2.5',
              'rubric_hash' => pre['rubric_hash'],
              'canonical_id' => {
                'value' => input.dig('canonical_id', 'value'),
                'kind' => input.dig('canonical_id', 'kind'),
                'aliases' => Array(input.dig('canonical_id', 'aliases'))
              },
              'paper_type' => input['paper_type'] || llm['paper_type'],
              'reproduction_target' => llm['reproduction_target'],
              'step_source' => input['step_source'] || llm['step_source'],
              'granularity_note' => llm['granularity_note'],
              'assessor_id' => input['assessor_id'],
              'assessed_at' => pre['assessed_at'],
              'funnel_stage' => pre['funnel_stage'],
              'stage2_candidate' => derived.stage2_candidate,
              'capture_claim' => derived.capture_claim,
              'steps' => derived.steps,
              'counts' => derived.counts,
              'headline' => derived.headline,
              'levers' => derived.levers,
              'gaps' => Array(llm['gaps']),
              'liveness' => Array(llm['liveness']),
              'assessable' => llm['assessable'] || { 'is_assessable' => true },
              'contested_corrected' => Array(llm['contested_corrected']),
              # This tool cannot sign. R5 (human sign-off before any attestation or
              # per-paper publication) is enforced by construction, not by policy.
              'human_signoff' => { 'signed' => false, 'reviewer_id' => 'PENDING (unsigned draft)' },
              'assessor_stack' => {
                'operator_id' => input['operator_id'],
                'stage' => pre['funnel_stage'],
                'llm' => { 'provider' => provider, 'model' => model, 'invoked_at' => invoked_at }
              },
              'manifest' => {
                'b1_manifest_hash' => pre['b1_manifest_hash'],
                'chain_record' => 'not-yet-recorded',
                # Stage 2 supersedes the stage-1 report it revises.
                'supersedes' => prior_report(input)&.dig('manifest', 'b1_manifest_hash')
              }
              # report_content_hash is deliberately absent: the schema says omit until
              # submit, and gc_tier1_submit recomputes it server-side.
            }.compact
          end

          def dry_run(input, pre)
            {
              'status' => 'dry_run',
              'gates' => 'ok',
              'would_commit' => pre,
              'sources' => input['sources'].map { |s| { 'kind' => s['kind'], 'ref' => s['ref'] } },
              'schema_validator' => Validator.validate({}).backend,
              'note' => 'No LLM call, no report. b1_manifest_hash above is what phase 1 would commit.'
            }
          end

          def render(input, pre, report, report_json, derived, outcome, overreach)
            {
              'status' => 'assessed',
              'report_json' => report_json,
              'report' => report,
              'derived' => {
                'counts' => derived.counts, 'headline' => derived.headline, 'levers' => derived.levers,
                'capture_claim' => derived.capture_claim, 'stage2_candidate' => derived.stage2_candidate
              },
              'guards' => {
                'schema' => 'ok',
                'schema_validator' => outcome.backend,
                'b1_manifest_hash' => 'ok',
                'rubric_hash_matches_corpus' => pre['rubric_hash_matches_corpus'],
                'report_json_bytes' => report_json.bytesize,
                'stage_demotions' => derived.demotions,
                'llm_overreach' => overreach
              },
              'assessor_stack' => report['assessor_stack'],
              'human_signoff_required' => true,
              'next_step' => 'Human review and sign-off (rubric R5 / collection protocol §10), ' \
                             'then gc_tier1_submit on the anchor.'
            }.tap { |out| out['input_echo'] = { 'funnel_stage' => input['funnel_stage'] } }
          end
        end
      end
    end
  end
end
