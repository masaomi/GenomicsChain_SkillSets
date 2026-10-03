# frozen_string_literal: true

require 'json'

module KairosMcp
  module SkillSets
    module GenomicschainCore
      module VerdictSpec
        # Tier4 — the distillation record's hooks for SubmitCore
        # (self-application design §7.3, O-2 (a)). Not deployed to production
        # in v0.1: no gc_tier4_submit tool is registered, and nothing outside
        # tests calls this class until S9.
        #
        # The digest subject is the package's file list: SubmitCore recomputes
        # the package digest from it (the S−1 tree rule) and refuses a record
        # whose claimed digest differs. The signed identity is what a reader
        # would rely on — which Skill, judged under which fixed conditions, by
        # which Tier-3 runs, with which verdicts — so a submitter cannot sign
        # one judgment and record another.
        class Tier4
          SIGNED_IDENTITY_FIELDS = %w[
            subject_ref stage package_digest acceptance_sha256 distiller_model
            source_jobspec_digest source_result_hash
            reversion_jobspec_digest reversion_result_hash
            reversion_execution_verdict reversion_comparison_verdict reversion_expected_output_sha256
            other_data_performed other_data_seed other_data_reference_sha256
            other_data_jobspec_digest other_data_result_hash
            other_data_execution_verdict other_data_comparison_verdict
            trust_tier
          ].freeze

          MCP_TOOL = 'gc_tier4_submit'

          # @param distillation [Hash] the builder input (see Manifest::Tier4Builder)
          # @param package_files_json [String] JSON array of {relative_path, sha256}
          def initialize(distillation:, package_files_json:)
            @d = Manifest::Tier4Builder.deep_strings(distillation)
            @package_files_json = package_files_json
          end

          def subject_ref
            @d['subject_ref']
          end

          def parse_digest_subject!
            files = JSON.parse(@package_files_json)
            raise SubmitCore::DigestMismatch, 'package_files_json must be a non-empty array' unless files.is_a?(Array) && !files.empty?

            files
          rescue JSON::ParserError => e
            raise SubmitCore::DigestMismatch, "package_files_json is not valid JSON: #{e.message}"
          end

          def recompute_digest!(parsed)
            Manifest::Tier4Builder.package_digest(parsed)
          end

          def claimed_digest
            @d['package_digest']
          end

          def signed_identity_params
            src = @d['source'] || {}
            rev = @d['reversion'] || {}
            oth = @d['other_data'] || {}
            {
              'subject_ref' => @d['subject_ref'], 'stage' => @d['stage'], 'package_digest' => @d['package_digest'],
              'acceptance_sha256' => @d.dig('acceptance', 'sha256'), 'distiller_model' => @d.dig('distiller', 'model'),
              'source_jobspec_digest' => src['jobspec_digest'], 'source_result_hash' => src['result_hash'],
              'reversion_jobspec_digest' => rev['jobspec_digest'], 'reversion_result_hash' => rev['result_hash'],
              'reversion_execution_verdict' => rev['execution_verdict'],
              'reversion_comparison_verdict' => rev['comparison_verdict'],
              'reversion_expected_output_sha256' => rev['expected_output_sha256'],
              'other_data_performed' => oth['performed'], 'other_data_seed' => oth['seed'],
              'other_data_reference_sha256' => oth['reference_sha256'],
              'other_data_jobspec_digest' => oth['jobspec_digest'], 'other_data_result_hash' => oth['result_hash'],
              'other_data_execution_verdict' => oth['execution_verdict'],
              'other_data_comparison_verdict' => oth['comparison_verdict'],
              'trust_tier' => @d['trust_tier'] || 'self_reported'
            }
          end

          # The package list must be the one the distillation names: SubmitCore
          # checked the digest against the claim, this checks the claim against
          # the files the record will carry.
          def assert_submitted_matches_signed!
            files = @d['package_files']
            return if files.nil?
            return if Manifest::Tier4Builder.package_digest(files) == @d['package_digest']

            raise SubmitCore::IdentityMismatch, 'package_files in the distillation do not hash to package_digest'
          end

          # The pass flags and leaderboard eligibility are derived or server-set;
          # a client that sends them is trying to write its own verdict.
          def reject_client_server_set_fields!(_parsed)
            supplied = Manifest::Tier4Builder::DERIVED_FIELDS & @d.keys
            return if supplied.empty?

            raise SubmitCore::IdentityMismatch, "client-supplied derived field(s): #{supplied.join(', ')}"
          end

          def server_set_fields(_pubkey)
            { 'leaderboard_eligible' => false }
          end

          def build_manifest(operator:, submission_key:, server_fields:)
            raise SubmitCore::IdentityMismatch, 'a distillation is never leaderboard-eligible' unless server_fields['leaderboard_eligible'] == false

            record = Manifest.build_tier4_distillation(
              @d.merge('operator' => operator, 'submission_key' => submission_key)
            )
            Manifest.validate_tier4!(record)
            record
          end

          # Both checks appear in the claim, the reversion first. A claim that
          # carried only "passed" would hide that one check may not have been run.
          def claim_for(submission_key:)
            other = if @d.dig('other_data', 'performed') == true
                      Manifest::Tier4Builder.passed?(@d['other_data']) ? 'passed' : 'failed'
                    else
                      'not_performed'
                    end
            reversion = Manifest::Tier4Builder.passed?(@d['reversion'] || {}) ? 'passed' : 'failed'
            "tier4:#{@d['stage']}:reversion_#{reversion}:other_data_#{other}:#{@d['package_digest']}:#{submission_key}"
          end

          def trust_tier_gate!
            tier = @d['trust_tier'] || 'self_reported'
            return if tier == 'self_reported'

            raise SubmitCore::TrustTierError, "MVP admits only trust_tier=self_reported (got #{tier.inspect})"
          end

          def apply_gates!(parsed_files)
            KairosMcp::Manifest.dos_gate!(parsed_files)
            KairosMcp::Manifest.restricted_subset!(parsed_files)
            KairosMcp::Manifest.dos_gate!(@d)
            KairosMcp::Manifest.restricted_subset!(@d)
          end
        end
      end
    end
  end
end
