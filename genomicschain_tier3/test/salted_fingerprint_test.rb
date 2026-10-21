# frozen_string_literal: true

# Tier 3 v0.1 §9-4 / §4.3 — under fingerprint_form = salted, every listed
# fingerprint and digest field is C(f) under the job's commitment key (a value
# that is not a file: C over its canonical JSON bytes). declaration_ref,
# route_ref, bundle_digest, outputs_digest and the bundle rows stay as they
# are. Each salted case is set beside its plain twin so the pre-images in the
# interface note are pinned in both forms.
require_relative 't3_helper'
require_relative '../tools/gc_tier3_attest'

class SaltedFingerprintTest < Minitest::Test
  include T3Helpers

  def setup = reset_nonces

  # Plain: SHA-256; salted: gc-commitment-0.1 under key.
  def hv(key, obj) = key ? h_salted(key, obj) : h_plain(obj)
  def fv(key, path) = key ? C.commit_file(key, path) : Digest::SHA256.file(path).hexdigest

  # One route-A job, declared, attempted once, attested. Yields what the
  # checks need.
  def run_job(form)
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ckp, key = form == 'salted' ? write_commitment_key(dir) : [nil, nil]
      args = declare_args(dir, skp, form: form, commitment_key_path: ckp)
      d = ok!(args)['declaration']
      attempt = ok!(attempt_args(dir))
      a = ok!(attest_args(dir, skp, own_ref(dir)))['attestation']
      yield(dir: dir, key: key, args: args, declaration: d, attempt: attempt, attestation: a)
    end
  end

  def check_declaration(j)
    key = j[:key]
    args = j[:args]
    d = j[:declaration]
    assert_equal hv(key, args['build_plan']), d['build_plan_digest']
    identity = { 'build_plan_digest' => d['build_plan_digest'], 'data' => args['data'], 'pipeline' => args['pipeline'] }
    assert_equal({ 'rule' => 'gc-job-identity-0.3', 'digest' => hv(key, identity) }, d['job_identity'])
    assert_equal hv(key, args['inputs'].map { |p| fv(key, p) }.sort), d['inputs_commitment']
    want = key ? h_salted(key, sha('hi')) : sha('hi')
    assert_equal [{ 'path' => 'out.txt', 'algorithm' => 'sha256', 'value' => want }], d.dig('targets', 'items')
    assert_equal 'tier2:demo-adjudication', d['route_ref'], 'route_ref stays as declared'
  end

  def check_attempt(j)
    key = j[:key]
    row = j[:attempt]['attempt']
    workdir = j[:attempt]['workdir']
    assert_equal [{ 'path' => 'out.txt', 'value' => fv(key, File.join(workdir, 'out.txt')) }], row['output_fingerprints']
    env = { 'env' => j[:args]['build_plan']['env'], 'pins' => [%w[tool 1.0]] }
    assert_equal hv(key, env), row['env_digest']
  end

  def check_attestation(j)
    key = j[:key]
    a = j[:attestation]
    workdir = j[:attempt]['workdir']
    result_hash = M.tier3_result_hash(T3::Execution::LocalBackend.output_files_of(workdir))
    assert_equal hv(key, [result_hash]), a['result_commitment']
    manifest = File.join(process_dir(j[:dir]), 'manifest.json')
    assert_equal fv(key, manifest), a['process_record_digest']
    assert_equal own_ref(j[:dir]), a['declaration_ref'], 'declaration_ref stays as given'
  end

  # --- declaration --------------------------------------------------------------------

  def test_salted_declaration_digests_are_c_of_f
    run_job('salted') do |j|
      check_declaration(j)
      assert_equal C.declaration(j[:key]), j[:declaration]['commitment']
    end
  end

  def test_plain_declaration_digests_are_sha256
    run_job('plain') { |j| check_declaration(j) }
  end

  # --- attempt rows --------------------------------------------------------------------

  def test_salted_attempt_fingerprints_and_env_digest_are_c_of_f
    run_job('salted') { |j| check_attempt(j) }
  end

  def test_plain_attempt_fingerprints_and_env_digest_are_sha256
    run_job('plain') { |j| check_attempt(j) }
  end

  # --- attestation ---------------------------------------------------------------------

  def test_salted_result_commitment_and_process_record_digest_are_c_of_f
    run_job('salted') do |j|
      check_attestation(j)
      assert_equal j[:declaration]['commitment'], j[:attestation]['commitment']
    end
  end

  def test_plain_result_commitment_and_process_record_digest_are_sha256
    run_job('plain') { |j| check_attestation(j) }
  end

  # A cannot-build attempt contributes nil to the result_commitment list.
  def test_result_commitment_lists_nil_for_an_attempt_that_did_not_build
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ckp, key = write_commitment_key(dir)
      ok!(declare_args(dir, skp, form: 'salted', commitment_key_path: ckp,
                                 'build_plan' => plan(steps: [flaky_step(File.join(dir, 'marker'))])))
      ok!(attempt_args(dir))
      second = ok!(attempt_args(dir))
      a = ok!(attest_args(dir, skp, own_ref(dir)))['attestation']
      rh = M.tier3_result_hash(T3::Execution::LocalBackend.output_files_of(second['workdir']))
      assert_equal h_salted(key, [nil, rh]), a['result_commitment']
    end
  end

  # --- route B: what stays plain (§4.3 (1), (2)) -----------------------------------------

  def test_route_b_salted_keeps_bundle_digest_outputs_digest_rows_and_route_ref_plain
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ckp, key = write_commitment_key(dir) # executor-made: the bundle is not option 2
      rows = v03_rows
      d = ok!(declare_args(dir, skp, route: 'B', form: 'salted', commitment_key_path: ckp,
                                     'pipeline' => { 'command' => write_command('counts.tsv' => V03_OUTPUT) },
                                     **route_b_args(rows: rows, route_proof_id: 'attest_prov_fixture',
                                                    bundle_digest: v03_signed['bundle_digest'])))['declaration']
      t = d['targets']
      assert_equal v03_signed['bundle_digest'], t['bundle_digest']
      assert_equal v03_signed['outputs_digest'], t['outputs_digest']
      assert_equal rows, t['rows']
      assert_equal GC::ProvProofRef.for('attest_prov_fixture'), d['route_ref']
      assert_equal C.declaration(key), d['commitment']
      row = ok!(attempt_args(dir))
      assert_equal [1, 1], row['attempt'].values_at('m', 'n'), 'comparison is plain SHA-256 against the plain rows'
      assert_equal C.commit_file(key, File.join(row['workdir'], 'counts.tsv')),
                   row.dig('attempt', 'output_fingerprints', 0, 'value'), 'the recorded fingerprint is still C(f)'
    end
  end

  # §4.2: for option 2 the commitment key is the bundle key, so the attempt's
  # fingerprint equals the bundle's own value.
  def test_option_2_fingerprints_are_under_the_bundle_key
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ckp, key = write_commitment_key(dir)
      rows = [['out.txt', 'hmac_sha256', C.commit(key, 'hi')]]
      d = ok!(declare_args(dir, skp, route: 'B', form: 'salted', commitment_key_path: ckp,
                                     **route_b_args(rows: rows)))['declaration']
      assert_equal rows, d.dig('targets', 'rows'), 'option-2 rows are not wrapped again'
      row = ok!(attempt_args(dir))['attempt']
      assert_equal rows.first.last, row.dig('output_fingerprints', 0, 'value')
    end
  end
end
