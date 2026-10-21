# frozen_string_literal: true

require 'delegate'
require 'genomicschain_core'
require_relative 'records'
require_relative 'verdict_spec/declaration'
require_relative 'verdict_spec/attestation'

module KairosMcp
  module SkillSets
    module GenomicschainTier3Record
      # RecordSubmit — the anchor's half of Tier 3 v0.1 (design §3.2, §9-1,
      # §9-2): thin adapters over SubmitCore and the two specs, as
      # Tier3Submit is for record 0.3 (17:22–32). The anchor never receives a
      # key or an output file; it receives params, an envelope and, for route
      # B, the Tier-2.5 record's proof_id beside them.
      module RecordSubmit
        SubmitCore = GenomicschainCore::SubmitCore
        ProofLookup = GenomicschainCore::ProofLookup

        # SubmitCore's view of the registry (review r2 C2). Its recovery lookup
        # takes the newest proof under a submission_key, whoever wrote it, and
        # is not a spec hook; through this view it sees only the Tier 3 records
        # this anchor's tool wrote, so a resend recovers its own record. Single
        # proofs (find_proof, revoked?) read through unchanged.
        class AnchorWrittenView < SimpleDelegator
          def read(type)
            records = __getobj__.read(type)
            return records unless type.to_s == 'proofs'

            records.select { |r| Records.written_here?(r, ProofLookup.parse_manifest_from_record(r)) }
          end
        end

        @attestation_mutexes = {}
        @attestation_mutex_guard = Mutex.new

        class << self
          # @param config [Hash, nil] nil = GenomicschainCore::Config.load
          # @return [Hash] SubmitCore's response plus :declaration_ref, read
          #   from the stored manifest (a recovered record included)
          def declaration(declaration:, operator:, bearer_pubkey_hash:, tip_source:, attestor:, registry: nil,
                          route_proof_id: nil, config: nil)
            registry ||= attestor.registry
            spec = VerdictSpec::Declaration.new(declaration: declaration, registry: registry,
                                                route_proof_id: route_proof_id, config: config)
            out = submit(spec, operator, registry, bearer_pubkey_hash: bearer_pubkey_hash, tip_source: tip_source,
                                                   attestor: attestor)
            ref = declaration_ref_of(registry, out[:synoptis_proof_id])
            ref ? out.merge(declaration_ref: ref) : out
          end

          # @param config [Hash, nil] accepted beside declaration's; the
          #   attestation reads no anchor setting
          def attestation(attestation:, operator:, bearer_pubkey_hash:, tip_source:, attestor:, registry: nil,
                          config: nil) # rubocop:disable Lint/UnusedMethodArgument
            registry ||= attestor.registry
            spec = VerdictSpec::Attestation.new(attestation: attestation, registry: registry)
            # §3.4's one-per-declaration check and the store happen under
            # SubmitCore's per-submission_key lock, which two attestations of
            # one declaration do not share; this lock is theirs. Its key comes
            # after the house gates (spec.lock_key), so an oversized value
            # never becomes a table key.
            with_declaration_mutex(spec.lock_key) do
              submit(spec, operator, registry, bearer_pubkey_hash: bearer_pubkey_hash, tip_source: tip_source,
                                               attestor: attestor)
            end
          end

          private

          # Review r2 C2: SubmitCore runs on the anchor-written view, so its
          # recovery lookup can only land on a record this tool wrote; a
          # foreign proof under the same submission_key is neither recovered
          # nor in the way of the real submission (pre-flight r3 §2.2 (b)).
          #
          # No false success (§3.4〔実装〕, operator 2026-10-21 question 8): the
          # store itself can answer with another writer's proof (Synoptis's
          # duplicate check meets one planted with the real claim before the
          # first submit). Whatever proof comes back must be this tool's,
          # under this submission_key; otherwise nothing was recorded, and the
          # answer says so without naming that proof.
          def submit(spec, operator, registry, **kw)
            out = SubmitCore.submit(spec: spec, operator: operator, registry: AnchorWrittenView.new(registry), **kw)
            return out unless out[:synoptis_proof_id]
            return out if own_manifest(registry, out[:synoptis_proof_id])&.dig('submission_key') == out[:submission_key]

            raise SubmitCore::RecordingFailed, 'the store answered with a proof gc_tier3_record_submit did not write ' \
                                               'under this submission_key; nothing was recorded'
          end

          # The manifest of the proof, only if this tool wrote it (F2's rule).
          def own_manifest(registry, proof_id)
            record = registry.read(:proofs).find { |r| (r[:proof_id] || r['proof_id']) == proof_id }
            manifest = record && ProofLookup.parse_manifest_from_record(record)
            manifest if record && Records.written_here?(record, manifest)
          end

          def declaration_ref_of(registry, proof_id)
            manifest = proof_id && own_manifest(registry, proof_id)
            return nil unless manifest && manifest['record_type'] == Records::DECLARATION

            manifest.slice('declaration_digest', 'recorded_at')
          end

          # One mutex per declaration_ref while some call holds or waits for
          # it; the entry leaves the table with its last user (review r1 F2),
          # so the table does not grow with every declaration ever attested.
          def with_declaration_mutex(key, &)
            entry = @attestation_mutex_guard.synchronize do
              (@attestation_mutexes[key] ||= { mutex: Mutex.new, users: 0 }).tap { |e| e[:users] += 1 }
            end
            begin
              entry[:mutex].synchronize(&)
            ensure
              @attestation_mutex_guard.synchronize do
                entry[:users] -= 1
                @attestation_mutexes.delete(key) if entry[:users].zero?
              end
            end
          end
        end
      end
    end
  end
end
