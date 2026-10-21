# frozen_string_literal: true

require 'digest'

module KairosMcp
  module SkillSets
    module GenomicschainCore
      # gc-backing-0.1 — what stands behind each part of a record (prov design
      # v0.1.15 §6.3 (6)). Kept in core because two packages label their
      # records with it: prov's reachability observation now, Tier 3 stage 0
      # later.
      #
      #   procedure_checked  GenomicsChain's procedure re-derived it from the
      #                      record or the submitted material
      #   anchor_observed    the anchor observed it from its own position; a
      #                      dated observation that cannot be re-derived
      #   customer_signed    a statement signed by the declared key exists
      #                      (who said it)
      #   customer_stated    what that statement says
      #   not_checked        no one checked it
      #   platform_audit_log, hardware_attested
      #                      reserved (Tier 3 stages 1 and 2)
      module Backing
        VERSION = 'gc-backing-0.1'
        LABELS = %w[procedure_checked anchor_observed customer_signed customer_stated not_checked].freeze
        RESERVED = %w[platform_audit_log hardware_attested].freeze
      end

      # How one record points at a provenance record without naming it: the
      # SHA-256 of its proof_id. The proof_id is the key that reads the prov
      # record, so it is not handed to whoever can read the pointing record;
      # a verifier holding both proof_ids checks the link (v0.1.15 (6), (7)).
      module ProvProofRef
        module_function

        def for(proof_id)
          raise ArgumentError, 'proof_id missing' if proof_id.nil? || proof_id.to_s.empty?

          Digest::SHA256.hexdigest(proof_id.to_s)
        end
      end
    end
  end
end
