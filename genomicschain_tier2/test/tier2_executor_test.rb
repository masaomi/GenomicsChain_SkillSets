# frozen_string_literal: true
# Tier-2 execution flow (design v0.3 §3) end-to-end on a REAL LocalBackend
# (no Thoa account needed). Exercises submit/poll/fetch -> admissibility gate ->
# local result_hash recompute -> comparator -> verdict.
require 'minitest/autorun'
require 'tmpdir'
require 'kairos_mcp/version'

$LOAD_PATH.unshift(File.expand_path('../../genomicschain_core/lib', __dir__))
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'genomicschain_tier2'

GT2 = KairosMcp::SkillSets::GenomicschainTier2

class Tier2ExecutorTest < Minitest::Test
  def job_spec(workdir, command)
    GT2::Execution::JobSpec.new(
      subject_ref: 'repro://656122/C9',
      env: { 'lock' => 'conda-lock-abc' }, data: { 'accessions' => [] },
      pipeline: { 'steps' => ['C9'], 'step_source' => 'snakefile',
                  command: command, workdir: workdir },
      backend_id: 'local', resources: {}
    )
  end

  def run_exec(workdir, command, expected_sha)
    GT2::Tier2Executor.run(
      job_spec: job_spec(workdir, command),
      expected_output: { 'target' => 'checksum', 'sha256' => expected_sha, 'source' => 'paper_declared' },
      backend: GT2::Execution::LocalBackend.new,
      workdir: workdir
    )
  end

  def test_match_yields_executed_r
    Dir.mktmpdir do |d|
      cmd = ['ruby', '-e', 'File.write("out.txt", "hello")']
      # First run with a wrong target to learn the produced result_hash.
      probe = run_exec(d, cmd, 'f' * 64)
      assert_equal 'executed_inconclusive_needs_tolerance', probe.verdict
      refute_nil probe.first_divergence
      assert_equal 64, probe.result_hash.length

      # Re-run with the correct expected result_hash -> executed_r.
      res = run_exec(d, cmd, probe.result_hash)
      assert_equal 'executed_r', res.verdict
      assert_nil res.first_divergence
      assert_equal 'exact_sha256', res.comparator_id
      assert_nil res.backend_result_hash # local: no independent reported hash (I11)
      assert_equal 'repro://656122/C9', res.subject_ref
      assert_equal 64, res.jobspec_digest.length
    end
  end

  def test_mismatch_is_inconclusive_not_bare_mismatch
    Dir.mktmpdir do |d|
      res = run_exec(d, ['ruby', '-e', 'File.write("out.txt", "world")'], 'a' * 64)
      assert_equal 'executed_inconclusive_needs_tolerance', res.verdict
      assert_equal 'sha256_mismatch', res.first_divergence['kind']
      assert_equal 'result_tree_sha256', res.first_divergence['compared_mode']
      assert_equal 'a' * 64, res.first_divergence['expected_sha256']
    end
  end

  def test_failed_command_yields_env_failed
    Dir.mktmpdir do |d|
      res = run_exec(d, ['ruby', '-e', 'exit 1'], 'a' * 64)
      assert_equal 'env_failed', res.verdict
    end
  end

  def test_no_output_yields_outputs_unusable
    Dir.mktmpdir do |d|
      res = run_exec(d, ['ruby', '-e', 'nil'], 'a' * 64)
      assert_equal 'outputs_unusable', res.verdict
    end
  end

  # A remote-style backend reporting a hash that diverges from the locally
  # recomputed one -> env_failed (tamper/transport). LocalBackend cannot produce
  # this (it emits no backend_result_hash), so use a hand-rolled backend.
  def test_backend_local_hash_divergence_is_env_failed
    Dir.mktmpdir do |d|
      backend = Object.new
      def backend.id; 'thoa'; end
      def backend.submit(_js); 'r1'; end
      def backend.poll(_r); :done; end
      def backend.fetch(_r, _dst)
        ofiles = [{ 'sha256' => 'a' * 64, 'relative_path' => 'out.txt', 'size_bytes' => 2 }]
        GT2::Execution::Receipt.new(
          terminal_state: :done, process_exit_code: 0, backend_reported_status: 'ok',
          stdout_sha256: '0' * 64, stderr_sha256: '0' * 64, output_files: ofiles,
          artifact_manifest_sha256: 'x', backend_metadata: { 'backend_result_hash' => 'f' * 64 },
          container_digest: nil, attestation_doc: nil
        )
      end
      res = GT2::Tier2Executor.run(
        job_spec: job_spec(d, ['true']),
        expected_output: { 'target' => 'checksum', 'sha256' => 'a' * 64, 'source' => 'paper_declared' },
        backend: backend, workdir: d
      )
      assert_equal 'env_failed', res.verdict
    end
  end

  # Single-file target (I7): compare a named output file's hash, not the aggregate.
  def test_single_file_target_compares_that_file
    Dir.mktmpdir do |d|
      cmd = ['ruby', '-e', 'File.write("out.txt", "hello")']
      file_sha = Digest::SHA256.hexdigest('hello')
      res = GT2::Tier2Executor.run(
        job_spec: job_spec(d, cmd),
        expected_output: { 'target' => 'file:out.txt', 'sha256' => file_sha, 'source' => 'paper_declared' },
        backend: GT2::Execution::LocalBackend.new, workdir: d
      )
      assert_equal 'executed_r', res.verdict
    end
  end
end
