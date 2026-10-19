# frozen_string_literal: true
# scripts/gc_submit_client.rb — the operator's signing half, checked against
# the anchor's verifying half. What the client signs must be what SubmitCore
# re-derives and what Signer verifies, or no record can ever be made.
require 'minitest/autorun'
require 'tmpdir'
require 'json'
require 'digest'
require 'open3'
require 'rbconfig'
require 'fileutils'
require 'base64'
require 'kairos_mcp/version'
require_relative 'proofs_sandbox'
require 'kairos_mcp/skillset'
require 'genomicschain_core'
require_relative '../../scripts/gc_submit_client'

class SubmitClientTest < Minitest::Test
  GC = KairosMcp::SkillSets::GenomicschainCore
  CLIENT = File.expand_path('../../scripts/gc_submit_client.rb', __dir__)

  def setup
    KairosMcp::Manifest::Signer.instance_variable_set(:@global_reservation, nil)
  end

  def adjudication
    {
      'adjudication_rubric_version' => 'codescan-adjudication-0.1.0',
      'subject' => {
        'canonical_id' => '10.1101/2024.06.17.598857', 'tier1_rubric_version' => '0.2.5',
        'tier1_report_content_hash' => 'b' * 64, 'codescan_evidence_digest' => 'a' * 64,
        'codescan_toolchain' => { 'ruby' => '3.4.10', 'psych' => '5.2.2', 'codescan_rubric_version' => 'codescan-static-0.1.0' }
      },
      'stage_transition' => { 'from' => 'stage1-prose-only', 'to' => 'stage2-code-verified', 'applied' => false },
      'levers' => { 'code_derived' => { 'in_code_db_pin_classA' => false },
                    'lever1_environment_lock' => { 'declared_lock' => { 'value' => true }, 'byte_fixed_lock' => { 'value' => false },
                                                   'headline' => 'ships a declared lock, but its bytes are not fixed' } },
      'discrepancies' => [], 'ambiguous_links' => [],
      'counts' => { 'rules_in_code' => 3, 'rules_unique' => 3, 'tier1_steps' => 2, 'steps_linked' => 1, 'steps_unlinked' => 2,
                    'proposed_demotions' => 0, 'demotion_proposal_is_a_lower_bound' => true }
    }
  end

  def with_key
    Dir.mktmpdir do |d|
      path = File.join(d, 'op.key')
      info = GcSubmitClient.keygen(path)
      yield path, GcSubmitClient.load_key(path), info
    end
  end

  def test_keygen_writes_a_seed_the_loader_accepts_and_reports_the_bound_hash
    with_key do |path, key, info|
      assert_equal '600', File.stat(path).mode.to_s(8)[-3..]
      assert_equal GcSubmitClient.pubkey_string(key), info['pubkey']
      assert_equal Digest::SHA256.hexdigest(info['pubkey']), info['pubkey_hash']
      assert_raises(RuntimeError) { GcSubmitClient.keygen(path) }
    end
  end

  # The envelope the client builds must verify on the anchor's Signer against
  # the anchor's TipSource — same bytes, same tip rules.
  def test_envelope_verifies_with_the_anchor_signer
    with_key do |_, key, _|
      Dir.mktmpdir do |tmp|
        _registry, tip_source, = ProofsSandbox.context(tmp)
        KairosMcp::Manifest::Signer.bootstrap_seen_list!(tip_source: tip_source)
        params = GcSubmitClient.signed_params('tier2', adjudication, { 'url' => 'https://x', 'commit' => 'a' * 40 })
        op = GcSubmitClient.operator_envelope(key, 'gc_tier2_submit', params, tip_source.latest_tip_hash)
        assert KairosMcp::Manifest::Signer.verify_admission!(
          operator: op, tip_source: tip_source, transport: :stdio,
          args: { 'mcp_tool_name' => 'gc_tier2_submit', 'params' => params }
        )
      end
    end
  end

  # End to end through SubmitCore: what the client signed is what the server
  # re-derives, so the record is made. No HTTP here; the transport is plain
  # JSON-RPC and is exercised by --print-only below.
  def test_client_signed_submission_is_recorded_by_tier2_submit
    with_key do |_, key, info|
      Dir.mktmpdir do |tmp|
        registry, tip_source, = ProofsSandbox.context(tmp)
        KairosMcp::Manifest::Signer.bootstrap_seen_list!(tip_source: tip_source)
        repo = { 'url' => 'https://forgemia.inra.fr/urgi-anagen/panREPET', 'commit' => '6d8748a03a7e' }
        params = GcSubmitClient.signed_params('tier2', adjudication, repo)
        op = GcSubmitClient.operator_envelope(key, 'gc_tier2_submit', params, tip_source.latest_tip_hash)
        out = GC::Tier2Submit.submit(
          adjudication: adjudication, identity: params, repository: repo, operator: op,
          bearer_pubkey_hash: info['pubkey_hash'], tip_source: tip_source,
          attestor: StubAttestor.new(registry: registry), registry: registry
        )
        assert_equal 'recorded', out[:status]
        assert out[:claim].start_with?('tier2:declared_lock:0:')
      end
    end
  end

  def test_tier1_params_come_from_the_same_module_the_anchor_uses
    report = { 'canonical_id' => { 'value' => '10.1101/x' }, 'rubric_version' => '0.2.5', 'rubric_hash' => 'c' * 64,
               'funnel_stage' => 'stage1-prose-only', 'headline' => { 'static_readiness' => '0.5' },
               'assessor_id' => 'a', 'assessor_stack' => { 'operator_id' => 'm', 'stage' => 's',
                                                           'llm' => { 'provider' => 'p', 'model' => 'm', 'invoked_at' => 't' } },
               'manifest' => {} }
    assert_equal GC::Tier1Submit.signed_params_for(report), GcSubmitClient.signed_params('tier1', report, nil)
  end

  # --tier prov (prov design §9 U4): what the client signs for a bundle is
  # what the anchor's VerdictSpec::Prov derives, so SubmitCore records it; and
  # the CLI sends the bundle as text, with every --zk-receipt as base64 under
  # its own sha256.
  def test_prov_bundle_signed_by_the_client_is_recorded_and_sent_with_its_receipts
    GcSubmitClient.load_prov
    require 'genomicschain_prov/writer/environment'
    require 'genomicschain_prov/prov_submit'
    zk = File.expand_path('../../genomicschain_prov/test/fixtures/zk_sizefactor_s1', __dir__)
    with_key do |path, key, info|
      Dir.mktmpdir do |d|
        bundle_path, receipt = prov_bundle(d, zk)
        text = File.read(bundle_path)
        registry, tip_source, = ProofsSandbox.context(File.join(d, 'proofs'))
        KairosMcp::Manifest::Signer.bootstrap_seen_list!(tip_source: tip_source)
        params = GcSubmitClient.signed_params('prov', text, nil)
        assert_equal GenomicsChainProv::ProvSubmit.signed_params_for(text), params
        op = GcSubmitClient.operator_envelope(key, 'gc_prov_submit', params, tip_source.latest_tip_hash)
        fake = Class.new(GenomicsChainProv::ZkVerifier) do
          def run(_b, _i) = { 'verified' => true, 'journal_ok' => true, 'tool' => 'gc_zk_verify', 'version' => '0.1.0',
                              'risc0_zkvm' => '3.0.6', 'journal_convention' => 'gc-zk-journal-0.1',
                              'journal_input_sha256' => '5cb5cfc3a976faa8b8db6a8799ebc3372097833845e38d99e9247c14a86aede3',
                              'journal_output_sha256' => '7d8c053239d53b373ae09674c2bd3f1456038c414e54534762ba7592ec9b4515' }
        end.new(bin: '/nonexistent')
        out = GenomicsChainProv::ProvSubmit.submit(
          bundle: text, identity: params, operator: op, bearer_pubkey_hash: info['pubkey_hash'],
          tip_source: tip_source, attestor: StubAttestor.new(registry: registry), registry: registry,
          zk_receipt_bytes: GcSubmitClient.receipt_bytes([receipt]), zk_verifier: fake
        )
        assert_equal 'recorded', out[:status]
        assert out[:claim].start_with?('prov:prov-predicate-0.3.7:immutable:1/1:')

        req_json, err, st = Open3.capture3(RbConfig.ruby, CLIENT, '--tier', 'prov', '--bundle', bundle_path,
                                           '--zk-receipt', receipt, '--key', path, '--data-dir', d, '--print-only')
        assert st.success?, err
        req = JSON.parse(req_json)
        args = req.dig('params', 'arguments')
        assert_equal 'gc_prov_submit', req.dig('params', 'name')
        assert_equal text, args['bundle'], 'the bundle travels as the exact text that was checked'
        assert_equal params, args['identity']
        bytes = File.binread(receipt)
        assert_equal({ Digest::SHA256.hexdigest(bytes) => Base64.strict_encode64(bytes) }, args['zk_receipt_bytes'])
      end
    end
  end

  # --tier prov-reach (prov design v0.1.15 §6.3): the identity the CLI signs
  # is the one the anchor's VerdictSpec::Reach re-derives, with a new nonce on
  # every run; the prov proof_id travels beside it, unsigned.
  def test_prov_reach_request_is_what_the_anchor_rederives_with_a_new_nonce_each_run
    GcSubmitClient.load_prov
    require 'genomicschain_prov/verdict_spec/reach'
    bundle = File.expand_path('../../genomicschain_prov/test/fixtures/nfcore_demo_1_2_0/bco.json', __dir__)
    with_key do |path, _, _|
      Dir.mktmpdir do |d|
        run = lambda do |*extra|
          Open3.capture3(RbConfig.ruby, CLIENT, '--tier', 'prov-reach', '--bundle', bundle, '--key', path,
                         '--data-dir', d, '--print-only', *extra)
        end
        reqs = 2.times.map do
          out, err, st = run.call('--prov-proof-id', 'attest_abc')
          assert st.success?, err
          JSON.parse(out)
        end
        args = reqs.first.dig('params', 'arguments')
        assert_equal 'gc_prov_reach', reqs.first.dig('params', 'name')
        assert_equal 'attest_abc', args['prov_proof_id']
        assert_equal File.read(bundle), args['bundle']
        spec = GenomicsChainProv::VerdictSpec::Reach.new(bundle: args['bundle'], identity: args['identity'],
                                                         prov_proof_id: 'attest_abc', registry: nil, prober: nil)
        spec.parse_digest_subject!
        spec.assert_submitted_matches_signed!
        nonces = reqs.map { |r| r.dig('params', 'arguments', 'identity', 'observation_nonce') }
        assert_equal 2, nonces.uniq.length
        _, err, st = run.call
        refute st.success?
        assert_includes err, '--prov-proof-id'
      end
    end
  end

  def prov_bundle(dir, zk)
    w = GenomicsChainProv::Writer
    FileUtils.mkdir_p(File.join(dir, 'tools'))
    %w[S1_odd.kmat S1_odd__valid_exact.sfq3].each { |f| FileUtils.cp(File.join(zk, f), dir) }
    receipt = File.join(dir, 'receipt.bin')
    FileUtils.cp(File.join(zk, 'receipt.succinct.bin'), receipt)
    File.write(File.join(dir, 'tools', 'checker.sh'), "#!/bin/sh\n")
    File.write(File.join(dir, 'run.sh'), "#!/bin/sh\n")
    plan = w.normalise_plan(
      'name' => 'size-factor-check', 'script' => 'run.sh',
      'runtime' => { 'engine' => 'sh', 'version' => '5.2.21', 'uri' => '/bin/sh', 'path' => '/bin/sh' },
      'stages' => [{ 'name' => 'sizefactor', 'inputs' => ['S1_odd.kmat'], 'outputs' => ['S1_odd__valid_exact.sfq3'],
                     'tools' => [{ 'name' => 'checker.sh', 'version' => '0.1.0', 'uri' => 'tools/checker.sh' }] }],
      'zk_receipts' => [{ 'receipt' => 'receipt.bin', 'image_id' => File.read(File.join(zk, 'image_id.txt')).strip,
                          'zkvm_version' => '3.0.6', 'step_number' => 1, 'input' => 'S1_odd.kmat',
                          'output' => 'S1_odd__valid_exact.sfq3' }]
    )
    resolved = w::Environment.resolve!(plan, base_dir: dir, docker: false)
    decl = w::Environment.zk_declarations(plan['zk_receipts'], base_dir: dir)
    path = File.join(dir, 'bco.json')
    File.write(path, JSON.pretty_generate(w.build(plan, checksums: resolved['checksums'], zk_receipts: decl['zk_receipts'])))
    [path, receipt]
  end

  # The CLI builds a tools/call request and, with --print-only, sends nothing.
  def test_print_only_emits_a_signed_jsonrpc_request
    with_key do |path, _, _|
      Dir.mktmpdir do |d|
        adj = File.join(d, 'adj.json')
        File.write(adj, JSON.generate(adjudication))
        # --data-dir on an empty registry must resolve to the genesis tip, and
        # doing it in a subprocess proves the script loads everything it needs
        # on its own (the first run against a real server failed here).
        out, err, st = Open3.capture3(
          RbConfig.ruby, CLIENT, '--tier', 'tier2', '--adjudication', adj, '--key', path,
          '--data-dir', d, '--repository-commit', 'f' * 40, '--dry-run', '--print-only'
        )
        assert st.success?, err
        req = JSON.parse(out)
        assert_equal 'tools/call', req['method']
        assert_equal 'gc_tier2_submit', req.dig('params', 'name')
        args = req.dig('params', 'arguments')
        assert_equal true, args['dry_run']
        assert_equal 'signed', args.dig('operator', 'mode')
        assert_equal '0' * 64, args.dig('operator', 'signature', 'chain_tip_hash')
        assert_equal 'f' * 40, args.dig('identity', 'repository_commit')
        assert_equal GC::Tier2Submit.adjudication_digest(adjudication), args.dig('identity', 'adjudication_digest')
      end
    end
  end
end

# Shared with tier3_submit_test when both load; defined here so this file runs alone.
unless defined?(StubAttestor)
  class StubAttestor
    attr_reader :registry

    def initialize(registry:)
      @registry = registry
    end

    def issue(**kw)
      engine = ::Synoptis::AttestationEngine.new(registry: @registry, config: { 'require_signature' => false })
      result = engine.create_attestation(
        attester_id: 'ed25519:stub', subject_ref: kw[:subject_ref], claim: kw[:claim],
        evidence: kw[:evidence], actor_role: kw[:actor_role]
      )
      { status: result[:status], synoptis_proof_id: result[:proof_id] }
    end
  end
end
