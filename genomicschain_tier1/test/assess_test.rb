# frozen_string_literal: true

# gc_tier1_assess tests (genomicschain_tier1 package, spec v0.2).
require 'minitest/autorun'
require 'json'
require 'digest'

$LOAD_PATH.unshift(File.expand_path('../../genomicschain_core/lib', __dir__))
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'kairos_mcp/version'
require 'kairos_mcp/tools/base_tool'
require 'genomicschain_tier1'

A = KairosMcp::SkillSets::GenomicschainTier1::Assess

module AssessHelpers
  # A stub assessor. Tests drive the guards, not a provider.
  def llm_returning(fields)
    ->(_payload) { { 'status' => 'ok', 'model' => 'stub-model', 'provider' => 'stub', 'fields' => fields } }
  end

  def step(id, data: 2, code: 2, version: 2, params: 2, verdict: 'R', layer: 'C', **rest)
    { 'step_id' => id, 'label' => "step #{id}", 'layer' => layer,
      'axes' => { 'data' => data, 'code' => code, 'version' => version, 'params' => params },
      'verdict' => verdict }.merge(rest.transform_keys(&:to_s))
  end

  def llm_fields(steps:, capture_claim: 'floating', **rest)
    { 'paper_type' => 'pure-computational', 'reproduction_target' => 'demo',
      'step_source' => 'prose-methods', 'steps' => steps, 'gaps' => [], 'liveness' => [],
      'assessable' => { 'is_assessable' => true },
      'capture_claim' => capture_claim }.merge(rest.transform_keys(&:to_s))
  end

  def base_args(**over)
    { 'canonical_id' => { 'value' => '10.1101/2025.11.08.687335', 'kind' => 'doi' },
      'sources' => [{ 'kind' => 'paper_text', 'ref' => 'jats', 'content' => 'Methods...' }],
      'funnel_stage' => 'stage1-prose-only',
      'assessor_id' => 'gc_tier1_assess/0.1 + masaomi',
      'operator_id' => 'masaomi',
      'assessed_at' => '2026-08-04' }.merge(over)
  end

  def run_assess(fields, **over)
    A::Assessor.new(llm: llm_returning(fields)).run(base_args(**over))
  end
end

class PreCommitTest < Minitest::Test
  include AssessHelpers

  # The corpus pinned the digest of the WHOLE rubric file, frontmatter included.
  def test_rubric_hash_matches_the_201_report_corpus
    assert_equal A::PreCommit::KNOWN_RUBRIC_HASH, A::PreCommit.rubric_hash
  end

  def test_b1_is_computed_by_core_and_gains_a_stage2_field
    s1 = A::PreCommit.build(canonical_id: { 'value' => 'doi:x' }, assessor_id: 'a',
                            funnel_stage: 'stage1-prose-only', assessed_at: '2026-08-04')
    s2 = A::PreCommit.build(canonical_id: { 'value' => 'doi:x' }, assessor_id: 'a',
                            funnel_stage: 'stage2-code-verified', assessed_at: '2026-08-04')

    assert_equal Digest::SHA256.hexdigest(['doi:x', A::PreCommit.rubric_hash, 'a', '2026-08-04'].join('|')),
                 s1['b1_manifest_hash']
    assert_equal Digest::SHA256.hexdigest(
      ['doi:x', A::PreCommit.rubric_hash, 'a', '2026-08-04', 'stage2'].join('|')
    ), s2['b1_manifest_hash']
    refute_equal s1['b1_manifest_hash'], s2['b1_manifest_hash']
  end

  def test_assessed_at_must_be_a_date
    assert_raises(A::PreCommit::PreCommitError) do
      A::PreCommit.build(canonical_id: { 'value' => 'x' }, assessor_id: 'a',
                         funnel_stage: 'stage1-prose-only', assessed_at: '2026-08-04T10:00:00Z')
    end
  end
end

class Stage1GuardTest < Minitest::Test
  include AssessHelpers

  # The corpus is 201 reports, all stage1, with 0 R steps between them. An assessor
  # that claims R from prose is claiming something stage 1 cannot see.
  def test_stage1_caps_version_and_cannot_reach_r_star
    out = run_assess(llm_fields(steps: [step('C1'), step('C2')]))

    assert_equal 0, out.dig('derived', 'counts', 'n_R')
    assert_equal 2, out.dig('derived', 'counts', 'n_RI')
    assert(out['report']['steps'].all? { |s| s.dig('axes', 'version') == 1 })
    assert(out['report']['steps'].all? { |s| s['env_capture_class'] == 'n/a' })
    assert_includes out['report']['steps'].first['subflags'], 'stage1-ceiling-demoted'
    assert(out.dig('guards', 'stage_demotions').any? { |d| d['reason'] == 'stage1-claim-only' })
  end

  def test_stage1_levers_are_all_false
    levers = run_assess(llm_fields(steps: [step('C1')])).dig('derived', 'levers')

    assert_equal false, levers['software_env_lock']
    assert_equal false, levers['in_code_db_pin_classA']
    assert_equal false, levers['has_validated_env_capture']
    assert_equal 'unverified (stage1)', levers['software_env_platform_coverage']
  end

  def test_static_readiness_carries_the_stage1_ceiling_qualifier
    headline = run_assess(llm_fields(steps: [step('C1')])).dig('derived', 'headline')

    assert_includes headline['static_readiness'], 'stage1 ceiling only'
    assert_includes headline['static_readiness'], 'no R-star'
    # The upper bound must name itself as a bound and disown the word "reproducible".
    assert_includes headline['inference_inclusive_upper_bound'], 'readiness upper bound'
    assert_includes headline['inference_inclusive_upper_bound'], 'never "reproducible"'
  end

  # Four of the 201 corpus reports emitted a non-zero n_fetch_required at stage 1,
  # against their own prompt. Force the rule, but never silently.
  def test_stage1_forces_fetch_counts_to_zero_and_records_it
    out = run_assess(llm_fields(steps: [step('C1', subflags: ['fetch-required'])]))

    assert_equal 0, out.dig('derived', 'counts', 'n_fetch_required')
    assert(out.dig('guards', 'stage_demotions').any? { |d| d['reason'] == 'stage1-forced-zero' })
  end
end

class FieldShapeTest < Minitest::Test
  include AssessHelpers

  # 519 of the corpus's violations are version_subtier values outside the enum,
  # 457 of them the literal "none". The rubric says report it WHEN version=1.
  def test_version_subtier_is_omitted_unless_version_is_one
    out = run_assess(llm_fields(steps: [step('C1', version_subtier: 'none')]),
                     'funnel_stage' => 'stage1-prose-only')
    s = out['report']['steps'].first

    assert_equal 1, s.dig('axes', 'version')
    assert_equal 'floating', s['version_subtier'] # version==1, so a valid subtier is required
  end

  def test_null_axes_are_filled_and_recorded
    broken = step('C1')
    broken['axes']['data'] = nil
    out = run_assess(llm_fields(steps: [broken]))

    assert_equal 0, out['report']['steps'].first.dig('axes', 'data')
    assert(out.dig('guards', 'stage_demotions').any? { |d| d['reason'] == 'unscored-axis-filled' })
  end

  def test_wet_lab_steps_are_zeroed_oos_and_excluded_from_S
    out = run_assess(llm_fields(steps: [step('C1'), step('W1', layer: 'W')]))

    assert_equal 1, out.dig('derived', 'counts', 'S')
    assert_equal 1, out.dig('derived', 'counts', 'W')
    w = out['report']['steps'].last
    assert_equal 'OOS', w['verdict']
    assert_equal({ 'data' => 0, 'code' => 0, 'version' => 0, 'params' => 0 }, w['axes'])
  end

  def test_capture_claim_outside_the_enum_fails_closed
    err = assert_raises(A::Derivation::DerivationError) do
      run_assess(llm_fields(steps: [step('C1')], capture_claim: 'env_lock'))
    end
    assert_includes err.message, 'outside the enum'
  end
end

class Stage2Test < Minitest::Test
  include AssessHelpers

  def stage1_report
    JSON.parse(run_assess(llm_fields(steps: [step('C1')]))['report_json'])
  end

  def stage2_run(steps, evidence: { 'software_env_lock' => true, 'lock_cite' => 'conda-lock.yml',
                                    'platform_coverage' => 'linux-64 only' }, claim: 'env_lock_claimed')
    prior = stage1_report
    fields = llm_fields(steps: steps, capture_claim: claim, lever_evidence: evidence)
    A::Assessor.new(llm: llm_returning(fields)).run(
      base_args('funnel_stage' => 'stage2-code-verified',
                'prior_report_json' => JSON.generate(prior),
                'sources' => [{ 'kind' => 'paper_text', 'ref' => 'jats', 'content' => 'Methods' },
                              { 'kind' => 'repo_file', 'ref' => 'conda-lock.yml', 'content' => 'x' }])
    )
  end

  def test_stage2_requires_a_code_source
    err = assert_raises(A::Assessor::AssessError) do
      A::Assessor.new(llm: llm_returning(llm_fields(steps: [step('C1')]))).run(
        base_args('funnel_stage' => 'stage2-code-verified', 'prior_report_json' => JSON.generate(stage1_report))
      )
    end
    assert_includes err.message, 'repo_file'
  end

  def test_stage2_requires_the_prior_stage1_report
    err = assert_raises(A::Assessor::AssessError) do
      A::Assessor.new(llm: llm_returning(llm_fields(steps: [step('C1')]))).run(
        base_args('funnel_stage' => 'stage2-code-verified',
                  'sources' => [{ 'kind' => 'repo_file', 'ref' => 'Snakefile', 'content' => 'x' }])
      )
    end
    assert_includes err.message, 'prior_report_json'
  end

  def test_supersedes_points_at_the_stage1_b1_hash
    prior = stage1_report
    out = stage2_run([step('C1', env_capture_class: 'A_verified_in_code', lock_covers_toolchain: true)])

    assert_equal prior.dig('manifest', 'b1_manifest_hash'), out['report'].dig('manifest', 'supersedes')
    refute_equal prior.dig('manifest', 'b1_manifest_hash'), out['report'].dig('manifest', 'b1_manifest_hash')
  end

  def test_version_two_step_carries_no_subtier
    out = stage2_run([step('C1', env_capture_class: 'A_verified_in_code', lock_covers_toolchain: true)])

    assert_nil out['report']['steps'].first['version_subtier']
  end

  def test_r_star_needs_class_a_and_toolchain_coverage
    covered = stage2_run([step('C1', env_capture_class: 'A_verified_in_code', lock_covers_toolchain: true)])
    assert_equal 1, covered.dig('derived', 'counts', 'n_R')

    uncovered = stage2_run([step('C1', env_capture_class: 'A_verified_in_code', lock_covers_toolchain: false)])
    assert_equal 0, uncovered.dig('derived', 'counts', 'n_R')
    assert(uncovered.dig('guards', 'stage_demotions').any? { |d| d['reason'] == 'stage2-r-gate' })
  end

  # The aMeta shape: a genuine conda-lock, but every external DB pinned in prose
  # only. v0.1 of the spec would have called this "validated env capture".
  def test_lock_upheld_but_no_r_star_is_not_validated_env_capture
    out = stage2_run([step('C1', env_capture_class: 'B_pin_prose_only', version: 1,
                           version_subtier: 'exact_pins_partial', lock_covers_toolchain: false)])

    assert_equal true, out.dig('derived', 'levers', 'software_env_lock')
    assert_equal false, out.dig('derived', 'levers', 'in_code_db_pin_classA')
    assert_equal false, out.dig('derived', 'levers', 'has_validated_env_capture')
    assert_equal 0, out.dig('derived', 'counts', 'n_R')
  end

  def test_lock_claim_is_refused_when_its_citation_names_no_supplied_source
    out = stage2_run([step('C1', env_capture_class: 'A_verified_in_code', lock_covers_toolchain: true)],
                     evidence: { 'software_env_lock' => true, 'lock_cite' => 'pixi.lock' })

    assert_equal false, out.dig('derived', 'levers', 'software_env_lock')
  end

  def test_stage2_static_readiness_carries_the_unexecuted_qualifier
    out = stage2_run([step('C1', env_capture_class: 'A_verified_in_code', lock_covers_toolchain: true)])
    line = out.dig('derived', 'headline', 'static_readiness')

    assert_includes line, 'unexecuted'
    assert_includes line, 'n_exact_capture_unexecuted='
    assert_includes line, 'n_fetch_required='
  end
end

class Stage2CandidateTest < Minitest::Test
  include AssessHelpers

  def candidate_for(claim)
    run_assess(llm_fields(steps: [step('C1')], capture_claim: claim)).dig('derived', 'stage2_candidate')
  end

  def test_positive_gate
    %w[env_lock_claimed container_digest_claimed release_snapshot].each do |claim|
      assert_equal true, candidate_for(claim), claim
    end
  end

  # Protocol v0.2.6 removed exact_pins_partial from the positive gate: prose already
  # caps it at version=1, so a code check yields zero R-star gain. Those papers reach
  # stage 2 only through the separately drawn audit gate.
  def test_exact_pins_partial_is_off_the_positive_gate
    %w[exact_pins_partial floating none].each do |claim|
      assert_equal false, candidate_for(claim), claim
    end
  end
end

class ReportShapeTest < Minitest::Test
  include AssessHelpers

  def test_report_is_never_signed_and_omits_report_content_hash
    report = run_assess(llm_fields(steps: [step('C1')]))['report']

    assert_equal false, report.dig('human_signoff', 'signed')
    assert_nil report['report_content_hash']
    assert_equal 'not-yet-recorded', report.dig('manifest', 'chain_record')
  end

  def test_tool_derived_fields_from_the_llm_are_dropped_and_reported
    fields = llm_fields(steps: [step('C1')],
                        counts: { 'n_R' => 99 }, funnel_stage: 'stage2-code-verified',
                        human_signoff: { 'signed' => true, 'reviewer_id' => 'self' })
    out = run_assess(fields)

    assert_equal 0, out.dig('derived', 'counts', 'n_R')
    assert_equal false, out['report'].dig('human_signoff', 'signed')
    assert_equal 'stage1-prose-only', out['report']['funnel_stage']
    assert_includes out.dig('guards', 'llm_overreach'), 'counts'
    assert_includes out.dig('guards', 'llm_overreach'), 'human_signoff'
  end

  def test_emitted_report_validates_and_b1_recomputes
    out = run_assess(llm_fields(steps: [step('C1')]))

    assert_equal 'ok', out.dig('guards', 'schema')
    assert_equal 'ok', out.dig('guards', 'b1_manifest_hash')
    assert_equal true, out.dig('guards', 'rubric_hash_matches_corpus')
    report = JSON.parse(out['report_json'])
    assert KairosMcp::SkillSets::GenomicschainCore::B1ManifestHash.matches?(report)
  end

  def test_repro_index_is_refused_below_four_steps
    small = run_assess(llm_fields(steps: [step('C1')]))
    assert_nil small.dig('derived', 'headline', 'repro_index')

    big = run_assess(llm_fields(steps: (1..4).map { |i| step("C#{i}") }))
    assert_equal 4, big.dig('derived', 'headline', 'repro_index', 'S')
  end

  def test_dry_run_commits_nothing_and_calls_no_llm
    exploding = ->(_p) { raise 'the LLM must not be called on a dry run' }
    out = A::Assessor.new(llm: exploding).run(base_args('dry_run' => true))

    assert_equal 'dry_run', out['status']
    assert_match(/\A[a-f0-9]{64}\z/, out.dig('would_commit', 'b1_manifest_hash'))
  end
end

class GateTest < Minitest::Test
  include AssessHelpers

  def assert_refused(message, **over)
    err = assert_raises(A::Assessor::AssessError) do
      A::Assessor.new(llm: llm_returning(llm_fields(steps: [step('C1')]))).run(base_args(**over))
    end
    assert_includes err.message, message
  end

  def test_gates
    assert_refused('at least one source', 'sources' => [])
    assert_refused('canonical_id.value', 'canonical_id' => { 'value' => '', 'kind' => 'doi' })
    assert_refused('canonical_id.kind', 'canonical_id' => { 'value' => 'x', 'kind' => 'arxiv' })
    assert_refused('operator_id', 'operator_id' => '')
    assert_refused('funnel_stage', 'funnel_stage' => 'stage3')
    assert_refused('neither content nor sha256',
                   'sources' => [{ 'kind' => 'paper_text', 'ref' => 'r' }])
    assert_refused('sources[0].kind',
                   'sources' => [{ 'kind' => 'tweet', 'ref' => 'r', 'content' => 'x' }])
  end

  # Self-application design O-3: a paper with no DOI is named by the sha256 of
  # its text, and the name must be the hash of a text actually supplied.
  def test_text_sha256_names_the_supplied_paper_text
    text_id = Digest::SHA256.hexdigest('Methods...')
    out = A::Assessor.new(llm: llm_returning(llm_fields(steps: [step('C1')])))
                     .run(base_args('canonical_id' => { 'value' => text_id, 'kind' => 'text_sha256' }))

    assert_equal 'ok', out.dig('guards', 'schema')
    assert_equal 'text_sha256', JSON.parse(out['report_json']).dig('canonical_id', 'kind')

    assert_refused('64 lowercase hex', 'canonical_id' => { 'value' => 'not-a-hash', 'kind' => 'text_sha256' })
    assert_refused('supplied paper_text content',
                   'canonical_id' => { 'value' => Digest::SHA256.hexdigest('other text'), 'kind' => 'text_sha256' })
    assert_refused('supplied paper_text content',
                   'canonical_id' => { 'value' => text_id, 'kind' => 'text_sha256' },
                   'sources' => [{ 'kind' => 'paper_text', 'ref' => 'jats', 'sha256' => text_id }])
  end
end

class LiveRunRegressionTest < Minitest::Test
  include AssessHelpers

  # Both found on the first run against a real assessor (2026-08-04,
  # 10.1101/2025.11.08.687335).

  # The assessor emitted no step_ids, and a flat S1..S19 sequence hides the
  # layer that inter-rater agreement is aligned on.
  def test_generated_step_ids_follow_the_corpus_C_W_convention
    steps = [step('', layer: 'C'), step('', layer: 'W'), step('', layer: 'C')]
    ids = run_assess(llm_fields(steps: steps))['report']['steps'].map { |s| s['step_id'] }

    assert_equal %w[C1 W1 C2], ids
  end

  # An assessor that scores every axis >= 1 and then writes NI has contradicted
  # itself; axis-min wins, but that correction goes UP and must say so.
  def test_a_verdict_raised_by_axis_min_is_not_labelled_a_demotion
    out = run_assess(llm_fields(steps: [step('C1', data: 1, code: 1, version: 1, params: 2, verdict: 'NI')]))
    change = out.dig('guards', 'stage_demotions').find { |d| d['field'] == 'verdict' }

    assert_equal 'RI', out['report']['steps'].first['verdict']
    assert_equal 'axis-min-raised', change['reason']
    refute_includes out['report']['steps'].first['subflags'], 'stage1-ceiling-demoted'
  end
end

require_relative '../tools/gc_tier1_assess'
require 'genomicschain_core/comparison_body'

# Self-application design §6.4: a Tier-1 run recorded through the tool,
# replayed with its response injected, gives the same comparison body and
# sends the same request — the check that the prompt builder, not only the
# derivation, agrees between two builds of the checker.
class RecordAndReplayTest < Minitest::Test
  include AssessHelpers

  Registry = Struct.new(:fields) do
    def call_tool(_name, _args, invocation_context:)
      [{ text: JSON.generate('status' => 'ok', 'model' => 'm', 'provider' => 'p', 'fields' => fields) }]
    end
  end

  def test_a_recorded_exchange_replays_to_the_same_body_and_request
    tool = KairosMcp::SkillSets::GenomicschainTier1::Tools::GcTier1Assess
           .new(nil, registry: Registry.new(llm_fields(steps: [step('C1')])))
    recorded = JSON.parse(tool.call(base_args.merge('record_llm_exchange' => true)).first[:text])
    exchange = recorded.fetch('llm_exchange')

    sent = nil
    replayed = A::Assessor.new(llm: ->(req) { sent = req; exchange['response'] }).run(base_args)

    body = KairosMcp::SkillSets::GenomicschainCore::ComparisonBody
    assert_equal body.digest('tier1_report', JSON.parse(recorded['report_json']))['sha256'],
                 body.digest('tier1_report', JSON.parse(replayed['report_json']))['sha256']
    assert_equal exchange['request'], JSON.parse(JSON.generate(sent.compact))
    refute JSON.parse(tool.call(base_args).first[:text]).key?('llm_exchange')
  end
end
