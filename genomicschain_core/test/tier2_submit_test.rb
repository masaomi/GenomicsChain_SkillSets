# frozen_string_literal: true
# Tier2Submit via SubmitCore — the same Synoptis-only path Tier-1 and Tier-3 use.
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

GCore2 = KairosMcp::SkillSets::GenomicschainCore

class Tier2StubAttestor
  attr_reader :calls, :registry

  def initialize(registry:)
    @registry = registry
    @calls = []
  end

  def issue(**kw)
    @calls << kw
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

class Tier2RaisingAttestor
  def issue(**); raise GCore2::Attestation::SynoptisAttestor::AttestorError, 'attestor down'; end
end

class Tier2SubmitCoreTest < Minitest::Test
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

  # The shape gc_tier2_adjudicate emits (panREPET, 2026-09-08, reduced to the
  # fields the record reads). Per-resource lists are kept short on purpose: the
  # record never stores them, only their digest.
  def adjudication(declared_lock: true, byte_fixed: false, demotions: 0, content_hash: 'b' * 64)
    {
      'adjudication_rubric_version' => 'codescan-adjudication-0.1.0',
      'rubric_source' => 'repro_tier1_guide (rubric v0.2.5) § fetch-required',
      'subject' => {
        'canonical_id' => '10.1101/2024.06.17.598857',
        'tier1_rubric_version' => '0.2.5',
        'tier1_report_content_hash' => content_hash,
        'codescan_evidence_digest' => 'a' * 64,
        'codescan_toolchain' => { 'ruby' => '3.4.10', 'ruby_platform' => 'arm64-darwin23', 'psych' => '5.2.2',
                                  'codescan_rubric_version' => 'codescan-static-0.1.0' },
        'adjudication_toolchain' => { 'ruby' => '3.4.10', 'ruby_platform' => 'arm64-darwin23' }
      },
      'stage_transition' => { 'from' => 'stage1-prose-only', 'to' => 'stage2-code-verified', 'applied' => false,
                              'note' => 'Proposed.' },
      'resource_classes' => [{ 'key' => 'GFF', 'locator' => 'x.gff', 'env_capture_class' => 'B_pin_prose_only' }],
      'step_dispositions' => [{ 'rule' => 'extractCopies', 'env_capture_class' => 'n/a' }],
      'levers' => {
        'code_derived' => { 'software_env_lock' => byte_fixed, 'software_env_lock_at_versioned' => declared_lock,
                            'in_code_db_pin_classA' => false },
        'tier1_claimed' => { 'software_env_lock' => true, 'in_code_db_pin_classA' => true },
        'lever1_environment_lock' => {
          'declared_lock' => { 'value' => declared_lock, 'threshold' => 'versioned' },
          'byte_fixed_lock' => { 'value' => byte_fixed, 'threshold' => 'immutable' },
          'headline' => 'ships a declared lock, but its bytes are not fixed'
        }
      },
      'discrepancies' => [{ 'code' => 'resource_read_but_never_declared' }],
      'counts' => { 'rules_in_code' => 16, 'rules_unique' => 16, 'tier1_steps' => 8, 'steps_linked' => 4,
                    'steps_unlinked' => 12, 'dispositions' => 16, 'proposed_demotions' => demotions,
                    'demotion_proposal_is_a_lower_bound' => true },
      'ambiguous_links' => [{ 'rule' => 'x', 'step_ids' => %w[C1 C2] }],
      'limits' => ['Steps are linked to rules by NAME.']
    }
  end

  def repository
    { 'url' => 'https://forgemia.inra.fr/urgi-anagen/panREPET', 'commit' => '6d8748a03a7e053cfe2b84364170bf1712c6df0f' }
  end

  def signed_operator(tip_source, params)
    sk = Ed25519::SigningKey.generate
    pk = sk.verify_key
    nonce = SecureRandom.hex(16)
    tip = tip_source.latest_tip_hash
    payload = KairosMcp::Manifest.canonical_json(
      'mcp_tool_name' => 'gc_tier2_submit', 'params' => params, 'nonce' => nonce, 'chain_tip_hash' => tip
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

  def submit(registry, tip_source, adj, identity, op, pkhash, attestor, repository: nil)
    GCore2::Tier2Submit.submit(
      adjudication: adj, identity: identity, repository: repository, operator: op,
      bearer_pubkey_hash: pkhash, tip_source: tip_source, attestor: attestor, registry: registry
    )
  end

  def test_happy_path_records_synoptis_proof_with_manifest_envelope
    with_proofs do |registry, tip_source|
      adj = adjudication
      identity = GCore2::Tier2Submit.signed_params_for(adj, repository)
      op, pkhash, = signed_operator(tip_source, identity)

      out = submit(registry, tip_source, adj, identity, op, pkhash, Tier2StubAttestor.new(registry: registry),
                   repository: repository)

      assert_equal 'recorded', out[:status]
      refute_nil out[:synoptis_proof_id]
      digest = GCore2::Tier2Submit.adjudication_digest(adj)
      assert_equal "tier2:declared_lock:0:#{digest}:#{out[:submission_key]}", out[:claim]

      proofs = registry.read(:proofs)
      assert_equal 1, proofs.length
      manifest = GCore2::ProofLookup.parse_manifest_from_record(proofs.first)
      assert_equal 'tier2_adjudication', manifest['record_type']
      assert_equal '0.1', manifest['record_version']
      assert_equal out[:submission_key], manifest['submission_key']
      assert_equal digest, manifest['adjudication_digest']
      assert_equal 'a' * 64, manifest['codescan_evidence_digest']
      assert_equal 'b' * 64, manifest['tier1_report_content_hash']
      assert_equal 'doi:10.1101/2024.06.17.598857', manifest['subject_ref']
      assert_equal({ 'declared_lock' => true, 'byte_fixed_lock' => false, 'in_code_db_pin_classA' => false,
                     'headline' => 'ships a declared lock, but its bytes are not fixed' }, manifest['levers'])
      assert_equal 4, manifest.dig('counts', 'steps_linked')
      assert_equal '3.4.10', manifest.dig('toolchain', 'ruby')
      assert_equal 'self_reported', manifest['trust_tier']
      assert_equal false, manifest.dig('stage_transition', 'applied')
      assert_equal repository['commit'], manifest.dig('repository', 'commit')
      assert_equal 'operator_stated', manifest.dig('repository', 'provenance')
      refute manifest.key?('resource_classes'), 'per-resource lists stay with the operator'
      refute manifest.key?('step_dispositions')
    end
  end

  # The interpreter is part of what is signed (author's decision 2026-09-09):
  # the same bytes under a different Ruby gave a different adjudication.
  def test_toolchain_ruby_is_in_the_signed_identity
    adj = adjudication
    identity = GCore2::Tier2Submit.signed_params_for(adj)
    assert_equal '3.4.10', identity['toolchain_ruby']
    assert_includes GCore2::Tier2Submit::SIGNED_IDENTITY_FIELDS, 'toolchain_ruby'
  end

  # Every signed field is derived from the adjudication again. An identity
  # that claims a lock the adjudication does not show is refused.
  def test_identity_that_disagrees_with_the_adjudication_is_rejected
    with_proofs do |registry, tip_source|
      adj = adjudication(declared_lock: false)
      forged = GCore2::Tier2Submit.signed_params_for(adj).merge('lever1_declared_lock' => true)
      op, pkhash, = signed_operator(tip_source, forged)
      assert_raises(GCore2::Tier2Submit::IdentityMismatch) do
        submit(registry, tip_source, adj, forged, op, pkhash, Tier2StubAttestor.new(registry: registry))
      end
    end
  end

  # Signing one adjudication and submitting another (a count edited after
  # signing) trips the digest recompute before anything else.
  def test_tampered_adjudication_is_a_digest_mismatch
    with_proofs do |registry, tip_source|
      adj = adjudication
      identity = GCore2::Tier2Submit.signed_params_for(adj)
      op, pkhash, = signed_operator(tip_source, identity)
      tampered = JSON.parse(JSON.generate(adj))
      tampered['counts']['proposed_demotions'] = 5
      assert_raises(GCore2::Tier2Submit::DigestMismatch) do
        submit(registry, tip_source, tampered, identity, op, pkhash, Tier2StubAttestor.new(registry: registry))
      end
    end
  end

  # A Tier-2 record must bind to a Tier-1 report identity. The older stage-2
  # reports carry no report_content_hash; their adjudications are refused,
  # not recorded with a hole where the binding goes.
  def test_adjudication_without_tier1_content_hash_is_refused
    with_proofs do |registry, tip_source|
      adj = adjudication(content_hash: nil)
      identity = GCore2::Tier2Submit.signed_params_for(adj)
      op, pkhash, = signed_operator(tip_source, identity)
      err = assert_raises(GCore2::Tier2Submit::SubmitError) do
        submit(registry, tip_source, adj, identity, op, pkhash, Tier2StubAttestor.new(registry: registry))
      end
      assert_match(/tier1_report_content_hash/, err.message)
    end
  end

  def test_applied_stage_transition_is_refused
    with_proofs do |registry, tip_source|
      adj = adjudication
      adj['stage_transition']['applied'] = true
      identity = GCore2::Tier2Submit.signed_params_for(adj)
      op, pkhash, = signed_operator(tip_source, identity)
      err = assert_raises(GCore2::Tier2Submit::SubmitError) do
        submit(registry, tip_source, adj, identity, op, pkhash, Tier2StubAttestor.new(registry: registry))
      end
      assert_match(/applied must be false/, err.message)
    end
  end

  def test_client_supplied_trust_tier_rejected
    with_proofs do |registry, tip_source|
      adj = adjudication.merge('trust_tier' => 'peer_verified')
      identity = GCore2::Tier2Submit.signed_params_for(adj)
      op, pkhash, = signed_operator(tip_source, identity)
      assert_raises(GCore2::Tier2Submit::TrustTierError) do
        submit(registry, tip_source, adj, identity, op, pkhash, Tier2StubAttestor.new(registry: registry))
      end
    end
  end

  def test_unsigned_mode_rejected
    with_proofs do |registry, tip_source|
      adj = adjudication
      identity = GCore2::Tier2Submit.signed_params_for(adj)
      assert_raises(GCore2::Tier2Submit::UnsignedModeError) do
        submit(registry, tip_source, adj, identity, { 'mode' => 'anonymous' }, 'x' * 64,
               Tier2StubAttestor.new(registry: registry))
      end
    end
  end

  def test_bearer_pubkey_binding_fail_closed
    with_proofs do |registry, tip_source|
      adj = adjudication
      identity = GCore2::Tier2Submit.signed_params_for(adj)
      op, = signed_operator(tip_source, identity)
      assert_raises(GCore2::Tier2Submit::BearerBindingError) do
        submit(registry, tip_source, adj, identity, op, nil, Tier2StubAttestor.new(registry: registry))
      end
    end
  end

  def test_zero_writes_to_operational_chain
    with_proofs do |registry, tip_source|
      Dir.mktmpdir do |chain_dir|
        chain = with_operational_chain(chain_dir)
        before = chain.chain.length
        adj = adjudication
        identity = GCore2::Tier2Submit.signed_params_for(adj)
        op, pkhash, = signed_operator(tip_source, identity)
        submit(registry, tip_source, adj, identity, op, pkhash, Tier2StubAttestor.new(registry: registry))
        assert_equal before, chain.chain.length
      end
    end
  end

  def test_nonce_not_committed_when_synoptis_store_fails
    with_proofs do |registry, tip_source|
      adj = adjudication
      identity = GCore2::Tier2Submit.signed_params_for(adj)
      op, pkhash, = signed_operator(tip_source, identity)
      nonce = op.dig('signature', 'nonce')
      out = submit(registry, tip_source, adj, identity, op, pkhash, Tier2RaisingAttestor.new)
      assert_equal 'recording_failed_retryable', out[:status]
      refute KairosMcp::Manifest::Signer.global_reservation.committed?(nonce)
      assert_equal 0, registry.read(:proofs).length
    end
  end

  def test_recovery_returns_existing_proof_without_second_store
    with_proofs do |registry, tip_source|
      adj = adjudication
      identity = GCore2::Tier2Submit.signed_params_for(adj)
      op, pkhash, = signed_operator(tip_source, identity)
      att = Tier2StubAttestor.new(registry: registry)
      first = submit(registry, tip_source, adj, identity, op, pkhash, att)
      second = submit(registry, tip_source, adj, identity, op, pkhash, att)
      assert_equal first[:synoptis_proof_id], second[:synoptis_proof_id]
      assert_equal true, second[:recovered]
      assert_equal 1, registry.read(:proofs).length
    end
  end

  # Two different adjudications by the same operator must not share an
  # idempotency key (SubmitCore derives it from the digest subject).
  def test_idempotency_key_distinguishes_adjudications
    with_proofs do |registry, tip_source|
      att = Tier2StubAttestor.new(registry: registry)
      a1 = adjudication
      i1 = GCore2::Tier2Submit.signed_params_for(a1)
      op1, pk1, = signed_operator(tip_source, i1)
      out1 = submit(registry, tip_source, a1, i1, op1, pk1, att)

      a2 = adjudication(demotions: 3)
      i2 = GCore2::Tier2Submit.signed_params_for(a2)
      op2, pk2, = signed_operator(tip_source, i2)
      out2 = submit(registry, tip_source, a2, i2, op2, pk2, att)

      refute_equal out1[:idempotency_key], out2[:idempotency_key]
      assert out2[:claim].start_with?('tier2:declared_lock:3:')
    end
  end

  def test_oversized_adjudication_rejected_by_dos_gate
    with_proofs do |registry, tip_source|
      adj = adjudication
      adj['resource_classes'] = Array.new(2000) { |i| { 'key' => "k#{i}", 'locator' => 'x' * 40 } }
      identity = GCore2::Tier2Submit.signed_params_for(adj)
      op, pkhash, = signed_operator(tip_source, identity)
      assert_raises(KairosMcp::Manifest::DoSGateTripped) do
        submit(registry, tip_source, adj, identity, op, pkhash, Tier2StubAttestor.new(registry: registry))
      end
    end
  end
end
