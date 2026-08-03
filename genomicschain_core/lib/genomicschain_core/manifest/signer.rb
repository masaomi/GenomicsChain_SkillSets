# frozen_string_literal: true

require 'base64'
require 'digest'
require_relative '../manifest'

module KairosMcp
  module Manifest
    # Signer — ed25519 signature verification + nonce/tip freshness.
    # Supports KairosChain operational chain OR Synoptis proofs TipSource (v0.4.1 §3.4).
    module Signer
      NONCE_WINDOW_BLOCKS = 10_000
      CHAIN_TIP_MAX_BLOCKS  = 100
      CHAIN_TIP_MAX_SECONDS = 6 * 60 * 60

      class SignerError < StandardError; end
      class InvalidSignature < SignerError; end
      class NonceReplay < SignerError; end
      class StaleChainTip < SignerError; end
      class UnsupportedAlgorithm < SignerError; end
      class TransportPolicyViolation < SignerError; end

      class << self
        def verify_admission!(operator:, chain: nil, tip_source: nil, transport: :stdio,
                              reservation_set: global_reservation, args: {}, now: Time.now.utc)
          raise SignerError, 'operator missing' if operator.nil?
          raise SignerError, 'chain or tip_source required' if chain.nil? && tip_source.nil?

          mode = (operator['mode'] || operator[:mode]).to_s
          case mode
          when 'signed'
            verify_signed!(operator, chain, tip_source, reservation_set, args, now, nonce_exempt: false)
          when 'anonymous'
            true
          when 'alpha_legacy'
            unless transport == :stdio
              raise TransportPolicyViolation,
                    'alpha_legacy mode is permitted only on stdio transport (design §4 F1)'
            end
            true
          else
            raise SignerError, "unknown operator mode: #{mode.inspect}"
          end
        end

        # Recovery re-verify: ed25519 over the envelope without nonce reservation (§4.3 N-F).
        def verify_recovery!(operator:, args:, reservation_set: global_reservation)
          raise SignerError, 'operator missing' if operator.nil?
          mode = (operator['mode'] || operator[:mode]).to_s
          raise SignerError, "recovery requires signed mode (got #{mode.inspect})" unless mode == 'signed'

          verify_signed!(operator, nil, nil, reservation_set, args, Time.now.utc,
                         nonce_exempt: true, skip_tip_check: true)
        end

        def global_reservation
          @global_reservation ||= ReservationSet.new
        end

        def bootstrap_seen_list!(chain = nil, tip_source: nil)
          set = global_reservation
          if tip_source
            tip_source.bootstrap_committed_nonces!(reservation_set: set)
          elsif chain
            recent_nonces(chain).each { |n| set.bootstrap_insert(n) }
          end
          set
        end

        def verify_bytes(message:, signature:, pubkey:)
          require 'ed25519'
          vk = Ed25519::VerifyKey.new(pubkey)
          vk.verify(signature, message)
        rescue Ed25519::VerifyError, StandardError
          false
        end

        private

        def verify_signed!(operator, chain, tip_source, reservation_set, args, now,
                           nonce_exempt: false, skip_tip_check: false)
          pubkey_str = operator['pubkey'] || operator[:pubkey]
          sig        = operator['signature'] || operator[:signature]
          raise InvalidSignature, 'pubkey/signature missing' if pubkey_str.nil? || sig.nil?

          sig = sig.transform_keys(&:to_s)
          algorithm = sig['algorithm'] || 'ed25519'
          raise UnsupportedAlgorithm, algorithm unless algorithm == 'ed25519'

          sig_b64 = sig['value'] || sig['signature']
          nonce         = sig['nonce']
          chain_tip_hash = sig['chain_tip_hash']
          raise InvalidSignature, 'nonce missing' if nonce.nil? || nonce.empty?
          raise InvalidSignature, 'chain_tip_hash missing' if chain_tip_hash.nil? || chain_tip_hash.empty?

          unless skip_tip_check
            if tip_source
              unless tip_source.tip_fresh?(chain_tip_hash, now: now)
                raise StaleChainTip,
                      "chain_tip_hash not within recent #{CHAIN_TIP_MAX_BLOCKS} proofs or #{CHAIN_TIP_MAX_SECONDS}s"
              end
            else
              enforce_chain_tip_freshness!(chain_tip_hash, chain, now)
            end
          end

          unless nonce_exempt
            unless reservation_set.try_reserve(nonce)
              raise NonceReplay, "nonce already seen or reserved: #{nonce}"
            end
          end

          message_obj = {
            'mcp_tool_name'  => args['mcp_tool_name'] || args[:mcp_tool_name] || 'gc_run_fastqc',
            'params'         => args['params'] || args[:params] || {},
            'nonce'          => nonce,
            'chain_tip_hash' => chain_tip_hash
          }
          message = KairosMcp::Manifest.canonical_json(message_obj)

          pubkey_bytes = decode_pubkey(pubkey_str)
          sig_bytes    = decode_signature(sig_b64)

          unless verify_bytes(message: message, signature: sig_bytes, pubkey: pubkey_bytes)
            reservation_set.release(nonce) unless nonce_exempt
            raise InvalidSignature, 'ed25519 signature did not verify'
          end

          true
        end

        def recent_blocks(chain, n)
          return chain.recent_blocks(n) if chain.respond_to?(:recent_blocks)
          return chain.chain.last(n) if chain.respond_to?(:chain)
          []
        end

        def enforce_chain_tip_freshness!(tip_hash, chain, now)
          recent = recent_blocks(chain, CHAIN_TIP_MAX_BLOCKS + 1)
          match = recent.find { |b| (b.respond_to?(:hash) ? b.hash : b['hash']) == tip_hash }
          raise StaleChainTip, "chain_tip_hash not within recent #{CHAIN_TIP_MAX_BLOCKS} blocks" if match.nil?

          ts = match.respond_to?(:timestamp) ? match.timestamp : match['timestamp']
          if ts
            t = ts.is_a?(Time) ? ts : Time.parse(ts.to_s)
            age = now - t.utc
            if age > CHAIN_TIP_MAX_SECONDS
              raise StaleChainTip,
                    "chain_tip_hash is #{age.to_i}s old (max #{CHAIN_TIP_MAX_SECONDS}s)"
            end
          end
          true
        end

        def decode_pubkey(s)
          payload = s.to_s.sub(/\Aed25519:/, '')
          Base64.urlsafe_decode64(payload)
        rescue ArgumentError
          Base64.decode64(payload)
        end

        def decode_signature(s)
          Base64.urlsafe_decode64(s.to_s)
        rescue ArgumentError
          Base64.decode64(s.to_s)
        end

        def recent_nonces(chain)
          blocks = recent_blocks(chain, NONCE_WINDOW_BLOCKS)
          return [] if blocks.empty?

          blocks.flat_map do |b|
            data = b.respond_to?(:data) ? b.data : b['data']
            extract_nonces_from_block_data(data || [])
          end.compact.uniq
        end

        def extract_nonces_from_block_data(data)
          data.each_with_object([]) do |line, acc|
            next unless line.is_a?(String) && line.start_with?('manifest_json:')

            payload = line.sub(/\Amanifest_json:\s*/, '')
            parsed = JSON.parse(payload) rescue nil
            next if parsed.nil?

            n = parsed.dig('operator', 'signature', 'nonce')
            acc << n unless n.nil?
          end
        end
      end

      class ReservationSet
        def initialize
          @committed = {}
          @reserved  = {}
          @mutex     = Mutex.new
        end

        def bootstrap_insert(nonce)
          @mutex.synchronize { @committed[nonce] = true }
        end

        def try_reserve(nonce)
          @mutex.synchronize do
            return false if @committed.key?(nonce) || @reserved.key?(nonce)
            @reserved[nonce] = true
            true
          end
        end

        def commit(nonce)
          @mutex.synchronize do
            @reserved.delete(nonce)
            @committed[nonce] = true
          end
        end

        def release(nonce)
          @mutex.synchronize { @reserved.delete(nonce) }
        end

        def reserved?(nonce); @mutex.synchronize { @reserved.key?(nonce) }; end
        def committed?(nonce); @mutex.synchronize { @committed.key?(nonce) }; end
        def size; @mutex.synchronize { @committed.size + @reserved.size }; end
      end
    end
  end
end
