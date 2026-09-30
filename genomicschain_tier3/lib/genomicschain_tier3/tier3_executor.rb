# frozen_string_literal: true

require_relative 'execution/backend'
require_relative 'execution/comparator'
require_relative 'execution/local_backend'

module KairosMcp
  module SkillSets
    module GenomicschainTier3
      # Tier3Executor — the executed-R flow, record 0.3.
      #
      #   for each run: backend.submit/poll/fetch -> GATE (verdict_admissible?)
      #     -> local result_hash recompute -> backend/local divergence check
      #   then: comparator (if a target exists) + run-to-run agreement (if >1 run)
      #     -> execution_verdict + comparison_verdict
      #
      # Two verdict axes, not one. "Did it run" and "did it match" are
      # independent, and the 2026-08-14 corpus survey found 0/5 gate-passing
      # papers declaring a comparison target — so most real runs answer the
      # first question and legitimately have nothing to say about the second.
      #
      # Produces a VerdictResult (identity + verdicts, NO operator/signature).
      # Signing, chain-recording and attestation are gc_tier3_submit's job.
      class Tier3Executor
        VerdictResult = Struct.new(
          :subject_ref, :jobspec_digest, :execution_verdict, :comparison_verdict,
          :environment_provenance, :inputs_provenance, :run_count, :self_consistency,
          :trust_tier, :result_hash, :backend_result_hash, :container_digest,
          :expected_output, :expected_output_sha256,
          :expected_output_source, :expected_output_validated_by,
          :expected_output_source_citation, :expected_output_target,
          :comparator_id, :comparator_version, :backend_id, :output_files,
          :first_divergence, :receipt, :receipts, keyword_init: true
        )

        # @param job_spec [Execution::JobSpec] canonical spec; its digest is the recorded identity
        # @param backend [Execution::Backend]
        # @param workdirs [Array<String>] one directory per run. Length IS run_count.
        #   Separate directories are required rather than reusing one, because a
        #   second run into a populated directory would hash the first run's
        #   outputs and report agreement that never happened.
        # @param expected_output [Hash, nil] {target, sha256, source, ...}; nil when
        #   the paper declares no comparison target (the common case)
        # @param inputs_provenance [String] where the inputs came from; never guessed
        # @param environment_provenance [String, nil] nil => derived from the JobSpec.
        #   Pass 'authored_by_operator' explicitly when the operator built an
        #   environment the paper did not supply — that cannot be derived, and a
        #   certificate must not present it as the declared environment.
        def self.run(job_spec:, backend:, workdirs:, expected_output: nil,
                     comparator_id: 'exact_sha256', trust_tier: 'self_reported',
                     inputs_provenance: 'unknown', environment_provenance: nil,
                     variation: 'same_environment')
          dirs = Array(workdirs)
          raise ArgumentError, 'at least one workdir is required' if dirs.empty?
          if dirs.uniq.length != dirs.length
            raise ArgumentError, 'workdirs must be distinct: a repeat run into a populated ' \
                                 'directory would re-hash the previous run and fake agreement'
          end

          eo = expected_output || {}
          base = {
            subject_ref: job_spec.subject_ref,
            jobspec_digest: job_spec.digest,
            trust_tier: trust_tier,
            run_count: dirs.length,
            inputs_provenance: inputs_provenance,
            environment_provenance: environment_provenance || derive_environment_provenance(job_spec),
            container_digest: container_digest_of(job_spec),
            expected_output: (eo.empty? ? nil : eo),
            expected_output_sha256: eo['sha256'] || eo[:sha256],
            expected_output_source: eo['source'] || eo[:source],
            expected_output_validated_by: eo['validated_by'] || eo[:validated_by],
            expected_output_source_citation: eo['source_citation'] || eo[:source_citation],
            expected_output_target: eo['target'] || eo[:target],
            backend_id: backend.id
          }

          receipts = []
          hashes = []

          dirs.each do |wd|
            spec = spec_for(job_spec, wd)
            ref = backend.submit(spec)
            return terminal(base, 'env_failed') if backend.poll(ref) == :failed

            receipt = backend.fetch(ref, wd)
            return terminal(base, 'env_failed', receipt) unless receipt.terminal_state == :done
            return terminal(base, 'outputs_unusable', receipt) unless receipt.verdict_admissible?

            # Local recompute — do NOT trust the backend-reported hash.
            local_hash = KairosMcp::Manifest.tier3_result_hash(receipt.output_files)
            brh = receipt.backend_result_hash
            if brh && brh != local_hash
              # Backend says one thing, our recompute says another: transport or
              # backend tamper, not a comparison outcome.
              return terminal(
                base.merge(result_hash: local_hash, backend_result_hash: brh,
                           output_files: hashes_only(receipt.output_files)),
                'env_failed', receipt
              )
            end

            receipts << receipt
            hashes << local_hash
          end

          first = receipts.first
          cmp, self_consistency = compare_runs(hashes, first.output_files, eo, comparator_id, variation)

          VerdictResult.new(
            **base,
            execution_verdict: 'completed',
            comparison_verdict: cmp.comparison_verdict,
            self_consistency: self_consistency,
            result_hash: hashes.first,
            backend_result_hash: first.backend_result_hash,
            comparator_id: cmp.comparator_id,
            comparator_version: cmp.comparator_version,
            output_files: hashes_only(first.output_files),
            first_divergence: cmp.first_divergence,
            receipt: first,
            receipts: receipts
          )
        end

        # The comparison half of `run`, applied to directories a run already
        # filled and that were then frozen (self-application design §6.4, Tier 3:
        # the DDC compares these on both sides without executing anything). It
        # returns the comparison fields only: no VerdictResult, no
        # execution_verdict, because nothing was executed here (INV-S7).
        def self.compare_frozen(workdirs:, expected_output: nil, comparator_id: 'exact_sha256',
                                variation: 'same_environment')
          dirs = Array(workdirs)
          raise ArgumentError, 'at least one workdir is required' if dirs.empty?
          dirs.each { |wd| raise ArgumentError, "workdir does not exist: #{wd}" unless Dir.exist?(wd) }
          # Two spellings of one directory would hash it twice and report agreement.
          raise ArgumentError, 'workdirs must be distinct' if dirs.map { |d| File.realpath(d) }.uniq.length != dirs.length

          files = dirs.map { |wd| Execution::LocalBackend.output_files_of(wd) }
          hashes = files.map { |f| KairosMcp::Manifest.tier3_result_hash(f) }
          cmp, self_consistency = compare_runs(hashes, files.first, expected_output || {}, comparator_id, variation)
          {
            'run_count' => dirs.length, 'result_hash' => hashes.first, 'output_files' => hashes_only(files.first),
            'comparison_verdict' => cmp.comparison_verdict, 'comparator_id' => cmp.comparator_id,
            'comparator_version' => cmp.comparator_version, 'first_divergence' => cmp.first_divergence,
            'self_consistency' => self_consistency
          }
        end

        def self.compare_runs(hashes, first_output_files, expected_output, comparator_id, variation)
          cmp = if Execution::Comparator.target?(expected_output)
                  Execution::Comparator.for(comparator_id)
                                       .compare(result_hash: hashes.first,
                                                output_files: first_output_files,
                                                expected_output: expected_output)
                else
                  Execution::Comparator.no_target
                end
          self_consistency =
            if hashes.length > 1
              Execution::Comparator.agreement(run_result_hashes: hashes, variation: variation)
            end
          [cmp, self_consistency]
        end

        # A run that never completed has no comparison to report — that is
        # `not_attempted`, which is distinct from `no_target_declared` (there
        # may well have been a target; we never got far enough to use it).
        def self.terminal(base, execution_verdict, receipt = nil)
          VerdictResult.new(
            **base,
            execution_verdict: execution_verdict,
            comparison_verdict: 'not_attempted',
            self_consistency: nil,
            comparator_id: nil, comparator_version: nil,
            result_hash: base[:result_hash], backend_result_hash: base[:backend_result_hash],
            output_files: base[:output_files], first_divergence: nil,
            receipt: receipt, receipts: [receipt].compact
          )
        end

        # Which pinned artifact the environment came from. 'authored_by_operator'
        # is intentionally NOT derivable: only the operator knows they built an
        # environment the paper did not supply, and that distinction is the one a
        # certificate is most tempted to blur.
        def self.derive_environment_provenance(job_spec)
          env = stringify(job_spec.env)
          pipeline = stringify(job_spec.pipeline)
          return 'declared_container' if present?(env['container_digest'])
          return 'declared_lock'      if present?(env['lock']) || present?(env['env_id'])
          return 'declared_tools'     if present?(pipeline['tools'])

          'none'
        end

        def self.container_digest_of(job_spec)
          digest = stringify(job_spec.env)['container_digest']
          digest.to_s =~ /\Asha256:[a-f0-9]{64}\z/ ? digest.to_s : nil
        end

        # Per-run execution directory. The recorded jobspec_digest is the
        # caller's canonical spec, so repeats are of one identity rather than N.
        #
        # NOTE (pre-existing, not fixed here): JobSpec#digest covers `pipeline`,
        # which carries workdir/download_dir — so the recorded digest embeds a
        # local path and the same job digests differently on another machine.
        # Queued, not changed in this revision.
        def self.spec_for(job_spec, workdir)
          pipeline = stringify(job_spec.pipeline)
          key = pipeline.key?('download_dir') ? 'download_dir' : 'workdir'
          return job_spec if pipeline[key].to_s == workdir.to_s

          Execution::JobSpec.new(
            subject_ref: job_spec.subject_ref, env: job_spec.env, data: job_spec.data,
            pipeline: pipeline.merge(key => workdir),
            backend_id: job_spec.backend_id, resources: job_spec.resources
          )
        end

        def self.hashes_only(output_files)
          (output_files || []).map do |f|
            h = f.transform_keys(&:to_s)
            { 'sha256' => h['sha256'], 'relative_path' => h['relative_path'], 'size_bytes' => h['size_bytes'] }.compact
          end
        end

        def self.present?(value)
          !value.nil? && !value.to_s.strip.empty?
        end

        def self.stringify(obj)
          obj.is_a?(Hash) ? obj.each_with_object({}) { |(k, v), h| h[k.to_s] = v } : {}
        end
      end
    end
  end
end
