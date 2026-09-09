# frozen_string_literal: true

require 'open3'
require 'timeout'
require 'digest'
require 'fileutils'
require_relative 'backend'

module KairosMcp
  module SkillSets
    module GenomicschainTier3
      module Execution
        # ThoaBackend (design v0.3 §2) — managed cloud execution via the thoa CLI.
        #
        # Same interface as LocalBackend. `thoa run` is synchronous, so submit
        # executes and records the terminal state; poll/fetch then read it back.
        # The 30-min sync Timeout of the legacy gc_run_fastqc path is explicitly
        # NOT reused (design v0.3 §2: Tier-3 genomics jobs run for hours) —
        # default here is 6h and is per-job overridable.
        #
        # job_spec.pipeline carries (string or symbol keys):
        #   cmd           => String  (required) command run inside the job env
        #   tools         => String|Array  e.g. "fastqc,multiqc"
        #   inputs        => Array<String> host paths/globs sent to the job
        #   output        => String  job-relative output dir (thoa -o), default '.'
        #   download_dir  => String  (required) local dir receiving the outputs
        #   job_name / job_description => String
        # job_spec.env['lock'] is passed as --env-source when it resolves to a file.
        # job_spec.resources => {n_cores:, ram_gb:, storage_gb:}
        class ThoaBackend < Backend
          DEFAULT_TIMEOUT = 21_600 # 6h — Tier-3 jobs are long-running (design §2)

          # Opt-in marker a job command may print so the REMOTE side reports its
          # own result digest. When present, Tier3Executor's divergence check
          # (design v0.3 §1a') becomes live for this run: it defeats a
          # backend/transport that alters the outputs of a real run in flight.
          #
          # It is OFF unless the job emits it, and deliberately so: thoa's CLI
          # provides no independent result digest of its own, and synthesising
          # one from OUR local recompute would assert a confirmation that never
          # happened (same reasoning as LocalBackend's impl-review I11). To use
          # it, the job command must print the canonical Tier-3 result hash —
          # sha256 over the sorted [{relative_path, sha256, size_bytes}] set
          # (Manifest.tier3_result_hash) — as:
          #   TIER3_RESULT_SHA256=<64 hex>
          RESULT_HASH_MARKER = /^\s*TIER3_RESULT_SHA256=([0-9a-f]{64})\s*$/

          class ThoaUnavailable < Backend::BackendError; end

          def initialize(timeout: DEFAULT_TIMEOUT)
            @timeout = timeout
            @jobs = {}
            @seq = 0
          end

          def id
            'thoa'
          end

          def submit(job_spec)
            preflight!
            pipeline = stringify(job_spec.pipeline)
            cmd = pipeline['cmd']
            raise BackendError, 'thoa backend requires pipeline[:cmd]' if cmd.nil? || cmd.to_s.strip.empty?

            download_dir = pipeline['download_dir']
            raise BackendError, 'thoa backend requires pipeline[:download_dir]' if download_dir.nil?
            FileUtils.mkdir_p(download_dir)

            cmd_array = build_command(job_spec, pipeline, download_dir)

            @seq += 1
            ref = "thoa-#{@seq}"
            @last_ref = ref
            output = nil
            status = nil
            begin
              Timeout.timeout(@timeout) do
                output, status = Open3.capture2e(*cmd_array)
              end
            rescue Timeout::Error
              @jobs[ref] = { exit_code: nil, output: "thoa run timed out after #{@timeout}s",
                             download_dir: download_dir, timed_out: true }
              return ref
            end

            @jobs[ref] = { exit_code: status.exitstatus, output: output,
                           download_dir: download_dir, timed_out: false }
            ref
          end

          # Raw runner output of the most recent submit. A job that fails at
          # poll never reaches fetch, so its Receipt (and with it every trace of
          # WHY it failed) is never built — an env_failed verdict would
          # otherwise carry no diagnosis at all. Callers surface this.
          def last_output
            @last_ref && @jobs.dig(@last_ref, :output)
          end

          def poll(ref)
            job = @jobs[ref] or return :failed
            job[:exit_code] == 0 ? :done : :failed
          end

          def fetch(ref, dst = nil)
            job = @jobs[ref] or raise BackendError, "unknown job ref: #{ref}"
            root = dst && Dir.exist?(dst) ? dst : job[:download_dir]

            output_files = KairosMcp::Manifest.walk_files(root).map do |f|
              { 'sha256' => f[:sha256], 'relative_path' => f[:relative_path], 'size_bytes' => f[:size_bytes] }
            end

            metadata = { 'job_id' => ref, 'thoa_job_id' => extract_job_id(job[:output]) }.compact
            reported = job[:output].to_s[RESULT_HASH_MARKER, 1]
            metadata['backend_result_hash'] = reported if reported

            Receipt.new(
              terminal_state: job[:exit_code] == 0 ? :done : :failed,
              process_exit_code: job[:exit_code],
              backend_reported_status: job[:timed_out] ? 'timeout' : "exit=#{job[:exit_code]}",
              stdout_sha256: Digest::SHA256.hexdigest(job[:output].to_s),
              stderr_sha256: nil, # thoa CLI merges streams (capture2e)
              output_files: output_files,
              artifact_manifest_sha256: KairosMcp::Manifest.tier3_result_hash(output_files),
              backend_metadata: metadata,
              # thoa runs tools natively in a managed VM; there is no container
              # digest to report (parity with the legacy fastqc 'thoa-managed').
              container_digest: nil,
              attestation_doc: nil
            )
          end

          # thoa is a managed cloud runner, not a TEE: its results are
          # self-reported, exactly like local/ec2 (design v0.3 §1b').
          def attestation_kind
            :self_reported_hash
          end

          def raw_output(ref)
            @jobs.dig(ref, :output)
          end

          def cli_available?
            system('which thoa > /dev/null 2>&1') ||
              system('conda run -n thoa_py3.11 which thoa > /dev/null 2>&1')
          end

          def api_key_set?
            key = ENV['THOA_API_KEY']
            !key.nil? && !key.strip.empty?
          end

          private

          def preflight!
            unless cli_available?
              raise ThoaUnavailable,
                    'thoa CLI not found (PATH or conda env thoa_py3.11). See https://thoa.io/docs/quickstart#install'
            end
            unless api_key_set?
              raise ThoaUnavailable,
                    'THOA_API_KEY is not set. Get a key at https://thoa.io/workbench/api_keys'
            end
          end

          def cmd_prefix
            system('which thoa > /dev/null 2>&1') ? ['thoa'] : ['conda', 'run', '-n', 'thoa_py3.11', 'thoa']
          end

          # Array form throughout — no shell interpolation of caller-supplied values.
          def build_command(job_spec, pipeline, download_dir)
            res = stringify(job_spec.resources || {})
            args = cmd_prefix + ['run', '--cmd', pipeline['cmd'].to_s]

            args += environment_args(job_spec, pipeline)

            Array(pipeline['inputs']).each { |i| args += ['--input', i.to_s] }
            args += ['--output', (pipeline['output'] || '.').to_s]

            # Reproducibility gate: thoa retries a failed job with AI-applied
            # changes by default (--max-attempts 3). A retry that alters the job
            # means the pipeline that ran is no longer the pipeline that was
            # declared and digested, which is exactly what a Tier-3 verdict
            # asserts. Disable it unless the caller explicitly opts in.
            args << '--strict' unless truthy?(pipeline['allow_ai_retry'])

            args += ['--n-cores', res['n_cores'].to_s] if res['n_cores']
            args += ['--ram', res['ram_gb'].to_s] if res['ram_gb']
            args += ['--storage', res['storage_gb'].to_s] if res['storage_gb']
            args += ['--job-name', pipeline['job_name'].to_s] if pipeline['job_name']
            args += ['--job-description', pipeline['job_description'].to_s] if pipeline['job_description']
            args += ['--download-dir', download_dir.to_s]
            args
          end

          # thoa 0.1.6 requires EXACTLY ONE of --tools / --env-source / --env-id:
          # two are rejected as mutually exclusive, zero as unspecified.
          #
          # Supplying two is also ambiguous about which environment is the
          # Lever-1 identity being tested, so we fail loudly rather than pick
          # one: silently dropping a declaration would change the environment
          # under test without changing the jobspec_digest.
          def environment_args(job_spec, pipeline)
            env = stringify(job_spec.env || {})
            env_id = env['env_id']
            lock = env['lock']
            # A lock that is not a readable path (e.g. a bare digest) cannot be
            # handed to --env-source; the tools list then stands on its own.
            lock = nil unless lock && File.exist?(lock.to_s)
            tools = Array(pipeline['tools'].is_a?(String) ? pipeline['tools'].split(',') : pipeline['tools'])
                    .map { |t| t.to_s.strip }.reject(&:empty?)

            declared = { '--env-id' => env_id, '--env-source' => lock, '--tools' => (tools.empty? ? nil : tools) }
                       .reject { |_, v| v.nil? }
            unless declared.length == 1
              got = declared.empty? ? 'none' : declared.keys.join(' + ')
              hint = if declared.empty? && env['lock']
                       " (env[:lock] = #{env['lock'].inspect} was not usable: not a readable path.)"
                     else
                       ''
                     end
              raise BackendError,
                    "thoa requires EXACTLY ONE environment source, got #{got}. " \
                    "Supply env[:env_id], OR env[:lock] as a readable env file, OR pipeline[:tools].#{hint}"
            end

            return ['--env-id', env_id.to_s] if env_id
            return ['--env-source', lock.to_s] if lock

            tools.flat_map { |t| ['--tools', t] }
          end

          def truthy?(value)
            [true, 'true', 1, '1'].include?(value)
          end

          def extract_job_id(output)
            output.to_s[/job[_ -]?id[:=]\s*([A-Za-z0-9_-]+)/i, 1]
          end

          def stringify(obj)
            case obj
            when Hash then obj.each_with_object({}) { |(k, v), h| h[k.to_s] = v }
            else obj || {}
            end
          end
        end
      end
    end
  end
end
