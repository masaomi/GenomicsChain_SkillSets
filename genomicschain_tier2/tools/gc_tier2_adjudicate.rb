# frozen_string_literal: true

require 'json'
require 'genomicschain_tier2'

module KairosMcp
  module SkillSets
    module GenomicschainTier2
      module Tools
        # gc_tier2_adjudicate — a Tier-1 report read against the code it describes.
        #
        # The second half of the code-reading tier. `gc_tier2_scan` says what the
        # repository declares; this says what that means for a report written
        # from the paper's prose.
        #
        # The rubric already asked for this and named the gate: `env_capture_class`
        # is "a Stage-2 code-verified classification", and Stage-1 is instructed
        # not to assign it — "leave `n/a` and set `funnel_stage: stage1-prose-only`;
        # R★ requires Stage-2 verification". A Stage-1 report holding R★ steps is
        # therefore not wrong, it is *unverified*, and this tool is what verifies it.
        #
        # No LLM. The judgement lives in one versioned mapping table
        # (Adjudicator::CAPS and #classify); applying it is deterministic, so the
        # assessed party can re-run it and argue with the rule instead of with a
        # verdict they cannot inspect. That property is the reason to spend the
        # effort making this half deterministic rather than asking a model.
        #
        # It PROPOSES and signs nothing. The rubric's human sign-off gate is
        # mandatory, and the step linkage here is a name match — the place where
        # a human is most needed.
        class GcTier2Adjudicate < KairosMcp::Tools::BaseTool
          def name
            'gc_tier2_adjudicate'
          end

          def description
            'Read a Tier-1 report against a gc_tier2_scan result: assign each external reference ' \
              'resource an env_capture_class (A verified-in-code / B pin-prose-only / C mutable-latest), ' \
              'propose the per-step verdict caps the rubric attaches to B and C, recompute the two ' \
              'paper-level levers from the code, and report where the report and the code disagree. ' \
              'Deterministic and LLM-free; proposes only. Hand the output verbatim to gc_tier2_submit ' \
              '(anchor) to sign and record it as a Synoptis proof.'
          end

          def category
            :analysis
          end

          def usecase_tags
            %w[reproducibility tier1 codescan adjudication env-capture-class levers stage2]
          end

          def related_tools
            %w[gc_tier2_scan gc_tier1_assess gc_tier2_submit]
          end

          def harness_requirement
            { tier: :self_contained, requires_externals: [],
              reason: 'pure comparison of two JSON documents; no network, no model call' }
          end

          def input_schema
            {
              type: 'object',
              properties: {
                tier1_report: {
                  type: %w[string object],
                  description: 'The Tier-1 report: a path to report.json, a JSON string, or the object.'
                },
                codescan_report: {
                  type: %w[string object],
                  description: 'A gc_tier2_scan result. Must have been produced with ' \
                               'include_declarations=true — the declarations are the evidence every ' \
                               'disposition cites.'
                },
                path: {
                  type: 'string',
                  description: 'Alternative to codescan_report: a repository directory to scan first. ' \
                               'Convenience only; the two-call form is preferred because it keeps the ' \
                               'scan result available as the evidence a disposition points at.'
                }
              },
              required: %w[tier1_report]
            }
          end

          def call(arguments)
            args = arguments.transform_keys(&:to_s)
            t1 = load_json(args['tier1_report'])
            return text_content('Error: tier1_report could not be read as JSON') unless t1.is_a?(Hash)

            scan = resolve_scan(args)
            return text_content(scan[:error]) if scan.is_a?(Hash) && scan[:error]

            report = ::GenomicsChainTier2::Adjudicator.new(t1, scan).adjudicate
            text_content(JSON.pretty_generate(report))
          rescue StandardError => e
            text_content("Error: gc_tier2_adjudicate failed — #{e.class}: #{e.message}")
          end

          private

          def resolve_scan(args)
            if args['codescan_report']
              scan = load_json(args['codescan_report'])
              return { error: 'Error: codescan_report could not be read as JSON' } unless scan.is_a?(Hash)
              unless scan['declarations']
                return { error: 'Error: codescan_report has no declarations. Re-run gc_tier2_scan with ' \
                                'include_declarations=true — a disposition without its evidence is the ' \
                                'defect this tier exists to prevent.' }
              end

              symbolize(scan)
            elsif args['path']
              return { error: "Error: not a directory: #{args['path']}" } unless File.directory?(args['path'].to_s)

              ::GenomicsChainTier2::Scanner.new(args['path']).scan
            else
              { error: 'Error: one of codescan_report or path is required' }
            end
          end

          def load_json(value)
            return value if value.is_a?(Hash)

            s = value.to_s
            return JSON.parse(File.read(s)) if !s.strip.start_with?('{') && File.file?(s)

            JSON.parse(s)
          rescue JSON::ParserError, Errno::ENOENT, Errno::ENAMETOOLONG
            nil
          end

          # A scan round-tripped through JSON comes back with string keys, while
          # the Scanner emits symbol-keyed declarations. Normalise the inner
          # records so a report read from a file behaves the same as one held in
          # memory.
          def symbolize(scan)
            %w[declarations prose_locators rules].each do |k|
              next unless scan[k].is_a?(Array)

              scan[k] = scan[k].map { |h| h.is_a?(Hash) ? h.transform_keys(&:to_sym) : h }
            end
            scan
          end
        end
      end
    end
  end
end
