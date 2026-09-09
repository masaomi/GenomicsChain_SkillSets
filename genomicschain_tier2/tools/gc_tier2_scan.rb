# frozen_string_literal: true

require 'json'
require 'genomicschain_tier2'

module KairosMcp
  module SkillSets
    module GenomicschainTier2
      module Tools
        # gc_tier2_scan — what a workflow repository declares, read without running it.
        #
        # This is the static half of the code-reading tier: the tier that sits
        # between reading the paper and executing the workflow. It exists
        # because depth of inspection changes the verdict — a pilot on aMeta
        # demoted 13 of 30 steps that the prose reading had accepted — and
        # because that pilot's own result cannot now be re-derived, since no
        # step index was ever recorded. Everything here is line-anchored for
        # that reason.
        #
        # No network, no subprocess, no evaluation. The tool takes a directory
        # that is already on disk; fetching is the operator's action, kept
        # outside so that a scan has no side effects and can be re-run by the
        # party being scanned. `snakemake --dry-run` and `nextflow -stub-run`
        # would answer more than parsing does, and both execute code out of the
        # repository under examination — which is the execution tier's cost and
        # trust profile, not this one's.
        #
        # What it does NOT do: compare its findings against what the paper
        # claimed. That needs the Tier-1 report as its other half and is a
        # separate layer, deliberately, because this half is deterministic and
        # that half is not. A finding here can be re-derived by its subject;
        # that is what makes it contestable rather than merely disputable.
        class GcTier2Scan < KairosMcp::Tools::BaseTool
          def name
            'gc_tier2_scan'
          end

          def description
            'Read a checked-out workflow repository and report every software, container and data ' \
              'resource it declares, each classified by how strongly it is pinned (immutable / versioned / ' \
              'ranged / floating / local_path / absent) and anchored to a file and line. Runs nothing, ' \
              'fetches nothing, and evaluates no workflow definition. Emits an evidence digest over the ' \
              'bytes it read so a re-scan can be shown to have seen the same repository.'
          end

          def category
            :analysis
          end

          def usecase_tags
            %w[reproducibility codescan static-analysis workflow snakemake nextflow conda pinning tier2]
          end

          def related_tools
            %w[gc_tier1_assess gc_tier3_execute]
          end

          def harness_requirement
            { tier: :self_contained, requires_externals: [],
              reason: 'pure file reading; no network, no subprocess, no workflow evaluation' }
          end

          def input_schema
            {
              type: 'object',
              properties: {
                path: {
                  type: 'string',
                  description: 'Directory of an already checked-out repository. Cloning is deliberately ' \
                               'not done here: it is a network side effect, and keeping it outside lets ' \
                               'the scanned party re-run this scan themselves on their own copy.'
                },
                include_declarations: {
                  type: 'boolean',
                  description: 'Include the full declaration list (default false). Findings always carry ' \
                               'their own evidence, so the full list is only needed to audit what was NOT ' \
                               'flagged.'
                },
                include_fixtures: {
                  type: 'boolean',
                  description: 'Count test fixtures alongside shipped configuration (default false). A ' \
                               'repository normally carries a copy of its config under test/, and counting ' \
                               'both doubles every data finding.'
                }
              },
              required: %w[path]
            }
          end

          def call(arguments)
            args = arguments.transform_keys(&:to_s)
            path = args['path'].to_s
            return text_content('Error: path is required') if path.strip.empty?
            return text_content("Error: not a directory: #{path}") unless File.directory?(path)

            report = ::GenomicsChainTier2::Scanner.new(path).scan
            report['rubric_version'] = ::GenomicsChainTier2::RUBRIC_VERSION
            report['limits'] = LIMITS

            unless args['include_fixtures']
              report['declarations'] = report['declarations'].reject { |d| d[:scope] == 'fixture' }
            end
            report.delete('declarations') unless args['include_declarations']

            text_content(JSON.pretty_generate(report))
          rescue StandardError => e
            text_content("Error: gc_tier2_scan failed — #{e.class}: #{e.message}")
          end

          # Stated in every report, because a scan that does not say what it
          # cannot see invites its silence to be read as a clean result.
          LIMITS = [
            'Declarations only. A resource referenced from a script but never declared in a parsed ' \
              'file is invisible here.',
            'No workflow evaluation, so a value computed at runtime — a config key assembled in ' \
              'Python, a path built from a wildcard — is not resolved.',
            'DOIs found in prose are not classified as data deposits or as citations; a paper citing ' \
              'itself counts among them. That separation is a judgement and belongs to the next layer.',
            'A lock file is reported as covering software, but this tool does not verify that it covers ' \
              'the same packages the environment files name.',
            'Parsers cover conda environment files, conda-lock files, Snakemake container directives, ' \
              'Dockerfiles and YAML configuration. Nextflow, CWL and WDL are not yet parsed.'
          ].freeze
        end
      end
    end
  end
end
