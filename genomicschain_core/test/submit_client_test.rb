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
