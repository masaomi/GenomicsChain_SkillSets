# frozen_string_literal: true
# B1ManifestHash Stage-1 vs Stage-2 pipe convention (R3 NF1).
require 'minitest/autorun'
require 'digest'
require 'kairos_mcp/version'
require 'kairos_mcp/skillset'
require_relative '../lib/genomicschain_core'

GCore = KairosMcp::SkillSets::GenomicschainCore

class B1ManifestHashTest < Minitest::Test
  def base
    {
      'canonical_id' => { 'value' => '10.1101/2025.01.29.635579' },
      'rubric_hash' => 'a' * 64,
      'assessor_id' => 'assessor',
      'assessed_at' => '2026-07-29',
      'funnel_stage' => 'stage1-prose-only',
      'assessor_stack' => { 'stage' => 'stage1-prose-only' },
      'manifest' => {}
    }
  end

  def test_stage1_four_pipe_fields
    r = base
    expected = Digest::SHA256.hexdigest(
      [r.dig('canonical_id', 'value'), r['rubric_hash'], r['assessor_id'], r['assessed_at']].join('|')
    )
    assert_equal expected, GCore::B1ManifestHash.compute(r)
    refute_includes GCore::B1ManifestHash.precommit_string(r), '|stage2'
  end

  def test_stage2_appends_fifth_field
    r = base.merge(
      'funnel_stage' => 'stage2-code-verified',
      'assessor_stack' => { 'stage' => 'stage2-code-verified' }
    )
    pre = GCore::B1ManifestHash.precommit_string(r)
    assert_equal(
      [r.dig('canonical_id', 'value'), r['rubric_hash'], r['assessor_id'], r['assessed_at'], 'stage2'].join('|'),
      pre
    )
    assert_equal Digest::SHA256.hexdigest(pre), GCore::B1ManifestHash.compute(r)
  end

  def test_empty_assessed_at_rejected_by_assert
    r = base.merge('assessed_at' => '')
    r['manifest'] = { 'b1_manifest_hash' => 'f' * 64 }
    assert_raises(GCore::SubmitCore::DigestMismatch) { GCore::B1ManifestHash.assert_matches!(r) }
  end
end
