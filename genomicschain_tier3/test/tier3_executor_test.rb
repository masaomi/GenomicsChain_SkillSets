# frozen_string_literal: true
# Tier-3 execution flow (record 0.3) end-to-end on a REAL LocalBackend (no Thoa
# account needed). Exercises submit/poll/fetch -> admissibility gate -> local
# result_hash recompute -> the TWO verdict axes, plus repeated runs.
require 'minitest/autorun'
require 'tmpdir'
require 'digest'
require 'kairos_mcp/version'

$LOAD_PATH.unshift(File.expand_path('../../genomicschain_core/lib', __dir__))
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'genomicschain_tier3'

GT2 = KairosMcp::SkillSets::GenomicschainTier3

class Tier3ExecutorTest < Minitest::Test
  WRITE_HELLO = ['ruby', '-e', 'File.write("out.txt", "hello")'].freeze
  WRITE_RANDOM = ['ruby', '-e', 'require "securerandom"; File.write("out.txt", SecureRandom.hex)'].freeze

  def job_spec(workdir, command, env: { 'lock' => 'conda-lock-abc' })
    GT2::Execution::JobSpec.new(
      subject_ref: 'repro://656122/C9',
      env: env, data: { 'accessions' => [] },
      pipeline: { 'steps' => ['C9'], 'step_source' => 'snakefile',
                  command: command, workdir: workdir },
      backend_id: 'local', resources: {}
    )
  end

  def run_exec(workdir, command, expected_sha, target: 'checksum')
    GT2::Tier3Executor.run(
      job_spec: job_spec(workdir, command),
      expected_output: { 'target' => target, 'sha256' => expected_sha, 'source' => 'paper_declared' },
      backend: GT2::Execution::LocalBackend.new,
      workdirs: [workdir]
    )
  end

  # --- axis 1: did it run -----------------------------------------------

  def test_failed_command_yields_env_failed_and_no_comparison
    Dir.mktmpdir do |d|
      res = run_exec(d, ['ruby', '-e', 'exit 1'], 'a' * 64)
      assert_equal 'env_failed', res.execution_verdict
      # A target existed; we never got far enough to use it. That is
      # not_attempted, which is NOT the same as no_target_declared.
      assert_equal 'not_attempted', res.comparison_verdict
    end
  end

  def test_no_output_yields_outputs_unusable
    Dir.mktmpdir do |d|
      res = run_exec(d, ['ruby', '-e', 'nil'], 'a' * 64)
      assert_equal 'outputs_unusable', res.execution_verdict
      assert_equal 'not_attempted', res.comparison_verdict
    end
  end

  # A remote-style backend reporting a hash that diverges from the locally
  # recomputed one -> env_failed (tamper/transport), not a comparison outcome.
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
      res = GT2::Tier3Executor.run(
        job_spec: job_spec(d, ['true']),
        expected_output: { 'target' => 'checksum', 'sha256' => 'a' * 64, 'source' => 'paper_declared' },
        backend: backend, workdirs: [d]
      )
      assert_equal 'env_failed', res.execution_verdict
    end
  end

  # --- axis 2: did it match ---------------------------------------------

  def test_match_yields_completed_and_match_exact
    Dir.mktmpdir do |d|
      probe = run_exec(d, WRITE_HELLO, 'f' * 64)
      assert_equal 'completed', probe.execution_verdict
      assert_equal 'mismatch', probe.comparison_verdict
      assert_equal 64, probe.result_hash.length

      res = run_exec(d, WRITE_HELLO, probe.result_hash)
      assert_equal 'completed', res.execution_verdict
      assert_equal 'match_exact', res.comparison_verdict
      assert_nil res.first_divergence
      assert_equal 'exact_sha256', res.comparator_id
      assert_nil res.backend_result_hash # local: no independent reported hash (I11)
      assert_equal 1, res.run_count
      assert_nil res.self_consistency
    end
  end

  def test_mismatch_records_first_divergence
    Dir.mktmpdir do |d|
      res = run_exec(d, ['ruby', '-e', 'File.write("out.txt", "world")'], 'a' * 64)
      assert_equal 'mismatch', res.comparison_verdict
      assert_equal 'sha256_mismatch', res.first_divergence['kind']
      assert_equal 'result_tree_sha256', res.first_divergence['compared_mode']
      assert_equal 'a' * 64, res.first_divergence['expected_sha256']
    end
  end

  def test_single_file_target_compares_that_file
    Dir.mktmpdir do |d|
      res = run_exec(d, WRITE_HELLO, Digest::SHA256.hexdigest('hello'), target: 'file:out.txt')
      assert_equal 'match_exact', res.comparison_verdict
    end
  end

  # THE COMMON CASE: the paper declares nothing to compare against. Under record
  # 0.2 this was reported as an inconclusive comparison; it is a complete outcome.
  def test_absent_expected_output_yields_no_target_declared
    Dir.mktmpdir do |d|
      res = GT2::Tier3Executor.run(
        job_spec: job_spec(d, WRITE_HELLO),
        backend: GT2::Execution::LocalBackend.new, workdirs: [d]
      )
      assert_equal 'completed', res.execution_verdict
      assert_equal 'no_target_declared', res.comparison_verdict
      assert_nil res.comparator_id
      assert_nil res.first_divergence
      assert_nil res.expected_output_sha256
      assert_equal 64, res.result_hash.length
    end
  end

  # --- run_count / self-consistency -------------------------------------

  def test_two_agreeing_runs_report_all_identical
    Dir.mktmpdir do |a|
      Dir.mktmpdir do |b|
        res = GT2::Tier3Executor.run(
          job_spec: job_spec(a, WRITE_HELLO),
          backend: GT2::Execution::LocalBackend.new, workdirs: [a, b]
        )
        assert_equal 'completed', res.execution_verdict
        assert_equal 2, res.run_count
        assert_equal true, res.self_consistency['all_identical']
        assert_equal 2, res.self_consistency['runs']
        assert_equal 2, res.self_consistency['run_result_hashes'].length
        assert_equal 'same_environment', res.self_consistency['variation']
      end
    end
  end

  def test_two_differing_runs_report_divergence
    Dir.mktmpdir do |a|
      Dir.mktmpdir do |b|
        res = GT2::Tier3Executor.run(
          job_spec: job_spec(a, WRITE_RANDOM),
          backend: GT2::Execution::LocalBackend.new, workdirs: [a, b]
        )
        assert_equal 'completed', res.execution_verdict
        assert_equal false, res.self_consistency['all_identical']
        assert_equal 'run_to_run_mismatch', res.self_consistency['first_divergence']['kind']
        assert_equal 1, res.self_consistency['first_divergence']['run_index']
      end
    end
  end

  # Reusing one directory would hash run 1's outputs during run 2 and report
  # agreement that never happened. Refused rather than silently accepted.
  def test_duplicate_workdirs_are_refused
    Dir.mktmpdir do |d|
      err = assert_raises(ArgumentError) do
        GT2::Tier3Executor.run(job_spec: job_spec(d, WRITE_HELLO),
                               backend: GT2::Execution::LocalBackend.new, workdirs: [d, d])
      end
      assert_match(/distinct/, err.message)
    end
  end

  # --- provenance --------------------------------------------------------

  def test_environment_provenance_is_derived_from_the_jobspec
    Dir.mktmpdir do |d|
      digest = "sha256:#{'a' * 64}"
      assert_equal 'declared_container',
                   GT2::Tier3Executor.derive_environment_provenance(job_spec(d, WRITE_HELLO, env: { 'container_digest' => digest }))
      assert_equal 'declared_lock',
                   GT2::Tier3Executor.derive_environment_provenance(job_spec(d, WRITE_HELLO, env: { 'lock' => '/tmp/env.yml' }))
      assert_equal 'none',
                   GT2::Tier3Executor.derive_environment_provenance(job_spec(d, WRITE_HELLO, env: {}))
    end
  end

  # 'authored_by_operator' cannot be derived — only the operator knows they built
  # an environment the paper never supplied — so an explicit value must win.
  def test_environment_provenance_override_is_honoured
    Dir.mktmpdir do |d|
      res = GT2::Tier3Executor.run(
        job_spec: job_spec(d, WRITE_HELLO),
        backend: GT2::Execution::LocalBackend.new, workdirs: [d],
        environment_provenance: 'authored_by_operator', inputs_provenance: 'public_accession'
      )
      assert_equal 'authored_by_operator', res.environment_provenance
      assert_equal 'public_accession', res.inputs_provenance
    end
  end

  def test_inputs_provenance_defaults_to_unknown_never_guessed
    Dir.mktmpdir do |d|
      res = GT2::Tier3Executor.run(job_spec: job_spec(d, WRITE_HELLO),
                                   backend: GT2::Execution::LocalBackend.new, workdirs: [d])
      assert_equal 'unknown', res.inputs_provenance
    end
  end

  def test_container_digest_is_recorded_when_declared
    Dir.mktmpdir do |d|
      digest = "sha256:#{'b' * 64}"
      res = GT2::Tier3Executor.run(
        job_spec: job_spec(d, WRITE_HELLO, env: { 'container_digest' => digest }),
        backend: GT2::Execution::LocalBackend.new, workdirs: [d]
      )
      assert_equal digest, res.container_digest
      assert_equal 'declared_container', res.environment_provenance
    end
  end
end
