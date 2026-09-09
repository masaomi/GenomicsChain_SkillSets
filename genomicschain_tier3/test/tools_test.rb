# frozen_string_literal: true
# gc_tier3_execute MCP wrapper tests (record 0.3 — two verdict axes).
require 'minitest/autorun'
require 'tmpdir'
require 'json'
require 'digest'

$LOAD_PATH.unshift(File.expand_path('../../genomicschain_core/lib', __dir__))
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'kairos_mcp/version'
require 'kairos_mcp/tools/base_tool'
require 'genomicschain_tier3'
require_relative '../tools/gc_tier3_execute'

GT = KairosMcp::SkillSets::GenomicschainTier3::Tools

module ToolHelpers
  def payload(response)
    JSON.parse(response.first[:text])
  end

  def error?(response)
    response.first[:text].start_with?('Error:')
  end

  def base_args(tmp)
    {
      'subject_ref' => 'repro://656122/C9',
      'backend' => 'local',
      'env' => { 'lock' => 'sha256:envlock' },
      'data' => { 'accessions' => [] },
      'pipeline' => { 'steps' => ['C9'], 'step_source' => 'stage2',
                      'command' => ['bash', '-c', 'printf hi > out.txt'], 'workdir' => tmp }
    }
  end

  def local_args(tmp, expected_sha:, target: 'file:out.txt')
    base_args(tmp).merge(
      'expected_output' => { 'target' => target, 'sha256' => expected_sha,
                             'source' => 'paper_declared',
                             'source_citation' => 'doi:10.1038/s41467-018-06108-1',
                             'validated_by' => 'human:masaomi' }
    )
  end
end

class GcTier3ExecuteTest < Minitest::Test
  include ToolHelpers

  def tool = GT::GcTier3Execute.new(nil)

  # --- with a declared target -------------------------------------------

  def test_local_run_matching_target_yields_match_exact
    Dir.mktmpdir do |tmp|
      out = payload(tool.call(local_args(tmp, expected_sha: Digest::SHA256.hexdigest('hi'))))

      assert_equal 'completed', out['execution_verdict']
      assert_equal 'match_exact', out['comparison_verdict']
      assert_equal 1, out['run_count']
      assert_equal 'self_reported', out['trust_tier']
      assert_equal 'local', out.dig('backend', 'id')
      assert_equal 'exact_sha256', out.dig('verdict_result', 'comparator_id')
      assert_equal 'file:out.txt', out.dig('verdict_result', 'expected_output_target')
      assert_nil out['first_divergence']
      assert_equal out.dig('verdict_result', 'jobspec_digest'),
                   KairosMcp::Manifest.canonical_json_sha256(JSON.parse(out['jobspec_json']))
      assert_equal false, out.dig('backend', 'reports_own_result_hash')
    end
  end

  def test_mismatch_captures_first_divergence_and_warns_exact_is_strict
    Dir.mktmpdir do |tmp|
      out = payload(tool.call(local_args(tmp, expected_sha: 'f' * 64)))

      assert_equal 'completed', out['execution_verdict']
      assert_equal 'mismatch', out['comparison_verdict']
      assert_equal 'file:out.txt', out.dig('first_divergence', 'compared_mode')
      assert_equal Digest::SHA256.hexdigest('hi'), out.dig('first_divergence', 'produced')
      assert(out['notes'].any? { |n| n.include?('exact_sha256 is strict') })
    end
  end

  def test_aggregate_target_compares_the_result_tree
    Dir.mktmpdir do |tmp|
      out = payload(tool.call(local_args(tmp, expected_sha: 'f' * 64, target: 'result_tree')))
      assert_equal 'result_tree_sha256', out.dig('first_divergence', 'compared_mode')
      assert_equal out.dig('verdict_result', 'result_hash'), out.dig('first_divergence', 'produced')
    end
  end

  # --- without a declared target (the common case) ------------------------

  def test_absent_expected_output_is_accepted_and_reported_as_no_target
    Dir.mktmpdir do |tmp|
      out = payload(tool.call(base_args(tmp)))

      assert_equal 'completed', out['execution_verdict']
      assert_equal 'no_target_declared', out['comparison_verdict']
      refute out.key?('expected_output')
      assert_nil out.dig('verdict_result', 'expected_output_sha256')
      assert(out['notes'].any? { |n| n.include?('complete outcome, not an inconclusive one') })
      assert_match(/ran to completion/, out['establishes'])
      assert_match(/declares no target/, out['establishes'])
    end
  end

  def test_schema_no_longer_requires_expected_output
    schema = tool.input_schema
    assert_equal %w[subject_ref pipeline], schema[:required]
    assert_equal %w[local thoa], schema.dig(:properties, :backend, :enum)
    assert_equal 'gc_tier3_execute', tool.name
  end

  # --- repeated runs ------------------------------------------------------

  def test_runs_above_one_requires_matching_run_workdirs
    Dir.mktmpdir do |tmp|
      response = tool.call(base_args(tmp).merge('runs' => 2))
      assert error?(response)
      assert_match(/run_workdirs with 2 distinct/, response.first[:text])
    end
  end

  def test_two_runs_report_self_consistency
    Dir.mktmpdir do |a|
      Dir.mktmpdir do |b|
        args = base_args(a).merge('runs' => 2, 'run_workdirs' => [a, b])
        out = payload(tool.call(args))

        assert_equal 2, out['run_count']
        assert_equal true, out.dig('self_consistency', 'all_identical')
        assert_equal 2, out.dig('self_consistency', 'runs')
        assert_match(/2 time\(s\)/, out['establishes'])
        assert_match(/All 2 runs produced the same result/, out['establishes'])
      end
    end
  end

  def test_duplicate_run_workdirs_are_refused
    Dir.mktmpdir do |tmp|
      response = tool.call(base_args(tmp).merge('runs' => 2, 'run_workdirs' => [tmp, tmp]))
      assert error?(response)
      assert_match(/distinct/, response.first[:text])
    end
  end

  # --- provenance surfaced to the caller ----------------------------------

  def test_operator_authored_environment_is_flagged_in_notes
    Dir.mktmpdir do |tmp|
      out = payload(tool.call(base_args(tmp).merge('environment_provenance' => 'authored_by_operator')))
      assert_equal 'authored_by_operator', out.dig('verdict_result', 'environment_provenance')
      assert(out['notes'].any? { |n| n.include?('must not describe this run') })
      assert_match(/NOT one the paper supplied/, out['establishes'])
    end
  end

  def test_controlled_access_inputs_are_flagged_in_notes
    Dir.mktmpdir do |tmp|
      out = payload(tool.call(base_args(tmp).merge('inputs_provenance' => 'controlled_access')))
      assert_equal 'controlled_access', out.dig('verdict_result', 'inputs_provenance')
      assert(out['notes'].any? { |n| n.include?('cannot repeat this run') })
    end
  end

  # --- failure paths ------------------------------------------------------

  def test_failing_command_gates_to_env_failed
    Dir.mktmpdir do |tmp|
      args = local_args(tmp, expected_sha: 'f' * 64)
      args['pipeline'] = args['pipeline'].merge('command' => ['bash', '-c', 'echo boom >&2; exit 7'])
      out = payload(tool.call(args))

      assert_equal 'env_failed', out['execution_verdict']
      assert_equal 'not_attempted', out['comparison_verdict']
      assert_nil out.dig('verdict_result', 'comparator_id')
      assert_match(/boom/, out['backend_diagnostics'])
      assert_match(/Nothing was established/, out['establishes'])
    end
  end

  def test_successful_run_carries_no_backend_diagnostics
    Dir.mktmpdir do |tmp|
      out = payload(tool.call(local_args(tmp, expected_sha: Digest::SHA256.hexdigest('hi'))))
      refute out.key?('backend_diagnostics')
    end
  end

  def test_unknown_backend_and_missing_workdir_are_clean_errors
    Dir.mktmpdir do |tmp|
      assert error?(tool.call(base_args(tmp).merge('backend' => 'aws_tee')))

      no_workdir = base_args(tmp)
      no_workdir['pipeline'] = no_workdir['pipeline'].reject { |k, _| k == 'workdir' }
      response = tool.call(no_workdir)
      assert error?(response)
      assert_match(/workdir could not be resolved/, response.first[:text])
    end
  end

  def test_relative_workdir_is_rejected
    Dir.mktmpdir do |tmp|
      response = tool.call(base_args(tmp).merge('workdir' => 'relative/dir'))
      assert error?(response)
      assert_match(/absolute path/, response.first[:text])
    end
  end

  def test_thoa_backend_fails_closed_when_the_cli_or_key_is_absent
    skip 'thoa CLI + THOA_API_KEY present: the fail-closed path is not exercised here' if thoa_ready?

    Dir.mktmpdir do |tmp|
      args = base_args(tmp).merge(
        'backend' => 'thoa',
        'pipeline' => { 'steps' => ['C9'], 'cmd' => 'printf hi > out.txt', 'download_dir' => tmp }
      )
      response = tool.call(args)
      assert error?(response)
      assert_match(/thoa CLI not found|THOA_API_KEY/, response.first[:text])
    end
  end

  private

  def thoa_ready?
    key = ENV['THOA_API_KEY']
    !key.to_s.strip.empty? &&
      (system('which thoa > /dev/null 2>&1') || system('conda run -n thoa_py3.11 which thoa > /dev/null 2>&1'))
  end
end
