# frozen_string_literal: true

module KairosMcp
  module SkillSets
    module GenomicschainTier2
      module Execution
        # ExecutionBackend interface (design v0.3 §2).
        #
        # The ONE abstraction built up front. Thin + async-capable: genomics
        # jobs run for hours, so submit/poll/fetch are separated (the legacy
        # gc_run_fastqc 30-min sync Timeout is too short for Tier-2).
        #
        # Implementations:
        #   - ThoaBackend (default, this slice) — managed cloud via thoa CLI.
        #   - LocalBackend / AwsEc2Backend — wrap submit+poll+fetch synchronously (later).
        #   - AwsTeeBackend (future) — attestation_kind => :tee_hardware, slots in
        #     WITHOUT reworking the job/attestation model (Receipt already carries
        #     attestation_doc).
        #
        # fetch returns a VALIDATED Receipt (design v0.3 §1a'/§2/T6): a verdict is
        # computed only after terminal_state == :done && exit_code == 0 && outputs
        # complete. The runner recomputes result_hash locally from Receipt.output_files
        # (Manifest.tier2_result_hash); divergence from backend_result_hash => env_failed.
        class Backend
          class BackendError < StandardError; end

          # @return [String] backend id: "thoa" | "aws_ec2" | "local" | "aws_tee"
          def id
            raise NotImplementedError, "#{self.class}#id"
          end

          # @param job_spec [JobSpec]
          # @return [String, Hash] a backend job reference (opaque handle)
          def submit(_job_spec)
            raise NotImplementedError, "#{self.class}#submit"
          end

          # @param backend_job_ref
          # @return [Symbol] :queued | :running | :done | :failed
          def poll(_backend_job_ref)
            raise NotImplementedError, "#{self.class}#poll"
          end

          # @param backend_job_ref
          # @param dst [String] local directory to receive outputs
          # @return [Receipt]
          def fetch(_backend_job_ref, _dst)
            raise NotImplementedError, "#{self.class}#fetch"
          end

          # @return [Symbol] :self_reported_hash (thoa/ec2/local) | :tee_hardware (future)
          def attestation_kind
            :self_reported_hash
          end
        end

        # Receipt — the validated result of an execution (design v0.3 §2/§1a').
        # output_files entries are {sha256, relative_path, size_bytes}, feeding
        # Manifest.tier2_result_hash for the local result_hash recompute.
        Receipt = Struct.new(
          :terminal_state,          # :done | :failed
          :process_exit_code,       # Integer | nil
          :backend_reported_status, # raw backend status string
          :stdout_sha256,
          :stderr_sha256,
          :output_files,            # Array<Hash{sha256,relative_path,size_bytes}>
          :artifact_manifest_sha256,
          :backend_metadata,        # Hash{job_id, backend_result_hash?, ...}
          :container_digest,
          :attestation_doc,         # TEE only; nil otherwise
          keyword_init: true
        ) do
          # Output-completeness precondition (design v0.3 §2/T6): a verdict may
          # only be computed when the job terminated successfully AND produced a
          # non-empty output set. Returns true when a verdict is admissible.
          def verdict_admissible?
            terminal_state == :done &&
              (process_exit_code.nil? || process_exit_code.zero?) &&
              !output_files.nil? && !output_files.empty?
          end

          def backend_result_hash
            backend_metadata && (backend_metadata['backend_result_hash'] ||
                                 backend_metadata[:backend_result_hash])
          end
        end

        # JobSpec — resolved from a Stage-2 report (design v0.3 §3). env from
        # Lever-1 lock/digest; data from Lever-2 pins + liveness accessions;
        # pipeline from steps[] + step_source. jobspec_digest = sha256(canonical).
        JobSpec = Struct.new(
          :subject_ref,     # "repro://656122/C9"
          :env,             # {lock:, container_digest:} (Lever-1)
          :data,            # {pins:[], accessions:[]} (Lever-2 + liveness)
          :pipeline,        # {steps:[], step_source:}
          :backend_id,
          :resources,       # {n_cores:, ram_gb:, storage_gb:}
          keyword_init: true
        ) do
          # Canonical digest of the spec (env + data + pins + pipeline). Uses the
          # same canonical JSON as the rest of the manifest layer so the server
          # can RECOMPUTE and validate it (design v0.3 §5'(e)).
          def digest
            KairosMcp::Manifest.canonical_json_sha256(
              'subject_ref' => subject_ref,
              'env' => stringify(env),
              'data' => stringify(data),
              'pipeline' => stringify(pipeline)
            )
          end

          def canonical_json
            KairosMcp::Manifest.canonical_json(
              'subject_ref' => subject_ref,
              'env' => stringify(env),
              'data' => stringify(data),
              'pipeline' => stringify(pipeline)
            )
          end

          private

          def stringify(obj)
            case obj
            when Hash then obj.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify(v) }
            when Array then obj.map { |v| stringify(v) }
            else obj
            end
          end
        end
      end
    end
  end
end
