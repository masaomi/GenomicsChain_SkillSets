# frozen_string_literal: true
# CanonicalJson is what gets signed, digested and stored. It must not lose values.
require 'minitest/autorun'
require 'kairos_mcp/version'
require 'genomicschain_core/manifest'

class CanonicalJsonTest < Minitest::Test
  # Regression (2026-09-09): `obj[k] || obj[k.to_sym]` turned every false into
  # nil, so a signed false, a digested false and a stored false all became
  # null. Lever readings, leaderboard_eligible and all_identical are booleans
  # whose common value is false.
  def test_false_survives_canonicalisation
    out = KairosMcp::Manifest.canonical_json('a' => false, 'b' => true, 'c' => nil, 'd' => { 'e' => false })
    assert_equal '{"a":false,"b":true,"c":null,"d":{"e":false}}', out
  end

  def test_symbol_keys_and_false_values
    assert_equal '{"x":false}', KairosMcp::Manifest.canonical_json(x: false)
  end

  def test_false_and_null_digest_differently
    refute_equal KairosMcp::Manifest.canonical_json_sha256('a' => false),
                 KairosMcp::Manifest.canonical_json_sha256('a' => nil)
  end

  def test_keys_sorted_recursively
    assert_equal '{"a":{"b":1,"c":2},"z":[{"k":0}]}',
                 KairosMcp::Manifest.canonical_json('z' => [{ 'k' => 0 }], 'a' => { 'c' => 2, 'b' => 1 })
  end
end
