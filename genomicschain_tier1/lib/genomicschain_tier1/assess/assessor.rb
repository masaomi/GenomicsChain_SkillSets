# frozen_string_literal: true

require 'digest'
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
          # text_sha256 names a paper with no DOI by the sha256 of its text
          # (self-application design O-3); it must be the hash of supplied
          # paper_text content, so the name and the text read cannot come apart.
          CANONICAL_ID_KINDS = %w[doi pmid pdf_sha256 repo_url text_sha256].freeze

          # Tool-derived keys. If the assessor emits any of them they are dropped and
          # reported, never merged — the LLM must not be able to promote its own stage
          # or restate its own arithmetic.
          RESERVED = %w[
            counts headline levers stage2_candidate rubric_hash rubric_version
            metric_semantics_version manifest human_signoff assessor_stack funnel_stage
            report_content_hash assessed_at assessor_id canonical_id
          ].freeze

          # Effort is not sent: gc_tier1_assess passes none, and llm_client's
          # BedrockAdapter has no output_config (operator decision 2026-10-18 to
          # keep it so). The model's documented default therefore applies, and
          # the report says that it is a default, not a setting someone chose.
          # Defaults per Anthropic's model documentation as of 2026-10-06.
          DEFAULT_EFFORT = {
            'claude-sonnet-5-5' => 'high', 'claude-sonnet-5' => 'high',
            'claude-opus-5-5' => 'medium', 'claude-opus-5' => 'high',
            'claude-haiku-5-5' => 'medium'
          }.freeze
          # Only on a path verified to send no effort. Another provider (the
          # claude_code fallback on an AuthError, say) may apply its own, so the
          # report leaves effort out rather than guess it.
          EFFORT_UNSENT_PROVIDERS = %w[bedrock].freeze

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

            llm_fields, llm_stack = score(input)
            overreach = llm_fields.keys & RESERVED
            llm_fields = llm_fields.reject { |k, _| RESERVED.include?(k) }

            derived = Derivation.apply(
              llm: llm_fields, funnel_stage: input['funnel_stage'],
              lock_cited_in_sources: lock_cited?(input, llm_fields)
            )

            report = build_report(input, pre, llm_fields, derived, llm_stack: llm_stack)
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

            gate_text_sha256!(value.to_s, sources) if kind == 'text_sha256'

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

          # Only supplied content counts; a declared sha256 names no text read.
          def gate_text_sha256!(value, sources)
            unless value.match?(/\A[0-9a-f]{64}\z/)
              raise AssessError, 'canonical_id.value for kind text_sha256 must be 64 lowercase hex'
            end

            texts = sources.select { |s| s['kind'].to_s == 'paper_text' && !s['content'].to_s.empty? }
                           .map { |s| Digest::SHA256.hexdigest(s['content'].to_s) }
            return if texts.include?(value)

            raise AssessError, 'canonical_id.value for kind text_sha256 must equal the sha256 of supplied paper_text content'
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
              # No temperature: Claude Sonnet 5 rejects non-default temperature
              # with a 400, and the operator unified all GenomicsChain LLM calls
              # on Sonnet 5 (decision 2026-08-07). Scoring determinism via
              # temperature 0 is deliberately given up; provider default applies.
              'model' => input.dig('llm', 'model'),
              'max_tokens' => input.dig('llm', 'max_tokens'),
              'provider_override' => input.dig('llm', 'provider')
            )
            fields = extract_fields(response)
            provider = response['provider'] || input.dig('llm', 'provider') || 'unknown'
            model = response['model'] || input.dig('llm', 'model') || 'unknown'
            [fields, llm_stack(provider, model, response['requested_model'], invoked_at)]
          end

          # model is what the provider says answered; model_requested is the ID
          # llm_call was asked to use (a Bedrock inference profile such as
          # eu.anthropic.claude-sonnet-5-5, which names the region as well), and
          # is present only where llm_call reports it.
          def llm_stack(provider, model, model_requested, invoked_at)
            effort = (DEFAULT_EFFORT[model.to_s.sub(/\A(?:[a-z]+\.)?anthropic\./, '')] if
                      EFFORT_UNSENT_PROVIDERS.include?(provider))
            {
              'provider' => provider,
              'model' => model,
              'model_requested' => model_requested,
              'effort' => effort,
              'effort_source' => effort && 'model default; not sent in the request',
              'invoked_at' => invoked_at
            }.compact
          end

          # Providers disagree on where the text lives, and llm_client passes the
          # adapter's raw response through untouched: claude_code returns
          # {'content' => '<json>'}, the Anthropic API returns
          # {'content' => [{'type' => 'text', 'text' => '<json>'}]}, and a
          # provider honouring output_schema natively may return the object
          # already parsed. All four shapes have to land in the same place, and
          # a Hash that is merely the transport envelope must not be mistaken for
          # the assessor's fields.
          def extract_fields(response)
            raise AssessError, "LLM call failed: #{response['error'] || 'no response'}" if response['status'] == 'error'

            candidate = response['fields'] || response['parsed'] || response['response'] || response['text']
            fields = coerce_fields(candidate)
            raise AssessError, 'assessor returned no scorable fields' if fields.nil?

            fields
          end

          def coerce_fields(value)
            case value
            when Hash
              return value.transform_keys(&:to_s) if value.key?('steps') || value.key?(:steps)

              # Transport envelope: unwrap and try again.
              inner = value['content'] || value['text'] || value['result']
              inner.nil? ? nil : coerce_fields(inner)
            when Array
              # Anthropic-style content blocks.
              text = value.filter_map { |b| b.is_a?(Hash) ? (b['text'] || b[:text]) : b }.join
              text.empty? ? nil : coerce_fields(text)
            when String
              parse_json_object(value)
            end
          end

          # Models fence JSON even when told not to, and sometimes prepend a line
          # of prose. Take the outermost object rather than failing on the wrapper.
          def parse_json_object(text)
            stripped = text.strip.sub(/\A```(?:json)?\s*/m, '').sub(/```\s*\z/m, '').strip
            first = stripped.index('{')
            last = stripped.rindex('}')
            raise AssessError, 'assessor returned no JSON object' if first.nil? || last.nil? || last < first

            JSON.parse(stripped[first..last]).transform_keys(&:to_s)
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

          def build_report(input, pre, llm, derived, llm_stack:)
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
                # Read from this package's own skillset.json, so it names the
                # code that produced the report and not a caller's idea of it.
                'assessor_version' => "genomicschain_tier1 #{GenomicschainTier1::VERSION}",
                'llm' => llm_stack
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
