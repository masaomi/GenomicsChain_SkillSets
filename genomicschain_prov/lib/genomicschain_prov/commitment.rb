# frozen_string_literal: true

require 'openssl'
require 'digest'
require 'securerandom'

module GenomicsChainProv
  # Commitment — `gc-commitment-0.1`, the salted fingerprint rule (design
  # v0.1.16 §5; shared with Tier 3 stage 0, which is to be aligned with it).
  #
  #   key     exactly 32 bytes from a cryptographic RNG; never sent to the anchor
  #   C(f)    = HMAC-SHA256(key, bytes of f)                 64 lowercase hex
  #   key_id  = SHA-256("gc-commitment-0.1/key-id" ‖ key)   64 lowercase hex
  #
  # The key length is checked on every read (§5): HMAC pads a short key with
  # zero bytes, so a key of another length could act as the same key. Hiding
  # rests on the key being uniform random and on HMAC-SHA256 being a PRF; the
  # binding of C(f) to f rests on SHA-256's collision resistance.
  #
  # Nothing here logs, prints or stores a key. Error messages name the rule,
  # never a key byte or a fingerprint.
  module Commitment
    class KeyError < StandardError; end

    RULE = 'gc-commitment-0.1'
    KEY_BYTES = 32
    KEY_ID_PREFIX = 'gc-commitment-0.1/key-id'
    HEX64 = /\A[0-9a-f]{64}\z/

    module_function

    # @return [String] the key, as binary, after checking it is 32 bytes
    # @raise [KeyError]
    def check_key!(key)
      raise KeyError, "#{RULE}: the key is not a byte string" unless key.is_a?(String)

      bin = key.b
      raise KeyError, "#{RULE}: the key must be exactly #{KEY_BYTES} bytes (got #{bin.bytesize})" unless bin.bytesize == KEY_BYTES

      bin
    end

    # A fresh key for one bundle (§5: one key per bundle, no reuse option).
    def generate_key
      SecureRandom.random_bytes(KEY_BYTES)
    end

    # C(f) over bytes held in memory.
    def commit(key, bytes)
      OpenSSL::HMAC.hexdigest('SHA256', check_key!(key), bytes.to_s.b)
    end

    # C(f) over a file, read in chunks. nil when the file cannot be read.
    def commit_file(key, path)
      hmac = OpenSSL::HMAC.new(check_key!(key), OpenSSL::Digest.new('SHA256'))
      File.open(path, 'rb') do |f|
        while (chunk = f.read(1 << 20))
          hmac.update(chunk)
        end
      end
      hmac.hexdigest
    rescue SystemCallError
      nil
    end

    def key_id(key)
      Digest::SHA256.hexdigest(KEY_ID_PREFIX.b + check_key!(key))
    end

    # The extension's `commitment` object (§6.1).
    def declaration(key)
      { 'rule' => RULE, 'key_id' => key_id(key) }
    end

    # A key file is the 32 raw bytes and nothing else: a hex text file, a
    # trailing newline or a short file is refused, not repaired.
    def read_key_file(path)
      check_key!(File.binread(path))
    rescue SystemCallError => e
      raise KeyError, "#{RULE}: the key file cannot be read (#{e.class.name.split('::').last})"
    end

    # Writes a new key file, readable by its owner only. Refuses to overwrite:
    # replacing a key would orphan every fingerprint made under it.
    def write_key_file(path, key)
      bin = check_key!(key)
      File.open(path, File::WRONLY | File::CREAT | File::EXCL | File::BINARY, 0o600) { |f| f.write(bin) }
      path
    rescue Errno::EEXIST
      raise KeyError, "#{RULE}: a file already exists at the key path; a key is never overwritten"
    end
  end
end
