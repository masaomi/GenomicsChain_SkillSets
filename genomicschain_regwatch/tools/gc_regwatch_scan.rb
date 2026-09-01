# frozen_string_literal: true

require 'json'
require 'genomicschain_regwatch'

module KairosMcp
  module SkillSets
    module GenomicschainRegwatch
      module Tools
        # gc_regwatch_scan — has anything moved, and what is coming due.
        #
        # Two mechanisms, kept apart because the things they watch behave
        # differently. A dated obligation (IVDR class C, 2026-09-26) needs a
        # countdown. An undated one — EU GMP Annex 22 has no finalisation date
        # at all — can only be caught by watching the bytes. Merging them into
        # one "check" loses whichever is not the one you designed for.
        #
        # Scanning has no side effect. Recording the baseline is a separate
        # switch, because a check that rewrites its own reference point on
        # every run cannot be re-run.
        class GcRegwatchScan < KairosMcp::Tools::BaseTool
          def name
            'gc_regwatch_scan'
          end

          def description
            'Fetch every source on the regulatory watchlist, compare a normalised content digest against ' \
              'the recorded baseline, and count down the dated triggers. Reports changed / unchanged / ' \
              'unreachable / new per source and stops: whether a change is material is a judgement, and ' \
              'this tool does not make it. An unreachable source is never folded into "unchanged".'
          end

          def category
            :analysis
          end

          def usecase_tags
            %w[regulatory watch monitoring drift deadline compliance standards genomicschain kairoschain]
          end

          def related_tools
            %w[gc_regwatch_report context_save chain_record]
          end

          def harness_requirement
            { tier: :harness_assisted, requires_externals: %w[network],
              reason: 'fetches public regulator and standards-body pages over HTTPS; no subprocess, no auth' }
          end

          def input_schema
            {
              type: 'object',
              properties: {
                watchlist: {
                  type: 'string',
                  description: 'Path to the watchlist markdown. Defaults to the one shipped with this ' \
                               'package (knowledge/regwatch_watchlist.md).'
                },
                baseline: {
                  type: 'string',
                  description: 'Path to the baseline JSON holding the last recorded digests. Defaults to ' \
                               'state/regwatch_baseline.json beside the watchlist.'
                },
                only: {
                  type: 'array', items: { type: 'string' },
                  description: 'Limit the scan to these watchlist ids. A full sweep is slow and invites ' \
                               'rate limiting; most sessions only need the two or three items that were moving.'
                },
                horizon_days: {
                  type: 'integer',
                  description: 'How far ahead to list dated triggers (default 120). Items already overdue ' \
                               'are always listed, with a negative count.'
                },
                offline: {
                  type: 'boolean',
                  description: 'Skip all fetching and report only the deadline countdown (default false). ' \
                               'Digests are not compared, and the report says so.'
                },
                record: {
                  type: 'boolean',
                  description: 'After scanning, write the observed digests as the new baseline (default ' \
                               'false). Do this only once the changes have been read and ruled on — ' \
                               'recording before reading discards the finding.'
                }
              },
              required: []
            }
          end

          def call(arguments)
            args = arguments.transform_keys(&:to_s)

            wl_path = args['watchlist'] || default_watchlist
            base_path = args['baseline'] || default_baseline(wl_path)

            return text_content("Error: watchlist not found: #{wl_path}") unless File.file?(wl_path)

            watchlist = ::GenomicsChainRegwatch::Watchlist.load(wl_path)
            scanner = ::GenomicsChainRegwatch::Scanner.new(watchlist, baseline_path: base_path)

            result = scanner.scan(
              only: args['only'],
              horizon_days: (args['horizon_days'] || 120).to_i,
              offline: args['offline'] ? true : false
            )
            result['watchlist_path'] = wl_path

            if args['record'] && !args['offline']
              result['recorded'] = scanner.record(result)
            elsif args['record'] && args['offline']
              result['recorded'] = { 'skipped' => 'offline scan compares nothing; nothing to record' }
            end

            text_content(JSON.pretty_generate(result))
          rescue StandardError => e
            text_content("Error: gc_regwatch_scan failed — #{e.class}: #{e.message}")
          end

          private

          def package_root
            File.expand_path('..', __dir__)
          end

          def default_watchlist
            File.join(package_root, 'knowledge', 'regwatch_watchlist.md')
          end

          def default_baseline(wl_path)
            File.join(File.dirname(File.dirname(wl_path)), 'state', 'regwatch_baseline.json')
          end
        end
      end
    end
  end
end
