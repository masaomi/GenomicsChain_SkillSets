# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require 'digest'

module KairosMcp
  module SkillSets
    module GenomicschainCore
      module Attestation
        class SynoptisAttestor
          class AttestorError < StandardError; end
          class AttestorUnavailable < AttestorError; end

          def self.available?
            defined?(::Synoptis::AttestationEngine)
          end

          # The anchor attests under its own identity and signs with its own key.
          #
          # attester_id is the anchor's MMP instance_id, which is also what
          # Synoptis::ToolHelpers#resolve_agent_id supplies as revoker_id, so a
          # proof recorded here is revocable by the anchor that recorded it.
          # The submitting operator's ed25519 pubkey is not the attester. It is
          # carried as submitter_pubkey, a field of the canonical payload from
          # envelope version 1.1.0 onward, so it is covered by the signature
          # rather than only travelling inside manifest['operator'].
          def self.build(operator_pubkey:, safety: nil, registry: nil, anchor_identity: nil)
            unless available?
              raise AttestorUnavailable,
                    'synoptis SkillSet is not loaded (attestation unavailable).'
            end

            data_dir = File.join(KairosMcp.data_dir, 'synoptis_data')
            FileUtils.mkdir_p(data_dir)
            registry ||= ::Synoptis::Registry::FileRegistry.new(data_dir: data_dir)
            config = load_config
            engine = ::Synoptis::AttestationEngine.new(registry: registry, config: config)

            identity = anchor_identity || resolve_anchor_identity

            new(engine: engine, attester_id: identity[:agent_id], crypto: identity[:crypto],
                submitter_pubkey: operator_pubkey, require_signature: config['require_signature'],
                actor_user_id: safety&.current_user&.dig(:user), registry: registry)
          end

          # Resolves the anchor's own MMP identity and signing key. Returns nil
          # members rather than raising: the refusal belongs at the point of use
          # (#issue), so that building an attestor stays cheap and a missing key
          # surfaces as a recording failure rather than a load failure.
          def self.resolve_anchor_identity
            identity = ::MMP::Identity.new(
              workspace_root: KairosMcp.data_dir,
              config: (::MMP.load_config rescue {}) # rubocop:disable Style/RescueModifier
            )
            # instance_id, not introduce: both yield the same identifier, but
            # introduce also globs skills, scans skillsets and signs, so it
            # raises for reasons unrelated to identity — which the rescue below
            # would then turn into "this anchor has no identity" and refuse
            # every submit.
            { agent_id: identity.instance_id, crypto: identity.crypto }
          rescue StandardError
            { agent_id: nil, crypto: nil }
          end

          def self.load_config
            path = File.join(KairosMcp.skillsets_dir, 'synoptis', 'config', 'synoptis.yml')
            return {} unless File.exist?(path)

            raw = YAML.safe_load(File.read(path)) || {}
            att = raw['attestation'] || raw[:attestation] || {}
            {
              'default_ttl' => att['default_ttl'] || att[:default_ttl],
              'max_evidence_size' => att['max_evidence_size'] || att[:max_evidence_size],
              # fetch's default is evaluated eagerly, so a key present but
              # holding nil yielded nil — falsy — and disabled the refusal.
              'require_signature' => resolve_require_signature(att)
            }
          rescue StandardError
            {}
          end

          # An unset, blank or malformed value means "required". Only an
          # explicit false turns the refusal off.
          def self.resolve_require_signature(att)
            raw = att.key?('require_signature') ? att['require_signature'] : att[:require_signature]
            raw.nil? ? true : raw
          end

          attr_reader :registry

          def initialize(engine:, attester_id:, crypto: nil, submitter_pubkey: nil,
                         require_signature: true, actor_user_id: nil, registry: nil)
            @engine = engine
            @attester_id = attester_id
            @crypto = crypto
            @submitter_pubkey = submitter_pubkey
            @require_signature = require_signature.nil? ? true : require_signature
            @actor_user_id = actor_user_id
            @registry = registry
          end

          # ttl: nil falls through to the engine's default_ttl (prov design §6,
          # core change 3). Before 0.6.0 there was no way to pass one, so every
          # proof issued here inherited 86400 s — memory synoptis-proof-ttl-hazard.
          def issue(subject_ref:, claim:, evidence:, actor_role:, ttl: nil)
            refuse_unattributable!
            refuse_unsigned!

            result = @engine.create_attestation(
              attester_id: @attester_id, subject_ref: subject_ref, claim: claim,
              evidence: evidence, actor_role: actor_role, actor_user_id: @actor_user_id,
              crypto: @crypto, submitter_pubkey: @submitter_pubkey, ttl: ttl
            )
            result = symbolize(result)

            if result[:status].to_s == 'error'
              if result[:existing_proof_id]
                return { status: 'existing', synoptis_proof_id: result[:existing_proof_id] }
              end

              raise AttestorError, "synoptis rejected the attestation: #{result[:message]}"
            end

            { status: result[:status], synoptis_proof_id: result[:proof_id] }
          end

          private

          # A proof whose attester cannot be named is not attributable to the
          # anchor that recorded it, and is not revocable by it either, since
          # RevocationManager authorises on revoker_id == attester_id.
          def refuse_unattributable!
            return unless @attester_id.nil? || @attester_id.to_s.empty?

            raise AttestorError,
                  'anchor identity unavailable: refusing to record a proof with no attester'
          end

          # synoptis is configured with require_signature, and its Verifier
          # returns missing_signature for an unsigned envelope. Recording one
          # would report success while producing a proof that never verifies,
          # so the failure is raised here instead of being stored silently.
          def refuse_unsigned!
            return unless @require_signature
            return unless @crypto.nil?

            raise AttestorError,
                  'anchor signing key unavailable: refusing to record a proof that could never verify'
          end

          def symbolize(hash)
            return {} unless hash.is_a?(Hash)

            hash.each_with_object({}) { |(k, v), h| h[k.to_sym] = v }
          end
        end
      end
    end
  end
end
