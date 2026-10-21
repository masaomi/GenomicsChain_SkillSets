# frozen_string_literal: true
# Record 0.3 on an anchor without genomicschain_tier3 (Tier 3 v0.1 implementation
# review r3 D1; operator 2026-10-21, question 7 「core の中で値の入れ物を作る」;
# design §5 row "core tools/gc_tier3_submit.rb"). The anchor installs core +
# prov + tier3_record and never tier3, so core's anchor-only gc_tier3_submit
# must build its value type inside core. The submit runs in a fresh Ruby process
# whose load path holds core, synoptis and mmp and NOT genomicschain_tier3/lib;
# its dry run, response and stored manifest must meet what the existing suite
# pins for this input (tier3_submit_test.rb's verdict_result, the R0 idempotency
# key in fixtures/idempotency_keys_r0.json, record 0.3's derivations). A drift
# guard keeps core's value type in step with Tier3Executor::VerdictResult.
require 'minitest/autorun'
require 'tmpdir'
require 'json'
require 'digest'
require 'open3'
require 'rbconfig'
require_relative 'idempotency_fixture'

class GcTier3SubmitWithoutTier3Test < Minitest::Test
  CORE_DIR = File.expand_path('..', __dir__)
  WORKTREE = File.expand_path('..', CORE_DIR)
  TOOL = File.join(CORE_DIR, 'tools', 'gc_tier3_submit.rb')
  TIER3_LIB = File.join(WORKTREE, 'genomicschain_tier3', 'lib')

  # The input of tier3_submit_test.rb's verdict_result(job_spec), with a fixed
  # signing key and nonce so two processes sign the same envelope.
  RUNNER = <<~'RUBY'
    require 'json'
    require 'digest'
    require 'base64'
    require 'fileutils'
    require 'ed25519'
    require 'kairos_mcp/version'
    require 'kairos_mcp/tools/base_tool'
    require 'kairos_mcp/storage/file_backend'
    require 'synoptis/proof_envelope'
    require 'synoptis/verifier'
    require 'synoptis/attestation_engine'
    require 'synoptis/registry/file_registry'
    require 'genomicschain_core'
    tool_path, data = ARGV
    require tool_path
    GCK = KairosMcp::SkillSets::GenomicschainCore
    KairosMcp.data_dir = data
    cfg = File.join(KairosMcp.skillsets_dir, 'genomicschain_core', 'config')
    FileUtils.mkdir_p(cfg)
    File.write(File.join(cfg, 'genomicschain_core.yml'), "genomicschain:\n  anchor_profile: true\n")
    registry = Synoptis::Registry::FileRegistry.new(data_dir: File.join(data, 'synoptis_data'))
    tip = GCK::TipSource.new(registry: registry)

    class StubAttestor
      def initialize(registry) = (@registry = registry)
      attr_reader :registry

      def issue(**kw)
        engine = Synoptis::AttestationEngine.new(registry: @registry, config: { 'require_signature' => false })
        r = engine.create_attestation(attester_id: 'ed25519:stub', subject_ref: kw[:subject_ref], claim: kw[:claim],
                                      evidence: kw[:evidence], actor_role: kw[:actor_role])
        { status: r[:status], synoptis_proof_id: r[:proof_id] }
      end
    end
    stub = StubAttestor.new(registry)
    GCK::Attestation::SynoptisAttestor.define_singleton_method(:build) { |**_kw| stub }

    job = { 'subject_ref' => 'repro://656122/C9', 'env' => { 'lock' => 'abc' }, 'data' => { 'accessions' => [] },
            'pipeline' => { 'steps' => ['C9'] } }
    eo = { 'target' => 'checksum', 'sha256' => 'c' * 64, 'source' => 'paper_declared',
           'source_citation' => 'doi:10.1038/s41467-018-06108-1', 'validated_by' => 'human:masaomi' }
    vr = { 'subject_ref' => 'repro://656122/C9', 'jobspec_digest' => KairosMcp::Manifest.canonical_json_sha256(job),
           'execution_verdict' => 'completed', 'comparison_verdict' => 'match_exact',
           'environment_provenance' => 'declared_lock', 'inputs_provenance' => 'public_accession', 'run_count' => 1,
           'trust_tier' => 'self_reported', 'result_hash' => 'd' * 64, 'expected_output' => eo,
           'expected_output_sha256' => 'c' * 64, 'expected_output_source' => 'paper_declared',
           'expected_output_validated_by' => 'human:masaomi', 'expected_output_source_citation' => eo['source_citation'],
           'expected_output_target' => 'checksum', 'comparator_id' => 'exact_sha256', 'comparator_version' => '0.1.0',
           'backend_id' => 'thoa', 'output_files' => [{ 'sha256' => 'a' * 64, 'relative_path' => 'o.txt', 'size_bytes' => 3 }] }
    # IdempotencyFixture::SIGNING_KEY (test/idempotency_fixture.rb), so the record's idempotency key
    # is the one fixtures/idempotency_keys_r0.json pins for this input.
    sk = Ed25519::SigningKey.new(Digest::SHA256.digest('gc-v0.1.15-r0-idempotency-fixture'))
    pubkey = 'ed25519:' + Base64.urlsafe_encode64(sk.verify_key.to_bytes, padding: false)
    params = GCK::Tier3Submit::SIGNED_IDENTITY_FIELDS.to_h { |f| [f, vr[f]] }
    nonce = 'ab' * 16
    payload = KairosMcp::Manifest.canonical_json('mcp_tool_name' => 'gc_tier3_submit', 'params' => params,
                                                 'nonce' => nonce, 'chain_tip_hash' => tip.latest_tip_hash)
    op = { 'mode' => 'signed', 'pubkey' => pubkey,
           'signature' => { 'algorithm' => 'ed25519', 'signed_fields' => %w[mcp_tool_name params nonce chain_tip_hash],
                            'value' => Base64.urlsafe_encode64(sk.sign(payload), padding: false),
                            'nonce' => nonce, 'chain_tip_hash' => tip.latest_tip_hash } }
    safety = Object.new
    bearer = Digest::SHA256.hexdigest(pubkey)
    safety.define_singleton_method(:current_user) { { user: 'anchor-test', pubkey_hash: bearer } }
    tool = GCK::Tools::GcTier3Submit.new(safety)
    args = { 'verdict_result' => vr, 'jobspec_json' => KairosMcp::Manifest.canonical_json(job),
             'expected_output' => eo, 'operator' => op }
    dry_text = tool.call(args.merge('dry_run' => true)).first[:text]
    real_text = tool.call(args).first[:text]
    real = JSON.parse(real_text)
    manifest = GCK::ProofLookup.parse_evidence(registry.find_proof(real['synoptis_proof_id']).evidence)['manifest']
    print JSON.generate('dry' => JSON.parse(dry_text), 'real' => real, 'manifest' => manifest,
                        'tier3_loaded' => $LOADED_FEATURES.grep(%r{/genomicschain_tier3/}).any?)
  RUBY

  def run_submit(with_tier3:)
    libs = [File.join(CORE_DIR, 'lib')] + $LOAD_PATH.grep(%r{/(synoptis|mmp)/lib\z})
    libs << TIER3_LIB if with_tier3
    Dir.mktmpdir('t3_h1') do |data|
      out, err, status = Open3.capture3(RbConfig.ruby, *libs.flat_map { |l| ['-I', l] }, '-e', RUNNER, TOOL, data)
      assert status.success?, "with_tier3=#{with_tier3}: #{(out + err)[-1500..] || (out + err)}"
      JSON.parse(out)
    end
  end

  # The RUNNER's input, for the derivations below.
  JOB = { 'subject_ref' => 'repro://656122/C9', 'env' => { 'lock' => 'abc' }, 'data' => { 'accessions' => [] },
          'pipeline' => { 'steps' => ['C9'] } }.freeze
  EO = { 'target' => 'checksum', 'sha256' => 'c' * 64, 'source' => 'paper_declared',
         'source_citation' => 'doi:10.1038/s41467-018-06108-1', 'validated_by' => 'human:masaomi' }.freeze
  OUTPUT_FILES = [{ 'sha256' => 'a' * 64, 'relative_path' => 'o.txt', 'size_bytes' => 3 }].freeze

  def jobspec_digest
    require 'genomicschain_core/manifest'
    KairosMcp::Manifest.canonical_json_sha256(JOB)
  end

  # record 0.3's result_evidence_sha256 (verdict_spec/tier3.rb:99–108) for this input.
  def result_evidence
    require 'genomicschain_core/manifest'
    bundle = { 'backend_id' => 'thoa', 'local_result_hash' => 'd' * 64, 'jobspec_digest' => jobspec_digest,
               'output_files' => OUTPUT_FILES }
    Digest::SHA256.hexdigest(KairosMcp::Manifest.canonical_json(bundle))
  end

  def test_record_0_3_submits_without_tier3_on_the_load_path
    without = run_submit(with_tier3: false)
    assert_equal false, without['tier3_loaded'], 'genomicschain_tier3 was not loaded'
    real = without['real']
    assert_equal ['recorded', false], real.values_at('status', 'recovered')
    assert real['claim'].start_with?("tier3:completed:match_exact:#{'d' * 64}:")
    assert real['claim'].end_with?(":#{real['submission_key']}")
    assert_equal true, real['leaderboard_eligible']
    assert_equal result_evidence, real['result_evidence_sha256']
    assert_equal IdempotencyFixture.expected('tier3_verdict')['fresh'], real['idempotency_key'],
                 'the idempotency key fixtures/idempotency_keys_r0.json pins for this input'
  end

  def test_the_stored_manifest_has_the_fields_this_input_fixes
    m = run_submit(with_tier3: false)['manifest']
    want = {
      'record_type' => 'tier3_verdict', 'record_version' => '0.3', 'mcp_tool_name' => 'gc_tier3_submit',
      'subject_ref' => 'repro://656122/C9', 'jobspec_digest' => jobspec_digest, 'execution_verdict' => 'completed',
      'comparison_verdict' => 'match_exact', 'environment_provenance' => 'declared_lock',
      'inputs_provenance' => 'public_accession', 'run_count' => 1, 'trust_tier' => 'self_reported',
      'result_hash' => 'd' * 64, 'backend_id' => 'thoa', 'expected_output' => EO, 'expected_output_sha256' => 'c' * 64,
      'comparator_id' => 'exact_sha256', 'comparator_version' => '0.1.0', 'output_files' => OUTPUT_FILES,
      'result_evidence_sha256' => result_evidence, 'leaderboard_eligible' => true
    }
    want.each { |k, v| assert_equal v, m[k], k }
    assert_match(/\A[0-9a-f]{64}\z/, m['submission_key'])
  end

  def test_the_dry_run_passes_every_check_without_tier3
    dry = run_submit(with_tier3: false)['dry']
    assert_equal ['dry_run', false], dry.values_at('status', 'recorded')
    assert_equal({ 'gates' => 'ok', 'jobspec_digest_recompute' => 'ok', 'expected_output_matches_signed' => 'ok',
                   'operator_mode' => 'ok (signed)', 'trust_tier' => 'ok (self_reported)', 'bearer_binding' => 'ok',
                   'record_schema' => 'ok', 'attestor' => 'ok (synoptis loaded)' }, dry['checks'])
    assert_equal result_evidence, dry.dig('would_record', 'result_evidence_sha256')
    assert_equal true, dry.dig('would_record', 'leaderboard_eligible')
  end

  # Drift guard: core's value type keeps Tier3Executor::VerdictResult's members,
  # in order, and its keyword construction (with tier3 on the load path here).
  def test_cores_verdict_result_has_tier3_executors_members_in_order
    $LOAD_PATH.unshift(File.join(CORE_DIR, 'lib')) unless $LOAD_PATH.include?(File.join(CORE_DIR, 'lib'))
    $LOAD_PATH.unshift(TIER3_LIB) unless $LOAD_PATH.include?(TIER3_LIB)
    require 'kairos_mcp/version'
    require 'kairos_mcp/tools/base_tool'
    require 'genomicschain_core'
    require TOOL
    require 'genomicschain_tier3/tier3_executor'
    core = KairosMcp::SkillSets::GenomicschainCore::Tools::GcTier3Submit::VerdictResult
    tier3 = KairosMcp::SkillSets::GenomicschainTier3::Tier3Executor::VerdictResult
    assert_equal tier3.members, core.members
    assert_equal tier3.keyword_init?, core.keyword_init?
  end
end
