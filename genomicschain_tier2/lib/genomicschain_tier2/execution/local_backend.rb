# frozen_string_literal: true

require 'open3'
require 'digest'
require_relative 'backend'

module KairosMcp
  module SkillSets
    module GenomicschainTier2
      module Execution
        # LocalBackend (design v0.3 §2, "local" backend for small/self-contained
        # jobs; disk-guarded). Runs a pipeline command via Open3 in a workdir,
        # hashes the produced outputs, and returns a validated Receipt. This is a
        # REAL backend (not a mock) — it also serves as the testable reference for
        # the Tier-2 execution flow without needing a Thoa account.
        #
        # job_spec.pipeline is expected to carry:
        #   :command => Array<String> (array form; no shell)
        #   :workdir => String (must exist; command runs here; outputs land here)
        class LocalBackend < Backend
          def initialize
            @jobs = {}
            @seq = 0
          end

          def id
            'local'
          end

          def submit(job_spec)
            cmd = job_spec.pipeline[:command] || job_spec.pipeline['command']
            workdir = job_spec.pipeline[:workdir] || job_spec.pipeline['workdir']
            raise BackendError, 'local backend requires pipeline[:command] (array form)' unless cmd.is_a?(Array)
            raise BackendError, "workdir does not exist: #{workdir}" unless workdir && Dir.exist?(workdir)

            @seq += 1
            ref = "local-#{@seq}"
            @last_ref = ref
            stdout, stderr, status = Open3.capture3(*cmd, chdir: workdir)
            @jobs[ref] = {
              exit_code: status.exitstatus,
              stdout: stdout, stderr: stderr, workdir: workdir
            }
            ref
          end

          def poll(ref)
            job = @jobs[ref] or return :failed
            job[:exit_code].zero? ? :done : :failed
          end

          # Raw output of the most recent submit. A job that fails at poll never
          # reaches fetch, so its Receipt is never built and an env_failed
          # verdict would otherwise carry no diagnosis. Callers surface this.
          def last_output
            job = @last_ref && @jobs[@last_ref]
            return nil unless job

            [job[:stdout], job[:stderr]].compact.reject(&:empty?).join("\n")
          end

          def fetch(ref, _dst)
            job = @jobs[ref] or raise BackendError, "unknown job ref: #{ref}"
            output_files = KairosMcp::Manifest.walk_files(job[:workdir]).map do |f|
              { 'sha256' => f[:sha256], 'relative_path' => f[:relative_path], 'size_bytes' => f[:size_bytes] }
            end
            local_hash = KairosMcp::Manifest.tier2_result_hash(output_files)
            Receipt.new(
              terminal_state: job[:exit_code].zero? ? :done : :failed,
              process_exit_code: job[:exit_code],
              backend_reported_status: "exit=#{job[:exit_code]}",
              stdout_sha256: Digest::SHA256.hexdigest(job[:stdout]),
              stderr_sha256: Digest::SHA256.hexdigest(job[:stderr]),
              output_files: output_files,
              artifact_manifest_sha256: local_hash,
              # For local, the backend-reported hash IS the local recompute (no
              # transport gap). A real remote backend reports its own hash which
              # the runner then re-verifies against a fresh local recompute.
              # Local runs on the same host: there is NO independent reporting
              # boundary, so we do NOT emit a backend_result_hash (impl-review I11).
              # A misleading "reported == recomputed" would imply confirmation that
              # never happened. Remote backends (Thoa/TEE) DO report their own hash.
              backend_metadata: { 'job_id' => ref },
              container_digest: nil,
              attestation_doc: nil
            )
          end
        end
      end
    end
  end
end
