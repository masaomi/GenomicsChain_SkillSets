# frozen_string_literal: true

require 'digest'
require 'json'

module KairosMcp
  module SkillSets
    module GenomicschainCore
      module VerdictSpec
        # Tier3VerdictSpec — tier-3 hooks for SubmitCore (design v0.4.1 §4.4).
        class Tier3
          # Record 0.3: `verdict` is gone, replaced by the two independent axes.
          # environment_provenance / inputs_provenance / run_count are SIGNED,
          # not merely recorded: they are precisely the fields a certificate
          # would be tempted to overstate ("the declared environment" when the
          # operator authored it, "reproducible" from a single run), so they
          # must be non-repudiable alongside the verdict itself.
          SIGNED_IDENTITY_FIELDS = %w[
            subject_ref jobspec_digest execution_verdict comparison_verdict
            trust_tier result_hash
            environment_provenance inputs_provenance run_count
            expected_output_sha256 expected_output_source expected_output_validated_by
            expected_output_source_citation expected_output_target
            comparator_id comparator_version backend_id
          ].freeze

          MCP_TOOL = 'gc_tier3_submit'

          def initialize(verdict_result:, jobspec_json:, expected_output:)
            @vr = verdict_result
            @jobspec_json = jobspec_json
            @expected_output = expected_output
          end

          attr_reader :vr, :expected_output

          def subject_ref
            @vr.subject_ref
          end

          def parse_digest_subject!
            JSON.parse(@jobspec_json)
          rescue JSON::ParserError => e
            raise SubmitCore::DigestMismatch, "jobspec_json is not valid JSON: #{e.message}"
          end

          def recompute_digest!(parsed)
            KairosMcp::Manifest.canonical_json_sha256(parsed)
          end

          def claimed_digest
            @vr.jobspec_digest
          end

          def signed_identity_params
            SIGNED_IDENTITY_FIELDS.each_with_object({}) { |f, h| h[f] = @vr[f.to_sym] }
          end

          # A run with no comparison target submits no expected_output. That is
          # the common case (0/5 in the 2026-08-14 survey), so absence is valid
          # — but absence on ONE side only is a mismatch, not a shortcut: a
          # submitter must not drop the target after signing one, nor attach a
          # target the signature never covered.
          def assert_submitted_matches_signed!
            eo = (@expected_output || {}).transform_keys(&:to_s)
            signed_target = @vr.expected_output_sha256
            return if eo.empty? && signed_target.nil?

            if eo.empty? != signed_target.nil?
              raise SubmitCore::IdentityMismatch,
                    "expected_output presence differs from the signed identity " \
                    "(submitted=#{eo.empty? ? 'absent' : 'present'}, " \
                    "signed=#{signed_target.nil? ? 'absent' : 'present'})"
            end

            {
              'sha256' => @vr.expected_output_sha256,
              'source' => @vr.expected_output_source,
              'validated_by' => @vr.expected_output_validated_by,
              'source_citation' => @vr.expected_output_source_citation,
              'target' => @vr.expected_output_target
            }.each do |k, signed_val|
              next if eo[k] == signed_val

              raise SubmitCore::IdentityMismatch,
                    "expected_output.#{k} (#{eo[k].inspect}) != signed (#{signed_val.inspect})"
            end
          end

          def reject_client_server_set_fields!(_payload)
            # Tier-3 has no client-supplied server-set fields beyond leaderboard_eligible.
          end

          def server_set_fields(pubkey)
            { 'leaderboard_eligible' => leaderboard_eligible?(pubkey) }
          end

          def build_manifest(operator:, submission_key:, server_fields:)
            result_bundle = {
              'backend_id' => @vr.backend_id,
              'backend_result_hash' => @vr.backend_result_hash,
              'local_result_hash' => @vr.result_hash,
              'jobspec_digest' => @vr.jobspec_digest,
              'output_files' => (@vr.output_files || [])
            }.compact
            result_evidence_sha256 = Digest::SHA256.hexdigest(
              KairosMcp::Manifest.canonical_json(result_bundle)
            )

            record = KairosMcp::Manifest.build_tier3_verdict(
              'subject_ref' => @vr.subject_ref,
              'jobspec_digest' => @vr.jobspec_digest,
              'execution_verdict' => @vr.execution_verdict,
              'comparison_verdict' => @vr.comparison_verdict,
              'environment_provenance' => @vr.environment_provenance,
              'inputs_provenance' => @vr.inputs_provenance,
              'run_count' => @vr.run_count,
              'self_consistency' => @vr.self_consistency,
              'trust_tier' => @vr.trust_tier,
              'result_hash' => @vr.result_hash,
              'backend_result_hash' => @vr.backend_result_hash,
              'expected_output' => (@expected_output.nil? || @expected_output.empty? ? nil : @expected_output),
              'comparator_id' => @vr.comparator_id,
              'comparator_version' => @vr.comparator_version,
              'backend_id' => @vr.backend_id,
              'container_digest' => @vr.container_digest,
              'output_files' => @vr.output_files,
              'result_evidence_sha256' => result_evidence_sha256,
              'leaderboard_eligible' => server_fields['leaderboard_eligible'],
              'submission_key' => submission_key,
              'operator' => operator
            )
            KairosMcp::Manifest.validate_tier3!(record)
            record
          end

          # Both axes appear in the claim string. A claim carrying only "did it
          # run" would read as a reproduction claim to anyone scanning the
          # registry, which is the misreading this whole split exists to stop.
          def claim_for(submission_key:)
            "tier3:#{@vr.execution_verdict}:#{@vr.comparison_verdict}:#{@vr.result_hash}:#{submission_key}"
          end

          def trust_tier_gate!
            return if @vr.trust_tier == 'self_reported'

            raise SubmitCore::TrustTierError,
                  "MVP admits only trust_tier=self_reported (got #{@vr.trust_tier.inspect})"
          end

          def apply_gates!(parsed_jobspec)
            KairosMcp::Manifest.dos_gate!(parsed_jobspec)
            KairosMcp::Manifest.restricted_subset!(parsed_jobspec)
            return if @expected_output.nil? || @expected_output.empty?

            KairosMcp::Manifest.dos_gate!(@expected_output)
            KairosMcp::Manifest.restricted_subset!(@expected_output)
          end

          def extra_result_fields
            { leaderboard_eligible: server_set_fields(nil)['leaderboard_eligible'],
              result_evidence_sha256: nil }
          end

          private

          MATCHED = %w[match_exact match_normalized].freeze

          # Deliberately unreachable for a paper that declares no comparison
          # target — which was every paper in the 2026-08-14 survey. The strong
          # claim is NOT relaxed to make the leaderboard non-empty; an empty
          # leaderboard is the honest reading of the literature, and a
          # certificate that stretched to fill it would be worth nothing.
          def leaderboard_eligible?(_pubkey)
            citation = @vr.expected_output_source_citation
            @vr.execution_verdict == 'completed' &&
              MATCHED.include?(@vr.comparison_verdict) &&
              @vr.expected_output_source == 'paper_declared' &&
              !citation.nil? && !citation.to_s.empty?
          end
        end
      end
    end
  end
end
