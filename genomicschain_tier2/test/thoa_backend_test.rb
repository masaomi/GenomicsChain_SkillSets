# frozen_string_literal: true
# ThoaBackend (design v0.3 §2). Exercises command construction and the Receipt
# path WITHOUT invoking the real thoa CLI (no THOA_API_KEY / no cloud job).
require 'minitest/autorun'
require 'tmpdir'
require 'digest'
require 'fileutils'

$LOAD_PATH.unshift(File.expand_path('../../genomicschain_core/lib', __dir__))
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'genomicschain_tier2'

GSE = KairosMcp::SkillSets::GenomicschainTier2::Execution

class ThoaBackendTest < Minitest::Test
  # Pins cmd_prefix so the test does not depend on whether `thoa` is on PATH.
  class TestableThoa < GSE::ThoaBackend
    def cmd_prefix = ['thoa']
  end

  def job_spec(pipeline, env: {}, resources: {})
    GSE::JobSpec.new(
      subject_ref: 'repro://656122/C9', env: env, data: { 'accessions' => [] },
      pipeline: pipeline, backend_id: 'thoa', resources: resources
    )
  end

  def test_builds_array_form_command_with_resources_and_download_dir
    js = job_spec(
      { 'cmd' => 'fastqc -o out in/*.fastq.gz', 'tools' => 'fastqc,multiqc',
        'inputs' => ['/data/in'], 'output' => 'out', 'download_dir' => '/tmp/dl',
        'job_name' => 'gc-c9' },
      resources: { 'n_cores' => 8, 'ram_gb' => 16, 'storage_gb' => 50 }
    )
    cmd = TestableThoa.new.send(:build_command, js, js.pipeline, '/tmp/dl')

    assert_equal %w[thoa run --cmd], cmd[0, 3]
    assert_equal 'fastqc -o out in/*.fastq.gz', cmd[3]
    # Comma-separated tools expand to repeated --tools flags.
    assert_equal 2, cmd.each_index.count { |i| cmd[i] == '--tools' }
    assert_includes cmd, 'multiqc'
    # AI auto-retry is off by default: a retried job is not the declared job.
    assert_includes cmd, '--strict'
    assert_equal '/data/in', cmd[cmd.index('--input') + 1]
    assert_equal '8', cmd[cmd.index('--n-cores') + 1]
    assert_equal '16', cmd[cmd.index('--ram') + 1]
    assert_equal '50', cmd[cmd.index('--storage') + 1]
    assert_equal '/tmp/dl', cmd[cmd.index('--download-dir') + 1]
    # Array form: no value is ever concatenated into a shell string.
    assert(cmd.all? { |a| a.is_a?(String) })
  end

  def test_env_lock_passed_as_env_source_only_when_it_resolves_to_a_file
    Dir.mktmpdir do |tmp|
      lock = File.join(tmp, 'environment.yml')
      File.write(lock, "name: c9\n")

      with_lock = job_spec({ 'cmd' => 'x', 'download_dir' => tmp }, env: { 'lock' => lock })
      cmd = TestableThoa.new.send(:build_command, with_lock, with_lock.pipeline, tmp)
      assert_equal lock, cmd[cmd.index('--env-source') + 1]

      # A digest-only lock (not a path) cannot be handed to --env-source; the
      # tools list then stands alone as the single environment source.
      digest_lock = job_spec({ 'cmd' => 'x', 'tools' => 'fastqc', 'download_dir' => tmp },
                             env: { 'lock' => 'sha256:abc' })
      cmd2 = TestableThoa.new.send(:build_command, digest_lock, digest_lock.pipeline, tmp)
      refute_includes cmd2, '--env-source'
      assert_equal 'fastqc', cmd2[cmd2.index('--tools') + 1]
    end
  end

  # thoa 0.1.6 requires EXACTLY ONE environment source — zero is rejected too,
  # so catch it here rather than after an upload attempt.
  def test_no_environment_source_is_a_backend_error
    Dir.mktmpdir do |tmp|
      js = job_spec({ 'cmd' => 'x', 'download_dir' => tmp })
      err = assert_raises(GSE::Backend::BackendError) do
        TestableThoa.new.send(:build_command, js, js.pipeline, tmp)
      end
      assert_match(/EXACTLY ONE environment source, got none/, err.message)

      # An unusable lock is called out explicitly so it is not silently ignored.
      bad_lock = job_spec({ 'cmd' => 'x', 'download_dir' => tmp }, env: { 'lock' => 'sha256:abc' })
      err2 = assert_raises(GSE::Backend::BackendError) do
        TestableThoa.new.send(:build_command, bad_lock, bad_lock.pipeline, tmp)
      end
      assert_match(/not a readable path/, err2.message)
    end
  end

  # thoa 0.1.6: --tools / --env-source / --env-id are mutually exclusive. Two
  # declarations are also ambiguous about which environment is under test, so
  # this fails loudly instead of silently dropping one.
  def test_two_environment_sources_is_a_backend_error
    Dir.mktmpdir do |tmp|
      lock = File.join(tmp, 'environment.yml')
      File.write(lock, "name: c9\n")

      both = job_spec({ 'cmd' => 'x', 'tools' => 'fastqc', 'download_dir' => tmp }, env: { 'lock' => lock })
      err = assert_raises(GSE::Backend::BackendError) do
        TestableThoa.new.send(:build_command, both, both.pipeline, tmp)
      end
      assert_match(/EXACTLY ONE environment source, got --env-source \+ --tools/, err.message)

      with_env_id = job_spec({ 'cmd' => 'x', 'tools' => 'fastqc', 'download_dir' => tmp },
                             env: { 'env_id' => 'uuid-1' })
      assert_raises(GSE::Backend::BackendError) do
        TestableThoa.new.send(:build_command, with_env_id, with_env_id.pipeline, tmp)
      end
    end
  end

  def test_env_id_reuses_an_existing_thoa_environment
    Dir.mktmpdir do |tmp|
      js = job_spec({ 'cmd' => 'x', 'download_dir' => tmp }, env: { 'env_id' => 'uuid-1' })
      cmd = TestableThoa.new.send(:build_command, js, js.pipeline, tmp)
      assert_equal 'uuid-1', cmd[cmd.index('--env-id') + 1]
      refute_includes cmd, '--tools'
      refute_includes cmd, '--env-source'
    end
  end

  def test_ai_retry_can_be_opted_back_in
    Dir.mktmpdir do |tmp|
      js = job_spec({ 'cmd' => 'x', 'tools' => 'fastqc', 'download_dir' => tmp, 'allow_ai_retry' => true })
      refute_includes TestableThoa.new.send(:build_command, js, js.pipeline, tmp), '--strict'
    end
  end

  def test_missing_cmd_or_download_dir_is_a_backend_error
    backend = TestableThoa.new
    def backend.preflight! = nil

    assert_raises(GSE::Backend::BackendError) do
      backend.submit(job_spec({ 'download_dir' => '/tmp' }))
    end
    assert_raises(GSE::Backend::BackendError) do
      backend.submit(job_spec({ 'cmd' => 'echo hi' }))
    end
  end

  def test_preflight_fails_closed_without_cli_or_api_key
    backend = TestableThoa.new
    def backend.cli_available? = false
    err = assert_raises(GSE::ThoaBackend::ThoaUnavailable) { backend.send(:preflight!) }
    assert_match(/thoa CLI not found/, err.message)

    backend2 = TestableThoa.new
    def backend2.cli_available? = true
    def backend2.api_key_set? = false
    err2 = assert_raises(GSE::ThoaBackend::ThoaUnavailable) { backend2.send(:preflight!) }
    assert_match(/THOA_API_KEY/, err2.message)
  end

  # fetch() hashes whatever landed in the download dir and produces a Receipt
  # the executor can gate on. Job state is injected so no cloud job is needed.
  def test_fetch_produces_admissible_receipt_from_download_dir
    Dir.mktmpdir do |tmp|
      File.write(File.join(tmp, 'out.txt'), "hi\n")
      backend = seeded_backend(tmp, output: "job_id: abc123\ndone\n", exit_code: 0)

      assert_equal :done, backend.poll('thoa-1')
      receipt = backend.fetch('thoa-1', tmp)

      assert receipt.verdict_admissible?
      assert_equal 1, receipt.output_files.length
      assert_equal 'out.txt', receipt.output_files.first['relative_path']
      assert_equal Digest::SHA256.hexdigest("hi\n"), receipt.output_files.first['sha256']
      assert_equal 'abc123', receipt.backend_metadata['thoa_job_id']
      assert_equal :self_reported_hash, backend.attestation_kind
    end
  end

  # thoa reports no independent result digest of its own, so by default the
  # backend emits none — asserting one from our own recompute would claim a
  # confirmation that never happened (LocalBackend impl-review I11).
  def test_no_backend_result_hash_unless_the_job_emits_the_marker
    Dir.mktmpdir do |tmp|
      File.write(File.join(tmp, 'out.txt'), "hi\n")

      plain = seeded_backend(tmp, output: "done\n", exit_code: 0).fetch('thoa-1', tmp)
      assert_nil plain.backend_result_hash

      marked = seeded_backend(tmp, output: "TIER2_RESULT_SHA256=#{'a' * 64}\ndone\n", exit_code: 0)
                 .fetch('thoa-1', tmp)
      assert_equal 'a' * 64, marked.backend_result_hash
    end
  end

  def test_failed_and_timed_out_jobs_are_not_admissible
    Dir.mktmpdir do |tmp|
      File.write(File.join(tmp, 'out.txt'), "hi\n")

      failed = seeded_backend(tmp, output: 'boom', exit_code: 3)
      assert_equal :failed, failed.poll('thoa-1')
      refute failed.fetch('thoa-1', tmp).verdict_admissible?

      timed_out = seeded_backend(tmp, output: 'timeout', exit_code: nil, timed_out: true)
      assert_equal :failed, timed_out.poll('thoa-1')
      receipt = timed_out.fetch('thoa-1', tmp)
      refute receipt.verdict_admissible?
      assert_equal 'timeout', receipt.backend_reported_status
    end
  end

  def test_empty_output_set_is_not_admissible
    Dir.mktmpdir do |tmp|
      backend = seeded_backend(tmp, output: "done\n", exit_code: 0)
      refute backend.fetch('thoa-1', tmp).verdict_admissible?
    end
  end

  private

  def seeded_backend(download_dir, output:, exit_code:, timed_out: false)
    backend = TestableThoa.new
    backend.instance_variable_set(
      :@jobs,
      { 'thoa-1' => { exit_code: exit_code, output: output,
                      download_dir: download_dir, timed_out: timed_out } }
    )
    backend
  end
end
