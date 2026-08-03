# frozen_string_literal: true

require 'digest'
require 'json'

module KairosMcp
  module SkillSets
    module GenomicschainCore
      module VerdictSpec
        # Tier2VerdictSpec — tier-2 hooks for SubmitCore (design v0.4.1 §4.4).
        class Tier2
          SIGNED_IDENTITY_FIELDS = %w[
            subject_ref jobspec_digest verdict trust_tier result_hash
            expected_output_sha256 expected_output_source expected_output_validated_by
            expected_output_source_citation expected_output_target
            comparator_id comparator_version backend_id
          ].freeze

          MCP_TOOL = 'gc_tier2_submit'

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

          def assert_submitted_matches_signed!
            eo = @expected_output.transform_keys(&:to_s)
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
            # Tier-2 has no client-supplied server-set fields beyond leaderboard_eligible.
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

            record = KairosMcp::Manifest.build_tier2_verdict(
              'subject_ref' => @vr.subject_ref,
              'jobspec_digest' => @vr.jobspec_digest,
              'verdict' => @vr.verdict,
              'trust_tier' => @vr.trust_tier,
              'result_hash' => @vr.result_hash,
              'backend_result_hash' => @vr.backend_result_hash,
              'expected_output' => @expected_output,
              'comparator_id' => @vr.comparator_id,
              'comparator_version' => @vr.comparator_version,
              'backend_id' => @vr.backend_id,
              'output_files' => @vr.output_files,
              'result_evidence_sha256' => result_evidence_sha256,
              'leaderboard_eligible' => server_fields['leaderboard_eligible'],
              'submission_key' => submission_key,
              'operator' => operator
            )
            KairosMcp::Manifest.validate_tier2!(record)
            record
          end

          def claim_for(submission_key:)
            "tier2:#{@vr.verdict}:#{@vr.result_hash}:#{submission_key}"
          end

          def trust_tier_gate!
            return if @vr.trust_tier == 'self_reported'

            raise SubmitCore::TrustTierError,
                  "MVP admits only trust_tier=self_reported (got #{@vr.trust_tier.inspect})"
          end

          def apply_gates!(parsed_jobspec)
            KairosMcp::Manifest.dos_gate!(parsed_jobspec)
            KairosMcp::Manifest.restricted_subset!(parsed_jobspec)
            KairosMcp::Manifest.dos_gate!(@expected_output)
            KairosMcp::Manifest.restricted_subset!(@expected_output)
          end

          def extra_result_fields
            { leaderboard_eligible: server_set_fields(nil)['leaderboard_eligible'],
              result_evidence_sha256: nil }
          end

          private

          def leaderboard_eligible?(_pubkey)
            citation = @vr.expected_output_source_citation
            @vr.expected_output_source == 'paper_declared' &&
              !citation.nil? && !citation.to_s.empty?
          end
        end
      end
    end
  end
end
