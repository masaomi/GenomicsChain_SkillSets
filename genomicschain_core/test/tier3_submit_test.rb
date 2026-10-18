# frozen_string_literal: true
# Tier3Submit via SubmitCore — Synoptis-only path (design v0.4.1 Step 1).
require 'minitest/autorun'
require 'tmpdir'
require 'json'
require 'digest'
require 'securerandom'
require 'base64'
require 'ed25519'
require 'kairos_mcp/version'
require 'kairos_mcp/kairos_chain/chain'
require 'kairos_mcp/storage/file_backend'
require_relative 'proofs_sandbox'
require_relative 'idempotency_fixture'
require 'kairos_mcp/skillset'
require 'genomicschain_core'

GCore = KairosMcp::SkillSets::GenomicschainCore

TestVerdictResult = Struct.new(
  :subject_ref, :jobspec_digest, :execution_verdict, :comparison_verdict,
  :environment_provenance, :inputs_provenance, :run_count, :self_consistency,
  :trust_tier, :result_hash, :backend_result_hash, :container_digest,
  :expected_output, :expected_output_sha256,
  :expected_output_source, :expected_output_validated_by,
  :expected_output_source_citation, :expected_output_target,
  :comparator_id, :comparator_version, :backend_id, :output_files,
  :first_divergence, :receipt,
  keyword_init: true
)

TestJobSpec = Struct.new(
  :subject_ref, :env, :data, :pipeline, :backend_id, :resources,
  keyword_init: true
) do
  def canonical_json
    KairosMcp::Manifest.canonical_json(
      'subject_ref' => subject_ref,
      'env' => env, 'data' => data, 'pipeline' => pipeline
    )
  end

  def digest
    KairosMcp::Manifest.canonical_json_sha256(
      'subject_ref' => subject_ref,
      'env' => env, 'data' => data, 'pipeline' => pipeline
    )
  end
end

class StubAttestor
  attr_reader :calls, :registry

  def initialize(registry:)
    @registry = registry
    @calls = []
    @seq = 0
  end

  def issue(**kw)
    @calls << kw
    @seq += 1
    envelope = JSON.parse(kw[:evidence])
    # This stub exercises SubmitCore's orchestration, not signing, and holds no
    # key. The engine now refuses to store a proof it cannot sign, so the
    # relaxation is stated here rather than defaulted into.
    engine = ::Synoptis::AttestationEngine.new(
      registry: @registry, config: { 'require_signature' => false }
    )
    result = engine.create_attestation(
      attester_id: 'ed25519:stub', subject_ref: kw[:subject_ref], claim: kw[:claim],
      evidence: kw[:evidence], actor_role: kw[:actor_role]
    )
    { status: result[:status], synoptis_proof_id: result[:proof_id] }
  end
end

class RaisingAttestor
  def issue(**); raise GCore::Attestation::SynoptisAttestor::AttestorError, 'attestor down'; end
end

class Tier3SubmitCoreTest < Minitest::Test
  def setup
    KairosMcp::Manifest::Signer.instance_variable_set(:@global_reservation, nil)
  end

  def with_proofs
    Dir.mktmpdir do |tmp|
      registry, tip_source, = ProofsSandbox.context(tmp)
      KairosMcp::Manifest::Signer.bootstrap_seen_list!(tip_source: tip_source)
      yield registry, tip_source
    end
  end

  def with_operational_chain(dir)
    backend = KairosMcp::Storage::FileBackend.new(
      storage_dir: dir,
      blockchain_file: File.join(dir, 'blockchain.json'),
      action_log_file: File.join(dir, 'action_log.jsonl')
    )
    chain = KairosMcp::KairosChain::Chain.new(
      chain_file: File.join(dir, 'blockchain.json'), storage_backend: backend
    )
    chain.add_block(['seed'])
    chain
  end

  def job_spec
    TestJobSpec.new(
      subject_ref: 'repro://656122/C9', env: { 'lock' => 'abc' },
      data: { 'accessions' => [] }, pipeline: { 'steps' => ['C9'] },
      backend_id: 'thoa', resources: {}
    )
  end

  def verdict_result(js, trust_tier: 'self_reported', comparator_version: '0.1.0',
                     source: 'paper_declared', validated_by: 'human:masaomi',
                     comparison_verdict: 'match_exact')
    eo = { 'target' => 'checksum', 'sha256' => 'c' * 64, 'source' => source,
           'source_citation' => 'doi:10.1038/s41467-018-06108-1', 'validated_by' => validated_by }
    TestVerdictResult.new(
      subject_ref: 'repro://656122/C9', jobspec_digest: js.digest,
      execution_verdict: 'completed', comparison_verdict: comparison_verdict,
      environment_provenance: 'declared_lock', inputs_provenance: 'public_accession',
      run_count: 1, self_consistency: nil,
      trust_tier: trust_tier, result_hash: 'd' * 64,
      backend_result_hash: nil, container_digest: nil, expected_output: eo,
      expected_output_sha256: 'c' * 64, expected_output_source: source,
      expected_output_validated_by: validated_by,
      expected_output_source_citation: eo['source_citation'], expected_output_target: eo['target'],
      comparator_id: 'exact_sha256', comparator_version: comparator_version, backend_id: 'thoa',
      output_files: [{ 'sha256' => 'a' * 64, 'relative_path' => 'o.txt', 'size_bytes' => 3 }],
      first_divergence: nil, receipt: nil
    )
  end

  # A completed run against a paper that declared no comparison target — the
  # common shape after the 2026-08-14 survey (0/5 papers declared one).
  def no_target_verdict_result(js)
    TestVerdictResult.new(
      subject_ref: 'repro://656122/C9', jobspec_digest: js.digest,
      execution_verdict: 'completed', comparison_verdict: 'no_target_declared',
      environment_provenance: 'declared_container', inputs_provenance: 'public_accession',
      run_count: 2,
      self_consistency: { 'runs' => 2, 'all_identical' => true, 'comparator_id' => 'exact_sha256',
                          'run_result_hashes' => ['d' * 64, 'd' * 64], 'variation' => 'same_environment' },
      trust_tier: 'self_reported', result_hash: 'd' * 64,
      backend_result_hash: nil, container_digest: "sha256:#{'e' * 64}",
      expected_output: nil, expected_output_sha256: nil, expected_output_source: nil,
      expected_output_validated_by: nil, expected_output_source_citation: nil,
      expected_output_target: nil,
      comparator_id: nil, comparator_version: nil, backend_id: 'thoa',
      output_files: [{ 'sha256' => 'a' * 64, 'relative_path' => 'o.txt', 'size_bytes' => 3 }],
      first_divergence: nil, receipt: nil
    )
  end

  def signed_operator(tip_source, vr, sk: Ed25519::SigningKey.generate)
    pk = sk.verify_key
    nonce = SecureRandom.hex(16)
    tip = tip_source.latest_tip_hash
    params = GCore::Tier3Submit::SIGNED_IDENTITY_FIELDS.each_with_object({}) { |f, h| h[f] = vr[f.to_sym] }
    payload = KairosMcp::Manifest.canonical_json(
      'mcp_tool_name' => 'gc_tier3_submit', 'params' => params, 'nonce' => nonce, 'chain_tip_hash' => tip
    )
    pubkey_str = 'ed25519:' + Base64.urlsafe_encode64(pk.to_bytes, padding: false)
    op = {
      'mode' => 'signed', 'pubkey' => pubkey_str,
      'signature' => {
        'algorithm' => 'ed25519',
        'signed_fields' => %w[mcp_tool_name params nonce chain_tip_hash],
        'value' => Base64.urlsafe_encode64(sk.sign(payload), padding: false),
        'nonce' => nonce, 'chain_tip_hash' => tip
      }
    }
    [op, Digest::SHA256.hexdigest(pubkey_str), sk]
  end

  def submit(registry, tip_source, vr, op, pkhash, attestor, jobspec_json: nil, expected_output: nil)
    GCore::Tier3Submit.submit(
      verdict_result: vr, operator: op, jobspec_json: jobspec_json || job_spec.canonical_json,
      bearer_pubkey_hash: pkhash, tip_source: tip_source, attestor: attestor,
      expected_output: expected_output || vr.expected_output, registry: registry
    )
  end

  def test_happy_path_records_synoptis_proof_with_manifest_envelope
    with_proofs do |registry, tip_source|
      vr = verdict_result(job_spec)
      op, pkhash, = signed_operator(tip_source, vr)
      att = StubAttestor.new(registry: registry)

      out = submit(registry, tip_source, vr, op, pkhash, att)

      assert_equal 'recorded', out[:status]
      refute_nil out[:synoptis_proof_id]
      assert out[:claim].start_with?('tier3:completed:match_exact:')
      assert out[:claim].end_with?(":#{out[:submission_key]}")
      assert_equal true, out[:leaderboard_eligible]
      refute_nil out[:result_evidence_sha256]

      proofs = registry.read(:proofs)
      assert_equal 1, proofs.length
      manifest = GCore::ProofLookup.parse_manifest_from_record(proofs.first)
      assert_equal out[:submission_key], manifest['submission_key']
      assert_equal out[:result_evidence_sha256], manifest['result_evidence_sha256']
      assert_equal '0.3', manifest['record_version']
      assert_equal 'completed', manifest['execution_verdict']
      assert_equal 'match_exact', manifest['comparison_verdict']
      assert_equal 'declared_lock', manifest['environment_provenance']
      assert_equal 1, manifest['run_count']
      refute manifest.key?('verdict'), 'record 0.3 must not carry the collapsed single verdict'
    end
  end

  # The common shape: a completed run against a paper that declared no
  # comparison target. It must record and remain INELIGIBLE for the
  # leaderboard — the strong claim is not relaxed to make it reachable.
  def test_no_target_run_records_and_is_not_leaderboard_eligible
    with_proofs do |registry, tip_source|
      vr = no_target_verdict_result(job_spec)
      op, pkhash, = signed_operator(tip_source, vr)

      out = submit(registry, tip_source, vr, op, pkhash, StubAttestor.new(registry: registry),
                   expected_output: nil)

      assert_equal 'recorded', out[:status]
      assert out[:claim].start_with?('tier3:completed:no_target_declared:')
      assert_equal false, out[:leaderboard_eligible]

      manifest = GCore::ProofLookup.parse_manifest_from_record(registry.read(:proofs).first)
      assert_equal 'no_target_declared', manifest['comparison_verdict']
      refute manifest.key?('expected_output'), 'no target means no expected_output block'
      refute manifest.key?('expected_output_sha256')
      assert_equal 2, manifest['run_count']
      assert_equal true, manifest.dig('self_consistency', 'all_identical')
      assert_equal "sha256:#{'e' * 64}", manifest['container_digest']
    end
  end

  def test_zero_writes_to_operational_chain
    with_proofs do |registry, tip_source|
      Dir.mktmpdir do |chain_dir|
        chain = with_operational_chain(chain_dir)
        before = chain.chain.length

        vr = verdict_result(job_spec)
        op, pkhash, = signed_operator(tip_source, vr)
        submit(registry, tip_source, vr, op, pkhash, StubAttestor.new(registry: registry))

        assert_equal before, chain.chain.length
      end
    end
  end

  def test_operator_supplied_unvalidated_is_not_eligible
    with_proofs do |registry, tip_source|
      vr = verdict_result(job_spec, source: 'operator_supplied', validated_by: nil)
      op, pkhash, = signed_operator(tip_source, vr)
      out = submit(registry, tip_source, vr, op, pkhash, StubAttestor.new(registry: registry))
      assert_equal false, out[:leaderboard_eligible]
    end
  end

  def test_recorded_target_must_match_signed
    with_proofs do |registry, tip_source|
      vr = verdict_result(job_spec)
      op, pkhash, = signed_operator(tip_source, vr)
      forged_eo = vr.expected_output.merge('target' => 'file:evil.txt')
      assert_raises(GCore::Tier3Submit::IdentityMismatch) do
        submit(registry, tip_source, vr, op, pkhash, StubAttestor.new(registry: registry),
               expected_output: forged_eo)
      end
    end
  end

  def test_unsigned_mode_rejected
    with_proofs do |registry, tip_source|
      vr = verdict_result(job_spec)
      assert_raises(GCore::Tier3Submit::UnsignedModeError) do
        submit(registry, tip_source, vr, { 'mode' => 'anonymous' }, 'x' * 64,
               StubAttestor.new(registry: registry))
      end
    end
  end

  def test_jobspec_digest_mismatch_rejected
    with_proofs do |registry, tip_source|
      vr = verdict_result(job_spec)
      op, pkhash, = signed_operator(tip_source, vr)
      assert_raises(GCore::Tier3Submit::JobSpecMismatch) do
        submit(registry, tip_source, vr, op, pkhash, StubAttestor.new(registry: registry),
               jobspec_json: JSON.generate('subject_ref' => 'repro://forged'))
      end
    end
  end

  def test_bearer_pubkey_binding_fail_closed
    with_proofs do |registry, tip_source|
      vr = verdict_result(job_spec)
      op, _, = signed_operator(tip_source, vr)
      assert_raises(GCore::Tier3Submit::BearerBindingError) do
        submit(registry, tip_source, vr, op, nil, StubAttestor.new(registry: registry))
      end
    end
  end

  def test_non_mvp_trust_tier_rejected_without_reserving_nonce
    with_proofs do |registry, tip_source|
      vr = verdict_result(job_spec, trust_tier: 'peer_verified')
      op, pkhash, = signed_operator(tip_source, vr)
      nonce = op.dig('signature', 'nonce')
      assert_raises(GCore::Tier3Submit::TrustTierError) do
        submit(registry, tip_source, vr, op, pkhash, StubAttestor.new(registry: registry))
      end
      refute KairosMcp::Manifest::Signer.global_reservation.reserved?(nonce)
    end
  end

  def test_nonce_released_on_post_admission_failure
    with_proofs do |registry, tip_source|
      vr = verdict_result(job_spec, comparator_version: 'not-semver')
      op, pkhash, = signed_operator(tip_source, vr)
      nonce = op.dig('signature', 'nonce')
      assert_raises(KairosMcp::Manifest::SchemaViolation) do
        submit(registry, tip_source, vr, op, pkhash, StubAttestor.new(registry: registry))
      end
      refute KairosMcp::Manifest::Signer.global_reservation.reserved?(nonce)
      refute KairosMcp::Manifest::Signer.global_reservation.committed?(nonce)
    end
  end

  def test_nonce_not_committed_when_synoptis_store_fails
    with_proofs do |registry, tip_source|
      vr = verdict_result(job_spec)
      op, pkhash, = signed_operator(tip_source, vr)
      nonce = op.dig('signature', 'nonce')
      out = submit(registry, tip_source, vr, op, pkhash, RaisingAttestor.new)
      assert_equal 'recording_failed_retryable', out[:status]
      refute KairosMcp::Manifest::Signer.global_reservation.committed?(nonce)
      assert_equal 0, registry.read(:proofs).length
    end
  end

  def test_nonce_replay_rejected_for_fresh_submission_with_committed_nonce
    with_proofs do |registry, tip_source|
      vr1 = verdict_result(job_spec)
      op1, pkhash, sk = signed_operator(tip_source, vr1)
      submit(registry, tip_source, vr1, op1, pkhash, StubAttestor.new(registry: registry))

      KairosMcp::Manifest::Signer.instance_variable_set(:@global_reservation, nil)
      KairosMcp::Manifest::Signer.bootstrap_seen_list!(tip_source: tip_source)

      vr2 = verdict_result(job_spec).dup
      vr2.result_hash = 'e' * 64
      reused_nonce = op1.dig('signature', 'nonce')
      tip = tip_source.latest_tip_hash
      params = GCore::Tier3Submit::SIGNED_IDENTITY_FIELDS.each_with_object({}) { |f, h| h[f] = vr2[f.to_sym] }
      payload = KairosMcp::Manifest.canonical_json(
        'mcp_tool_name' => 'gc_tier3_submit', 'params' => params,
        'nonce' => reused_nonce, 'chain_tip_hash' => tip
      )
      pk = Ed25519::VerifyKey.new(sk.verify_key.to_bytes) rescue sk.verify_key
      sig_val = Base64.urlsafe_encode64(sk.sign(payload), padding: false)
      op2 = op1.merge(
        'signature' => op1['signature'].merge(
          'value' => sig_val, 'chain_tip_hash' => tip, 'nonce' => reused_nonce
        )
      )

      assert_raises(KairosMcp::Manifest::Signer::NonceReplay) do
        submit(registry, tip_source, vr2, op2, pkhash, StubAttestor.new(registry: registry))
      end
    end
  end

  def test_recovery_returns_existing_proof_without_second_store
    with_proofs do |registry, tip_source|
      vr = verdict_result(job_spec)
      op, pkhash, = signed_operator(tip_source, vr)
      att = StubAttestor.new(registry: registry)
      first = submit(registry, tip_source, vr, op, pkhash, att)
      second = submit(registry, tip_source, vr, op, pkhash, att)

      assert_equal first[:synoptis_proof_id], second[:synoptis_proof_id]
      assert_equal true, second[:recovered]
      assert_equal 1, registry.read(:proofs).length
    end
  end

  # Design v0.1.15 (10) (viii): the key on both paths, pinned before core 0.6.2.
  def test_idempotency_key_matches_the_r0_fixture
    with_proofs do |registry, tip_source|
      vr = verdict_result(job_spec)
      op, pkhash, = signed_operator(tip_source, vr, sk: IdempotencyFixture::SIGNING_KEY)
      att = StubAttestor.new(registry: registry)
      first = submit(registry, tip_source, vr, op, pkhash, att)
      second = submit(registry, tip_source, vr, op, pkhash, att)
      IdempotencyFixture.check(self, 'tier3_verdict', first, second)
    end
  end

  def test_crash_after_store_nonce_bootstrapped_on_restart
    with_proofs do |registry, tip_source|
      vr = verdict_result(job_spec)
      op, pkhash, = signed_operator(tip_source, vr)
      nonce = op.dig('signature', 'nonce')
      submit(registry, tip_source, vr, op, pkhash, StubAttestor.new(registry: registry))

      KairosMcp::Manifest::Signer.instance_variable_set(:@global_reservation, nil)
      KairosMcp::Manifest::Signer.bootstrap_seen_list!(tip_source: tip_source)
      assert KairosMcp::Manifest::Signer.global_reservation.committed?(nonce)
    end
  end

  def test_oversized_manifest_rejected_gate_c
    with_proofs do |registry, tip_source|
      vr = verdict_result(job_spec)
      huge_files = Array.new(3000) do |i|
        { 'sha256' => 'a' * 64,
          'relative_path' => "out/deep/nested/path/with/extra/segments/file_#{i}_#{'x' * 40}.txt",
          'size_bytes' => 3 }
      end
      vr = vr.dup
      vr.output_files = huge_files
      op, pkhash, = signed_operator(tip_source, vr)
      assert_raises(GCore::Tier3Submit::EvidenceTooLarge) do
        submit(registry, tip_source, vr, op, pkhash, StubAttestor.new(registry: registry))
      end
    end
  end
end
