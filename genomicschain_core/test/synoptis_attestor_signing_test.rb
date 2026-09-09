# frozen_string_literal: true

# Drives the real SynoptisAttestor end to end. The existing submit tests use a
# StubAttestor, which is why an unsigned-proof defect survived: nothing exercised
# the attestor's own call into AttestationEngine. These tests call the shipped
# class, the shipped engine and the shipped Verifier, with the shipped config.

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'json'
require 'yaml'
# SynoptisAttestor.build resolves its data directory through KairosMcp, so the
# module has to be loaded for the build-level tests to redirect it at a tmpdir.
require 'kairos_mcp'
require_relative 'proofs_sandbox'
# proofs_sandbox loads the envelope, verifier, engine and registry; revocation
# is only needed here, so it is required in place rather than added to the
# shared sandbox.
require 'synoptis/revocation_manager'

# MMP is distributed as a SkillSet; the canonical copy is the gem template.
# Synoptis::Verifier#verify_signature returns false unless ::MMP::Crypto is
# defined, so a signature test has to load the real one rather than a double.
MMP_LIB = File.expand_path(
  '../../../../../KairosChain_2026/KairosChain_mcp_server/templates/skillsets/mmp/lib',
  __dir__
)
$LOAD_PATH.unshift(MMP_LIB) if File.directory?(MMP_LIB)
require 'mmp/crypto'
# SynoptisAttestor.resolve_anchor_identity reaches for MMP::Identity; loading it
# here lets the resolver be driven rather than only injected around.
require 'mmp/identity'

require 'genomicschain_core'

GCA = KairosMcp::SkillSets::GenomicschainCore::Attestation

class SynoptisAttestorSigningTest < Minitest::Test
  SHIPPED_CONFIG_PATH = File.expand_path(
    '../../synoptis/config/synoptis.yml', __dir__
  )

  def shipped_attestation_config
    att = YAML.safe_load(File.read(SHIPPED_CONFIG_PATH))['attestation']
    {
      'default_ttl' => att['default_ttl'],
      'max_evidence_size' => att['max_evidence_size'],
      'require_signature' => att.fetch('require_signature', true)
    }
  end

  # config: defaults to the shipped one. Tests that need to observe what the
  # shipped setting prevents pass a relaxed config explicitly, so the relaxation
  # is visible at the call site rather than hidden in the helper.
  def with_context(config: nil)
    Dir.mktmpdir do |dir|
      registry = ::Synoptis::Registry::FileRegistry.new(data_dir: dir)
      engine = ::Synoptis::AttestationEngine.new(registry: registry,
                                                 config: config || shipped_attestation_config)
      crypto = ::MMP::Crypto.new(keypair_path: File.join(dir, 'anchor.pem'), auto_generate: true)
      yield(registry, engine, crypto, dir)
    end
  end

  def attestor(engine:, registry:, agent_id: 'anchor-instance-0001', crypto: nil, require_signature: true)
    GCA::SynoptisAttestor.new(
      engine: engine, attester_id: agent_id, crypto: crypto,
      submitter_pubkey: 'ed25519:' + ('ab' * 32),
      require_signature: require_signature, registry: registry
    )
  end

  def issue(att, subject: 'doi:10.1/alpha', claim: 'tier1:0.8:hash:key')
    att.issue(subject_ref: subject, claim: claim, evidence: '{"manifest":{}}', actor_role: 'automated')
  end

  # The fix: the shipped config requires a signature, so the proof the attestor
  # records must carry one and must verify.
  def test_recorded_proof_is_signed_and_verifies_under_the_shipped_config
    with_context do |registry, engine, crypto|
      assert shipped_attestation_config['require_signature'],
             'shipped synoptis.yml no longer requires a signature; this test needs rewriting'

      result = issue(attestor(engine: engine, registry: registry, crypto: crypto))
      proof_id = result[:synoptis_proof_id]
      refute_nil proof_id

      envelope = registry.find_proof(proof_id)
      refute_nil envelope.signature, 'envelope was stored without a signature'

      verdict = engine.verify_attestation(proof_id, public_key: crypto.export_public_key)
      assert_equal [], verdict[:errors] || verdict['errors']
      assert verdict[:valid] || verdict['valid'], "verify_attestation returned #{verdict.inspect}"
    end
  end

  # Records the defect this change closes, and proves the test above
  # discriminates. Reachable only on an engine configured NOT to require a
  # signature: the shipped config now refuses this outcome (see the engine test
  # below), so the relaxed config is what makes the old behaviour observable.
  def test_unsigned_proof_is_stored_but_never_verifies_when_signatures_are_not_required
    relaxed = shipped_attestation_config.merge('require_signature' => false)
    with_context(config: relaxed) do |registry, engine|
      att = attestor(engine: engine, registry: registry, crypto: nil, require_signature: false)
      result = issue(att)

      envelope = registry.find_proof(result[:synoptis_proof_id])
      assert_nil envelope.signature

      verdict = ::Synoptis::Verifier.new(config: { require_signature: true })
                                    .verify(envelope)
      refute verdict[:valid]
      assert_includes verdict[:errors], 'missing_signature'
    end
  end

  # The invariant lives in the engine, which is the object configured with
  # require_signature — so every caller is covered, not only the attestor that
  # was patched. `attestation_issue` and `pm_record` both pass
  # `crypto: resolve_crypto`, which is nil whenever MMP cannot be resolved.
  def test_the_engine_itself_refuses_to_store_an_unsignable_proof
    with_context do |registry, engine|
      result = engine.create_attestation(
        attester_id: 'anchor-instance-0001', subject_ref: 'doi:10.1/alpha',
        claim: 'tier1:0.8:hash:key', evidence: '{"manifest":{}}',
        actor_role: 'automated', crypto: nil
      )
      assert_equal 'error', result[:status] || result['status']
      assert_match(/signing key unavailable/, result[:message] || result['message'])
      assert_empty registry.list_proofs(filter: {}), 'a proof was stored despite the refusal'
    end
  end

  def test_issue_refuses_when_the_anchor_has_no_signing_key
    with_context do |registry, engine|
      att = attestor(engine: engine, registry: registry, crypto: nil, require_signature: true)
      error = assert_raises(GCA::SynoptisAttestor::AttestorError) { issue(att) }
      assert_match(/signing key unavailable/, error.message)
      assert_empty registry.list_proofs(filter: {}), 'a proof was stored despite the refusal'
    end
  end

  def test_issue_refuses_when_the_anchor_identity_is_unresolved
    with_context do |registry, engine, crypto|
      att = attestor(engine: engine, registry: registry, agent_id: nil, crypto: crypto)
      error = assert_raises(GCA::SynoptisAttestor::AttestorError) { issue(att) }
      assert_match(/identity unavailable/, error.message)
      assert_empty registry.list_proofs(filter: {}), 'a proof was stored despite the refusal'
    end
  end

  # attester_id is now the anchor's own agent id, which is the value
  # Synoptis::ToolHelpers#resolve_agent_id passes as revoker_id — so a proof
  # recorded through the submit path became revocable by the anchor.
  def test_recorded_proof_is_revocable_by_the_anchor_that_recorded_it
    with_context do |registry, engine, crypto|
      agent_id = 'anchor-instance-0001'
      result = issue(attestor(engine: engine, registry: registry, agent_id: agent_id, crypto: crypto))
      manager = ::Synoptis::RevocationManager.new(registry: registry)

      outcome = manager.revoke(proof_id: result[:synoptis_proof_id], reason: 'test',
                               revoker_id: agent_id, actor_role: 'owner')
      assert_equal 'revoked', outcome[:status] || outcome['status']
      assert registry.revoked?(result[:synoptis_proof_id])
    end
  end

  # Ruling of 2026-08-02 (option A2). A proof does not certify itself: the key is
  # supplied by the caller, so a reader with no key gets no verdict rather than a
  # verdict resting on what the record says about itself.
  def test_a_recorded_proof_cannot_be_verified_without_being_handed_a_key
    with_context do |registry, engine, crypto|
      result = issue(attestor(engine: engine, registry: registry, crypto: crypto))
      envelope = registry.find_proof(result[:synoptis_proof_id])

      refute envelope.respond_to?(:attester_pubkey), 'the envelope reintroduced a recorded signing key'
      refute_includes envelope.canonical_json, 'attester_pubkey'

      verdict = engine.verify_attestation(result[:synoptis_proof_id])
      refute verdict[:valid], "verify without a supplied key returned #{verdict.inspect}"
      assert_includes verdict[:errors], 'no_public_key_for_verification'

      supplied = engine.verify_attestation(result[:synoptis_proof_id],
                                           public_key: crypto.export_public_key)
      assert supplied[:valid], "verify with the anchor key returned #{supplied.inspect}"
    end
  end

  # The defect this ruling exists to close, measured end to end. carries_identity_fields?
  # reads the version, and the version is a field of the record, so a forger writes it.
  # Under F1 this exact envelope verified clean from the record alone; the key must now
  # come from the caller, so relabelling buys nothing.
  def test_relabelling_a_forged_record_as_the_identity_version_gains_nothing
    with_context do |_registry, engine, _crypto, dir|
      attacker = ::MMP::Crypto.new(keypair_path: File.join(dir, 'attacker.pem'), auto_generate: true)
      verifier = ::Synoptis::Verifier.new(config: { require_signature: true })

      [::Synoptis::ProofEnvelope::PROOF_VERSION,
       ::Synoptis::ProofEnvelope::PROOF_VERSION_WITH_IDENTITY].each do |version|
        forged = ::Synoptis::ProofEnvelope.new(
          version: version, attester_id: 'victim-anchor-0001', subject_ref: 'doi:10.1/alpha',
          claim: 'tier1:FORGED', evidence: 'e', ttl: 86_400,
          # the shape a forger would try: hand the verifier the attacker's own key
          attester_pubkey: attacker.export_public_key
        )
        forged.instance_variable_set(:@signature, attacker.sign(forged.canonical_json))

        verdict = verifier.verify(forged)
        refute verdict[:valid], "a self-certifying record labelled #{version} was accepted"
        assert_includes verdict[:errors], 'no_public_key_for_verification'
      end
      assert engine
    end
  end

  # With no recorded key there is nothing to disagree with, so a wrong key is a
  # statement about the signature and is reported as one.
  def test_supplying_a_different_key_is_a_broken_signature
    with_context do |registry, engine, crypto, dir|
      other = ::MMP::Crypto.new(keypair_path: File.join(dir, 'other.pem'), auto_generate: true)
      result = issue(attestor(engine: engine, registry: registry, crypto: crypto))

      verdict = engine.verify_attestation(result[:synoptis_proof_id],
                                          public_key: other.export_public_key)
      refute verdict[:valid]
      assert_includes verdict[:errors], 'invalid_signature'
    end
  end

  # MCP clients send '' for an omitted optional string. Passing that through would
  # report invalid_signature — a claim about the signature when no key was given.
  def test_an_empty_public_key_is_no_key_rather_than_a_broken_signature
    with_context do |registry, engine, crypto|
      result = issue(attestor(engine: engine, registry: registry, crypto: crypto))

      ['', '   '].each do |blank|
        verdict = engine.verify_attestation(result[:synoptis_proof_id], public_key: blank)
        refute verdict[:valid]
        assert_includes verdict[:errors], 'no_public_key_for_verification'
        refute_includes verdict[:errors], 'invalid_signature'
      end
    end
  end

  # C-2: the submitter is a field of the signed canonical payload, not a value
  # buried in the evidence string.
  def test_submitter_pubkey_is_carried_in_the_signed_canonical_payload
    with_context do |registry, engine, crypto|
      submitter = 'ed25519:' + ('ab' * 32)
      result = issue(attestor(engine: engine, registry: registry, crypto: crypto))
      envelope = registry.find_proof(result[:synoptis_proof_id])

      assert_equal submitter, envelope.submitter_pubkey
      assert_equal ::Synoptis::ProofEnvelope::PROOF_VERSION_WITH_IDENTITY, envelope.version
      assert_includes envelope.canonical_json, 'submitter_pubkey'
      assert(engine.verify_attestation(result[:synoptis_proof_id],
                                       public_key: crypto.export_public_key)[:valid])
    end
  end

  # Tampering with the submitter must break the signature. Without this the
  # field would be a display value wearing a signature's clothes.
  def test_rewriting_the_submitter_breaks_the_signature
    with_context do |registry, engine, crypto|
      result = issue(attestor(engine: engine, registry: registry, crypto: crypto))
      stored = registry.find_proof(result[:synoptis_proof_id]).to_h
      forged = ::Synoptis::ProofEnvelope.from_h(stored.merge(submitter_pubkey: 'ed25519:' + ('cd' * 32)))

      verdict = ::Synoptis::Verifier.new(config: { require_signature: true })
                                    .verify(forged, public_key: crypto.export_public_key)
      refute verdict[:valid]
      assert_includes verdict[:errors], 'invalid_signature'
    end
  end

  # An envelope that predates the field keeps the byte-for-byte canonical form
  # it was signed over, so existing signatures are not invalidated.
  def test_version_1_0_0_envelopes_keep_their_canonical_form
    envelope = ::Synoptis::ProofEnvelope.new(
      attester_id: 'a', subject_ref: 's', claim: 'c', evidence: 'e', ttl: 86_400
    )
    assert_equal ::Synoptis::ProofEnvelope::PROOF_VERSION, envelope.version
    refute_includes envelope.canonical_json, 'submitter_pubkey'
  end

  # A submitter carried at a version that does not sign it is a value outside
  # the signature. It is reported by the Verifier, not raised at construction:
  # construction is also the deserialisation path, and raising there turns a bad
  # record into an exception for whoever reads it.
  def test_an_identity_field_outside_the_signature_is_reported_not_raised
    envelope = ::Synoptis::ProofEnvelope.new(
      version: ::Synoptis::ProofEnvelope::PROOF_VERSION,
      attester_id: 'a', subject_ref: 's', claim: 'c', submitter_pubkey: 'ed25519:x'
    )
    assert envelope.identity_outside_signature?, 'submitter_pubkey outside the signature went unreported'
    refute_includes envelope.canonical_json, 'submitter_pubkey'

    verdict = ::Synoptis::Verifier.new(config: { require_signature: false }).verify(envelope)
    refute verdict[:valid]
    assert_includes verdict[:errors], 'identity_outside_signature'
  end

  # attester_pubkey is not a field of this envelope at any version. A record that
  # carries one is carrying a value nothing reads — asserted here so a future
  # revision that reintroduces it has to change this test on purpose.
  def test_attester_pubkey_is_not_a_field_at_any_version
    [::Synoptis::ProofEnvelope::PROOF_VERSION,
     ::Synoptis::ProofEnvelope::PROOF_VERSION_WITH_IDENTITY].each do |version|
      envelope = ::Synoptis::ProofEnvelope.new(
        version: version, attester_id: 'a', subject_ref: 's', claim: 'c',
        attester_pubkey: 'ed25519:x'
      )
      refute envelope.respond_to?(:attester_pubkey), "#{version} exposes attester_pubkey"
      refute_includes envelope.canonical_json, 'attester_pubkey'
      refute_includes envelope.to_h.keys.map(&:to_s), 'attester_pubkey'
    end
  end

  # The stored-record path, not just the in-memory one: a proof already sitting in
  # the registry with a key written alongside it still yields no verdict without a
  # supplied key. The forger controls the file, so this is the shape that matters.
  def test_a_key_written_beside_a_stored_proof_is_not_used_to_verify
    with_context do |registry, engine, crypto, dir|
      forged = ::Synoptis::ProofEnvelope.new(
        version: ::Synoptis::ProofEnvelope::PROOF_VERSION_WITH_IDENTITY,
        attester_id: 'anchor-instance-0001', subject_ref: 'doi:10.1/alpha',
        claim: 'tier1:FORGED', evidence: 'e', ttl: 86_400
      )
      forged.instance_variable_set(:@signature, crypto.sign(forged.canonical_json))
      record = forged.to_h.merge('_type' => 'proof', 'attester_pubkey' => crypto.export_public_key)
      File.open(File.join(dir, 'proofs.jsonl'), 'a') { |f| f.puts JSON.generate(record) }

      verdict = engine.verify_attestation(forged.proof_id)
      refute verdict[:valid], 'a key written beside a stored proof was trusted'
      assert_includes verdict[:errors], 'no_public_key_for_verification'
      assert registry
    end
  end

  # The branch the attestation_verify schema advertises for older envelopes.
  def test_a_legacy_signed_envelope_without_a_recorded_key_cannot_be_verified_alone
    with_context do |_registry, engine, crypto|
      legacy = ::Synoptis::ProofEnvelope.new(
        version: ::Synoptis::ProofEnvelope::PROOF_VERSION,
        attester_id: 'a', subject_ref: 's', claim: 'c', evidence: 'e', ttl: 86_400
      )
      legacy.sign!(crypto)
      refute legacy.respond_to?(:attester_pubkey), 'signing recorded a key it does not sign'

      verifier = ::Synoptis::Verifier.new(config: { require_signature: true })
      assert_includes verifier.verify(legacy)[:errors], 'no_public_key_for_verification'
      assert verifier.verify(legacy, public_key: crypto.export_public_key)[:valid]
      assert engine # engine is unused here; the legacy path needs no registry
    end
  end

  # load_config is the last thing between a synoptis.yml that omits or blanks
  # require_signature and a silently signature-free anchor.
  def test_load_config_treats_an_unset_or_blank_require_signature_as_required
    previous = KairosMcp.data_dir
    Dir.mktmpdir do |dir|
      KairosMcp.data_dir = dir
      cfg_dir = File.join(dir, 'skillsets', 'synoptis', 'config')
      FileUtils.mkdir_p(cfg_dir)
      path = File.join(cfg_dir, 'synoptis.yml')

      File.write(path, "attestation:\n  default_ttl: 3600\n  require_signature: false\n")
      assert_equal false, GCA::SynoptisAttestor.load_config['require_signature']

      File.write(path, "attestation:\n  default_ttl: 3600\n")
      assert_equal true, GCA::SynoptisAttestor.load_config['require_signature']

      File.write(path, "attestation:\n  default_ttl: 3600\n  require_signature:\n")
      assert_equal true, GCA::SynoptisAttestor.load_config['require_signature']

      File.delete(path)
      assert_empty GCA::SynoptisAttestor.load_config
    end
  ensure
    KairosMcp.data_dir = previous
  end

  # A present-but-nil value must not disable the engine's refusal.
  def test_the_engine_treats_a_blank_require_signature_as_required
    Dir.mktmpdir do |dir|
      registry = ::Synoptis::Registry::FileRegistry.new(data_dir: dir)
      engine = ::Synoptis::AttestationEngine.new(
        registry: registry, config: { 'require_signature' => nil, 'default_ttl' => 86_400 }
      )
      result = engine.create_attestation(attester_id: 'a', subject_ref: 's', claim: 'c',
                                         evidence: 'e', actor_role: 'automated', crypto: nil)
      assert_equal 'error', result[:status]
      assert_empty registry.list_proofs(filter: {})
    end
  end

  # An unnameable attester is refused by the engine, so a caller whose identity
  # resolver failed cannot store a proof nobody can be held to or revoke.
  def test_the_engine_refuses_a_proof_with_no_attester
    with_context do |registry, engine, crypto|
      ['', '   ', nil].each do |bad|
        result = engine.create_attestation(attester_id: bad, subject_ref: 's', claim: "c-#{bad.inspect}",
                                           evidence: 'e', actor_role: 'automated', crypto: crypto)
        assert_equal 'error', result[:status], "attester_id #{bad.inspect} was accepted"
      end
      assert_empty registry.list_proofs(filter: {})
    end
  end

  # One malformed record must not take down an unfiltered listing: list_proofs
  # builds every record through from_h, so a raise there would fail the whole
  # registry rather than the one record.
  def test_one_malformed_record_does_not_break_listing_the_registry
    with_context do |registry, engine, crypto, dir|
      issue(attestor(engine: engine, registry: registry, crypto: crypto))
      File.open(File.join(dir, 'proofs.jsonl'), 'a') do |f|
        f.puts JSON.generate('_type' => 'proof', 'proof_id' => 'bad-1', 'version' => '1.0.0',
                             'attester_id' => 'x', 'subject_ref' => 's', 'claim' => 'c',
                             'ttl' => 86_400, 'timestamp' => Time.now.utc.iso8601,
                             'submitter_pubkey' => 'ed25519:zz')
      end

      listed = registry.list_proofs(filter: {})
      assert_equal 2, listed.size
      bad = listed.find { |e| e.proof_id == 'bad-1' }
      assert bad.identity_outside_signature?
    end
  end

  # F4 — SynoptisAttestor.build is the only path production takes
  # (gc_tier1_submit and gc_tier3_submit call nothing else), and it is where the
  # wiring lives: which identity attests, which key signs, which value is
  # carried as the submitter. Testing only #issue leaves that wiring undriven,
  # which is the same shape of gap that let the unsigned-proof defect survive.

  # Gives KairosMcp a throwaway data dir and a skillsets dir holding the shipped
  # synoptis.yml, so build reads the real config rather than the rescue fallback.
  def with_built_attestor(anchor_identity:, operator_pubkey: 'ed25519:' + ('ab' * 32))
    Dir.mktmpdir do |dir|
      previous = KairosMcp.data_dir
      begin
        KairosMcp.data_dir = dir
        FileUtils.mkdir_p(File.join(dir, 'skillsets', 'synoptis', 'config'))
        FileUtils.cp(SHIPPED_CONFIG_PATH, File.join(dir, 'skillsets', 'synoptis', 'config'))
        registry = ::Synoptis::Registry::FileRegistry.new(data_dir: File.join(dir, 'proofs'))
        attestor = GCA::SynoptisAttestor.build(
          operator_pubkey: operator_pubkey, registry: registry, anchor_identity: anchor_identity
        )
        yield(attestor, registry, operator_pubkey, dir)
      ensure
        KairosMcp.data_dir = previous
      end
    end
  end

  def test_build_wires_the_anchor_as_attester_and_the_operator_as_submitter
    Dir.mktmpdir do |keydir|
      crypto = ::MMP::Crypto.new(keypair_path: File.join(keydir, 'anchor.pem'), auto_generate: true)
      identity = { agent_id: 'anchor-instance-0001', crypto: crypto }

      with_built_attestor(anchor_identity: identity) do |attestor, registry, operator|
        result = issue(attestor)
        envelope = registry.find_proof(result[:synoptis_proof_id])

        assert_equal 'anchor-instance-0001', envelope.attester_id
        assert_equal operator, envelope.submitter_pubkey
        assert_equal ::Synoptis::ProofEnvelope::PROOF_VERSION_WITH_IDENTITY, envelope.version
        # C-1 is what makes the record the anchor's: it is signed by the anchor's
        # key and verifies against it, without the key being written into the record.
        assert ::Synoptis::Verifier.new(config: { require_signature: true })
                                   .verify(envelope, public_key: crypto.export_public_key)[:valid]
      end
    end
  end

  # Reads require_signature from the shipped synoptis.yml rather than from a
  # value the test chose, so relaxing it in build is caught here.
  def test_build_refuses_when_the_resolved_identity_has_no_signing_key
    with_built_attestor(anchor_identity: { agent_id: 'anchor-instance-0001', crypto: nil }) do |attestor, registry|
      error = assert_raises(GCA::SynoptisAttestor::AttestorError) { issue(attestor) }
      assert_match(/signing key unavailable/, error.message)
      assert_empty registry.list_proofs(filter: {})
    end
  end

  # resolve_anchor_identity is what build falls back on in production, so it is
  # driven here rather than always injected. The identifier is derived from the
  # workspace, which is the property build depends on: two anchors are two
  # attesters.
  def test_resolve_anchor_identity_yields_a_workspace_derived_id_and_a_key
    ids = []
    2.times do
      Dir.mktmpdir do |dir|
        previous = KairosMcp.data_dir
        begin
          KairosMcp.data_dir = dir
          resolved = GCA::SynoptisAttestor.resolve_anchor_identity
          refute_nil resolved[:agent_id], 'anchor identity did not resolve'
          refute_nil resolved[:crypto], 'anchor signing key did not resolve'
          assert_match(/\A[0-9a-f]{16}\z/, resolved[:agent_id])
          ids << resolved[:agent_id]
        ensure
          KairosMcp.data_dir = previous
        end
      end
    end
    refute_equal ids[0], ids[1], 'two different workspaces resolved to the same attester'
  end

  # The previous attester_id was the submitting operator's ed25519 pubkey, which
  # no shipped caller ever presents as revoker_id.
  def test_a_proof_attested_to_an_ed25519_pubkey_cannot_be_revoked_by_the_anchor
    with_context do |registry, engine, crypto|
      pubkey = 'ed25519:' + ('ab' * 32)
      result = issue(attestor(engine: engine, registry: registry, agent_id: pubkey, crypto: crypto))
      manager = ::Synoptis::RevocationManager.new(registry: registry)

      outcome = manager.revoke(proof_id: result[:synoptis_proof_id], reason: 'test',
                               revoker_id: 'anchor-instance-0001', actor_role: 'owner')
      assert_equal 'error', outcome[:status] || outcome['status']
      refute registry.revoked?(result[:synoptis_proof_id])
    end
  end
end
