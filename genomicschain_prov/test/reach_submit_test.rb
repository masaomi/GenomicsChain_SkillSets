# frozen_string_literal: true

# v0.1.15 R3 (design §6.3 (3), (6), (7)): the reachability observation
# through SubmitCore, over a prov record made the way the anchor makes them.
# The registry, the engine and SubmitCore are real; the prober is replaced so
# that nothing leaves the machine and every question asked is counted.
#
# Run: ruby -Ilib -Itest -I../genomicschain_core/lib -I../genomicschain_tier2/lib \
#        -I"$T/synoptis/lib" -I"$T/mmp/lib" test/reach_submit_test.rb
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
require 'kairos_mcp/skillset'
require 'kairos_mcp/tools/base_tool'
require 'synoptis/proof_envelope'
require 'synoptis/verifier'
require 'synoptis/attestation_engine'
require 'synoptis/registry/file_registry'

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'genomicschain_core'
require 'genomicschain_prov'
require 'genomicschain_prov/prov_submit'
require 'genomicschain_prov/reach_submit'
require 'genomicschain_prov/place_extension'
require 'genomicschain_prov/reach_verifier'
require 'open3'
require 'rbconfig'

GCoreR = KairosMcp::SkillSets::GenomicschainCore

class ReachStubAttestor
  attr_reader :registry, :calls

  def initialize(registry:)
    @registry = registry
    @calls = []
  end

  def issue(**kw)
    @calls << kw
    engine = ::Synoptis::AttestationEngine.new(registry: @registry,
                                               config: { 'require_signature' => false, 'default_ttl' => 86_400 })
    r = engine.create_attestation(attester_id: 'ed25519:stub', subject_ref: kw[:subject_ref], claim: kw[:claim],
                                  evidence: kw[:evidence], actor_role: kw[:actor_role], ttl: kw[:ttl])
    { status: r[:status], synoptis_proof_id: r[:proof_id] }
  end
end

class ReachSubmitTest < Minitest::Test
  R = GenomicsChainProv::Reach
  Spec = GenomicsChainProv::VerdictSpec::Reach
  BUNDLE = File.read(File.expand_path('fixtures/nfcore_demo_1_2_0/bco.json', __dir__))

  # Reads locators with the real Reference; answers "exists" to everything
  # and counts what it was asked.
  class CountingProber
    attr_reader :asked

    def initialize = (@asked = [])
    def target(cat, loc) = R::Reference.host(R::Reference.read(cat, loc))

    def ask(cat, loc, _host, seconds:)
      @asked << [cat, loc, seconds]
      'exists'
    end
  end

  def setup
    KairosMcp::Manifest::Signer.instance_variable_set(:@global_reservation, nil)
    @prober = CountingProber.new
  end

  def with_proofs
    Dir.mktmpdir do |tmp|
      registry = ::Synoptis::Registry::FileRegistry.new(data_dir: tmp)
      tip_source = GCoreR::TipSource.new(registry: registry)
      KairosMcp::Manifest::Signer.bootstrap_seen_list!(tip_source: tip_source)
      yield registry, tip_source
    end
  end

  def key = Ed25519::SigningKey.generate
  def pubkey(sk) = 'ed25519:' + Base64.urlsafe_encode64(sk.verify_key.to_bytes, padding: false)

  def operator(sk, tool, params, tip_source, nonce: SecureRandom.hex(16), mode: 'signed')
    tip = tip_source.latest_tip_hash
    payload = KairosMcp::Manifest.canonical_json('mcp_tool_name' => tool, 'params' => params, 'nonce' => nonce,
                                                 'chain_tip_hash' => tip)
    { 'mode' => mode, 'pubkey' => pubkey(sk),
      'signature' => { 'algorithm' => 'ed25519', 'signed_fields' => %w[mcp_tool_name params nonce chain_tip_hash],
                       'value' => Base64.urlsafe_encode64(sk.sign(payload), padding: false),
                       'nonce' => nonce, 'chain_tip_hash' => tip } }
  end

  # The bundle's prov record, as gc_prov_submit makes it.
  def prov_record(registry, tip_source, sk)
    identity = GenomicsChainProv::ProvSubmit.signed_params_for(BUNDLE)
    out = GenomicsChainProv::ProvSubmit.submit(
      bundle: BUNDLE, identity: identity, operator: operator(sk, 'gc_prov_submit', identity, tip_source),
      bearer_pubkey_hash: Digest::SHA256.hexdigest(pubkey(sk)), tip_source: tip_source,
      attestor: ReachStubAttestor.new(registry: registry), registry: registry
    )
    assert_equal 'recorded', out[:status]
    out[:synoptis_proof_id]
  end

  def reach(registry, tip_source, sk, prov_id, identity: nil, op: nil, bearer: nil, admission: R::Admission.new,
            bundle: BUNDLE)
    identity ||= Spec.signed_params_for(bundle, prov_id, SecureRandom.hex(32))
    op ||= operator(sk, 'gc_prov_reach', identity, tip_source)
    GenomicsChainProv::ReachSubmit.submit(
      bundle: bundle, identity: identity, prov_proof_id: prov_id, operator: op,
      bearer_pubkey_hash: bearer || Digest::SHA256.hexdigest(pubkey(sk)), tip_source: tip_source,
      attestor: ReachStubAttestor.new(registry: registry), registry: registry, prober: @prober, admission: admission
    )
  end

  def manifest(registry, proof_id)
    GCoreR::ProofLookup.parse_evidence(registry.find_proof(proof_id).evidence)['manifest']
  end

  # gc_prov_reach on an anchor-profile instance in a temporary data dir: the
  # attestor is the stub (the real one needs the anchor's MMP key) and the
  # prober is the counting one; the Bearer follows whichever key signs.
  GATE_YAML = "    own_names: [anchor.example.org]\n    own_addresses: ['203.0.113.7']\n    denylist: ['198.51.100.0/24']\n"

  def with_tool(gate_yaml: GATE_YAML)
    require 'minitest/mock'
    require 'fileutils'
    require_relative '../tools/gc_prov_reach'
    previous = KairosMcp.instance_variable_get(:@data_dir)
    Dir.mktmpdir('reach_tool') do |dir|
      KairosMcp.data_dir = dir
      cfg = File.join(KairosMcp.skillsets_dir, 'genomicschain_core', 'config')
      FileUtils.mkdir_p(cfg)
      File.write(File.join(cfg, 'genomicschain_core.yml'), "genomicschain:\n  anchor_profile: true\n  reach:\n#{gate_yaml}")
      registry = ::Synoptis::Registry::FileRegistry.new(data_dir: File.join(dir, 'synoptis_data'))
      tip_source = GCoreR::TipSource.new(registry: registry)
      KairosMcp::Manifest::Signer.bootstrap_seen_list!(tip_source: tip_source)
      holder = {}
      gate = {}
      stub = ReachStubAttestor.new(registry: registry)
      prober = @prober
      new_prober = lambda do |gate: {}, **|
        holder[:gate] = gate
        prober
      end
      GCoreR::Attestation::SynoptisAttestor.stub(:build, ->(**) { stub }) do
        R::Prober.stub(:new, new_prober) do
          safety = Object.new
          safety.define_singleton_method(:current_user) { { user: 'customer', pubkey_hash: holder[:bearer] } }
          tool = KairosMcp::SkillSets::GenomicschainProv::Tools::GcProvReach.new(safety)
          caller = Object.new
          caller.define_singleton_method(:call) do |args|
            pk = args.dig('operator', 'pubkey')
            holder[:bearer] = pk && Digest::SHA256.hexdigest(pk)
            out = tool.call(args)
            gate.replace(holder[:gate] || {})
            out
          end
          yield caller, registry, tip_source, gate
        end
      end
    end
  ensure
    KairosMcp.instance_variable_set(:@data_dir, previous)
    KairosMcp.instance_variable_set(:@path_cache, {})
  end

  # --- the record ------------------------------------------------------------------

  def test_an_observation_is_recorded_over_the_prov_record
    with_proofs do |registry, tip_source|
      sk = key
      prov_id = prov_record(registry, tip_source, sk)
      out = reach(registry, tip_source, sk, prov_id)
      assert_equal 'recorded', out[:status]
      m = manifest(registry, out[:synoptis_proof_id])
      digest = GenomicsChainProv::Identity.bundle_digest(BUNDLE)
      assert_equal %w[prov_reachability 0.1 gc_prov_reach], m.values_at('record_type', 'record_version', 'mcp_tool_name')
      assert_equal "prov-reach:sha256:#{digest}", m['subject_ref']
      assert_equal Digest::SHA256.hexdigest(prov_id), m['prov_proof_ref']
      assert_equal %w[anchor environment gc-reachability-0.1], m.values_at('observer', 'scope', 'reachability_rule')
      assert_equal true, m['same_signer']
      assert_equal Spec::NOT_CHECKED, m['not_checked']
      assert_equal 'gc-backing-0.1', m.dig('backing', 'vocabulary')
      assert_equal 'anchor_observed', m.dig('backing', 'counts')
      assert_match(/\A\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ\z/, m['observed_at'])
      assert_equal({ 'items' => 1, 'distinct' => 1, 'digest_match' => { 'public_registry' => 0, 'other_host' => 0 },
                     'exists' => { 'public_registry' => 1, 'other_host' => 0 }, 'access_denied' => 0, 'not_found' => 0,
                     'error' => 0, 'not_attempted' => 0, 'not_checkable' => 0 }, m.dig('counts', 'workflow_repository'))
      assert_equal 3, @prober.asked.length
      assert Spec.validate!(m)
      assert_equal "prov-reach:gc-reachability-0.1:#{digest}:#{out[:submission_key]}", out[:claim]
      assert_equal Digest::SHA256.hexdigest(out[:submission_key]), out[:idempotency_key]
      assert_equal %w[exists], out[:item_results]['workflow_repository']
    end
  end

  # (ix): the engine's default is 24 hours; this record names 100 years.
  def test_the_record_outlives_a_day
    with_proofs do |registry, tip_source|
      sk = key
      out = reach(registry, tip_source, sk, prov_record(registry, tip_source, sk))
      envelope = registry.find_proof(out[:synoptis_proof_id])
      assert_equal Spec::PROOF_TTL, envelope.ttl
      refute envelope.expired?
    end
  end

  def test_another_key_may_observe_and_the_record_says_so
    with_proofs do |registry, tip_source|
      prov_id = prov_record(registry, tip_source, key)
      out = reach(registry, tip_source, key, prov_id)
      assert_equal false, manifest(registry, out[:synoptis_proof_id])['same_signer']
    end
  end

  # (vii): same bundle, same key, two nonces → two records.
  def test_two_observations_are_two_records
    with_proofs do |registry, tip_source|
      sk = key
      prov_id = prov_record(registry, tip_source, sk)
      a = reach(registry, tip_source, sk, prov_id)
      b = reach(registry, tip_source, sk, prov_id)
      refute_equal a[:synoptis_proof_id], b[:synoptis_proof_id]
      assert_equal manifest(registry, a[:synoptis_proof_id])['counts'], manifest(registry, b[:synoptis_proof_id])['counts']
      assert_equal false, b[:recovered]
    end
  end

  # --- nothing is asked before the signature, and nothing on a resend (v) -------------

  def test_a_resend_recovers_and_asks_nothing_and_returns_no_per_item_results
    with_proofs do |registry, tip_source|
      sk = key
      prov_id = prov_record(registry, tip_source, sk)
      identity = Spec.signed_params_for(BUNDLE, prov_id, SecureRandom.hex(32))
      op = operator(sk, 'gc_prov_reach', identity, tip_source)
      first = reach(registry, tip_source, sk, prov_id, identity: identity, op: op)
      asked = @prober.asked.length
      second = reach(registry, tip_source, sk, prov_id, identity: identity, op: op)
      assert_equal first[:synoptis_proof_id], second[:synoptis_proof_id]
      assert_equal true, second[:recovered]
      assert_nil second[:item_results]
      assert_equal asked, @prober.asked.length
    end
  end

  def test_unsigned_wrong_bearer_and_bad_identities_ask_nothing
    with_proofs do |registry, tip_source|
      sk = key
      prov_id = prov_record(registry, tip_source, sk)
      good = Spec.signed_params_for(BUNDLE, prov_id, SecureRandom.hex(32))
      cases = {
        GCoreR::SubmitCore::UnsignedModeError =>
          -> { reach(registry, tip_source, sk, prov_id, op: operator(sk, 'gc_prov_reach', good, tip_source, mode: 'none'), identity: good) },
        GCoreR::SubmitCore::BearerBindingError => -> { reach(registry, tip_source, sk, prov_id, bearer: 'f' * 64) },
        GCoreR::SubmitCore::IdentityMismatch =>
          -> { reach(registry, tip_source, sk, prov_id, identity: good.merge('prov_proof_ref' => 'e' * 64)) },
        Spec::RuleVersionMismatch =>
          -> { reach(registry, tip_source, sk, prov_id, identity: good.merge('reachability_rule' => 'gc-reachability-0.0')) }
      }
      cases.each do |error, call|
        assert_raises(error) { call.call }
      end
      bad_nonce = good.merge('observation_nonce' => 'abc')
      assert_raises(GCoreR::SubmitCore::IdentityMismatch) { reach(registry, tip_source, sk, prov_id, identity: bad_nonce) }
      upper = good.merge('observation_nonce' => SecureRandom.hex(32).upcase)
      assert_raises(GCoreR::SubmitCore::IdentityMismatch) { reach(registry, tip_source, sk, prov_id, identity: upper) }
      # A server-set field offered in the identity is a key the identity may not hold.
      assert_raises(GCoreR::SubmitCore::IdentityMismatch) do
        reach(registry, tip_source, sk, prov_id, identity: good.merge('counts' => {}))
      end
      assert_empty @prober.asked
      assert_equal 1, registry.read(:proofs).length # the prov record only
    end
  end

  # Review r1: under a proof_id that names nothing, every call refused before
  # the signature is refused for its own reason, never as a missing prov
  # record, so the ledger is not read before the signature — a signature that
  # does not verify included.
  def test_the_prov_record_is_not_looked_up_before_the_signature
    with_proofs do |registry, tip_source|
      sk = key
      nowhere = 'no-such-proof'
      good = Spec.signed_params_for(BUNDLE, nowhere, SecureRandom.hex(32))
      forged = operator(sk, 'gc_prov_reach', good, tip_source)
      forged['signature']['value'] = Base64.urlsafe_encode64(sk.sign('something else'), padding: false)
      calls = [
        -> { reach(registry, tip_source, sk, nowhere, op: operator(sk, 'gc_prov_reach', good, tip_source, mode: 'none'), identity: good) },
        -> { reach(registry, tip_source, sk, nowhere, identity: good, bearer: 'f' * 64) },
        -> { reach(registry, tip_source, sk, nowhere, identity: good, op: forged) }
      ]
      calls.each do |call|
        e = assert_raises(StandardError) { call.call }
        refute_kind_of Spec::ProvRecordRejected, e
      end
      assert_raises(Spec::ProvRecordRejected) { reach(registry, tip_source, sk, nowhere, identity: good) }
      assert_empty @prober.asked
    end
  end

  # Review r1: a key the identity may not hold is counted, never echoed; a
  # bundle that is not JSON keeps no parser error behind its own.
  def test_refusals_do_not_echo_what_the_submitter_wrote
    with_proofs do |registry, tip_source|
      sk = key
      prov_id = prov_record(registry, tip_source, sk)
      good = Spec.signed_params_for(BUNDLE, prov_id, SecureRandom.hex(32))
      e = assert_raises(GCoreR::SubmitCore::IdentityMismatch) do
        reach(registry, tip_source, sk, prov_id, identity: good.merge('https://secret.example.org/x' => 1))
      end
      refute_includes e.message, 'secret'
      assert_includes e.message, '1 key(s) the identity may not hold'
    end
    spec = Spec.new(bundle: '{"x": https://secret.example.org}', identity: {}, prov_proof_id: 'p', registry: nil, prober: @prober)
    e = assert_raises(GCoreR::SubmitCore::DigestMismatch) { spec.parse_digest_subject! }
    assert_nil e.cause
  end

  def test_a_gate_address_that_is_not_an_address_stops_the_tool_before_anything_is_observed
    with_tool(gate_yaml: "    own_names: [anchor.example.org]\n    denylist: ['metadata.internal']\n") do |tool, registry, tip_source|
      sk = key
      prov_id = prov_record(registry, tip_source, sk)
      identity = Spec.signed_params_for(BUNDLE, prov_id, SecureRandom.hex(32))
      text = tool.call('bundle' => BUNDLE, 'prov_proof_id' => prov_id, 'identity' => identity,
                       'operator' => operator(sk, 'gc_prov_reach', identity, tip_source)).first[:text]
      assert_includes text, 'not an IP address or CIDR'
      assert_includes tool.call('bundle' => BUNDLE, 'prov_proof_id' => prov_id, 'operator' => {}, 'dry_run' => true).first[:text],
                      'not an IP address or CIDR'
      assert_empty @prober.asked
      assert_equal 1, registry.read(:proofs).length
    end
  end

  def test_a_dry_run_asks_nothing_and_looks_up_nothing
    registry = Object.new
    def registry.find_proof(*) = raise('looked up')
    spec = Spec.new(bundle: BUNDLE, identity: {}, prov_proof_id: 'p', registry: registry, prober: @prober)
    out = spec.dry_run
    assert_equal({ 'items' => 1, 'distinct' => 1, 'refused_without_resolving' => 0 }, out['counts']['runtime'])
    assert_equal Digest::SHA256.hexdigest('p'), out['signed_params']['prov_proof_ref']
    assert_empty @prober.asked
  end

  # --- refusals of form (§6.3 (3)): no record, nothing asked -------------------------

  # An observation record carries the same bundle_digest, so only its type
  # keeps it from being taken for the prov record.
  def test_an_observation_cannot_be_laid_over_another_observation
    with_proofs do |registry, tip_source|
      sk = key
      first = reach(registry, tip_source, sk, prov_record(registry, tip_source, sk))
      asked = @prober.asked.length
      assert_raises(Spec::ProvRecordRejected) { reach(registry, tip_source, sk, first[:synoptis_proof_id]) }
      assert_equal asked, @prober.asked.length
    end
  end

  def test_gate_a_refuses_a_large_or_deep_bundle_before_asking
    with_proofs do |registry, tip_source|
      sk = key
      prov_id = prov_record(registry, tip_source, sk)
      big = JSON.generate(JSON.parse(BUNDLE).merge('pad' => 'x' * (2 * 1024 * 1024)))
      deep = JSON.generate(JSON.parse(BUNDLE).merge('pad' => 40.times.reduce('x') { |acc, _| { 'n' => acc } }))
      assert_raises(GCoreR::SubmitCore::EvidenceTooLarge) { reach(registry, tip_source, sk, prov_id, bundle: big) }
      assert_raises(GCoreR::SubmitCore::EvidenceTooLarge) { reach(registry, tip_source, sk, prov_id, bundle: deep) }
      assert_empty @prober.asked
      assert_raises(ArgumentError) { GCoreR::ProvProofRef.for('') }
    end
  end

  def test_a_missing_revoked_or_foreign_prov_record_is_refused_before_asking
    with_proofs do |registry, tip_source|
      sk = key
      prov_id = prov_record(registry, tip_source, sk)
      e = assert_raises(Spec::ProvRecordRejected) { reach(registry, tip_source, sk, 'no-such-proof') }
      refute_includes e.message, 'no-such-proof'

      other = JSON.generate(JSON.parse(BUNDLE).merge('object_id' => 'urn:uuid:00000000-0000-4000-8000-0000000000aa'))
      assert_raises(Spec::ProvRecordRejected) { reach(registry, tip_source, sk, prov_id, bundle: other) }

      registry.store_revocation(proof_id: prov_id, reason: 'test', revoker_id: 'ed25519:stub')
      assert_raises(Spec::ProvRecordRejected) { reach(registry, tip_source, sk, prov_id) }
      assert_empty @prober.asked
      assert_equal 1, registry.read(:proofs).length
    end
  end

  def test_a_busy_anchor_refuses_records_nothing_and_releases_the_nonce
    with_proofs do |registry, tip_source|
      sk = key
      prov_id = prov_record(registry, tip_source, sk)
      busy = R::Admission.new
      identity = Spec.signed_params_for(BUNDLE, prov_id, SecureRandom.hex(32))
      op = operator(sk, 'gc_prov_reach', identity, tip_source)
      busy.hold(pubkey(sk)) do
        assert_raises(Spec::ObservationRefused) { reach(registry, tip_source, sk, prov_id, identity: identity, op: op, admission: busy) }
      end
      refute KairosMcp::Manifest::Signer.global_reservation.committed?(op.dig('signature', 'nonce'))
      assert_equal 'recorded', reach(registry, tip_source, sk, prov_id, identity: identity, op: op, admission: busy)[:status]
    end
  end

  # --- the MCP tool on a disposable anchor (R3 end to end) -----------------------------

  def test_the_tool_records_over_a_prov_record_on_a_local_anchor
    with_tool do |tool, registry, tip_source, gate|
      sk = key
      prov_id = prov_record(registry, tip_source, sk)
      identity = Spec.signed_params_for(BUNDLE, prov_id, SecureRandom.hex(32))
      res = JSON.parse(tool.call('bundle' => BUNDLE, 'prov_proof_id' => prov_id, 'identity' => identity,
                                 'operator' => operator(sk, 'gc_prov_reach', identity, tip_source)).first[:text])
      assert_equal 'recorded', res['status'], res.inspect
      assert_equal 1, res.dig('counts', 'runtime', 'exists', 'public_registry')
      assert_equal %w[exists], res.dig('item_results', 'runtime')
      refute res.key?('item_results_note')
      fresh = Spec.signed_params_for(BUNDLE, prov_id, SecureRandom.hex(32))
      op = operator(sk, 'gc_prov_reach', fresh, tip_source)
      first = JSON.parse(tool.call('bundle' => BUNDLE, 'prov_proof_id' => prov_id, 'identity' => fresh, 'operator' => op).first[:text])
      again = JSON.parse(tool.call('bundle' => BUNDLE, 'prov_proof_id' => prov_id, 'identity' => fresh, 'operator' => op).first[:text])
      assert_equal [false, true], [first['recovered'], again['recovered']]
      refute again.key?('item_results')
      assert_includes again['item_results_note'], 'not kept'
      assert_equal first['counts'], again['counts']
      assert_equal({ own_names: ['anchor.example.org'], own_addresses: ['203.0.113.7'], denylist: ['198.51.100.0/24'] }, gate)
      assert_equal 'prov_reachability', manifest(registry, res['synoptis_proof_id'])['record_type']
    end
  end

  def test_the_tools_dry_run_asks_nothing_and_a_rule_skew_returns_the_anchors_rule
    with_tool do |tool, registry, tip_source|
      sk = key
      prov_id = prov_record(registry, tip_source, sk)
      dry = JSON.parse(tool.call('bundle' => BUNDLE, 'prov_proof_id' => prov_id, 'operator' => {}, 'dry_run' => true).first[:text])
      assert_equal 'dry_run', dry['status']
      assert_equal Digest::SHA256.hexdigest(prov_id), dry.dig('signed_params', 'prov_proof_ref')
      identity = Spec.signed_params_for(BUNDLE, prov_id, SecureRandom.hex(32)).merge('reachability_rule' => 'gc-reachability-0.0')
      skew = JSON.parse(tool.call('bundle' => BUNDLE, 'prov_proof_id' => prov_id, 'identity' => identity,
                                  'operator' => operator(sk, 'gc_prov_reach', identity, tip_source)).first[:text])
      assert_equal 'RuleVersionMismatch', skew['error']
      assert_equal 'gc-reachability-0.1', skew.dig('versions', 'reachability_rule')
      assert_empty @prober.asked
      assert_equal 1, registry.read(:proofs).length
    end
  end

  def test_the_tool_is_registered_on_the_anchor_only
    prov = KairosMcp::Skillset.new(File.expand_path('..', __dir__))
    name = 'KairosMcp::SkillSets::GenomicschainProv::Tools::GcProvReach'
    with_tool do |tool|
      assert_includes prov.tool_class_names, name
      File.write(File.join(KairosMcp.skillsets_dir, 'genomicschain_core', 'config', 'genomicschain_core.yml'),
                 "genomicschain:\n  anchor_profile: false\n")
      refute_includes prov.tool_class_names, name
      # and a class loaded anyway refuses to run off the anchor
      out = tool.call('bundle' => BUNDLE, 'prov_proof_id' => 'p', 'operator' => {}, 'dry_run' => true).first[:text]
      assert_includes out, 'requires genomicschain.anchor_profile: true'
    end
  end

  # --- reading it back (R4: the public route, gc_prov_verify) -------------------------

  # An observation and its prov record through the public route, as a third
  # party reads them; `days` moves this check's clock forward.
  def observed(days: 0)
    with_proofs do |registry, tip_source|
      sk = key
      prov_id = prov_record(registry, tip_source, sk)
      out = reach(registry, tip_source, sk, prov_id)
      place = GenomicsChainProv::PlaceExtension.new(registry: registry)
      route = place.lookup(out[:synoptis_proof_id])
      now = -> { Time.now.utc + (days * 86_400) }
      yield route, prov_id, place.lookup(prov_id), now
    end
  end

  def verify(route, prov_id: nil, bundle: BUNDLE, now: -> { Time.now.utc })
    GenomicsChainProv::ReachVerifier.new(bundle_text: bundle, route: route, prov_proof_id: prov_id, now: now).run
  end

  def test_the_public_route_serves_the_observation_and_the_verifier_reads_it_consistent
    observed(days: 3) do |route, prov_id, _, now|
      refute_nil route
      r = verify(route, prov_id: prov_id, now: now)
      assert_equal 'consistent', r['state'], r['confirmed'].inspect
      assert_equal %w[bundle_digest subject_ref manifest_body_sha256 submission_key claim submitter_signature prov_proof_ref],
                   r['confirmed'].map { |c| c['check'] }
      says = r['anchor_says'].join("\n")
      assert_includes says, '(3 days before this check)'
      assert_includes says, 'same signer as the prov record: yes'
      assert_includes says, 'runtime exists from a public registry: 1 — the place answered that it exists'
      refute_match(/total|in all/i, says)
      refute_includes says, 'runtime not_found', 'a result with no place is not shown'
      refute_includes says, 'runtime digest_match', 'nor a split result with no place'
      refute_includes says, 'runtime exists from another host'
      assert_equal 5, r['not_checked'].length
      assert_includes r['not_checked'], GenomicsChainProv::ReachVerifier::NOT_CHECKED_TEXT['buildability']
      assert_equal [GenomicsChainProv::ReachVerifier::STATEMENT, *GenomicsChainProv::Identity::STATEMENTS], r['statements']
    end
  end

  def failed_checks(result) = result['confirmed'].reject { |c| c['ok'] }.map { |c| c['check'] }

  def test_without_the_prov_proof_id_the_link_is_named_unchecked_and_a_wrong_one_is_a_mismatch
    observed do |route, _, prov_route|
      r = verify(route)
      assert_equal 'consistent', r['state']
      assert(r['record_notes'].any? { |n| n.include?('--prov-proof-id') })
      assert_equal %w[prov_proof_ref], failed_checks(verify(route, prov_id: 'attest_not_this_one'))
      other = JSON.generate(JSON.parse(BUNDLE).merge('object_id' => 'urn:uuid:00000000-0000-4000-8000-0000000000bb'))
      assert_equal %w[bundle_digest subject_ref], failed_checks(verify(route, bundle: other))
      assert_equal 'not_comparable', verify(prov_route)['state'], 'a prov record is not read as an observation'
    end
  end

  # Each check stands on its own: a change to one field, with the evidence
  # re-hashed to match (as only a forger without the anchor's key would),
  # fails the check for that field.
  def test_each_rebuilt_field_is_checked_on_its_own
    observed do |route, prov_id, _|
      assert_equal %w[claim], failed_checks(verify(route.merge('claim' => "#{route['claim']}x"), prov_id: prov_id))
      ev = JSON.parse(route['evidence'])
      ev['manifest']['submission_key'] = 'f' * 64
      ev['manifest_body_sha256'] = Digest::SHA256.hexdigest(KairosMcp::Manifest.canonical_json(ev['manifest']))
      forged = route.merge('evidence' => KairosMcp::Manifest.canonical_json(ev), 'claim' => route['claim'].sub(/:[0-9a-f]{64}\z/, ":#{'f' * 64}"))
      assert_equal %w[submission_key], failed_checks(verify(forged, prov_id: prov_id))
    end
  end

  def test_gc_prov_verify_picks_the_verifier_by_record_type
    observed do |route, prov_id, prov_route|
      Dir.mktmpdir do |d|
        bundle = File.join(d, 'bco.json')
        File.write(bundle, BUNDLE)
        cli = File.expand_path('../bin/gc_prov_verify.rb', __dir__)
        { 'obs' => [route, ['--prov-proof-id', prov_id], "laid over the prov record #{prov_id}", 'what the GenomicsChain anchor was told'],
          'prov' => [prov_route, [], 'CONFIRMED here', 'grade'] }.each do |name, (body, extra, want1, want2)|
          env = File.join(d, "#{name}.json")
          File.write(env, JSON.generate(body))
          out, err, st = Open3.capture3(RbConfig.ruby, '-I', File.expand_path('../../genomicschain_core/lib', __dir__),
                                        '-I', File.expand_path('../../genomicschain_tier2/lib', __dir__),
                                        cli, bundle, '--envelope', env, *extra)
          assert_equal 0, st.exitstatus, "#{name}: #{out}#{err}"
          assert_includes out, want1
          assert_includes out, want2
        end
      end
    end
  end

  # --- nothing leaks into the record (vi) ---------------------------------------------

  def test_the_record_holds_no_locator_no_proof_id_and_no_per_item_result
    with_proofs do |registry, tip_source|
      sk = key
      prov_id = prov_record(registry, tip_source, sk)
      out = reach(registry, tip_source, sk, prov_id)
      stored = registry.find_proof(out[:synoptis_proof_id]).evidence.to_s
      ['github.com', 'nf-core/demo', 'nextflow-io', '555d145b9e701c012f53996a2f17efb2daff5fe7', prov_id].each do |s|
        refute_includes stored, s
      end
      refute_includes stored, 'item_results'
      refute manifest(registry, out[:synoptis_proof_id]).key?('items')
    end
  end
end
