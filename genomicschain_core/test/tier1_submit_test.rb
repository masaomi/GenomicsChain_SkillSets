# frozen_string_literal: true
# Tier1Submit via SubmitCore — Synoptis-only path (design v0.4.1 Step 4).
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
require 'kairos_mcp/skillset'
require 'genomicschain_core'

GCore = KairosMcp::SkillSets::GenomicschainCore

class StubAttestor
  attr_reader :calls, :registry

  def initialize(registry:)
    @registry = registry
    @calls = []
  end

  def issue(**kw)
    @calls << kw
    # This stub exercises SubmitCore's orchestration (recovery, dedup, nonce),
    # not signing, and holds no key. The engine now refuses to store a proof it
    # cannot sign, so the relaxation is stated here rather than defaulted into.
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
  def issue(**)
    raise GCore::Attestation::SynoptisAttestor::AttestorError, 'attestor down'
  end
end

class Tier1SubmitCoreTest < Minitest::Test
  RUBRIC_HASH = '4024d4d8817abb0feb76ca9e91effcb11fcea53b1caae2a2ee4efc985e4ca3b1'

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

  def base_report(overrides = {})
    report = {
      'rubric_version' => '0.2.5',
      'metric_semantics_version' => '0.2.5',
      'rubric_hash' => RUBRIC_HASH,
      'assessor_id' => 'claude (stage1 subagent) + masaomi',
      'assessed_at' => '2026-07-28',
      'canonical_id' => { 'value' => '10.1101/2025.01.29.635579', 'kind' => 'doi' },
      'paper_type' => 'mixed',
      'funnel_stage' => 'stage1-prose-only',
      'assessor_stack' => {
        'operator_id' => 'masaomi',
        'llm' => { 'provider' => 'anthropic', 'model' => 'claude-opus-4-6',
                   'invoked_at' => '2026-07-28T12:00:00Z' },
        'stage' => 'stage1-prose-only'
      },
      'steps' => [{
        'step_id' => 'C1', 'layer' => 'C',
        'axes' => { 'data' => 0, 'code' => 0, 'version' => 0, 'params' => 0 },
        'verdict' => 'NI', 'env_capture_class' => 'n/a'
      }],
      'counts' => { 'n_R' => 0, 'n_RI' => 0, 'n_NI' => 1, 'n_X' => 0, 'S' => 1, 'W' => 0 },
      'headline' => {
        'static_readiness' => '0/1 (0%) — stage1 ceiling only',
        'inference_inclusive_upper_bound' => '0/1',
        'coverage' => '1/1 computational'
      },
      'levers' => {
        'software_env_lock' => false, 'in_code_db_pin_classA' => false,
        'has_validated_env_capture' => false
      },
      'gaps' => [],
      'liveness' => [{ 'artifact' => 'none', 'http_status' => '404', 'checked_at' => '2026-07-28' }],
      'human_signoff' => { 'signed' => false, 'reviewer_id' => 'PENDING (stage1 draft)' },
      'manifest' => {
        'b1_manifest_hash' => nil,
        'chain_record' => 'not-yet-recorded',
        'supersedes' => nil
      }
    }
    report.merge(overrides).tap do |r|
      r['manifest'] = (report['manifest'] || {}).merge((overrides['manifest'] || {}))
      r['manifest']['b1_manifest_hash'] ||= GCore::B1ManifestHash.compute(r)
    end
  end

  def report_with_content_hash(report = base_report)
    h = GCore::ReportContentHash.compute(report)
    report.merge('report_content_hash' => h)
  end

  def signed_operator(tip_source, report)
    report = report_with_content_hash(report)
    sk = Ed25519::SigningKey.generate
    pk = sk.verify_key
    nonce = SecureRandom.hex(16)
    tip = tip_source.latest_tip_hash
    params = GCore::Tier1Submit.signed_params_for(report)
    payload = KairosMcp::Manifest.canonical_json(
      'mcp_tool_name' => 'gc_tier1_submit', 'params' => params,
      'nonce' => nonce, 'chain_tip_hash' => tip
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
    [report, op, Digest::SHA256.hexdigest(pubkey_str), sk]
  end

  def submit(registry, tip_source, report_json, op, pkhash, attestor)
    GCore::Tier1Submit.submit(
      report_json: report_json, operator: op, bearer_pubkey_hash: pkhash,
      tip_source: tip_source, attestor: attestor, registry: registry
    )
  end

  def test_happy_path_records_synoptis_proof
    with_proofs do |registry, tip_source|
      report, op, pkhash, = signed_operator(tip_source, base_report)
      json = JSON.generate(report)
      att = StubAttestor.new(registry: registry)

      out = submit(registry, tip_source, json, op, pkhash, att)

      assert_equal 'recorded', out[:status]
      refute_nil out[:synoptis_proof_id]
      assert out[:claim].start_with?('tier1:0/1 (0%)')
      assert out[:claim].include?(report['report_content_hash'])

      manifest = GCore::ProofLookup.parse_manifest_from_record(registry.read(:proofs).first)
      assert_equal 'tier1_report', manifest['record_type']
      assert_equal report['report_content_hash'], manifest['report_content_hash']
      assert_equal 'self_reported', manifest['trust_tier']
      assert_equal 'doi:10.1101/2025.01.29.635579', manifest['subject_ref']
    end
  end

  # Self-application design O-3: a paper with no DOI is recorded under the
  # sha256 of its text, never under "doi:".
  def test_text_sha256_paper_is_recorded_under_its_own_prefix
    text_id = 'c' * 64
    with_proofs do |registry, tip_source|
      report, op, pkhash, = signed_operator(
        tip_source, base_report('canonical_id' => { 'value' => text_id, 'kind' => 'text_sha256' })
      )
      out = submit(registry, tip_source, JSON.generate(report), op, pkhash, StubAttestor.new(registry: registry))

      assert_equal 'recorded', out[:status]
      manifest = GCore::ProofLookup.parse_manifest_from_record(registry.read(:proofs).first)
      assert_equal "text_sha256:#{text_id}", manifest['subject_ref']
    end
  end

  def test_zero_writes_to_operational_chain
    with_proofs do |registry, tip_source|
      Dir.mktmpdir do |chain_dir|
        chain = with_operational_chain(chain_dir)
        before = chain.chain.length
        report, op, pkhash, = signed_operator(tip_source, base_report)
        submit(registry, tip_source, JSON.generate(report), op, pkhash, StubAttestor.new(registry: registry))
        assert_equal before, chain.chain.length
      end
    end
  end

  def test_report_content_hash_mismatch_rejected
    with_proofs do |registry, tip_source|
      report, op, pkhash, = signed_operator(tip_source, base_report)
      report['report_content_hash'] = 'f' * 64
      assert_raises(GCore::Tier1Submit::DigestMismatch) do
        submit(registry, tip_source, JSON.generate(report), op, pkhash, StubAttestor.new(registry: registry))
      end
    end
  end

  def test_b1_manifest_hash_mismatch_rejected
    with_proofs do |registry, tip_source|
      report = base_report('manifest' => { 'b1_manifest_hash' => 'f' * 64,
                                           'chain_record' => 'not-yet-recorded', 'supersedes' => nil })
      report, op, pkhash, = signed_operator(tip_source, report)
      assert_raises(GCore::Tier1Submit::DigestMismatch) do
        submit(registry, tip_source, JSON.generate(report), op, pkhash, StubAttestor.new(registry: registry))
      end
    end
  end

  def test_steps_mutation_changes_digest_and_fails_submit
    with_proofs do |registry, tip_source|
      report, op, pkhash, = signed_operator(tip_source, base_report)
      forged = JSON.parse(JSON.generate(report))
      forged['steps'][0]['verdict'] = 'RI'
      assert_raises(GCore::Tier1Submit::DigestMismatch) do
        submit(registry, tip_source, JSON.generate(forged), op, pkhash, StubAttestor.new(registry: registry))
      end
    end
  end

  def test_headline_mutation_changes_digest_and_fails_submit
    with_proofs do |registry, tip_source|
      report, op, pkhash, = signed_operator(tip_source, base_report)
      forged = JSON.parse(JSON.generate(report))
      forged['headline']['static_readiness'] = '1/1 (100%) — forged'
      assert_raises(GCore::Tier1Submit::DigestMismatch) do
        submit(registry, tip_source, JSON.generate(forged), op, pkhash, StubAttestor.new(registry: registry))
      end
    end
  end

  def test_chain_record_excluded_from_digest
    report = base_report
    h1 = GCore::ReportContentHash.compute(report)
    report['manifest']['chain_record'] = 'synoptis:proof:abc'
    h2 = GCore::ReportContentHash.compute(report)
    assert_equal h1, h2
  end

  def test_b1_hash_included_in_digest
    report = base_report
    h1 = GCore::ReportContentHash.compute(report)
    report['manifest']['b1_manifest_hash'] = 'a' * 64
    h2 = GCore::ReportContentHash.compute(report)
    refute_equal h1, h2
  end

  def test_recovery_returns_existing_proof
    with_proofs do |registry, tip_source|
      report, op, pkhash, = signed_operator(tip_source, base_report)
      json = JSON.generate(report)
      att = StubAttestor.new(registry: registry)
      first = submit(registry, tip_source, json, op, pkhash, att)
      second = submit(registry, tip_source, json, op, pkhash, att)
      assert_equal first[:synoptis_proof_id], second[:synoptis_proof_id]
      assert_equal true, second[:recovered]
    end
  end

  def test_nonce_not_committed_when_synoptis_store_fails
    with_proofs do |registry, tip_source|
      report, op, pkhash, = signed_operator(tip_source, base_report)
      nonce = op.dig('signature', 'nonce')
      out = submit(registry, tip_source, JSON.generate(report), op, pkhash, RaisingAttestor.new)
      assert_equal 'recording_failed_retryable', out[:status]
      refute KairosMcp::Manifest::Signer.global_reservation.committed?(nonce)
    end
  end

  def test_missing_steps_rejected_before_admission
    with_proofs do |registry, tip_source|
      report = base_report
      report.delete('steps')
      report, op, pkhash, = signed_operator(tip_source, report)
      nonce = op.dig('signature', 'nonce')
      err = assert_raises(GCore::SubmitCore::SubmitError) do
        submit(registry, tip_source, JSON.generate(report), op, pkhash, StubAttestor.new(registry: registry))
      end
      assert_match(/steps|required/i, err.message)
      refute KairosMcp::Manifest::Signer.global_reservation.reserved?(nonce)
      refute KairosMcp::Manifest::Signer.global_reservation.committed?(nonce)
    end
  end

  def test_missing_human_signoff_rejected_before_admission
    with_proofs do |registry, tip_source|
      report = base_report
      report.delete('human_signoff')
      report, op, pkhash, = signed_operator(tip_source, report)
      nonce = op.dig('signature', 'nonce')
      err = assert_raises(GCore::SubmitCore::SubmitError) do
        submit(registry, tip_source, JSON.generate(report), op, pkhash, StubAttestor.new(registry: registry))
      end
      assert_match(/human_signoff|required/i, err.message)
      refute KairosMcp::Manifest::Signer.global_reservation.reserved?(nonce)
    end
  end

  def test_missing_metric_semantics_version_rejected_before_admission
    with_proofs do |registry, tip_source|
      report = base_report
      report.delete('metric_semantics_version')
      report, op, pkhash, = signed_operator(tip_source, report)
      nonce = op.dig('signature', 'nonce')
      err = assert_raises(GCore::SubmitCore::SubmitError) do
        submit(registry, tip_source, JSON.generate(report), op, pkhash, StubAttestor.new(registry: registry))
      end
      assert_match(/metric_semantics_version|required/i, err.message)
      refute KairosMcp::Manifest::Signer.global_reservation.reserved?(nonce)
      refute KairosMcp::Manifest::Signer.global_reservation.committed?(nonce)
    end
  end

  def test_missing_assessed_at_rejected
    with_proofs do |registry, tip_source|
      report = base_report
      report['assessed_at'] = ''
      report['manifest']['b1_manifest_hash'] = GCore::B1ManifestHash.compute(report.merge('assessed_at' => 'x'))
      report, op, pkhash, = signed_operator(tip_source, report)
      nonce = op.dig('signature', 'nonce')
      assert_raises(GCore::SubmitCore::SubmitError, GCore::SubmitCore::DigestMismatch) do
        submit(registry, tip_source, JSON.generate(report), op, pkhash, StubAttestor.new(registry: registry))
      end
      refute KairosMcp::Manifest::Signer.global_reservation.reserved?(nonce)
      refute KairosMcp::Manifest::Signer.global_reservation.committed?(nonce)
    end
  end

  def with_forced_proof_state(state)
    mod = GCore::ProofLookup
    orig = mod.method(:proof_state)
    mod.define_singleton_method(:proof_state) { |_registry, _proof_id| state }
    yield
  ensure
    mod.define_singleton_method(:proof_state, orig)
  end

  def test_recovery_revoked_returns_status
    with_proofs do |registry, tip_source|
      report, op, pkhash, = signed_operator(tip_source, base_report)
      json = JSON.generate(report)
      att = StubAttestor.new(registry: registry)
      first = submit(registry, tip_source, json, op, pkhash, att)
      with_forced_proof_state(:revoked) do
        out = submit(registry, tip_source, json, op, pkhash, att)
        assert_equal 'recorded_attestation_revoked', out[:status]
        assert_equal first[:synoptis_proof_id], out[:synoptis_proof_id]
      end
    end
  end

  def test_recovery_expired_returns_status
    with_proofs do |registry, tip_source|
      report, op, pkhash, = signed_operator(tip_source, base_report)
      json = JSON.generate(report)
      att = StubAttestor.new(registry: registry)
      first = submit(registry, tip_source, json, op, pkhash, att)
      with_forced_proof_state(:expired) do
        out = submit(registry, tip_source, json, op, pkhash, att)
        assert_equal 'recorded_attestation_expired', out[:status]
        assert_equal first[:synoptis_proof_id], out[:synoptis_proof_id]
      end
    end
  end
end
