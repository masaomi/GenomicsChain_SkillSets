# frozen_string_literal: true

require 'digest'
require 'json'

module KairosMcp
  module SkillSets
    module GenomicschainCore
      # SubmitCore — single recorded-write path for all tiers (design v0.4.1 §4).
      # Synoptis proofs only; no KairosChain operational chain writes (INV-1).
      class SubmitCore
        class SubmitError < StandardError; end
        class DigestMismatch < SubmitError; end
        class BearerBindingError < SubmitError; end
        class TrustTierError < SubmitError; end
        class UnsignedModeError < SubmitError; end
        class IdentityMismatch < SubmitError; end
        class EvidenceTooLarge < SubmitError; end
        class RecordingFailed < SubmitError; end

        # The record types whose idempotency key is sha256(submission_key)
        # (prov design v0.1.15 (7)): a list, so a new type is added by name and
        # the derivation every other tier uses stays as it was. Their values
        # from before this list existed are pinned in
        # test/fixtures/idempotency_keys_r0.json. Tier 3 v0.1 (design §9-1)
        # adds its declaration and attestation: neither carries a jobspec_digest
        # or a result_hash, so the derivation below would make their key a
        # constant per pubkey (19:257–262).
        SUBMISSION_KEYED = %w[prov_attestation prov_reachability tier3_declaration tier3_attestation].freeze

        @submission_mutexes = {}
        @submission_mutex_guard = Mutex.new

        class << self
          def submit(spec:, operator:, bearer_pubkey_hash:, tip_source:, registry:, attestor:)
            unless (operator['mode'] || operator[:mode]).to_s == 'signed'
              raise UnsignedModeError, 'submit requires operator.mode == signed'
            end

            nonce = operator.dig('signature', 'nonce') || operator.dig(:signature, 'nonce')
            pubkey = (operator['pubkey'] || operator[:pubkey]).to_s

            spec.trust_tier_gate!

            parsed = spec.parse_digest_subject!
            spec.apply_gates!(parsed)

            recomputed = spec.recompute_digest!(parsed)
            unless recomputed == spec.claimed_digest
              raise DigestMismatch,
                    "digest mismatch: claimed #{spec.claimed_digest}, recomputed #{recomputed}"
            end

            spec.assert_submitted_matches_signed!
            spec.reject_client_server_set_fields!(parsed)

            bind_bearer!(pubkey, bearer_pubkey_hash)

            signed_params = spec.signed_identity_params
            submission_key = derive_submission_key(
              digest_subject_hash: recomputed,
              signed_identity: signed_params,
              operator_pubkey: pubkey
            )

            with_submission_mutex(submission_key) do
              existing = ProofLookup.find_by_submission_key(registry, submission_key)
              if existing
                return recovery_branch(
                  spec: spec, operator: operator, pubkey: pubkey,
                  signed_params: signed_params, existing: existing,
                  registry: registry, submission_key: submission_key
                )
              end

              admission_args = {
                'mcp_tool_name' => spec.class::MCP_TOOL,
                'params' => signed_params
              }
              KairosMcp::Manifest::Signer.verify_admission!(
                operator: operator, tip_source: tip_source, transport: :stdio, args: admission_args
              )

              committed = false
              begin
                existing = ProofLookup.find_by_submission_key(registry, submission_key)
                if existing
                  KairosMcp::Manifest::Signer.global_reservation.release(nonce)
                  return recovery_branch(
                    spec: spec, operator: operator, pubkey: pubkey,
                    signed_params: signed_params, existing: existing,
                    registry: registry, submission_key: submission_key
                  )
                end

                server_fields = spec.server_set_fields(pubkey)
                manifest = spec.build_manifest(
                  operator: operator, submission_key: submission_key, server_fields: server_fields
                )
                claim = spec.claim_for(submission_key: submission_key)

                store_result = store_proof!(
                  attestor: attestor, registry: registry,
                  subject_ref: spec.subject_ref, claim: claim, manifest: manifest,
                  ttl: spec.respond_to?(:proof_ttl) ? spec.proof_ttl : nil
                )

                KairosMcp::Manifest::Signer.global_reservation.commit(nonce)
                committed = true

                build_response(
                  status: 'recorded',
                  synoptis_proof_id: store_result[:synoptis_proof_id],
                  claim: claim,
                  submission_key: submission_key,
                  manifest: manifest,
                  spec: spec,
                  pubkey: pubkey
                )
              rescue Attestation::SynoptisAttestor::AttestorError => e
                KairosMcp::Manifest::Signer.global_reservation.release(nonce) unless committed
                {
                  status: 'recording_failed_retryable',
                  message: e.message,
                  submission_key: submission_key
                }
              rescue StandardError
                KairosMcp::Manifest::Signer.global_reservation.release(nonce) unless committed
                raise
              end
            end
          end

          private

          def derive_submission_key(digest_subject_hash:, signed_identity:, operator_pubkey:)
            Digest::SHA256.hexdigest(
              KairosMcp::Manifest.canonical_json(
                'digest_subject_hash' => digest_subject_hash,
                'signed_identity' => signed_identity,
                'operator_pubkey' => operator_pubkey
              )
            )
          end

          def bind_bearer!(pubkey, bearer_pubkey_hash)
            if bearer_pubkey_hash.nil? || bearer_pubkey_hash.to_s.empty?
              raise BearerBindingError, 'signed submit requires a pubkey-bound Bearer (no pubkey_hash)'
            end
            return if Digest::SHA256.hexdigest(pubkey) == bearer_pubkey_hash

            raise BearerBindingError, 'operator pubkey does not match Bearer pubkey_hash'
          end

          # ttl: a spec that names its own proof lifetime passes it here (prov
          # design §6, core change 4: a provenance record must outlive the
          # engine's 24-hour default). nil keeps the engine default, so the
          # Tier-1/2/3 proofs are unchanged.
          def store_proof!(attestor:, registry:, subject_ref:, claim:, manifest:, ttl: nil)
            envelope = build_evidence_envelope(manifest)
            evidence_json = KairosMcp::Manifest.canonical_json(envelope)
            max_size = Config.max_evidence_size
            if evidence_json.bytesize > max_size
              raise EvidenceTooLarge,
                    "evidence size #{evidence_json.bytesize} exceeds max_evidence_size #{max_size}"
            end

            result = attestor.issue(
              subject_ref: subject_ref, claim: claim, evidence: evidence_json, actor_role: 'automated', ttl: ttl
            )
            proof_id = result[:synoptis_proof_id]
            raise RecordingFailed, 'synoptis store returned no proof_id' if proof_id.nil? || proof_id.to_s.empty?

            { synoptis_proof_id: proof_id, store_status: result[:status] }
          end

          def build_evidence_envelope(manifest)
            body = KairosMcp::Manifest.canonical_json(manifest)
            {
              'manifest' => manifest,
              'manifest_body_sha256' => Digest::SHA256.hexdigest(body)
            }
          end

          def recovery_branch(spec:, operator:, pubkey:, signed_params:, existing:, registry:, submission_key:)
            admission_args = {
              'mcp_tool_name' => spec.class::MCP_TOOL,
              'params' => signed_params
            }
            KairosMcp::Manifest::Signer.verify_recovery!(operator: operator, args: admission_args)
            spec.assert_submitted_matches_signed!

            stored_manifest = ProofLookup.parse_manifest_from_record(existing)
            stored_key = stored_manifest&.dig('submission_key')
            unless stored_key == submission_key
              raise IdentityMismatch, 'located proof submission_key mismatch'
            end

            proof_id = existing[:proof_id] || existing['proof_id']
            state = ProofLookup.proof_state(registry, proof_id)

            stored_nonce = stored_manifest.dig('operator', 'signature', 'nonce')
            reservation = KairosMcp::Manifest::Signer.global_reservation
            reservation.bootstrap_insert(stored_nonce) if stored_nonce && !reservation.committed?(stored_nonce)

            claim = spec.claim_for(submission_key: submission_key)
            case state
            when :active
              build_response(
                status: 'recorded',
                synoptis_proof_id: proof_id,
                claim: claim,
                submission_key: submission_key,
                manifest: stored_manifest,
                spec: spec,
                pubkey: pubkey,
                recovered: true
              )
            when :revoked
              { status: 'recorded_attestation_revoked', synoptis_proof_id: proof_id,
                claim: claim, submission_key: submission_key }
            when :expired
              { status: 'recorded_attestation_expired', synoptis_proof_id: proof_id,
                claim: claim, submission_key: submission_key }
            else
              raise SubmitError, "recovery found proof in unexpected state: #{state.inspect}"
            end
          end

          def build_response(status:, synoptis_proof_id:, claim:, submission_key:, manifest:, spec:, pubkey:,
                             recovered: false)
            out = {
              status: status,
              synoptis_proof_id: synoptis_proof_id,
              claim: claim,
              submission_key: submission_key,
              recovered: recovered
            }
            if manifest['leaderboard_eligible'] != nil
              out[:leaderboard_eligible] = manifest['leaderboard_eligible']
            end
            if manifest['result_evidence_sha256']
              out[:result_evidence_sha256] = manifest['result_evidence_sha256']
            end
            # A provenance record keys on its submission_key alone (prov design
            # §6, core change 2): that key already binds the bundle digest, the
            # whole signed identity — three procedure versions included — and
            # the pubkey. Selected by record_type, not by the key's presence,
            # because every tier's manifest carries a submission_key.
            if SUBMISSION_KEYED.include?(manifest['record_type'])
              out[:idempotency_key] = Digest::SHA256.hexdigest(submission_key.to_s)
              return out
            end

            # Digest subject first, headline result second, per tier:
            #   tier1 report_content_hash / static_readiness
            #   tier2 adjudication_digest  / codescan_evidence_digest
            #   tier3 jobspec_digest       / result_hash
            #   tier4 package_digest       / (none: both checks are in the claim)
            out[:idempotency_key] = Digest::SHA256.hexdigest(
              [manifest['jobspec_digest'] || manifest['report_content_hash'] || manifest['adjudication_digest'] ||
                 manifest['package_digest'],
               manifest['result_hash'] || manifest.dig('headline', 'static_readiness') ||
                 manifest['codescan_evidence_digest'],
               pubkey].compact.join('|')
            )
            out
          end

          def with_submission_mutex(key)
            mutex = @submission_mutex_guard.synchronize { @submission_mutexes[key] ||= Mutex.new }
            mutex.synchronize { yield }
          end
        end
      end
    end
  end
end
