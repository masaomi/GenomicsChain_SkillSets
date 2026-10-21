# frozen_string_literal: true

# Tier 3 v0.1 §9-5 / §6.2 — the wording verifier. Both warranty sentences
# verbatim (09:30, 09:31 as quoted in §6.2), the T_d / T_a line, the
# started_at note when a record 0.3 is also produced, the §9-5 sentence
# 「宣言されたが attestation されていない」 for a lone declaration (state code
# declared_not_attested; orchestrator amendment 2026-10-20), and never
# 「検証済み」 or 「再現された」. Read per record type: declaration alone, with
# its attestation, with a record 0.3.
require_relative 't3_record_helper'
require 'genomicschain_tier3_record/wording'

class WordingTest < Minitest::Test
  include T3RecordHelpers

  PK_A = 'ed25519:' + Base64.urlsafe_encode64('a' * 32, padding: false)
  PK_B = 'ed25519:' + Base64.urlsafe_encode64('b' * 32, padding: false)

  def decl(pubkey: PK_A)
    { 'record_type' => 'tier3_declaration', 'record_version' => '0.1', 'declaration_digest' => hex('declaration'),
      'recorded_at' => '2026-10-20T08:00:00Z', 'operator' => { 'pubkey' => pubkey } }
  end

  def att(d, pubkey: PK_A, ref: nil)
    { 'record_type' => 'tier3_attestation', 'record_version' => '0.1',
      'declaration_ref' => ref || { 'declaration_digest' => d['declaration_digest'], 'recorded_at' => d['recorded_at'] },
      'recorded_at' => '2026-10-21T09:00:00Z', 'operator' => { 'pubkey' => pubkey } }
  end

  def verdict_0_3 = { 'record_type' => 'tier3_verdict', 'record_version' => '0.3', 'started_at' => '2026-10-21T09:30:00Z' }

  def read(**kw) = T3R::Wording.read(**kw)

  def combinations
    d = decl
    { 'declaration' => { declaration: d },
      'declaration+attestation' => { declaration: d, attestation: att(d) },
      'declaration+attestation+0.3' => { declaration: d, attestation: att(d), tier3_verdict: verdict_0_3 },
      'declaration+0.3' => { declaration: d, tier3_verdict: verdict_0_3 } }
  end

  def test_both_warranty_sentences_appear_verbatim_for_every_record_type
    combinations.each do |name, kw|
      st = read(**kw)['statements']
      assert(st.any? { |s| s.include?(ZK_SENTENCE) }, "#{name}: the ZK sentence")
      assert(st.any? { |s| s.include?(T3_SENTENCE) }, "#{name}: the Tier 3 sentence")
    end
  end

  def test_the_record_times_line_appears_verbatim_for_every_record_type
    combinations.each do |name, kw|
      assert(read(**kw)['lines'].any? { |l| l.include?(TIMES_LINE) }, name)
    end
  end

  # Design line 417: 宣言だけの記録は「宣言されたが attestation されていない」と出す.
  def assert_not_attested(out)
    assert_equal 'declared_not_attested', out['state']
    assert(out['lines'].any? { |l| l.include?(NOT_ATTESTED_LINE) }, 'the §9-5 sentence')
  end

  def test_a_lone_declaration_reads_declared_not_attested
    out = read(declaration: decl)
    assert_not_attested(out)
    assert_equal({ 'T_d' => '2026-10-20T08:00:00Z' }, out['times'])
  end

  def test_an_attestation_under_the_same_key_pointing_at_the_declaration_reads_attested
    d = decl
    out = read(declaration: d, attestation: att(d))
    assert_equal 'attested', out['state']
    refute(out['lines'].any? { |l| l.include?(NOT_ATTESTED_LINE) })
    assert_equal({ 'T_d' => '2026-10-20T08:00:00Z', 'T_a' => '2026-10-21T09:00:00Z' }, out['times'])
  end

  # §4.1: attested means an attestation under the SAME signing key that
  # points at this declaration.
  def test_an_attestation_under_another_key_is_not_attested
    d = decl
    assert_not_attested(read(declaration: d, attestation: att(d, pubkey: PK_B)))
  end

  def test_an_attestation_pointing_at_another_declaration_is_not_attested
    d = decl
    other = { 'declaration_digest' => hex('another declaration'), 'recorded_at' => d['recorded_at'] }
    assert_not_attested(read(declaration: d, attestation: att(d, ref: other)))
    late = { 'declaration_digest' => d['declaration_digest'], 'recorded_at' => '2026-10-22T00:00:00Z' }
    assert_not_attested(read(declaration: d, attestation: att(d, ref: late)))
  end

  def test_the_started_at_note_appears_only_when_a_record_0_3_is_also_produced
    combinations.each do |name, kw|
      noted = read(**kw)['lines'].any? { |l| l.include?('started_at') }
      assert_equal kw.key?(:tier3_verdict), noted, name
    end
  end

  def test_forbidden_words_never_appear
    combinations.each do |name, kw|
      text = JSON.generate(read(**kw))
      FORBIDDEN.each { |w| refute_includes text, w, name }
    end
  end
end
