# frozen_string_literal: true

require 'json'
require 'tmpdir'
require 'fileutils'
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
        #
        # Two ways in, one scanner. `path` is a directory already on this
        # machine. `files` is the same repository carried inside the call as
        # {path, content} pairs — for a caller that cannot put bytes on this
        # disk, such as genomicschain.ch handing over a manuscript's unpublished
        # code (2026-09-11). The pairs are written to a temporary directory,
        # scanned exactly as a checkout would be, and removed before the call
        # returns; nothing of the upload outlives the response. The evidence
        # digest is computed the same way in both modes, so the party being
        # scanned can re-run the scan on their own copy and compare digests.
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
                               'the scanned party re-run this scan themselves on their own copy. ' \
                               'Exactly one of path or files is required.'
                },
                files: {
                  type: 'array',
                  description: 'The repository carried in the call instead of on disk: [{path, content}] ' \
                               'with repository-relative paths and UTF-8 text. Written to a temporary ' \
                               'directory, scanned as a checkout, deleted before returning. Only files the ' \
                               'scanner reads (Snakefile, Dockerfile*, .yml/.yaml/.smk/.lock/.md/.rst/' \
                               '.txt/.cfg/.toml/.json) need to be sent; others are counted as skipped. ' \
                               "Limits: #{MAX_FILES} files, #{MAX_TOTAL_BYTES} bytes in total.",
                  items: { type: 'object' }
                },
                label: {
                  type: 'string',
                  description: 'With files: what to report as target.root instead of the temporary ' \
                               'directory (an archive name, a repository URL). Free text.'
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
              required: []
            }
          end

          def call(arguments)
            args = arguments.transform_keys(&:to_s)
            path = args['path'].to_s
            files = args['files']

            if !path.strip.empty? && files
              return text_content('Error: give either path or files, not both')
            end
            return scan_files(files, args) if files
            return text_content('Error: one of path or files is required') if path.strip.empty?
            return text_content("Error: not a directory: #{path}") unless File.directory?(path)

            text_content(JSON.pretty_generate(report_for(path, args)))
          rescue StandardError => e
            text_content("Error: gc_tier2_scan failed — #{e.class}: #{e.message}")
          end

          MAX_FILES = 5_000
          MAX_TOTAL_BYTES = 16 * 1024 * 1024

          private

          def report_for(path, args)
            report = ::GenomicsChainTier2::Scanner.new(path).scan
            report['rubric_version'] = ::GenomicsChainTier2::RUBRIC_VERSION
            report['limits'] = LIMITS

            unless args['include_fixtures']
              report['declarations'] = report['declarations'].reject { |d| d[:scope] == 'fixture' }
            end
            report.delete('declarations') unless args['include_declarations']
            report
          end

          # The upload is materialised only for the duration of the scan. The
          # temporary directory is removed in `ensure`, so a scanner failure
          # cannot leave a stranger's unpublished code on the anchor's disk.
          def scan_files(files, args)
            problem = validate_files(files)
            return text_content("Error: #{problem}") if problem

            dir = Dir.mktmpdir('gc_tier2_scan')
            begin
              files.each do |f|
                f = f.transform_keys(&:to_s)
                abs = File.join(dir, f['path'])
                FileUtils.mkdir_p(File.dirname(abs))
                File.binwrite(abs, f['content'].to_s)
              end

              report = report_for(dir, args)
              # The temporary path names nothing a reader could return to, and
              # differs on every call; the label is what the caller knows the
              # upload as. Both digests are unaffected: evidence_digest is over
              # relative paths and content.
              report['target']['root'] = args['label'].to_s.strip.empty? ? 'uploaded files' : args['label'].to_s
              report['target']['source'] = 'files'
              report['target']['files_received'] = files.length
              report['target']['bytes_received'] = files.sum { |f| (f['content'] || f[:content]).to_s.bytesize }
              text_content(JSON.pretty_generate(report))
            ensure
              FileUtils.remove_entry_secure(dir) if dir && File.directory?(dir)
            end
          end

          # Every path is checked before anything is written: one rejected entry
          # fails the whole call, because a partially written repository would
          # scan as a different repository.
          def validate_files(files)
            return 'files must be a non-empty array of {path, content}' unless files.is_a?(Array) && files.any?
            return "files: more than #{MAX_FILES} entries" if files.length > MAX_FILES

            total = 0
            files.each_with_index do |f, i|
              return "files[#{i}] is not an object" unless f.is_a?(Hash)

              f = f.transform_keys(&:to_s)
              rel = f['path'].to_s
              return "files[#{i}].path is empty" if rel.strip.empty?
              return "files[#{i}].path is not repository-relative: #{rel.inspect}" if unsafe_path?(rel)
              return "files[#{i}].content is not a string" unless f['content'].is_a?(String)

              total += f['content'].bytesize
            end
            return "files: #{total} bytes exceeds the #{MAX_TOTAL_BYTES}-byte limit" if total > MAX_TOTAL_BYTES

            nil
          end

          # Repository-relative only: no absolute paths, no drive letters, no
          # parent-directory segments. Anything else could write outside the
          # temporary directory.
          def unsafe_path?(rel)
            return true if rel.include?("\0") || rel.start_with?('/') || rel.match?(%r{\A[A-Za-z]:[\\/]})

            rel.split(%r{[\\/]+}).any? { |seg| seg == '..' }
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
