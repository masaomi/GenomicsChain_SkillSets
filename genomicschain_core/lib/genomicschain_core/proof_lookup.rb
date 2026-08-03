# frozen_string_literal: true

require 'json'

module KairosMcp
  module SkillSets
    module GenomicschainCore
      # ProofLookup — scan Synoptis proofs for GenomicsChain domain records.
      module ProofLookup
        class << self
          def find_by_submission_key(registry, submission_key)
            registry.read(:proofs).reverse_each do |record|
              manifest = parse_manifest_from_record(record)
              next unless manifest
              sk = manifest['submission_key']
              return record if sk == submission_key
            end
            nil
          end

          def parse_manifest_from_record(record)
            envelope = parse_evidence(record[:evidence] || record['evidence'])
            return nil unless envelope.is_a?(Hash)

            manifest = envelope['manifest']
            manifest.is_a?(Hash) ? manifest : nil
          end

          def proof_state(registry, proof_id)
            return :absent if proof_id.nil? || proof_id.to_s.empty?

            envelope = registry.find_proof(proof_id)
            return :absent unless envelope

            return :revoked if registry.revoked?(proof_id)
            return :expired if envelope.expired?

            :active
          end

          def parse_evidence(raw)
            case raw
            when Hash then raw.transform_keys(&:to_s)
            when String
              JSON.parse(raw)
            else
              nil
            end
          rescue JSON::ParserError
            nil
          end
        end
      end
    end
  end
end
