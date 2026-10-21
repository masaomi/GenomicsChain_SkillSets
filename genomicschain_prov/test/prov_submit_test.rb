# frozen_string_literal: true

# U3 (design v0.1 §9, v0.1.12 §6.1): the Tier-2.5 record on the anchor's side.
#
# Bundles here are written by gc_prov_write's own library from a computation
# whose files exist in a temporary directory, so every checksum in them is the
# checksum of real bytes. The one ZK receipt is real too: the size-factor
# checker's succinct receipt from KairosChain_2026 (fixture zk_sizefactor_s1,
# provenance in its README), bound to the matrix and the claimed size factors
# it was proved for. Tests that need the gc_zk_verify binary skip, naming the
# build command, when it has not been built; the logic of ①–④ is also covered
# with an injected verifier so it never goes untested.
#
# Run: ruby -Ilib -Itest -I../genomicschain_core/lib -I../genomicschain_tier2/lib \
#        -I"$T/synoptis/lib" -I"$T/mmp/lib" test/prov_submit_test.rb
require 'minitest/autorun'
require 'minitest/mock'
require 'tmpdir'
require 'json'
require 'digest'
require 'securerandom'
require 'base64'
require 'fileutils'
require 'ed25519'
require 'kairos_mcp/version'
require 'kairos_mcp/kairos_chain/chain'
require 'kairos_mcp/storage/file_backend'
require 'kairos_mcp/skillset'
require 'kairos_mcp/tools/base_tool'
require 'synoptis/proof_envelope'
require 'synoptis/verifier'
require 'synoptis/attestation_engine'
require 'synoptis/registry/file_registry'

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'genomicschain_core'
require 'genomicschain_prov'
require 'genomicschain_prov/writer/environment'
require 'genomicschain_prov/prov_submit'
require 'genomicschain_prov/place_extension'
require_relative '../tools/gc_prov_submit'
require_relative '../../genomicschain_core/test/idempotency_fixture'

GCoreP = KairosMcp::SkillSets::GenomicschainCore

# Forwards ttl to a real engine, so the lifetime a spec names is the lifetime
# the stored envelope carries.
class ProvStubAttestor
  attr_reader :calls, :registry

  def initialize(registry:)
    @registry = registry
    @calls = []
  end

  def issue(**kw)
    @calls << kw
    engine = ::Synoptis::AttestationEngine.new(
      registry: @registry, config: { 'require_signature' => false, 'default_ttl' => 86_400 }
    )
    r = engine.create_attestation(attester_id: 'ed25519:stub', subject_ref: kw[:subject_ref], claim: kw[:claim],
                                  evidence: kw[:evidence], actor_role: kw[:actor_role], ttl: kw[:ttl],
                                  actor_user_id: 'customer-token-name')
    { status: r[:status], synoptis_proof_id: r[:proof_id] }
  end
end

class ProvRaisingAttestor
  def registry = nil
  def issue(**) = raise(GCoreP::Attestation::SynoptisAttestor::AttestorError, 'attestor down')
end

# The binary's answer, chosen by the test; ①'s sha check stays the real one.
class FakeZkVerifier < GenomicsChainProv::ZkVerifier
  def initialize(answer)
    super(bin: '/nonexistent/gc_zk_verify')
    @answer = answer
  end

  def run(_bytes, _image_id) = @answer
end

class ProvSubmitTest < Minitest::Test
  W = GenomicsChainProv::Writer
  Env = GenomicsChainProv::Writer::Environment
  Identity = GenomicsChainProv::Identity
  Prov = GenomicsChainProv::VerdictSpec::Prov
  ProvSubmit = GenomicsChainProv::ProvSubmit
  ZK = File.expand_path('fixtures/zk_sizefactor_s1', __dir__)
  IMAGE_ID = File.read(File.join(ZK, 'image_id.txt')).strip
  RECEIPT = File.binread(File.join(ZK, 'receipt.succinct.bin'))
  RECEIPT_SHA = Digest::SHA256.hexdigest(RECEIPT)
  INPUT_SHA = '5cb5cfc3a976faa8b8db6a8799ebc3372097833845e38d99e9247c14a86aede3'
  OUTPUT_SHA = '7d8c053239d53b373ae09674c2bd3f1456038c414e54534762ba7592ec9b4515'
  PLATFORM = { 'cpu_architecture' => 'x86_64', 'os_name' => 'Linux', 'os_release' => '6.8.0-1012-aws' }.freeze
  MARKER = 'MARKERq7zQ'

  def setup
    KairosMcp::Manifest::Signer.instance_variable_set(:@global_reservation, nil)
  end

  # --- bundles -------------------------------------------------------------------

  # One stage: the size-factor check over the S1 matrix. The stage's tool and
  # the workflow script are small files here, the runtime is /bin/sh; all get
  # checksums, so the bundle grades immutable unless checksums are skipped.
  def plan(zk: false, platform: PLATFORM, marker: false)
    p = {
      'name' => 'size-factor-check', 'version' => '0.1.0',
      'description' => 'median-of-ratios size factors, checked',
      'script' => 'run.sh',
      'runtime' => { 'engine' => 'sh', 'version' => '5.2.21', 'uri' => '/bin/sh', 'path' => '/bin/sh' },
      'params' => [{ 'param' => 'tolerance', 'value' => '1e-6', 'step' => 1 }],
      'stages' => [
        { 'name' => marker ? "#{MARKER}_stage" : 'sizefactor', 'description' => 'size factors for the matrix',
          'inputs' => ['S1_odd.kmat'], 'outputs' => ['S1_odd__valid_exact.sfq3'],
          'tools' => [{ 'name' => 'checker.sh', 'version' => '0.1.0', 'uri' => 'tools/checker.sh' }] }
      ]
    }
    p['params'] << { 'param' => 'note', 'value' => MARKER, 'step' => 1 } if marker
    p['platform'] = platform if platform
    if zk
      p['zk_receipts'] = [{ 'receipt' => 'receipt.bin', 'image_id' => IMAGE_ID, 'zkvm_version' => '3.0.6',
                            'step_number' => 1, 'input' => 'S1_odd.kmat', 'output' => 'S1_odd__valid_exact.sfq3' }]
    end
    p
  end

  # Writes the computation's files and returns the bundle as JSON text.
  # input: / output: / receipt: replace the fixture bytes (to break ③, ④, ②).
  def bundle(zk: false, checksums: true, platform: PLATFORM, marker: false, input: nil, output: nil, receipt: nil,
             object_id: '00000000-0000-4000-8000-000000000001')
    Dir.mktmpdir('prov_submit') do |dir|
      FileUtils.mkdir_p(File.join(dir, 'tools'))
      File.binwrite(File.join(dir, 'S1_odd.kmat'), input || File.binread(File.join(ZK, 'S1_odd.kmat')))
      File.binwrite(File.join(dir, 'S1_odd__valid_exact.sfq3'),
                    output || File.binread(File.join(ZK, 'S1_odd__valid_exact.sfq3')))
      File.binwrite(File.join(dir, 'receipt.bin'), receipt || RECEIPT)
      File.write(File.join(dir, 'tools', 'checker.sh'), "#!/bin/sh\n# runs the zk checker host\n")
      File.write(File.join(dir, 'run.sh'), "#!/bin/sh\nsh tools/checker.sh\n")
      pl = W.normalise_plan(plan(zk: zk, platform: platform, marker: marker))
      resolved = Env.resolve!(pl, base_dir: dir, checksums: checksums, docker: false)
      decl = Env.zk_declarations(pl['zk_receipts'], base_dir: dir)
      JSON.generate(W.build(pl, checksums: resolved['checksums'], object_id: "urn:uuid:#{object_id}",
                                created: '2026-10-12T00:00:00Z', platform: pl['platform'],
                                zk_receipts: decl['zk_receipts']))
    end
  end

  def receipt_bytes(bytes = RECEIPT)
    { Digest::SHA256.hexdigest(bytes) => Base64.strict_encode64(bytes) }
  end

  def good_zk_answer
    { 'tool' => 'gc_zk_verify', 'version' => '0.1.0', 'risc0_zkvm' => '3.0.6',
      'journal_convention' => 'gc-zk-journal-0.1', 'verified' => true, 'journal_ok' => true,
      'journal_input_sha256' => INPUT_SHA, 'journal_output_sha256' => OUTPUT_SHA }
  end

  def real_verifier
    skip 'gc_zk_verify not built: cargo build --release in genomicschain_prov/zk_verifier' unless GenomicsChainProv::ZkVerifier.available?
    GenomicsChainProv::ZkVerifier.new
  end

  # --- the anchor's context --------------------------------------------------------

  def with_proofs
    Dir.mktmpdir do |tmp|
      registry = ::Synoptis::Registry::FileRegistry.new(data_dir: tmp)
      tip_source = GCoreP::TipSource.new(registry: registry)
      KairosMcp::Manifest::Signer.bootstrap_seen_list!(tip_source: tip_source)
      yield registry, tip_source, tmp
    end
  end

  def signed_operator(tip_source, params, tool: 'gc_prov_submit', sk: Ed25519::SigningKey.generate)
    nonce = SecureRandom.hex(16)
    tip = tip_source.latest_tip_hash
    payload = KairosMcp::Manifest.canonical_json(
      'mcp_tool_name' => tool, 'params' => params, 'nonce' => nonce, 'chain_tip_hash' => tip
    )
    pubkey = 'ed25519:' + Base64.urlsafe_encode64(sk.verify_key.to_bytes, padding: false)
    op = { 'mode' => 'signed', 'pubkey' => pubkey,
           'signature' => { 'algorithm' => 'ed25519', 'signed_fields' => %w[mcp_tool_name params nonce chain_tip_hash],
                            'value' => Base64.urlsafe_encode64(sk.sign(payload), padding: false),
                            'nonce' => nonce, 'chain_tip_hash' => tip } }
    [op, Digest::SHA256.hexdigest(pubkey)]
  end

  def submit(registry, tip_source, b, identity, op, pkhash, attestor, zk_bytes: nil, verifier: nil)
    ProvSubmit.submit(bundle: b, identity: identity, operator: op, bearer_pubkey_hash: pkhash,
                      tip_source: tip_source, attestor: attestor, registry: registry,
                      zk_receipt_bytes: zk_bytes, zk_verifier: verifier)
  end

  def record(registry, b, attestor: nil, zk_bytes: nil, verifier: nil, tip_source: nil)
    tip_source ||= GCoreP::TipSource.new(registry: registry)
    identity = ProvSubmit.signed_params_for(b)
    op, pkhash = signed_operator(tip_source, identity)
    submit(registry, tip_source, b, identity, op, pkhash, attestor || ProvStubAttestor.new(registry: registry),
           zk_bytes: zk_bytes, verifier: verifier)
  end

  def manifests(registry)
    registry.read(:proofs).map { |r| GCoreP::ProofLookup.parse_manifest_from_record(r) }
  end

  # --- ported from tier2_submit_test (11 of 14, design §9) ---------------------------

  def test_happy_path_records_a_prov_proof_with_the_manifest_envelope
    with_proofs do |registry, tip_source|
      b = bundle
      out = record(registry, b, tip_source: tip_source)

      assert_equal 'recorded', out[:status]
      signed = ProvSubmit.signed_params_for(b)
      assert_equal "prov:prov-predicate-0.3.7:immutable:1/1:#{signed['bundle_digest']}:#{out[:submission_key]}",
                   out[:claim]
      m = manifests(registry).first
      assert_equal 'prov_attestation', m['record_type']
      # v0.1.16 S3 (i)–(iii): record 0.5, adapter 0.5.0, writer 0.4.0, one
      # more not_checked item; the signed field set is 0.4's.
      assert_equal '0.5', m['record_version']
      assert_equal "prov:sha256:#{signed['bundle_digest']}", m['subject_ref']
      assert_equal 'immutable', m['grade_overall']
      assert_equal 'self_reported', m['trust_tier']
      assert_equal Identity::NOT_CHECKED, m['not_checked']
      assert_equal 11, m['not_checked'].length
      assert_equal %w[resources_as_written zk_zero_knowledge_property], m['not_checked'].last(2)
      assert_equal 'prov-admission-0.2', m['admission_rule']
      assert_equal 'prov-adapter-bco-0.5.0', m['adapter_version']
      assert_equal 'prov-writer-0.4.0', m['producer_version']
      assert_equal out[:submission_key], m['submission_key']
      assert_equal Identity::SIGNED_FIELDS['0.4'], Identity::SIGNED_FIELDS['0.5']
      assert_equal signed, m.slice(*Identity::SIGNED_FIELDS['0.5'])
      assert_equal 'gc-resources-0.1', m['resources_rule_version']
    end
  end

  def test_identity_that_disagrees_with_the_bundle_is_rejected
    with_proofs do |registry, tip_source|
      b = bundle
      forged = ProvSubmit.signed_params_for(b).merge('inputs_with_checksum' => 7)
      op, pkhash = signed_operator(tip_source, forged)
      err = assert_raises(GCoreP::SubmitCore::IdentityMismatch) do
        submit(registry, tip_source, b, forged, op, pkhash, ProvStubAttestor.new(registry: registry))
      end
      assert_match(/inputs_with_checksum/, err.message)
      refute_match(/7/, err.message, 'the message names fields, not values')
    end
  end

  def test_tampered_bundle_is_a_digest_mismatch
    with_proofs do |registry, tip_source|
      b = bundle
      identity = ProvSubmit.signed_params_for(b)
      op, pkhash = signed_operator(tip_source, identity)
      tampered = JSON.parse(b)
      tampered['usability_domain'] = ['edited after signing']
      assert_raises(GCoreP::SubmitCore::DigestMismatch) do
        submit(registry, tip_source, JSON.generate(tampered), identity, op, pkhash, ProvStubAttestor.new(registry: registry))
      end
    end
  end

  def test_client_supplied_server_fields_are_rejected
    with_proofs do |registry, tip_source|
      b = bundle
      identity = ProvSubmit.signed_params_for(b).merge('trust_tier' => 'peer_verified')
      op, pkhash = signed_operator(tip_source, identity)
      assert_raises(GCoreP::SubmitCore::TrustTierError, GCoreP::SubmitCore::IdentityMismatch) do
        submit(registry, tip_source, b, identity, op, pkhash, ProvStubAttestor.new(registry: registry))
      end
      in_bundle = JSON.generate(JSON.parse(b).merge('not_checked' => []))
      identity2 = ProvSubmit.signed_params_for(in_bundle)
      op2, pk2 = signed_operator(tip_source, identity2)
      assert_raises(GCoreP::SubmitCore::TrustTierError) do
        submit(registry, tip_source, in_bundle, identity2, op2, pk2, ProvStubAttestor.new(registry: registry))
      end
      assert_empty registry.read(:proofs)
    end
  end

  def test_unsigned_mode_rejected
    with_proofs do |registry, tip_source|
      b = bundle
      assert_raises(GCoreP::SubmitCore::UnsignedModeError) do
        submit(registry, tip_source, b, ProvSubmit.signed_params_for(b), { 'mode' => 'anonymous' }, 'x' * 64,
               ProvStubAttestor.new(registry: registry))
      end
    end
  end

  def test_bearer_pubkey_binding_fail_closed
    with_proofs do |registry, tip_source|
      b = bundle
      identity = ProvSubmit.signed_params_for(b)
      op, = signed_operator(tip_source, identity)
      assert_raises(GCoreP::SubmitCore::BearerBindingError) do
        submit(registry, tip_source, b, identity, op, nil, ProvStubAttestor.new(registry: registry))
      end
    end
  end

  def test_zero_writes_to_operational_chain
    with_proofs do |registry, tip_source|
      Dir.mktmpdir do |chain_dir|
        backend = KairosMcp::Storage::FileBackend.new(
          storage_dir: chain_dir, blockchain_file: File.join(chain_dir, 'blockchain.json'),
          action_log_file: File.join(chain_dir, 'action_log.jsonl')
        )
        chain = KairosMcp::KairosChain::Chain.new(chain_file: File.join(chain_dir, 'blockchain.json'),
                                                  storage_backend: backend)
        chain.add_block(['seed'])
        before = chain.chain.length
        record(registry, bundle, tip_source: tip_source)
        assert_equal before, chain.chain.length
      end
    end
  end

  def test_nonce_not_committed_when_synoptis_store_fails
    with_proofs do |registry, tip_source|
      b = bundle
      identity = ProvSubmit.signed_params_for(b)
      op, pkhash = signed_operator(tip_source, identity)
      out = submit(registry, tip_source, b, identity, op, pkhash, ProvRaisingAttestor.new)
      assert_equal 'recording_failed_retryable', out[:status]
      refute KairosMcp::Manifest::Signer.global_reservation.committed?(op.dig('signature', 'nonce'))
      assert_empty registry.read(:proofs)
    end
  end

  def test_recovery_returns_existing_proof_without_second_store
    with_proofs do |registry, tip_source|
      b = bundle
      identity = ProvSubmit.signed_params_for(b)
      op, pkhash = signed_operator(tip_source, identity)
      att = ProvStubAttestor.new(registry: registry)
      first = submit(registry, tip_source, b, identity, op, pkhash, att)
      second = submit(registry, tip_source, b, identity, op, pkhash, att)
      assert_equal first[:synoptis_proof_id], second[:synoptis_proof_id]
      assert_equal true, second[:recovered]
      assert_equal 1, registry.read(:proofs).length
    end
  end

  # §6 / core change 2: the idempotency key is sha256(submission_key), so two
  # bundles from one customer never share it (before 0.6.0 it fell back to a
  # constant per key for this record type).
  def test_idempotency_key_is_per_bundle
    with_proofs do |registry, tip_source|
      out1 = record(registry, bundle, tip_source: tip_source)
      out2 = record(registry, bundle(object_id: '00000000-0000-4000-8000-000000000002'), tip_source: tip_source)
      refute_equal out1[:idempotency_key], out2[:idempotency_key]
      assert_equal Digest::SHA256.hexdigest(out1[:submission_key]), out1[:idempotency_key]
    end
  end

  # Design v0.1.15 (10) (viii): the value itself, on both paths, pinned in
  # core's R0 fixture before core 0.6.2 turns this record type's branch into a
  # list. The bundle probes nothing (no machine, docker: false), so the key
  # does not depend on the host the test runs on.
  #
  # v0.1.16 S3 (i): the same bundle plan now gives another bundle (writer
  # 0.4.0 names itself in it) and another signed identity (adapter 0.5.0), so
  # the submission_key and with it this key move. The R0 fixture is not
  # regenerated (its own rule); what is held instead is the rule core 0.6.2
  # set — the key is sha256(submission_key) on both paths — and the value
  # under v0.1.16, pinned here.
  R0_PROV_KEY = '8f8f78992c199c34513169d8c01a9fb4d433ff0bf596936ab47cfff249f5aa90'
  V0116_PROV_KEY = '5f69a8b32d51041872d1cd15d91a4c7587bd7183bac41f73133429ba03307edf'

  def test_idempotency_key_follows_the_0_6_2_rule_and_is_pinned_for_v0_1_16
    with_proofs do |registry, tip_source|
      b = bundle
      identity = ProvSubmit.signed_params_for(b)
      op, pkhash = signed_operator(tip_source, identity, sk: IdempotencyFixture::SIGNING_KEY)
      att = ProvStubAttestor.new(registry: registry)
      first = submit(registry, tip_source, b, identity, op, pkhash, att)
      second = submit(registry, tip_source, b, identity, op, pkhash, att)
      assert_equal false, first[:recovered]
      assert_equal true, second[:recovered]
      assert_equal R0_PROV_KEY, IdempotencyFixture.expected('prov_attestation')['fresh'], 'the R0 fixture is untouched'
      [first, second].each do |r|
        assert_equal Digest::SHA256.hexdigest(r[:submission_key]), r[:idempotency_key], 'the 0.6.2 rule holds'
        assert_equal V0116_PROV_KEY, r[:idempotency_key]
      end
    end
  end

  # Gate A (§6), rewritten from Tier-2's 64 KB DoS gate: a bundle above 64 KB
  # passes (nf-core/demo alone is 57.6 KB, rnaseq-scale bundles are larger), a
  # bundle above 2 MB is refused before anything else reads it.
  def test_gate_a_refuses_two_megabytes_and_passes_sixty_four_kilobytes
    with_proofs do |registry, tip_source|
      big = JSON.parse(bundle)
      big['usability_domain'] = Array.new(800) { |i| "padding line #{i} " + ('x' * 100) }
      b = JSON.generate(big)
      assert_operator b.bytesize, :>, 64 * 1024
      assert_equal 'recorded', record(registry, b, tip_source: tip_source)[:status]

      huge = JSON.parse(bundle)
      huge['usability_domain'] = ['x' * (2 * 1024 * 1024)]
      h = JSON.generate(huge)
      identity = ProvSubmit.signed_params_for(h)
      op, pkhash = signed_operator(tip_source, identity)
      assert_raises(GCoreP::SubmitCore::EvidenceTooLarge) do
        submit(registry, tip_source, h, identity, op, pkhash, ProvStubAttestor.new(registry: registry))
      end
    end
  end

  # --- U3 additions (§9) ------------------------------------------------------------

  # Core changes 3 and 4 end to end, through the real SynoptisAttestor: a prov
  # proof lives 100 years, a Tier-2 proof keeps the engine's 24 hours.
  def test_prov_proof_lives_a_hundred_years_and_tier2_keeps_the_default
    with_proofs do |registry, tip_source|
      engine = ::Synoptis::AttestationEngine.new(registry: registry,
                                                 config: { 'require_signature' => false, 'default_ttl' => 86_400 })
      attestor = GCoreP::Attestation::SynoptisAttestor.new(engine: engine, attester_id: 'mmp:anchor',
                                                            require_signature: false, registry: registry)
      out = record(registry, bundle, attestor: attestor, tip_source: tip_source)
      assert_equal 3_153_600_000, registry.find_proof(out[:synoptis_proof_id]).ttl

      adj = tier2_adjudication
      identity = GCoreP::Tier2Submit.signed_params_for(adj)
      op, pkhash = signed_operator(tip_source, identity, tool: 'gc_tier2_submit')
      t2 = GCoreP::Tier2Submit.submit(adjudication: adj, identity: identity, operator: op, bearer_pubkey_hash: pkhash,
                                      tip_source: tip_source, attestor: attestor, registry: registry)
      assert_equal 86_400, registry.find_proof(t2[:synoptis_proof_id]).ttl
    end
  end

  def test_a_procedure_version_skew_is_refused_with_the_anchors_three_versions
    with_proofs do |registry, tip_source|
      b = bundle
      identity = ProvSubmit.signed_params_for(b).merge('predicate_version' => 'prov-predicate-0.3.6')
      op, pkhash = signed_operator(tip_source, identity)
      err = assert_raises(Prov::ProcedureVersionMismatch) do
        submit(registry, tip_source, b, identity, op, pkhash, ProvStubAttestor.new(registry: registry))
      end
      assert_match(/predicate_version/, err.message)
      %w[prov-adapter-bco-0.5.0 prov-predicate-0.3.7 pin-strength-0.1.0].each { |v| assert_includes err.message, v }
    end
  end

  # The writer's bundle has no SCM block (a shell computation), so the two
  # repository fields record null rather than refusing the bundle (§6, round 3);
  # its script carries a checksum, which is what takes the workflow to
  # immutable without a commit hash (round 4).
  def test_scm_less_bundle_records_null_repository_and_script_checksum_pins_the_workflow
    with_proofs do |registry, tip_source|
      record(registry, bundle, tip_source: tip_source)
      m = manifests(registry).first
      assert_nil m['workflow_repository_sha256']
      assert_nil m['workflow_commit']
      assert_equal 'immutable', m['grade_workflow']
      assert_equal 1, m['scripts_total']
      assert_equal 1, m['scripts_with_checksum']
    end
  end

  # gc_prov_proof (§7): the envelope with exactly the listed fields, the
  # parsed manifest and `revoked`; 404 JSON for an unknown id and for a
  # Tier-2 record in the same registry; never the customer's token name.
  def test_the_public_route_serves_prov_records_only_with_the_listed_fields
    with_proofs do |registry, tip_source|
      out = record(registry, bundle, tip_source: tip_source)
      adj = tier2_adjudication
      identity = GCoreP::Tier2Submit.signed_params_for(adj)
      op, pkhash = signed_operator(tip_source, identity, tool: 'gc_tier2_submit')
      t2 = GCoreP::Tier2Submit.submit(adjudication: adj, identity: identity, operator: op, bearer_pubkey_hash: pkhash,
                                      tip_source: tip_source, attestor: ProvStubAttestor.new(registry: registry),
                                      registry: registry)

      ext = GenomicsChainProv::PlaceExtension.new(nil, registry: registry)
      assert_equal ['/place/web/prov'], ext.public_route_prefixes
      status, headers, body = ext.public_call(get("/place/web/prov/proof/#{out[:synoptis_proof_id]}"))
      assert_equal 200, status
      assert_equal 'application/json', headers['Content-Type']
      json = JSON.parse(body.join)
      expected = %w[proof_id version attester_id subject_ref claim evidence merkle_root timestamp ttl
                    submitter_pubkey signature manifest revoked]
      assert_equal expected.sort, json.keys.sort
      assert_equal 'prov_attestation', json.dig('manifest', 'record_type')
      assert_equal false, json['revoked']
      refute_includes body.join, 'customer-token-name', 'actor_user_id never leaves the anchor'

      [t2[:synoptis_proof_id], SecureRandom.uuid].each do |id|
        s, h, b = ext.public_call(get("/place/web/prov/proof/#{id}"))
        assert_equal 404, s
        assert_equal 'application/json', h['Content-Type']
        assert_equal({ 'error' => 'not_found' }, JSON.parse(b.join))
      end
      assert_nil ext.public_call(get("/place/web/prov/proof/#{out[:synoptis_proof_id]}", 'POST'))
    end
  end

  # --- v0.1.12 §6.1, v0.1.13 --------------------------------------------------------

  # v0.1.13 withdrew the immutable gate (it was GradeBelowRequirement under
  # prov-admission-0.1): a bundle below immutable is recorded, and the record
  # carries the grade it computed — the signed grade is what a reader judges.
  def test_a_bundle_below_immutable_is_recorded_with_its_grade
    with_proofs do |registry, tip_source|
      b = bundle(checksums: false, marker: true)
      out = record(registry, b, tip_source: tip_source)

      assert_equal 'recorded', out[:status]
      signed = ProvSubmit.signed_params_for(b)
      assert_equal "prov:prov-predicate-0.3.7:local_path:1/1:#{signed['bundle_digest']}:#{out[:submission_key]}",
                   out[:claim]
      m = manifests(registry).first
      assert_equal 'local_path', m['grade_overall']
      assert_equal 'local_path', m['grade_inputs']
      assert_equal 'prov-admission-0.2', m['admission_rule']
      assert_equal signed, m.slice(*Identity::SIGNED_FIELDS['0.4'])
      stored = JSON.generate(registry.read(:proofs))
      refute_includes stored, MARKER, 'the record carries grades and counts, never bundle values'
      refute_includes stored, 'S1_odd'
    end
  end

  # v0.1.14 §6.2 (3): a record with every resource field filled passes the
  # 0.4 schema and carries only GPU vendors and models — the machine's other
  # values and every stage value stay in the bundle. A model shaped like a
  # serial is left out and still counted.
  def test_a_bundle_with_resources_is_recorded_with_the_nine_fields_only
    with_proofs do |registry, tip_source|
      bco = JSON.parse(bundle)
      machine = { 'source' => 'probe', 'cpu_model' => 'AMD EPYC 7763 64-Core Processor', 'logical_cores' => 64,
                  'memory_total_bytes' => 549_755_813_888, 'disk_free_bytes' => 1,
                  'gpu_probe' => [{ 'tool' => 'nvidia-smi', 'result' => 'ok' }],
                  'gpus' => [{ 'vendor' => 'nvidia', 'model' => 'NVIDIA H100 80GB HBM3' }] * 2 +
                            [{ 'vendor' => 'nvidia', 'model' => 'SN-Z9Y8X7W6V5U4' }] }
      steps = [{ 'step_number' => 1, 'source' => 'nextflow_trace',
                 'requested' => { 'cpus' => 4, 'memory_bytes' => 8 * 1024**3 },
                 'observed' => { 'peak_memory_bytes' => 5 * 1024**3, 'realtime_seconds' => 41.5,
                                 'cpu_model' => 'AMD EPYC 7763 64-Core Processor' } }]
      bco['extension_domain'].first['genomicschain_extension']['resources'] = { 'machine' => machine, 'steps' => steps }
      b = JSON.generate(bco)
      out = record(registry, b, tip_source: tip_source)

      assert_equal 'recorded', out[:status]
      m = manifests(registry).first
      assert_equal 'full', m['grade_resources']
      assert_equal 3, m['gpus_total']
      assert_equal [{ 'vendor' => 'nvidia', 'model' => 'NVIDIA H100 80GB HBM3', 'count' => 2 }], m['gpu_models']
      assert_equal %w[nvidia], m['gpu_vendors_probed']
      assert_equal %w[nextflow_trace], m['resources_sources']
      stored = JSON.generate(registry.read(:proofs))
      ['SN-Z9Y8X7W6V5U4', 'EPYC', '549755813888', '41.5'].each { |v| refute_includes stored, v }
    end
  end

  def test_platform_is_recorded_when_stated_and_null_when_not
    with_proofs do |registry, tip_source|
      record(registry, bundle, tip_source: tip_source)
      record(registry, bundle(platform: nil, object_id: '00000000-0000-4000-8000-000000000003'), tip_source: tip_source)
      with, without = manifests(registry)
      assert_equal 'x86_64', with['platform_cpu_architecture']
      assert_equal 'Linux', with['platform_os_name']
      assert_equal '6.8.0-1012-aws', with['platform_os_release']
      %w[platform_cpu_architecture platform_os_name platform_os_release].each { |k| assert_nil without[k], k }
      assert without.key?('platform_cpu_architecture'), 'null is a signed value, not an absent key'
    end
  end

  # Optional really is optional: no receipt, no verifier needed, the new
  # fields are present and empty.
  def test_a_bundle_without_receipts_records_empty_zk_fields_without_a_verifier
    with_proofs do |registry, tip_source|
      out = record(registry, bundle, tip_source: tip_source,
                                     verifier: GenomicsChainProv::ZkVerifier.new(bin: '/nonexistent'))
      assert_equal 'recorded', out[:status]
      m = manifests(registry).first
      assert_equal [], m['zk_receipts']
      assert_nil m['zk_verification']
      assert m.key?('zk_verification')
    end
  end

  def test_a_real_receipt_passes_all_four_checks_and_only_its_identity_is_recorded
    verifier = real_verifier
    with_proofs do |registry, tip_source, dir|
      b = bundle(zk: true)
      out = record(registry, b, tip_source: tip_source, zk_bytes: receipt_bytes, verifier: verifier)
      assert_equal 'recorded', out[:status]
      m = manifests(registry).first
      assert_equal [{ 'receipt_sha256' => RECEIPT_SHA, 'image_id' => IMAGE_ID, 'zkvm_name' => 'risc0-zkvm',
                      'zkvm_version' => '3.0.6', 'stage' => 1, 'journal_convention' => 'gc-zk-journal-0.1' }],
                   m['zk_receipts']
      # S3 (ii): the binary is 0.2.0; called without --journal, it is 0.1 as before
      assert_equal({ 'verifier' => 'gc_zk_verify-0.2.0', 'risc0_zkvm' => '3.0.6',
                     'journal_convention' => 'gc-zk-journal-0.1', 'receipts_verified' => 1 }, m['zk_verification'])
      stored = Dir[File.join(dir, '**', '*')].select { |f| File.file?(f) }.map { |f| File.binread(f) }.join
      refute_includes stored, Base64.strict_encode64(RECEIPT)[0, 64], 'receipt bytes are never stored'
      refute_includes stored, INPUT_SHA, 'the input digest the journal binds stays in the bundle'
    end
  end

  # ① the bytes are not the declared receipt
  def test_bytes_that_are_not_the_declared_receipt_are_rejected
    with_proofs do |registry, tip_source|
      other = RECEIPT.dup
      other.setbyte(5000, other.getbyte(5000) ^ 1)
      err = assert_raises(Prov::ZkReceiptRejected) do
        record(registry, bundle(zk: true), tip_source: tip_source,
                                           zk_bytes: { RECEIPT_SHA => Base64.strict_encode64(other) },
                                           verifier: FakeZkVerifier.new(good_zk_answer))
      end
      assert_match(/receipt_sha256_mismatch/, err.message)
      assert_empty registry.read(:proofs)
    end
  end

  # ② a receipt that does not verify (one byte changed, declared as changed)
  def test_a_receipt_that_does_not_verify_is_rejected
    verifier = real_verifier
    with_proofs do |registry, tip_source|
      bad = RECEIPT.dup
      bad.setbyte(5000, bad.getbyte(5000) ^ 1)
      err = assert_raises(Prov::ZkReceiptRejected) do
        record(registry, bundle(zk: true, receipt: bad), tip_source: tip_source, zk_bytes: receipt_bytes(bad),
                                                         verifier: verifier)
      end
      assert_match(/receipt_not_verified/, err.message)
    end
  end

  # ③ the journal's input is not the step's recorded input
  def test_a_journal_input_that_is_not_the_recorded_input_is_rejected
    verifier = real_verifier
    with_proofs do |registry, tip_source|
      err = assert_raises(Prov::ZkReceiptRejected) do
        record(registry, bundle(zk: true, input: "a different matrix\n"), tip_source: tip_source,
                                                                          zk_bytes: receipt_bytes, verifier: verifier)
      end
      assert_match(/journal_input_mismatch/, err.message)
    end
  end

  # ④ the journal's output is not the step's recorded output
  def test_a_journal_output_that_is_not_the_recorded_output_is_rejected
    verifier = real_verifier
    with_proofs do |registry, tip_source|
      err = assert_raises(Prov::ZkReceiptRejected) do
        record(registry, bundle(zk: true, output: "1.0\n1.0\n"), tip_source: tip_source,
                                                                 zk_bytes: receipt_bytes, verifier: verifier)
      end
      assert_match(/journal_output_mismatch/, err.message)
    end
  end

  # ②–④ with an injected answer, so the decision logic is tested even where
  # the binary is not built.
  def test_the_four_checks_decide_on_the_verifiers_answer
    with_proofs do |registry, tip_source|
      { { 'verified' => false } => 'receipt_not_verified',
        { 'journal_ok' => false } => 'journal_not_convention',
        { 'journal_input_sha256' => '0' * 64 } => 'journal_input_mismatch',
        { 'journal_output_sha256' => '0' * 64 } => 'journal_output_mismatch' }.each do |change, code|
        err = assert_raises(Prov::ZkReceiptRejected) do
          record(registry, bundle(zk: true), tip_source: tip_source, zk_bytes: receipt_bytes,
                                             verifier: FakeZkVerifier.new(good_zk_answer.merge(change)))
        end
        assert_match(/#{code}/, err.message)
      end
      out = record(registry, bundle(zk: true), tip_source: tip_source, zk_bytes: receipt_bytes,
                                               verifier: FakeZkVerifier.new(good_zk_answer))
      assert_equal 'recorded', out[:status]
    end
  end

  def test_missing_or_undeclared_receipt_bytes_are_rejected
    with_proofs do |registry, tip_source|
      fake = FakeZkVerifier.new(good_zk_answer)
      err = assert_raises(Prov::ZkReceiptRejected) do
        record(registry, bundle(zk: true), tip_source: tip_source, zk_bytes: {}, verifier: fake)
      end
      assert_match(/receipt_bytes_missing/, err.message)

      extra = receipt_bytes.merge(Digest::SHA256.hexdigest('x') => Base64.strict_encode64('x'))
      err = assert_raises(Prov::ZkReceiptRejected) do
        record(registry, bundle(zk: true), tip_source: tip_source, zk_bytes: extra, verifier: fake)
      end
      assert_match(/does not declare/, err.message)

      err = assert_raises(Prov::ZkReceiptRejected) do
        record(registry, bundle, tip_source: tip_source, zk_bytes: receipt_bytes, verifier: fake)
      end
      assert_match(/declares no receipt/, err.message)
      assert_empty registry.read(:proofs)
    end
  end

  def test_without_a_verifier_only_bundles_with_receipts_are_refused
    with_proofs do |registry, tip_source|
      none = GenomicsChainProv::ZkVerifier.new(bin: '/nonexistent/gc_zk_verify')
      assert_raises(Prov::ZkVerifierUnavailable) do
        record(registry, bundle(zk: true), tip_source: tip_source, zk_bytes: receipt_bytes, verifier: none)
      end
      assert_equal 'recorded', record(registry, bundle, tip_source: tip_source, verifier: none)[:status]
    end
  end

  def test_a_defective_declaration_is_refused_before_any_bytes_are_read
    with_proofs do |registry, tip_source|
      bad = JSON.parse(bundle(zk: true))
      ext = bad['extension_domain'].first['genomicschain_extension']
      ext['zk_receipts'].first['output_uri'] = 'not_an_output_of_the_step.txt'
      err = assert_raises(Prov::ZkDeclarationInvalid) do
        record(registry, JSON.generate(bad), tip_source: tip_source, zk_bytes: receipt_bytes,
                                             verifier: FakeZkVerifier.new(good_zk_answer))
      end
      assert_match(/output_not_in_step/, err.message)
      refute_includes err.message, 'not_an_output_of_the_step'
    end
  end

  def test_the_extension_schema_defines_platform_and_zk_receipts
    path = File.expand_path('../../genomicschain_core/schemas/bco_extension_genomicschain_v0_1.json', __dir__)
    schema = JSON.parse(File.read(path))
    assert_equal W::EXTENSION_SCHEMA, schema['$id']
    assert_equal %w[cpu_architecture os_name os_release], schema.dig('properties', 'platform', 'properties').keys
    zk = schema.dig('properties', 'zk_receipts', 'items')
    assert_equal %w[sha256 image_id zkvm step_number journal input_uri output_uri].sort, zk['required'].sort
    written = JSON.parse(bundle(zk: true))['extension_domain'].first['genomicschain_extension']
    assert_equal (schema['properties'].keys & written.keys).sort, written.keys.sort,
                 'the writer writes no key the schema does not define'
    assert_equal zk['required'].sort, written['zk_receipts'].first.keys.sort
  end

  # implementation review r1: the writer produced resources the published
  # extension schema rejects. Everything a plan can put there now validates.
  def test_the_resources_the_writer_writes_validate_against_the_extension_schema
    begin
      require 'json_schemer'
    rescue LoadError
      skip 'json_schemer not installed'
    end
    path = File.expand_path('../../genomicschain_core/schemas/bco_extension_genomicschain_v0_1.json', __dir__)
    schemer = JSONSchemer.schema(JSON.parse(File.read(path)))
    plan = W.normalise_plan(
      'name' => 'x', 'stages' => [{ 'name' => 'a', 'resources' => { 'requested' => { 'cpus' => 2, 'memory_bytes' => 10 } } }],
      'machine' => { 'cpu_model' => 'AMD EPYC', 'logical_cores' => 8, 'memory_total_bytes' => 1,
                     'gpus' => [{ 'vendor' => 'NVIDIA', 'model' => 'NVIDIA H100', 'count' => 2,
                                  'runtime' => { 'name' => 'CUDA', 'version' => '12.2' } }] }
    )
    steps = W.plan_resource_steps(plan) +
            [{ 'step_number' => 1, 'source' => 'gc_resources_input', 'measured_by' => 't',
               'observed' => { 'peak_memory_bytes' => 5, 'realtime_seconds' => 1.5, 'cpu_model' => 'AMD EPYC' } }]
    ext = W.build(plan, resources: W.resources_block(machine: plan['machine'], steps: steps))['extension_domain']
           .first['genomicschain_extension']
    assert_empty schemer.validate(ext).map { |e| e['error'] }
    probed = { 'source' => 'probe', 'cpu_model' => 'x', 'gpu_probe' => [{ 'tool' => 'nvidia-smi', 'result' => 'timeout' }] }
    assert schemer.valid?(ext.merge('resources' => { 'machine' => probed }))
  end

  # §6: neither the bundle nor the predicate's per-item output reaches the
  # anchor's logs, its response or its registry — exercised through the MCP
  # tool on both outcomes, recorded and refused.
  def test_bundle_values_never_reach_the_response_the_logs_or_the_registry
    with_tool do |tool, registry, tip_source, dir|
      b = bundle(marker: true)
      identity = ProvSubmit.signed_params_for(b)
      op, = signed_operator(tip_source, identity)
      out, err = capture_io do
        @response = tool.call('bundle' => b, 'identity' => identity, 'operator' => op)
      end
      text = @response.first[:text]
      assert_match(/"status": "recorded"/, text)
      stored = Dir[File.join(dir, '**', '*')].select { |f| File.file?(f) }.map { |f| File.read(f) }.join
      [text, out, err, stored].each { |s| refute_includes s, MARKER }

      low = bundle(marker: true, checksums: false)
      li = ProvSubmit.signed_params_for(low)
      lop, = signed_operator(tip_source, li)
      out, err = capture_io { @response = tool.call('bundle' => low, 'identity' => li, 'operator' => lop) }
      assert_match(/"status": "recorded"/, @response.first[:text])
      [@response.first[:text], out, err].each { |s| refute_includes s, MARKER }

      # refused: the signed identity claims a grade the bundle does not yield
      forged = li.merge('grade_overall' => 'immutable')
      fop, = signed_operator(tip_source, forged)
      out, err = capture_io { @response = tool.call('bundle' => low, 'identity' => forged, 'operator' => fop) }
      assert_match(/IdentityMismatch|does not match/, @response.first[:text])
      [@response.first[:text], out, err].each { |s| refute_includes s, MARKER }
      stored = Dir[File.join(dir, '**', '*')].select { |f| File.file?(f) }.map { |f| File.read(f) }.join
      refute_includes stored, MARKER
      assert_equal 2, registry.read(:proofs).length
    end
  end

  def test_dry_run_reports_admission_and_the_params_to_sign
    with_tool do |tool, _registry, tip_source|
      b = bundle
      op, = signed_operator(tip_source, {})
      res = JSON.parse(tool.call('bundle' => b, 'operator' => op, 'dry_run' => true).first[:text])
      assert_equal 'dry_run', res['status']
      assert_equal ProvSubmit.signed_params_for(b), res['signed_params']
      assert_equal true, res.dig('checks', 'admission', 'issuable')
      assert_equal 'ok', res.dig('checks', 'gates')

      # no grade gate (v0.1.13): a local_path bundle is issuable and says its grade
      low = JSON.parse(tool.call('bundle' => bundle(checksums: false), 'operator' => op, 'dry_run' => true).first[:text])
      assert_equal true, low.dig('checks', 'admission', 'issuable')
      assert_equal 'local_path', low.dig('checks', 'admission', 'grade_overall')
      refute low['checks']['admission'].key?('below')
      assert_equal 'ok', low.dig('checks', 'gates')
    end
  end

  # Core change 1 (§7): anchor-only tools are read from ANY SkillSet's
  # skillset.json — prov's own, here — and appear only on an anchor-profile
  # node. Before 0.6.0 only genomicschain_core's list was read, so prov's
  # gc_prov_submit would never have registered.
  def test_core_registers_anchor_tools_listed_by_prov_on_the_anchor_only
    prov = KairosMcp::Skillset.new(File.expand_path('..', __dir__))
    submit = 'KairosMcp::SkillSets::GenomicschainProv::Tools::GcProvSubmit'
    with_tool do
      assert_includes prov.tool_class_names, submit
      File.write(File.join(KairosMcp.skillsets_dir, 'genomicschain_core', 'config', 'genomicschain_core.yml'),
                 "genomicschain:\n  anchor_profile: false\n")
      refute_includes prov.tool_class_names, submit
    end
    tier2 = KairosMcp::Skillset.new(File.expand_path('../../genomicschain_tier2', __dir__))
    assert_equal JSON.parse(File.read(File.join(tier2.path, 'skillset.json')))['tool_classes'], tier2.tool_class_names,
                 'a SkillSet without the key is untouched'
  end

  def test_the_tool_returns_the_anchors_versions_on_a_version_skew
    with_tool do |tool, _registry, tip_source|
      b = bundle
      identity = ProvSubmit.signed_params_for(b).merge('adapter_version' => 'prov-adapter-bco-0.3.7')
      op, = signed_operator(tip_source, identity)
      res = JSON.parse(tool.call('bundle' => b, 'identity' => identity, 'operator' => op).first[:text])
      assert_equal 'ProcedureVersionMismatch', res['error']
      assert_equal({ 'adapter' => 'prov-adapter-bco-0.5.0', 'predicate' => 'prov-predicate-0.3.7',
                     'pin_strength' => 'pin-strength-0.1.0', 'resources_rule' => 'gc-resources-0.1' }, res['versions'])
    end
  end

  # v0.1.14 §6.2 (5): a client older than prov 0.4.0 signs the 0.3 identity,
  # which has no resources_rule_version. It is told what the anchor runs and
  # nothing is recorded — the same path as any other version skew.
  def test_a_record_version_0_3_identity_is_refused_with_the_anchors_versions
    with_tool do |tool, registry, tip_source|
      b = bundle
      identity = ProvSubmit.signed_params_for(b).slice(*Identity::SIGNED_FIELDS['0.3'])
      op, = signed_operator(tip_source, identity)
      res = JSON.parse(tool.call('bundle' => b, 'identity' => identity, 'operator' => op).first[:text])
      assert_equal 'ProcedureVersionMismatch', res['error']
      assert_includes res['message'], 'resources_rule_version'
      assert_includes res['message'], 'record_version 0.5'
      assert_equal 'gc-resources-0.1', res.dig('versions', 'resources_rule')
      assert_empty registry.read(:proofs)
    end
  end

  private

  def get(path, method = 'GET')
    { 'REQUEST_METHOD' => method, 'PATH_INFO' => path }
  end

  FakeSafety = Struct.new(:current_user)

  # The MCP tool on an anchor-profile instance in a temporary data dir, with
  # the attestor swapped for the stub (the real one needs the anchor's MMP key).
  def with_tool
    previous = KairosMcp.instance_variable_get(:@data_dir) # not the reader: it resolves (and may create) a dir
    Dir.mktmpdir('prov_tool') do |dir|
      KairosMcp.data_dir = dir
      cfg = File.join(KairosMcp.skillsets_dir, 'genomicschain_core', 'config')
      FileUtils.mkdir_p(cfg)
      File.write(File.join(cfg, 'genomicschain_core.yml'), "genomicschain:\n  anchor_profile: true\n")
      registry = ::Synoptis::Registry::FileRegistry.new(data_dir: File.join(dir, 'synoptis_data'))
      tip_source = GCoreP::TipSource.new(registry: registry)
      sk_holder = {}
      tool = nil
      stub = ProvStubAttestor.new(registry: registry)
      GCoreP::Attestation::SynoptisAttestor.stub(:build, ->(**kw) { sk_holder[:pk] = kw[:operator_pubkey]; stub }) do
        # The Bearer is bound to whichever key signs: the safety reads it lazily.
        safety = Object.new
        safety.define_singleton_method(:current_user) do
          { user: 'customer-token-name', pubkey_hash: sk_holder[:bearer] }
        end
        tool = KairosMcp::SkillSets::GenomicschainProv::Tools::GcProvSubmit.new(safety)
        bearer_tool = BearerFollowingTool.new(tool, sk_holder)
        yield bearer_tool, registry, tip_source, dir
      end
    end
  ensure
    KairosMcp.instance_variable_set(:@data_dir, previous)
    KairosMcp.instance_variable_set(:@path_cache, {})
  end

  # Sets the Bearer's pubkey hash to the operator's own key before each call,
  # as gc_issue_bound_token does once per customer on a real anchor.
  class BearerFollowingTool
    def initialize(tool, holder)
      @tool = tool
      @holder = holder
    end

    def call(args)
      pk = args.dig('operator', 'pubkey')
      @holder[:bearer] = pk && Digest::SHA256.hexdigest(pk)
      @tool.call(args)
    end
  end

  # The Tier-2 adjudication shape (reduced) from tier2_submit_test, for the
  # two tests that need a non-prov proof beside a prov one.
  def tier2_adjudication
    {
      'adjudication_rubric_version' => 'codescan-adjudication-0.1.0',
      'subject' => {
        'canonical_id' => '10.1101/2024.06.17.598857', 'tier1_rubric_version' => '0.2.5',
        'tier1_report_content_hash' => 'b' * 64, 'codescan_evidence_digest' => 'a' * 64,
        'codescan_toolchain' => { 'ruby' => '3.4.10', 'codescan_rubric_version' => 'codescan-static-0.1.0' }
      },
      'stage_transition' => { 'from' => 'stage1-prose-only', 'to' => 'stage2-code-verified', 'applied' => false },
      'levers' => { 'code_derived' => { 'in_code_db_pin_classA' => false },
                    'lever1_environment_lock' => { 'declared_lock' => { 'value' => true },
                                                   'byte_fixed_lock' => { 'value' => false }, 'headline' => 'h' } },
      'counts' => { 'tier1_steps' => 8, 'steps_linked' => 4, 'proposed_demotions' => 0 }
    }
  end
end
