# frozen_string_literal: true
# gc_tier2_execute MCP wrapper tests (genomicschain_tier2 package).
require 'minitest/autorun'
require 'tmpdir'
require 'json'
require 'digest'

$LOAD_PATH.unshift(File.expand_path('../../genomicschain_core/lib', __dir__))
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'kairos_mcp/version'
require 'kairos_mcp/tools/base_tool'
require 'genomicschain_tier2'
require_relative '../tools/gc_tier2_execute'

GT = KairosMcp::SkillSets::GenomicschainTier2::Tools

module ToolHelpers
  def payload(response)
    JSON.parse(response.first[:text])
  end

  def error?(response)
    response.first[:text].start_with?('Error:')
  end

  def local_args(tmp, expected_sha:, target: 'file:out.txt')
    {
      'subject_ref' => 'repro://656122/C9',
      'backend' => 'local',
      'env' => { 'lock' => 'sha256:envlock' },
      'data' => { 'accessions' => [] },
      'pipeline' => { 'steps' => ['C9'], 'step_source' => 'stage2',
                      'command' => ['bash', '-c', 'printf hi > out.txt'], 'workdir' => tmp },
      'expected_output' => { 'target' => target, 'sha256' => expected_sha,
                             'source' => 'paper_declared',
                             'source_citation' => 'doi:10.1038/s41467-018-06108-1',
                             'validated_by' => 'human:masaomi' }
    }
  end
end

class GcTier2ExecuteTest < Minitest::Test
  include ToolHelpers

  def tool = GT::GcTier2Execute.new(nil)

  def test_local_run_matching_expected_output_yields_executed_r
    Dir.mktmpdir do |tmp|
      out = payload(tool.call(local_args(tmp, expected_sha: Digest::SHA256.hexdigest('hi'))))

      assert_equal 'executed_r', out['verdict']
      assert_equal 'self_reported', out['trust_tier']
      assert_equal 'local', out.dig('backend', 'id')
      assert_equal 'exact_sha256', out.dig('verdict_result', 'comparator_id')
      assert_equal 'file:out.txt', out.dig('verdict_result', 'expected_output_target')
      assert_nil out['first_divergence']
      assert_equal out.dig('verdict_result', 'jobspec_digest'),
                   KairosMcp::Manifest.canonical_json_sha256(JSON.parse(out['jobspec_json']))
      assert_equal false, out.dig('backend', 'reports_own_result_hash')
      assert(out['notes'].any? { |n| n.include?('no independent result hash') })
    end
  end

  def test_mismatch_is_inconclusive_and_captures_first_divergence
    Dir.mktmpdir do |tmp|
      out = payload(tool.call(local_args(tmp, expected_sha: 'f' * 64)))

      assert_equal 'executed_inconclusive_needs_tolerance', out['verdict']
      assert_equal 'file:out.txt', out.dig('first_divergence', 'compared_mode')
      assert_equal Digest::SHA256.hexdigest('hi'), out.dig('first_divergence', 'produced')
      assert(out['notes'].any? { |n| n.include?('DIAGNOSTIC') })
    end
  end

  def test_aggregate_target_compares_the_result_tree
    Dir.mktmpdir do |tmp|
      args = local_args(tmp, expected_sha: 'f' * 64, target: 'result_tree')
      out = payload(tool.call(args))
      assert_equal 'result_tree_sha256', out.dig('first_divergence', 'compared_mode')
      assert_equal out.dig('verdict_result', 'result_hash'), out.dig('first_divergence', 'produced')
    end
  end

  def test_failing_command_gates_to_env_failed
    Dir.mktmpdir do |tmp|
      args = local_args(tmp, expected_sha: 'f' * 64)
      args['pipeline'] = args['pipeline'].merge('command' => ['bash', '-c', 'echo boom >&2; exit 7'])
      out = payload(tool.call(args))

      assert_equal 'env_failed', out['verdict']
      assert_nil out.dig('verdict_result', 'comparator_id')
      assert_match(/boom/, out['backend_diagnostics'])
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
      bad_backend = local_args(tmp, expected_sha: 'f' * 64).merge('backend' => 'aws_tee')
      assert error?(tool.call(bad_backend))

      no_workdir = local_args(tmp, expected_sha: 'f' * 64)
      no_workdir['pipeline'] = no_workdir['pipeline'].reject { |k, _| k == 'workdir' }
      response = tool.call(no_workdir)
      assert error?(response)
      assert_match(/workdir could not be resolved/, response.first[:text])
    end
  end

  def test_relative_workdir_is_rejected
    Dir.mktmpdir do |tmp|
      args = local_args(tmp, expected_sha: 'f' * 64).merge('workdir' => 'relative/dir')
      response = tool.call(args)
      assert error?(response)
      assert_match(/absolute path/, response.first[:text])
    end
  end

  def test_thoa_backend_fails_closed_when_the_cli_or_key_is_absent
    skip 'thoa CLI + THOA_API_KEY present: the fail-closed path is not exercised here' if thoa_ready?

    Dir.mktmpdir do |tmp|
      args = local_args(tmp, expected_sha: 'f' * 64).merge(
        'backend' => 'thoa',
        'pipeline' => { 'steps' => ['C9'], 'cmd' => 'printf hi > out.txt', 'download_dir' => tmp }
      )
      response = tool.call(args)
      assert error?(response)
      assert_match(/thoa CLI not found|THOA_API_KEY/, response.first[:text])
    end
  end

  def test_schema_declares_the_required_inputs
    schema = tool.input_schema
    assert_equal %w[subject_ref pipeline expected_output], schema[:required]
    assert_equal %w[local thoa], schema.dig(:properties, :backend, :enum)
    assert_equal 'gc_tier2_execute', tool.name
  end

  private

  def thoa_ready?
    key = ENV['THOA_API_KEY']
    !key.to_s.strip.empty? &&
      (system('which thoa > /dev/null 2>&1') || system('conda run -n thoa_py3.11 which thoa > /dev/null 2>&1'))
  end
end
