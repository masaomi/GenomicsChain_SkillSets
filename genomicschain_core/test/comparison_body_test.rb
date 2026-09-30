# frozen_string_literal: true
# The self-application DDC compares these bodies between two builds of the
# checker (design §6.4, INV-S10). A body that drops too much, or that two
# broken records share, would report agreement that never happened.
require 'minitest/autorun'
require 'kairos_mcp/version'
require 'genomicschain_core/comparison_body'

class ComparisonBodyTest < Minitest::Test
  CB = KairosMcp::SkillSets::GenomicschainCore::ComparisonBody

  def tier1(invoked_at: '2026-10-01T00:00:00Z', headline: { 'static_readiness' => 'partial' })
    { 'rubric_version' => '0.2.5', 'metric_semantics_version' => '0.2.5', 'rubric_hash' => 'r' * 64,
      'canonical_id' => { 'value' => 'c' * 64, 'kind' => 'text_sha256', 'aliases' => [] },
      'assessor_id' => 'a', 'assessed_at' => '2026-10-01', 'funnel_stage' => 'stage1-prose-only',
      'steps' => [], 'counts' => { 'n' => 0 }, 'headline' => headline, 'gaps' => [],
      'human_signoff' => { 'signed' => false },
      'assessor_stack' => { 'operator_id' => 'o', 'llm' => { 'model' => 'm', 'invoked_at' => invoked_at } },
      'manifest' => { 'b1_manifest_hash' => 'b' * 64 } }
  end

  def test_only_the_excluded_fields_may_differ
    same = CB.digest('tier1_report', tier1(invoked_at: '2027-01-01T00:00:00Z'))['sha256']
    assert_equal CB.digest('tier1_report', tier1)['sha256'], same
    refute_equal CB.digest('tier1_report', tier1)['sha256'],
                 CB.digest('tier1_report', tier1(headline: { 'static_readiness' => 'ready' }))['sha256']
    refute_includes CB.digest('tier1_report', tier1)['canonical'], 'invoked_at'
  end

  def test_platform_and_root_are_excluded_and_versions_are_kept
    scan = lambda do |root, platform, ruby|
      { 'target' => { 'root' => root, 'evidence_digest' => 'e' * 64,
                      'toolchain' => { 'ruby' => ruby, 'ruby_platform' => platform, 'psych' => '5.2.2' } },
        'counts_by_pin' => {}, 'counts_by_kind' => {}, 'counts_in_fixtures' => {}, 'findings' => [],
        'declarations' => [], 'prose_locators' => [], 'rules' => [] }
    end
    a = CB.digest('tier2_scan', scan.call('/Users/x/repo', 'arm64-darwin23', '3.4.10'))['sha256']
    assert_equal a, CB.digest('tier2_scan', scan.call('/work/repo', 'x86_64-linux', '3.4.10'))['sha256']
    refute_equal a, CB.digest('tier2_scan', scan.call('/work/repo', 'x86_64-linux', '3.2.3'))['sha256']
  end

  def test_a_field_in_neither_list_stops_extraction
    err = assert_raises(CB::Incomplete) { CB.extract('tier1_report', tier1.merge('new_field' => 1)) }
    assert_includes err.message, 'new_field'
  end

  def test_an_empty_or_verdictless_record_yields_no_body
    assert_raises(CB::Incomplete) { CB.digest('tier3_compare', {}) }
    assert_raises(CB::Incomplete) do
      CB.digest('tier3_compare', 'run_count' => 1, 'result_hash' => nil, 'output_files' => [], 'comparison_verdict' => 'mismatch')
    end
  end
end
