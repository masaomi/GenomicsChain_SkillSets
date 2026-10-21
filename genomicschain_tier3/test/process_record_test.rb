# frozen_string_literal: true

# Tier 3 v0.1 §9-6 / §6.1 — the process record gc-t3-process-0.1: one
# directory on the executor's side holding six items and a manifest (path and
# fingerprint, canonical JSON; C(f) when salted). Only the manifest's digest
# reaches the record. Failed attempts stay in it.
require_relative 't3_helper'
require_relative '../tools/gc_tier3_attest'

class ProcessRecordTest < Minitest::Test
  include T3Helpers

  ITEMS = %w[01_declaration.json 02_build.jsonl 03_runs.jsonl 04_logs.jsonl 05_inference.json 06_scores.jsonl].freeze

  def setup = reset_nonces

  # Declared with one inferred pin and one rejected proposal; attempt 1 does
  # not build, attempt 2 does; then attested.
  def run_job(form = 'plain')
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ckp, key = form == 'salted' ? write_commitment_key(dir) : [nil, nil]
      build = flaky_step(File.join(dir, 'marker'))
      build['pins'] << pin(name: 'tool_guess', origin: 'inferred')
      rejected = [{ 'step' => 'fetch', 'name' => 'samtools', 'kind' => 'version', 'expected' => '1.19' }]
      d = ok!(declare_args(dir, skp, form: form, commitment_key_path: ckp,
                                     'build_plan' => plan(steps: [build]), 'rejected_proposals' => rejected))
      ok!(attempt_args(dir))
      ok!(attempt_args(dir))
      a = ok!(attest_args(dir, skp, own_ref(dir)))
      yield process_dir(dir), key, d, a['attestation']
    end
  end

  def manifest(pdir) = JSON.parse(File.read(File.join(pdir, 'manifest.json')))

  def test_the_directory_holds_the_six_items_and_the_manifest_only
    run_job do |pdir, _, _, _|
      assert_equal (ITEMS + ['manifest.json']).sort, Dir.children(pdir).sort
    end
  end

  def test_the_manifest_lists_the_six_items_with_their_sha256
    run_job do |pdir, _, _, _|
      m = manifest(pdir)
      assert_equal 'gc-t3-process-0.1', m['format']
      assert_equal ITEMS, m['files'].map { |f| f['path'] }
      m['files'].each do |f|
        assert_equal Digest::SHA256.file(File.join(pdir, f['path'])).hexdigest, f['fingerprint'], f['path']
      end
      assert_equal M.canonical_json(m), File.read(File.join(pdir, 'manifest.json')), 'manifest.json is canonical JSON'
    end
  end

  def test_process_record_digest_is_the_manifests_digest
    run_job do |pdir, _, _, a|
      bytes = File.binread(File.join(pdir, 'manifest.json'))
      assert_equal Digest::SHA256.hexdigest(bytes), a['process_record_digest']
      assert_equal M.canonical_json_sha256(manifest(pdir)), a['process_record_digest']
    end
  end

  def test_a_salted_manifest_uses_c_of_f
    run_job('salted') do |pdir, key, _, a|
      manifest(pdir)['files'].each do |f|
        assert_equal C.commit_file(key, File.join(pdir, f['path'])), f['fingerprint'], f['path']
      end
      assert_equal C.commit(key, File.binread(File.join(pdir, 'manifest.json'))), a['process_record_digest']
    end
  end

  def test_the_declaration_copy_is_the_signed_declaration
    run_job do |pdir, _, d, _|
      copy = JSON.parse(File.read(File.join(pdir, '01_declaration.json')))
      assert_equal 'gc-t3-process-0.1', copy['format']
      assert_equal d['declaration'], copy['declaration']
      assert_equal d['operator'], copy['operator']
    end
  end

  def test_failed_attempts_are_kept_and_only_built_attempts_ran
    run_job do |pdir, _, _, a|
      assert_equal a['attempts'], jsonl(File.join(pdir, '06_scores.jsonl'))
      builds = jsonl(File.join(pdir, '02_build.jsonl'))
      assert_equal %w[cannot_build built], builds.map { |b| b['rebuild'] }
      assert_equal [1, 1], builds.map { |b| b['steps'].length }
      assert_equal 1, builds.first['steps'].first['exit_code']
      runs = jsonl(File.join(pdir, '03_runs.jsonl'))
      assert_equal [[2, 1]], runs.map { |r| r.values_at('attempt', 'runs') }
      assert_equal [1, 2], jsonl(File.join(pdir, '04_logs.jsonl')).map { |l| l['attempt'] }
    end
  end

  def test_pin_observations_are_recorded
    run_job do |pdir, _, _, _|
      pins = jsonl(File.join(pdir, '02_build.jsonl')).last['pins']
      assert_equal [%w[tool 1.0 1.0], %w[tool_guess 1.0 1.0]], pins.map { |p| p.values_at('name', 'expected', 'observed') }
      assert(pins.all? { |p| p['ok'] == true })
      assert_equal %w[declared inferred], pins.map { |p| p['origin'] }
    end
  end

  # §2.4, §6.2: an inference's proposal is recorded as one, with whether it was taken.
  def test_inference_proposals_are_labelled_with_their_adoption
    run_job do |pdir, _, _, _|
      inf = JSON.parse(File.read(File.join(pdir, '05_inference.json')))
      assert_equal 'inferred', inf['label']
      by_name = inf['proposals'].to_h { |p| [p['name'], p] }
      assert_equal true, by_name.dig('tool_guess', 'adopted')
      assert_equal false, by_name.dig('samtools', 'adopted')
      assert(inf['proposals'].all? { |p| p['origin'] == 'inferred' })
      refute by_name.key?('tool'), 'a declared pin is not an inference'
    end
  end
end
