# frozen_string_literal: true

require_relative 'execution/backend'
require_relative 'execution/comparator'

module KairosMcp
  module SkillSets
    module GenomicschainTier2
      # Tier2Executor — the executed-R flow (design v0.3 §3).
      #
      #   backend.submit/poll/fetch -> GATE (verdict_admissible?) -> local
      #   result_hash recompute (§1a') -> backend/local divergence check (tamper)
      #   -> comparator -> verdict + trust_tier.
      #
      # Produces a VerdictResult (identity + verdict, NO operator/signature).
      # Signing, chain-recording and attestation are gc_tier2_submit's job
      # (design v0.3 §5'/§6') — this class does NOT sign or record.
      class Tier2Executor
        VerdictResult = Struct.new(
          :subject_ref, :jobspec_digest, :verdict, :trust_tier,
          :result_hash, :backend_result_hash, :expected_output, :expected_output_sha256,
          :expected_output_source, :expected_output_validated_by,
          :expected_output_source_citation, :expected_output_target,
          :comparator_id, :comparator_version, :backend_id, :output_files,
          :first_divergence, :receipt, keyword_init: true
        )

        # @param job_spec [Execution::JobSpec]
        # @param expected_output [Hash] {target, sha256, source, source_citation, validated_by}
        # @param backend [Execution::Backend]
        # @param comparator_id [String]
        # @param workdir [String] where the backend materializes outputs
        # @param trust_tier [String] MVP always 'self_reported'
        def self.run(job_spec:, expected_output:, backend:, workdir:,
                     comparator_id: 'exact_sha256', trust_tier: 'self_reported')
          base = {
            subject_ref: job_spec.subject_ref,
            jobspec_digest: job_spec.digest,
            trust_tier: trust_tier,
            expected_output: expected_output,
            expected_output_sha256: expected_output['sha256'] || expected_output[:sha256],
            expected_output_source: expected_output['source'] || expected_output[:source],
            expected_output_validated_by: expected_output['validated_by'] || expected_output[:validated_by],
            expected_output_source_citation: expected_output['source_citation'] || expected_output[:source_citation],
            expected_output_target: expected_output['target'] || expected_output[:target],
            backend_id: backend.id
          }

          ref = backend.submit(job_spec)
          state = backend.poll(ref)
          return terminal(base, 'env_failed') if state == :failed

          receipt = backend.fetch(ref, workdir)
          return terminal(base, 'env_failed', receipt) unless receipt.terminal_state == :done
          return terminal(base, 'outputs_unusable', receipt) unless receipt.verdict_admissible?

          # Local recompute (design v0.3 §1a') — do NOT trust the backend-reported hash.
          local_hash = KairosMcp::Manifest.tier2_result_hash(receipt.output_files)
          brh = receipt.backend_result_hash
          # Divergence between backend-reported and locally-recomputed => tamper/transport.
          return terminal(base.merge(result_hash: local_hash, backend_result_hash: brh,
                                     output_files: hashes_only(receipt.output_files)),
                          'env_failed', receipt) if brh && brh != local_hash

          cmp = Execution::Comparator.for(comparator_id)
                                     .compare(result_hash: local_hash,
                                              output_files: receipt.output_files,
                                              expected_output: expected_output)

          VerdictResult.new(
            **base,
            verdict: cmp.verdict,
            result_hash: local_hash,
            backend_result_hash: brh,
            comparator_id: cmp.comparator_id,
            comparator_version: cmp.comparator_version,
            output_files: hashes_only(receipt.output_files),
            first_divergence: cmp.first_divergence,
            receipt: receipt
          )
        end

        def self.terminal(base, verdict, receipt = nil)
          VerdictResult.new(
            **base, verdict: verdict,
            comparator_id: nil, comparator_version: nil,
            result_hash: base[:result_hash], backend_result_hash: base[:backend_result_hash],
            output_files: base[:output_files], first_divergence: nil, receipt: receipt
          )
        end

        def self.hashes_only(output_files)
          (output_files || []).map do |f|
            h = f.transform_keys(&:to_s)
            { 'sha256' => h['sha256'], 'relative_path' => h['relative_path'], 'size_bytes' => h['size_bytes'] }.compact
          end
        end
      end
    end
  end
end
