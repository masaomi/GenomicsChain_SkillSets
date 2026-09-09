# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'genomicschain_tier3'

module KairosMcp
  module SkillSets
    module GenomicschainTier3
      module Tools
        # gc_tier3_execute — thin MCP skin over Tier3Executor (record 0.3).
        #
        # Resolves a JobSpec from the caller-supplied Stage-2 resolution
        # (env / data / pipeline), runs it one or more times on the selected
        # backend, recomputes the result hash locally, compares against a
        # validated expected_output IF one exists, and returns the verdict
        # identity on two axes.
        #
        # expected_output is OPTIONAL. In the 2026-08-14 survey of the five
        # papers passing the Tier-1 gate, none declared a checksum or nominated
        # an artifact to compare against, so requiring one would have made the
        # only reachable claim unrequestable.
        #
        # It does NOT sign, record, or attest — that is gc_tier3_submit's job.
        # The returned `jobspec_json` is the canonical spec the submit side
        # re-hashes, so it must be passed through verbatim.
        class GcTier3Execute < KairosMcp::Tools::BaseTool
          BACKENDS = %w[local thoa].freeze
          INPUTS_PROVENANCE = %w[public_accession archive_doi controlled_access operator_supplied unknown].freeze
          ENV_PROVENANCE = %w[declared_container declared_lock declared_tools authored_by_operator none].freeze
          VARIATIONS = %w[same_environment distinct_environments].freeze

          def name
            'gc_tier3_execute'
          end

          def description
            'Run a Tier-3 execution job (local or Thoa backend) one or more times and compute a ' \
              'two-axis verdict: whether it ran, and whether it matched a declared target if one exists. ' \
              'Returns the verdict identity plus the canonical jobspec_json to hand to gc_tier3_submit. ' \
              'Does not sign or record anything.'
          end

          def category
            :utility
          end

          def usecase_tags
            %w[tier3 reproducibility executed_r genomics thoa verdict self_consistency]
          end

          def related_tools
            %w[gc_tier3_estimate gc_tier3_submit chain_status attestation_verify]
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
                  description: 'Lever-1 environment resolution, e.g. {lock: "/path/environment.yml", ' \
                               'container_digest: "sha256:..."}. Part of jobspec_digest, and the source ' \
                               'environment_provenance is derived from.'
                },
                data: {
                  type: 'object',
                  description: 'Lever-2 data resolution, e.g. {pins: [...], accessions: [...]}. Part of jobspec_digest.'
                },
                pipeline: {
                  type: 'object',
                  description: 'Pipeline resolution (steps, step_source) PLUS backend run keys. ' \
                               'local: {command: ["bash","-c","..."], workdir: "/abs/dir"}. ' \
                               'thoa: {cmd: "...", tools: "fastqc,multiqc", inputs: ["/abs/in"], output: "out", ' \
                               'download_dir: "/abs/dir"}. Part of jobspec_digest.'
                },
                resources: {
                  type: 'object',
                  description: 'Optional {n_cores, ram_gb, storage_gb}. NOT part of jobspec_digest. ' \
                               'For the thoa backend these are effectively REQUIRED: the CLI default ' \
                               'storage is 200 GB, which exceeds some accounts\' allocation and fails closed. ' \
                               'Use gc_tier3_estimate to size and price them first.'
                },
                expected_output: {
                  type: 'object',
                  description: 'OPTIONAL comparison target: {target, sha256, source, source_citation, validated_by}. ' \
                               'Omit when the paper declares none — the result is then comparison_verdict ' \
                               '"no_target_declared", which is a complete outcome, not a failure. ' \
                               'target = "file:<relative_path>" for a single-file checksum, or omit for the ' \
                               'aggregate result tree. source = paper_declared | llm_extracted | operator_supplied.'
                },
                runs: {
                  type: 'integer',
                  description: 'How many independent executions of the same JobSpec (default 1). ' \
                               '1 establishes only that it ran. >=2 additionally reports whether the runs ' \
                               'agreed. Cost scales linearly, so this is the operator\'s choice: 2 catches ' \
                               'the common nondeterminism (embedded timestamps, unseeded RNG); 3 is worth ' \
                               'it for tools with known randomness (ML, MCMC, sampling), because two runs ' \
                               'of a coin-flip agree half the time.'
                },
                run_workdirs: {
                  type: 'array', items: { type: 'string' },
                  description: 'REQUIRED when runs > 1: one absolute directory per run, all distinct. ' \
                               'Reusing one directory would re-hash the previous run\'s outputs and report ' \
                               'agreement that never happened.'
                },
                workdir: {
                  type: 'string',
                  description: 'Single-run output directory (defaults to pipeline.workdir for local, ' \
                               'pipeline.download_dir for thoa).'
                },
                inputs_provenance: {
                  type: 'string', enum: INPUTS_PROVENANCE,
                  description: 'Where the inputs came from. Never guessed; defaults to "unknown". ' \
                               '"controlled_access" records that a third party cannot repeat the run.'
                },
                environment_provenance: {
                  type: 'string', enum: ENV_PROVENANCE,
                  description: 'Omit to derive from env/pipeline. Pass "authored_by_operator" explicitly ' \
                               'when you built an environment the paper did not supply — that cannot be ' \
                               'derived, and a certificate must not present it as the declared environment.'
                },
                variation: {
                  type: 'string', enum: VARIATIONS,
                  description: 'For runs > 1: whether the repeats varied the environment (default ' \
                               'same_environment, which detects pipeline-internal nondeterminism only).'
                },
                comparator_id: {
                  type: 'string',
                  description: 'Comparator for the declared target (default "exact_sha256"). Ignored when ' \
                               'no target is supplied.'
                },
                stage2_report_ref: {
                  type: 'string',
                  description: 'Optional provenance echo of the Stage-2 report this resolution came from.'
                },
                thoa_timeout_seconds: {
                  type: 'integer',
                  description: 'Override the thoa run timeout (default 21600 = 6h).'
                }
              },
              required: %w[subject_ref pipeline]
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
            expected_output = args['expected_output'].nil? ? nil : hashify(args['expected_output'])

            # (I8/R2-D) Gate untrusted structures before anything expensive runs.
            if expected_output && !expected_output.empty?
              KairosMcp::Manifest.dos_gate!(expected_output)
              KairosMcp::Manifest.restricted_subset!(expected_output)
            end

            workdirs, error = resolve_workdirs(args, pipeline, backend_id)
            return text_content("Error: #{error}") if error

            workdirs.each do |wd|
              validate_path!(wd, 'workdir')
              FileUtils.mkdir_p(wd) if backend_id == 'thoa' && !Dir.exist?(wd)
              return text_content("Error: workdir does not exist: #{wd}") unless Dir.exist?(wd)
            end

            job_spec = Execution::JobSpec.new(
              subject_ref: subject_ref,
              env: hashify(args['env']),
              data: hashify(args['data']),
              pipeline: pipeline,
              backend_id: backend_id,
              resources: hashify(args['resources'])
            )

            backend = build_backend(backend_id, args)

            result = Tier3Executor.run(
              job_spec: job_spec, backend: backend, workdirs: workdirs,
              expected_output: expected_output,
              comparator_id: (args['comparator_id'] || 'exact_sha256').to_s,
              inputs_provenance: (args['inputs_provenance'] || 'unknown').to_s,
              environment_provenance: args['environment_provenance'],
              variation: (args['variation'] || 'same_environment').to_s
            )

            text_content(JSON.pretty_generate(render(result, job_spec, args, backend)))
          rescue Execution::Backend::BackendError, ArgumentError, KairosMcp::Manifest::ManifestError => e
            text_content("Error: #{e.class.name.split('::').last}: #{e.message}")
          rescue StandardError => e
            text_content("Error: gc_tier3_execute failed — #{e.class}: #{e.message}")
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

          # Returns [workdirs, error_message]. run_workdirs is mandatory above one
          # run rather than derived, so that a caller can place run 2 on another
          # host or mount and say so via `variation`.
          def resolve_workdirs(args, pipeline, backend_id)
            runs = (args['runs'] || 1).to_i
            return [nil, "runs must be >= 1 (got #{runs})"] if runs < 1

            explicit = Array(args['run_workdirs']).map(&:to_s).reject(&:empty?)

            if runs > 1
              if explicit.length != runs
                return [nil, "runs=#{runs} requires run_workdirs with #{runs} distinct absolute " \
                             "directories (got #{explicit.length})"]
              end
              return [nil, 'run_workdirs entries must be distinct'] if explicit.uniq.length != explicit.length

              return [explicit, nil]
            end

            return [explicit[0, 1], nil] unless explicit.empty?

            single = args['workdir']
            single = pipeline[backend_id == 'thoa' ? 'download_dir' : 'workdir'] if single.nil? || single.to_s.empty?
            if single.nil? || single.to_s.empty?
              return [nil, 'workdir could not be resolved. Supply `workdir`, or ' \
                           'pipeline.workdir (local) / pipeline.download_dir (thoa).']
            end

            [[single.to_s], nil]
          end

          # The verdict identity (the fields gc_tier3_submit signs) is emitted as
          # a flat `verdict_result` object so it can be passed straight through.
          def render(vr, job_spec, args, backend)
            verdict_result = {
              'subject_ref' => vr.subject_ref,
              'jobspec_digest' => vr.jobspec_digest,
              'execution_verdict' => vr.execution_verdict,
              'comparison_verdict' => vr.comparison_verdict,
              'environment_provenance' => vr.environment_provenance,
              'inputs_provenance' => vr.inputs_provenance,
              'run_count' => vr.run_count,
              'self_consistency' => vr.self_consistency,
              'trust_tier' => vr.trust_tier,
              'result_hash' => vr.result_hash,
              'backend_result_hash' => vr.backend_result_hash,
              'container_digest' => vr.container_digest,
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
              'execution_verdict' => vr.execution_verdict,
              'comparison_verdict' => vr.comparison_verdict,
              'run_count' => vr.run_count,
              'trust_tier' => vr.trust_tier,
              'verdict_result' => verdict_result,
              'expected_output' => vr.expected_output,
              'self_consistency' => vr.self_consistency,
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
              'establishes' => establishes(vr),
              'notes' => notes(vr),
              'next_step' => 'Pass verdict_result + jobspec_json + expected_output (verbatim, omit if absent) ' \
                             'to gc_tier3_submit together with a signed operator envelope.'
            }.compact
          end

          # The sentence a certificate may carry, stated in full so nobody has to
          # infer it from enum values. Never says "stable" or "reproducible":
          # it states the number of runs and lets the reader judge.
          def establishes(vr)
            return 'Nothing was established: the job did not complete.' unless vr.execution_verdict == 'completed'

            env = {
              'declared_container' => 'the container image the authors declared',
              'declared_lock' => 'the environment file the authors declared',
              'declared_tools' => 'the tool set the authors declared',
              'authored_by_operator' => 'an environment the operator authored, NOT one the paper supplied',
              'none' => 'an unpinned environment'
            }[vr.environment_provenance]

            parts = ["The pipeline ran to completion #{vr.run_count} time(s) in #{env}."]
            if vr.self_consistency
              parts << (vr.self_consistency['all_identical'] ? "All #{vr.run_count} runs produced the same result." : "The #{vr.run_count} runs did NOT all produce the same result.")
            end
            parts << case vr.comparison_verdict
                     when 'no_target_declared'
                       'No comparison against the paper was made, because the paper declares no target.'
                     when 'match_exact' then 'The result matched the declared target exactly.'
                     when 'match_normalized' then 'The result matched the declared target after normalisation.'
                     when 'mismatch' then 'The result did NOT match the declared target.'
                     else 'No comparison was attempted.'
                     end
            parts.join(' ')
          end

          DIAGNOSTIC_TAIL_BYTES = 2000

          def diagnostics(vr, backend)
            return nil unless %w[env_failed outputs_unusable data_blocked].include?(vr.execution_verdict)
            return nil unless backend.respond_to?(:last_output)

            output = backend.last_output.to_s
            return nil if output.empty?

            output.length > DIAGNOSTIC_TAIL_BYTES ? "...#{output[-DIAGNOSTIC_TAIL_BYTES..]}" : output
          end

          def notes(vr)
            notes = []
            if vr.comparison_verdict == 'no_target_declared'
              notes << 'The paper declares no comparison target, so no comparison was performed. This is a ' \
                       'complete outcome, not an inconclusive one — and it is the common case (0/5 papers ' \
                       'in the 2026-08-14 corpus survey declared one).'
            end
            if vr.comparison_verdict == 'mismatch' && vr.comparator_id == 'exact_sha256'
              notes << 'exact_sha256 is strict: it reports a mismatch for outputs whose content is ' \
                       'equivalent but not byte-identical (archive timestamps, embedded dates). Read ' \
                       'first_divergence before concluding the paper does not reproduce.'
            end
            if vr.self_consistency && vr.self_consistency['all_identical'] == false
              notes << 'Runs disagreed under exact_sha256. Check first_divergence before concluding the ' \
                       'pipeline is nondeterministic: byte-identical content inside an archive container ' \
                       'whose header carries a timestamp also lands here (measured with fastqc, 2026-08-14).'
            end
            if vr.environment_provenance == 'authored_by_operator'
              notes << 'The environment was authored by the operator. A certificate must not describe this ' \
                       'run as having used the environment the paper declared.'
            end
            if vr.inputs_provenance == 'controlled_access'
              notes << 'Inputs came from a controlled-access source, so a third party cannot repeat this run.'
            end
            if vr.execution_verdict == 'env_failed' && vr.backend_result_hash && vr.backend_result_hash != vr.result_hash
              notes << 'Backend-reported result hash diverges from the local recompute — treated as ' \
                       'transport/backend tamper.'
            end
            if vr.backend_result_hash.nil? && vr.receipt
              notes << 'Backend reported no independent result hash, so the divergence check did not run. ' \
                       'It witnesses transport integrity only, never that a run occurred.'
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
