# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'genomicschain_tier2'

module KairosMcp
  module SkillSets
    module GenomicschainTier2
      module Tools
        # gc_tier2_execute — thin MCP skin over Tier2Executor (design v0.3 §3).
        #
        # Resolves a JobSpec from the caller-supplied Stage-2 resolution
        # (env / data / pipeline), runs it on the selected backend, recomputes
        # the result hash locally, compares against the validated
        # expected_output, and returns the verdict identity.
        #
        # It does NOT sign, record, or attest — that is gc_tier2_submit's job
        # (design v0.3 §5'/§6'). The returned `jobspec_json` is the canonical
        # spec the submit side re-hashes, so it must be passed through verbatim.
        class GcTier2Execute < KairosMcp::Tools::BaseTool
          BACKENDS = %w[local thoa].freeze

          def name
            'gc_tier2_execute'
          end

          def description
            'Run a Tier-2 executed-R reproducibility job (local or Thoa backend) and compute a verdict ' \
              'against a validated expected_output. Returns the verdict identity plus the canonical ' \
              'jobspec_json to hand to gc_tier2_submit. Does not sign or record anything.'
          end

          def category
            :utility
          end

          def usecase_tags
            %w[tier2 reproducibility executed_r genomics thoa verdict]
          end

          def related_tools
            %w[gc_tier2_submit chain_status attestation_verify]
          end

          # Subprocess execution (thoa CLI / local pipeline command) — not core-only.
          def harness_requirement
            { tier: :harness_assisted, requires_externals: %w[thoa conda],
              reason: 'executes the pipeline through an external runner (thoa CLI or a local command)' }
          end

          def input_schema
            {
              type: 'object',
              properties: {
                subject_ref: {
                  type: 'string',
                  description: 'Stage-2 subject under evaluation, e.g. "repro://656122/C9".'
                },
                backend: {
                  type: 'string', enum: BACKENDS,
                  description: 'Execution backend. "thoa" (default) = managed cloud; "local" = Open3 on this host.'
                },
                env: {
                  type: 'object',
                  description: 'Lever-1 environment resolution, e.g. {lock: "/path/environment.yml", container_digest: "sha256:..."}. Part of jobspec_digest.'
                },
                data: {
                  type: 'object',
                  description: 'Lever-2 data resolution, e.g. {pins: [...], accessions: [...]}. Part of jobspec_digest.'
                },
                pipeline: {
                  type: 'object',
                  description: 'Pipeline resolution (steps, step_source) PLUS backend run keys. ' \
                               'local: {command: ["bash","-c","..."], workdir: "/abs/dir"}. ' \
                               'thoa: {cmd: "...", tools: "fastqc,multiqc", inputs: ["/abs/in"], output: "out", download_dir: "/abs/dir"}. ' \
                               'Part of jobspec_digest.'
                },
                resources: {
                  type: 'object',
                  description: 'Optional {n_cores, ram_gb, storage_gb}. NOT part of jobspec_digest.'
                },
                expected_output: {
                  type: 'object',
                  description: 'Validated target (design v0.3 §1d\'): {target, sha256, source, source_citation, validated_by}. ' \
                               'target = "file:<relative_path>" for a single-file checksum, or omit/other for the aggregate result tree. ' \
                               'source = paper_declared | llm_extracted | operator_supplied.'
                },
                workdir: {
                  type: 'string',
                  description: 'Absolute directory the outputs are read from (defaults to pipeline.workdir for local, pipeline.download_dir for thoa).'
                },
                comparator_id: {
                  type: 'string',
                  description: 'Comparator id (default "exact_sha256" — a DIAGNOSTIC; a mismatch yields executed_inconclusive_needs_tolerance).'
                },
                stage2_report_ref: {
                  type: 'string',
                  description: 'Optional provenance echo of the Stage-2 report this resolution came from. NOT part of jobspec_digest.'
                },
                thoa_timeout_seconds: {
                  type: 'integer',
                  description: 'Override the thoa run timeout (default 21600 = 6h).'
                }
              },
              required: %w[subject_ref pipeline expected_output]
            }
          end

          def call(arguments)
            args = arguments.transform_keys(&:to_s)
            subject_ref = args['subject_ref'].to_s
            backend_id = (args['backend'] || 'thoa').to_s
            unless BACKENDS.include?(backend_id)
              return text_content("Error: unknown backend '#{backend_id}' (expected: #{BACKENDS.join(', ')})")
            end

            pipeline = hashify(args['pipeline'])
            expected_output = hashify(args['expected_output'])

            # (I8/R2-D) Gate untrusted structures before anything expensive runs.
            KairosMcp::Manifest.dos_gate!(expected_output)
            KairosMcp::Manifest.restricted_subset!(expected_output)

            workdir = resolve_workdir(args, pipeline, backend_id)
            if workdir.nil?
              return text_content(
                "Error: workdir could not be resolved. Supply `workdir`, or " \
                "pipeline.workdir (local) / pipeline.download_dir (thoa)."
              )
            end
            validate_path!(workdir, 'workdir')
            FileUtils.mkdir_p(workdir) if backend_id == 'thoa' && !Dir.exist?(workdir)
            return text_content("Error: workdir does not exist: #{workdir}") unless Dir.exist?(workdir)

            job_spec = Execution::JobSpec.new(
              subject_ref: subject_ref,
              env: hashify(args['env']),
              data: hashify(args['data']),
              pipeline: pipeline,
              backend_id: backend_id,
              resources: hashify(args['resources'])
            )

            backend = build_backend(backend_id, args)
            comparator_id = (args['comparator_id'] || 'exact_sha256').to_s

            result = Tier2Executor.run(
              job_spec: job_spec, expected_output: expected_output,
              backend: backend, workdir: workdir, comparator_id: comparator_id
            )

            text_content(JSON.pretty_generate(render(result, job_spec, args, backend)))
          rescue Execution::Backend::BackendError, ArgumentError, KairosMcp::Manifest::ManifestError => e
            text_content("Error: #{e.class.name.split('::').last}: #{e.message}")
          rescue StandardError => e
            text_content("Error: gc_tier2_execute failed — #{e.class}: #{e.message}")
          end

          private

          def build_backend(backend_id, args)
            case backend_id
            when 'local' then Execution::LocalBackend.new
            when 'thoa'
              timeout = args['thoa_timeout_seconds']
              timeout ? Execution::ThoaBackend.new(timeout: timeout.to_i) : Execution::ThoaBackend.new
            end
          end

          def resolve_workdir(args, pipeline, backend_id)
            explicit = args['workdir']
            return explicit.to_s unless explicit.nil? || explicit.to_s.empty?

            key = backend_id == 'thoa' ? 'download_dir' : 'workdir'
            value = pipeline[key]
            value.nil? || value.to_s.empty? ? nil : value.to_s
          end

          # The verdict identity (the fields gc_tier2_submit signs) is emitted as
          # a flat `verdict_result` object so it can be passed straight through.
          def render(vr, job_spec, args, backend)
            verdict_result = {
              'subject_ref' => vr.subject_ref,
              'jobspec_digest' => vr.jobspec_digest,
              'verdict' => vr.verdict,
              'trust_tier' => vr.trust_tier,
              'result_hash' => vr.result_hash,
              'backend_result_hash' => vr.backend_result_hash,
              'expected_output_sha256' => vr.expected_output_sha256,
              'expected_output_source' => vr.expected_output_source,
              'expected_output_validated_by' => vr.expected_output_validated_by,
              'expected_output_source_citation' => vr.expected_output_source_citation,
              'expected_output_target' => vr.expected_output_target,
              'comparator_id' => vr.comparator_id,
              'comparator_version' => vr.comparator_version,
              'backend_id' => vr.backend_id,
              'output_files' => vr.output_files
            }

            {
              'status' => 'executed',
              'verdict' => vr.verdict,
              'trust_tier' => vr.trust_tier,
              'verdict_result' => verdict_result,
              'expected_output' => vr.expected_output,
              'jobspec_json' => job_spec.canonical_json,
              'first_divergence' => vr.first_divergence,
              'backend' => {
                'id' => backend.id,
                'attestation_kind' => backend.attestation_kind.to_s,
                'reported_status' => vr.receipt&.backend_reported_status,
                'exit_code' => vr.receipt&.process_exit_code,
                'reports_own_result_hash' => !vr.backend_result_hash.nil?
              },
              'stage2_report_ref' => args['stage2_report_ref'],
              'backend_diagnostics' => diagnostics(vr, backend),
              'notes' => notes(vr),
              'next_step' => 'Pass verdict_result + jobspec_json + expected_output (verbatim) to gc_tier2_submit ' \
                             'together with a signed operator envelope.'
            }.compact
          end

          # A job that fails at poll never reaches fetch, so there is no Receipt
          # and the verdict alone says only "env_failed" — useless for acting on.
          # Surface the runner's own output (tail) so the cause is visible; it is
          # diagnostic context only and enters neither the verdict identity nor
          # the chain record.
          DIAGNOSTIC_TAIL_BYTES = 2000

          def diagnostics(vr, backend)
            return nil unless %w[env_failed outputs_unusable data_blocked].include?(vr.verdict)
            return nil unless backend.respond_to?(:last_output)

            output = backend.last_output.to_s
            return nil if output.empty?

            output.length > DIAGNOSTIC_TAIL_BYTES ? "...#{output[-DIAGNOSTIC_TAIL_BYTES..]}" : output
          end

          def notes(vr)
            notes = []
            if vr.verdict == 'executed_inconclusive_needs_tolerance'
              notes << 'exact_sha256 is a DIAGNOSTIC: the mismatch is recorded as first_divergence and is ' \
                       'input to the tolerance comparator, not a reproduction failure (design v0.3 §4).'
            end
            if vr.verdict == 'env_failed' && vr.backend_result_hash && vr.backend_result_hash != vr.result_hash
              notes << 'Backend-reported result hash diverges from the local recompute — treated as ' \
                       'transport/backend tamper (design v0.3 §1a\').'
            end
            if vr.backend_result_hash.nil? && vr.receipt
              notes << 'Backend reported no independent result hash, so the divergence check did not run. ' \
                       'It witnesses transport integrity only, never that a run occurred (design v0.3 §1b\').'
            end
            notes
          end

          def hashify(value)
            return {} if value.nil?
            raise ArgumentError, 'expected a JSON object' unless value.is_a?(Hash)

            value.transform_keys(&:to_s)
          end

          # HTTP-mode defense: absolute paths only, no traversal segments.
          def validate_path!(path, label)
            raise ArgumentError, "#{label} must be an absolute path (got #{path.inspect})" unless path.start_with?('/')
            raise ArgumentError, "#{label} must not contain '..'" if path.split('/').include?('..')
          end
        end
      end
    end
  end
end
