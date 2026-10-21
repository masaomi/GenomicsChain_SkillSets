# frozen_string_literal: true
# gc_tier3_estimate — cost before spending. Offline mode throughout so the
# suite neither needs a thoa account nor touches the network.
require 'minitest/autorun'
require 'json'

$LOAD_PATH.unshift(File.expand_path('../../genomicschain_core/lib', __dir__))
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'kairos_mcp/version'
require 'kairos_mcp/tools/base_tool'
require 'genomicschain_tier3'
require_relative '../tools/gc_tier3_estimate'

class GcTier3EstimateTest < Minitest::Test
  def tool = KairosMcp::SkillSets::GenomicschainTier3::Tools::GcTier3Estimate.new(nil)

  def estimate(**over)
    args = { 'n_cores' => 16, 'ram_gb' => 64, 'storage_gb' => 100,
             'estimated_hours' => 1.0, 'offline' => true }.merge(over.transform_keys(&:to_s))
    JSON.parse(tool.call(args).first[:text])
  end

  def test_exact_measured_point_uses_that_rate
    out = estimate
    assert_equal 261.4, out.dig('rate', 'credits_per_hour')
    assert_equal 'measured_table', out.dig('rate', 'source')
    assert_equal false, out.dig('rate', 'is_upper_bound')
    assert_equal 261.4, out.dig('credits', 'total')
  end

  # Cost is linear in run count, which is the whole reason run count is the
  # operator's choice rather than a fixed policy.
  def test_runs_multiply_the_total_exactly
    one = estimate(runs: 1)
    three = estimate(runs: 3)
    assert_equal 3, three.dig('request', 'runs')
    assert_in_delta one.dig('credits', 'total') * 3, three.dig('credits', 'total'), 0.1
    assert_equal one.dig('credits', 'per_run'), three.dig('credits', 'per_run')
  end

  def test_hours_scale_the_total
    assert_in_delta 2614.0, estimate(estimated_hours: 10.0).dig('credits', 'total'), 0.1
  end

  # Smaller requests fall back to the nearest COVERING measured point and are
  # flagged as an upper bound, rather than being interpolated onto a curve the
  # measured points do not actually follow.
  def test_uncovered_small_request_is_flagged_as_an_upper_bound
    out = estimate(n_cores: 3, ram_gb: 12, storage_gb: 40)
    assert_equal 58.7, out.dig('rate', 'credits_per_hour')
    assert_equal '4c/16GB/50GB', out.dig('rate', 'measured_point')
    assert_equal true, out.dig('rate', 'is_upper_bound')
    assert(out['warnings'].any? { |w| w.include?('UPPER bound') })
  end

  # The P5 case: bigger than anything measured. It must refuse to quote rather
  # than extrapolate.
  def test_request_beyond_the_measured_table_returns_no_price
    out = estimate(n_cores: 32, ram_gb: 256, storage_gb: 500)
    assert_nil out.dig('rate', 'credits_per_hour')
    assert_nil out['total_credits']
    assert_match(/no measured point covers/, out.dig('rate', 'refused_because'))
    refute out.key?('credits')
  end

  def test_plans_are_priced_and_limit_checked
    out = estimate(estimated_hours: 40.0)
    starter = out['plans'].find { |p| p['name'] == 'starter' }
    pro     = out['plans'].find { |p| p['name'] == 'pro' }

    # 40h exceeds Starter's 24h ceiling.
    assert_equal false, starter['job_fits_plan_limits']
    assert_equal true, pro['job_fits_plan_limits']
    assert(out['warnings'].any? { |w| w.include?("Starter plan's 24h") })

    # Starter has the cheapest token; the upper plans sell ceilings, not volume.
    assert starter['usd_per_token'] < pro['usd_per_token']
    assert_in_delta 0.014, starter['usd_per_token'], 0.0001
  end

  def test_plan_allowance_consumption_is_reported
    out = estimate(estimated_hours: 10.0)
    starter = out['plans'].find { |p| p['name'] == 'starter' }
    # 2614 credits against a 2500/month allowance.
    assert_in_delta 1.05, starter['months_of_allowance_consumed'], 0.02
  end

  def test_aws_reference_is_included_with_a_ratio
    out = estimate(estimated_hours: 10.0)
    aws = out['aws_on_demand_reference']
    assert_equal 'm5.4xlarge', aws['instance']
    assert_in_delta 9.20, aws['usd_for_this_job'], 0.01
    assert aws['thoa_over_aws'] > 3, 'thoa should price well above raw on-demand'
    assert_match(/costs nothing while idle/, aws['note'])
  end

  def test_single_run_is_warned_about_what_it_cannot_establish
    assert(estimate(runs: 1)['warnings'].any? { |w| w.include?('runs >= 2') })
    refute(estimate(runs: 2)['warnings'].any? { |w| w.include?('runs >= 2') })
  end

  def test_measured_rates_are_dated_so_staleness_is_visible
    assert_equal '2026-08-17', estimate.dig('rate', 'measured_at')
  end

  def test_input_validation
    assert_match(/estimated_hours must be > 0/, tool.call({ 'estimated_hours' => 0 }).first[:text])
    assert_match(/runs must be >= 1/, tool.call({ 'estimated_hours' => 1, 'runs' => 0 }).first[:text])
  end

  def test_schema_requires_only_estimated_hours
    assert_equal %w[estimated_hours], tool.input_schema[:required]
    assert_equal 'gc_tier3_estimate', tool.name
  end
  # prov design v0.1.15 §6.3 (8): an observation beside the estimate, read
  # from this node's registry (a stand-in here), per category, never summed.
  FakeEnvelope = Struct.new(:evidence)

  def with_registry(manifest, revoked: false)
    t = tool
    reg = Object.new
    reg.define_singleton_method(:find_proof) { |id| id == 'obs1' ? FakeEnvelope.new(JSON.generate('manifest' => manifest)) : nil }
    reg.define_singleton_method(:revoked?) { |_| revoked }
    t.define_singleton_method(:reach_registry) { reg }
    yield t
  end

  def test_an_observation_is_shown_beside_the_estimate_per_category
    counts = { 'containers' => { 'not_found' => 1, 'access_denied' => 2, 'error' => 0, 'not_attempted' => 0, 'exists' => { 'public_registry' => 5 } },
               'runtime' => { 'not_found' => 0, 'access_denied' => 0, 'error' => 1, 'not_attempted' => 0 },
               'software' => { 'not_found' => 0, 'access_denied' => 0, 'error' => 0, 'not_attempted' => 0 } }
    manifest = { 'record_type' => 'prov_reachability', 'observed_at' => '2026-10-18T12:00:00Z', 'observer' => 'anchor', 'counts' => counts }
    with_registry(manifest) do |t|
      out = JSON.parse(t.call('estimated_hours' => 1.0, 'offline' => true, 'reachability_proof_id' => 'obs1').first[:text])
      r = out['reachability']
      assert_equal '2026-10-18T12:00:00Z', r['observed_at']
      assert_equal({ 'containers' => { 'not_found' => 1, 'access_denied' => 2 }, 'runtime' => { 'error' => 1 } },
                   r['not_answering_per_category'])
      assert_equal false, r['revoked']
      assert_equal 261.4, out.dig('credits', 'total'), 'the estimate itself is unchanged'
      other = JSON.parse(t.call('estimated_hours' => 1.0, 'offline' => true, 'reachability_proof_id' => 'nope').first[:text])
      assert_includes other.dig('reachability', 'note'), 'no reachability observation'
    end
    with_registry(manifest.merge('record_type' => 'prov_attestation')) do |t|
      out = JSON.parse(t.call('estimated_hours' => 1.0, 'offline' => true, 'reachability_proof_id' => 'obs1').first[:text])
      assert_includes out.dig('reachability', 'note'), 'no reachability observation'
    end
  end

  def test_a_node_without_a_registry_says_so_and_still_estimates
    t = tool
    t.define_singleton_method(:reach_registry) { nil }
    out = JSON.parse(t.call('estimated_hours' => 1.0, 'offline' => true, 'reachability_proof_id' => 'obs1').first[:text])
    assert_includes out.dig('reachability', 'note'), 'cannot be read on this node'
    assert_equal 261.4, out.dig('credits', 'total')
    refute JSON.parse(tool.call('estimated_hours' => 1.0, 'offline' => true).first[:text]).key?('reachability')
  end

  # Review r1: a registry that fails, or a record whose counts are not
  # numbers, is named by its class beside an estimate that still comes back.
  def test_an_unreadable_registry_or_record_never_stops_the_estimate
    t = tool
    t.define_singleton_method(:reach_registry) { raise Errno::EACCES, '/secret/path/synoptis_data' }
    out = JSON.parse(t.call('estimated_hours' => 1.0, 'offline' => true, 'reachability_proof_id' => 'obs1').first[:text])
    assert_equal 261.4, out.dig('credits', 'total')
    assert_includes out.dig('reachability', 'note'), 'Errno::EACCES'
    refute_includes out.to_s, '/secret/path'
    bad = { 'record_type' => 'prov_reachability', 'counts' => { 'containers' => { 'not_found' => { 'x' => 1 } } } }
    with_registry(bad) do |t2|
      out = JSON.parse(t2.call('estimated_hours' => 1.0, 'offline' => true, 'reachability_proof_id' => 'obs1').first[:text])
      assert_equal 261.4, out.dig('credits', 'total')
      assert_includes out.dig('reachability', 'note'), 'cannot be read here'
    end
  end
end
