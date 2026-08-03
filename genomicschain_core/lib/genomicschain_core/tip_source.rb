# frozen_string_literal: true

require 'json'
require 'digest'
require 'time'

module KairosMcp
  module SkillSets
    module GenomicschainCore
      # TipSource — proofs-chain tip adapter for Signer admission (design v0.4.1 §3.4).
      # Replaces KairosChain operational chain for nonce/tip freshness during submit.
      class TipSource
        GENESIS_TIP = ('0' * 64).freeze

        CHAIN_TIP_MAX_BLOCKS  = KairosMcp::Manifest::Signer::CHAIN_TIP_MAX_BLOCKS
        CHAIN_TIP_MAX_SECONDS = KairosMcp::Manifest::Signer::CHAIN_TIP_MAX_SECONDS

        def initialize(registry:)
          @registry = registry
        end

        # Hash of the last proof entry, or genesis sentinel when empty.
        def latest_tip_hash
          records = proof_records
          return GENESIS_TIP if records.empty?

          entry_hash(records.last)
        end

        # True iff +hash+ appears within the last CHAIN_TIP_MAX_BLOCKS proof entries
        # OR within CHAIN_TIP_MAX_SECONDS by entry _stored_at (OR, not AND).
        def tip_fresh?(hash, now: Time.now.utc)
          return true if hash == GENESIS_TIP && proof_records.empty?

          records = proof_records
          return false if records.empty?

          recent = records.last(CHAIN_TIP_MAX_BLOCKS)
          return true if recent.any? { |r| entry_hash(r) == hash }

          records.reverse_each do |r|
            next unless entry_hash(r) == hash

            stored_at = r[:_stored_at] || r['_stored_at']
            next if stored_at.nil?

            t = stored_at.is_a?(Time) ? stored_at : Time.parse(stored_at.to_s)
            return true if (now - t.utc) <= CHAIN_TIP_MAX_SECONDS
          end
          false
        rescue ArgumentError
          false
        end

        # Seed ReservationSet from GenomicsChain proof evidence manifests.
        def bootstrap_committed_nonces!(reservation_set: KairosMcp::Manifest::Signer.global_reservation)
          proof_records.each do |record|
            nonce = extract_nonce_from_record(record)
            reservation_set.bootstrap_insert(nonce) if nonce
          end
          reservation_set
        end

        def proof_records
          @registry.read(:proofs)
        end

        def entry_hash(record)
          Digest::SHA256.hexdigest(JSON.generate(record, sort_keys: true))
        end

        private

        def extract_nonce_from_record(record)
          manifest = ProofLookup.parse_manifest_from_record(record)
          return nil unless manifest

          manifest.dig('operator', 'signature', 'nonce')
        end
      end
    end
  end
end
