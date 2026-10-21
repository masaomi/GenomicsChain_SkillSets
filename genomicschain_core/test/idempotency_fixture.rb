# frozen_string_literal: true

require 'json'
require 'digest'
require 'ed25519'

# Design v0.1.15 (10) (viii): the idempotency key of every existing record
# type, captured on the fresh and the recovery path BEFORE core 0.6.2 turns
# SubmitCore's prov_attestation branch into a list of record types. The values
# in fixtures/idempotency_keys_r0.json were taken at core 0.6.1 and must not
# be regenerated after that change: a key that moves is the regression.
#
# The key is derived from manifest fields and the operator's pubkey (never the
# nonce or the chain tip), so one fixed signing key makes it reproducible.
module IdempotencyFixture
  PATH = File.expand_path('fixtures/idempotency_keys_r0.json', __dir__)
  SIGNING_KEY = Ed25519::SigningKey.new(Digest::SHA256.digest('gc-v0.1.15-r0-idempotency-fixture'))

  module_function

  def expected(record_type)
    JSON.parse(File.read(PATH)).dig('keys', record_type)
  end

  # A missing entry fails with the observed values, which is how the fixture
  # was first filled in (at core 0.6.1, before any core change).
  def check(test, record_type, fresh, recovery)
    test.assert_equal false, fresh[:recovered], "#{record_type}: first submission must be fresh"
    test.assert_equal true, recovery[:recovered], "#{record_type}: second submission must recover"
    got = { 'fresh' => fresh[:idempotency_key], 'recovery' => recovery[:idempotency_key] }
    want = expected(record_type)
    test.flunk("no fixture for #{record_type}; observed #{JSON.generate(got)}") unless want
    test.assert_equal want, got, "#{record_type}: idempotency key moved"
  end
end
