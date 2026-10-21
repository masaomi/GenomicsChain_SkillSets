# frozen_string_literal: true

require 'digest'
require 'genomicschain_core'
require 'genomicschain_prov/commitment'

module KairosMcp
  module SkillSets
    module GenomicschainTier3
      # Fingerprint — the one rule for every fingerprint and digest field the
      # executor writes (design §4.3, §9-4):
      #
      #   plain   F(file) = SHA-256 of its bytes     H(v) = SHA-256 of canonical JSON
      #   salted  F(file) = C(f) under the job key   H(v) = C over canonical JSON bytes
      #
      # C is gc-commitment-0.1 (14), called unchanged. No new encoding. The
      # key lives in this object only; inspect never shows it.
      class Fingerprint
        C = ::GenomicsChainProv::Commitment

        # A file that cannot be read has no fingerprint, salted or plain.
        class Unreadable < StandardError; end

        # @param key [String, nil] the job's commitment key (32 bytes); nil = plain
        def initialize(key = nil)
          @key = key && C.check_key!(key)
        end

        def salted? = !@key.nil?

        # C.commit_file answers nil for an unreadable file; that must not
        # become a value (review r1 F4).
        def file(path)
          value = @key ? C.commit_file(@key, path) : Digest::SHA256.file(path).hexdigest
          raise Unreadable, 'a file to fingerprint cannot be read' if value.nil?

          value
        rescue SystemCallError
          raise Unreadable, 'a file to fingerprint cannot be read'
        end

        def bytes(data) = @key ? C.commit(@key, data.to_s.b) : Digest::SHA256.hexdigest(data.to_s.b)

        # A value that is not a file: its canonical JSON bytes (§4.3).
        def value(obj) = bytes(KairosMcp::Manifest.canonical_json(obj))

        def inspect = "#<#{self.class.name} #{salted? ? 'salted' : 'plain'}>"
        alias to_s inspect
      end
    end
  end
end
