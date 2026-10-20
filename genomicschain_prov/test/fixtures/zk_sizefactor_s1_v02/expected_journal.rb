# Computes the gc-zk-journal-0.2 values a correct checker_v02 must commit,
# independently of the guest (Ruby OpenSSL, design §5 gc-commitment-0.1):
#   key_id = SHA-256("gc-commitment-0.1/key-id" ‖ key)
#   C(f)   = HMAC-SHA256(key, f)
# Usage: ruby expected_journal.rb <key file> <input file> <output file>
require 'openssl'
require 'json'

key, input, output = ARGV.map { |p| File.binread(p) }
abort 'key must be exactly 32 bytes' unless key.bytesize == 32
c = ->(data) { OpenSSL::HMAC.hexdigest('SHA256', key, data) }
puts JSON.pretty_generate(
  'journal_key_id' => OpenSSL::Digest::SHA256.hexdigest('gc-commitment-0.1/key-id' + key),
  'journal_input_commitment' => c.(input),
  'journal_output_commitment' => c.(output)
)
