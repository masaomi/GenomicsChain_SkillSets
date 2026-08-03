# frozen_string_literal: true

require 'json'
require_relative '../b1_manifest_hash'
require_relative '../report_content_hash'

module KairosMcp
  module SkillSets
    module GenomicschainCore
      module VerdictSpec
        # Tier1VerdictSpec — Tier-1 hooks for SubmitCore (design v0.4.1 §4.4, §5.2).
        class Tier1
          BASE_SIGNED_FIELDS = %w[
            canonical_id.value
            rubric_version
            rubric_hash
            report_content_hash
            funnel_stage
            headline.static_readiness
            assessor_id
            assessor_stack.operator_id
            assessor_stack.llm.provider
            assessor_stack.llm.model
            assessor_stack.llm.invoked_at
            assessor_stack.stage
          ].freeze

          MCP_TOOL = 'gc_tier1_submit'
          REPORT_JSON_MAX_BYTES = 2 * 1024 * 1024

          def initialize(report_json:, operator:)
            @report_json = report_json
            @operator = operator
            @report = nil
            @content_hash = nil
          end

          attr_reader :report

          def subject_ref
            doi = @report.dig('canonical_id', 'value')
            raise SubmitCore::SubmitError, 'canonical_id.value missing' if doi.nil? || doi.empty?

            "doi:#{doi}"
          end

          def parse_digest_subject!
            gate_a!(@report_json)
            @report = JSON.parse(@report_json)
          rescue JSON::ParserError => e
            raise SubmitCore::DigestMismatch, "report_json is not valid JSON: #{e.message}"
          end

          def recompute_digest!(_parsed)
            B1ManifestHash.assert_matches!(@report)
            @content_hash = ReportContentHash.compute(@report)
          end

          def claimed_digest
            claimed = @report['report_content_hash']
            if claimed.nil? || claimed.to_s.empty?
              raise SubmitCore::DigestMismatch, 'report_content_hash missing from report_json'
            end

            claimed.to_s
          end

          def signed_identity_params
            self.class.signed_params_for(@report, @content_hash)
          end

          def assert_submitted_matches_signed!
            signed = signed_identity_params
            signed.each do |path, expected|
              actual = dig_path(@report, path)
              next if actual == expected

              raise SubmitCore::IdentityMismatch,
                    "#{path} (#{actual.inspect}) != signed (#{expected.inspect})"
            end
          end

          def reject_client_server_set_fields!(report)
            if report.key?('trust_tier')
              raise SubmitCore::TrustTierError, 'trust_tier is server-set; must not appear in report_json'
            end
          end

          def server_set_fields(_pubkey)
            { 'trust_tier' => 'self_reported' }
          end

          def build_manifest(operator:, submission_key:, server_fields:)
            record = KairosMcp::Manifest.build_tier1_report(
              'subject_ref' => subject_ref,
              'report_content_hash' => @content_hash,
              'canonical_id_value' => @report.dig('canonical_id', 'value'),
              'rubric_version' => @report['rubric_version'],
              'rubric_hash' => @report['rubric_hash'],
              'headline' => @report['headline'],
              'funnel_stage' => @report['funnel_stage'],
              'assessor_stack' => @report['assessor_stack'],
              'assessor_id' => @report['assessor_id'],
              'manifest_b1_hash' => @report.dig('manifest', 'b1_manifest_hash'),
              'manifest_supersedes' => @report.dig('manifest', 'supersedes'),
              'trust_tier' => server_fields['trust_tier'],
              'submission_key' => submission_key,
              'operator' => operator
            )
            KairosMcp::Manifest.validate_tier1!(record)
            record
          end

          def claim_for(submission_key:)
            readiness = @report.dig('headline', 'static_readiness').to_s
            "tier1:#{readiness}:#{@content_hash}:#{submission_key}"
          end

          def trust_tier_gate!
            # trust_tier is server-set on the wrapper; report body must not carry it.
          end

          def apply_gates!(parsed_report)
            KairosMcp::Manifest.dos_gate!(parsed_report)
            KairosMcp::Manifest.restricted_subset!(parsed_report)
            validate_required_shape!(parsed_report)
            begin
              KairosMcp::Manifest.validate_report_body!(parsed_report)
            rescue KairosMcp::Manifest::SchemaViolation => e
              raise SubmitCore::SubmitError, e.message
            end
          end

          class << self
            def signed_field_paths(report)
              paths = BASE_SIGNED_FIELDS.dup
              sup = report.dig('manifest', 'supersedes')
              paths << 'manifest.supersedes' if sup && !sup.to_s.empty?
              paths
            end

            def signed_params_for(report, content_hash)
              report = report.transform_keys(&:to_s)
              report = report.merge('report_content_hash' => content_hash) unless content_hash.nil?
              signed_field_paths(report).each_with_object({}) do |path, acc|
                acc[path] = dig_path(report, path)
              end
            end

            def dig_path(obj, path)
              path.split('.').reduce(obj) do |cur, key|
                break nil if cur.nil?

                cur.is_a?(Hash) ? (cur[key] || cur[key.to_sym]) : nil
              end
            end

            def gate_a!(raw)
              size = raw.bytesize
              return if size <= REPORT_JSON_MAX_BYTES

              raise SubmitCore::EvidenceTooLarge,
                    "report_json size #{size} exceeds Gate A limit #{REPORT_JSON_MAX_BYTES}"
            end
          end

          private

          def dig_path(obj, path)
            self.class.dig_path(obj, path)
          end

          def gate_a!(raw)
            self.class.gate_a!(raw)
          end

          def validate_required_shape!(report)
            %w[rubric_version rubric_hash funnel_stage assessor_id assessed_at assessor_stack headline manifest].each do |k|
              unless report.key?(k) && !(report[k].nil? || (report[k].respond_to?(:empty?) && report[k].empty?))
                raise SubmitCore::SubmitError, "report_json missing required field #{k}"
              end
            end
            stack = report['assessor_stack']
            unless stack.is_a?(Hash) && stack.dig('llm', 'provider')
              raise SubmitCore::SubmitError, 'report_json missing assessor_stack.llm.provider'
            end
          end
        end
      end
    end
  end
end
