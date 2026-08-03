# frozen_string_literal: true

# Completed-report digest for Tier-1 submit (design v0.4.1 §5.2).
#
# Exclusions (closed list): manifest.chain_record, report_content_hash itself.
# All other fields — including manifest.b1_manifest_hash and manifest.supersedes —
# participate in the digest.
module KairosMcp
  module SkillSets
    module GenomicschainCore
      module ReportContentHash
        EXCLUDED_MANIFEST_KEYS = %w[chain_record].freeze

        module_function

        def digest_input(report)
          copy = deep_dup_hash(report)
          copy.delete('report_content_hash')
          if copy['manifest'].is_a?(Hash)
            m = copy['manifest'].transform_keys(&:to_s)
            EXCLUDED_MANIFEST_KEYS.each { |k| m.delete(k) }
            copy['manifest'] = m
          end
          copy
        end

        def compute(report)
          KairosMcp::Manifest.canonical_json_sha256(digest_input(report))
        end

        def deep_dup_hash(obj)
          case obj
          when Hash
            obj.each_with_object({}) do |(k, v), acc|
              acc[k.to_s] = deep_dup_hash(v)
            end
          when Array
            obj.map { |v| deep_dup_hash(v) }
          else
            obj
          end
        end
      end
    end
  end
end
