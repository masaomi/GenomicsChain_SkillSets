# frozen_string_literal: true
# Tier-4 distillation record through SubmitCore (self-application design §7.3).
# Not deployed: these tests are the only callers of VerdictSpec::Tier4.
require 'minitest/autorun'
require 'tmpdir'
require 'json'
require 'digest'
require 'securerandom'
require 'base64'
require 'ed25519'
require 'kairos_mcp/version'
require_relative 'proofs_sandbox'
require 'kairos_mcp/skillset'
require 'genomicschain_core'
require 'genomicschain_core/verdict_spec/tier4'

T4Core = KairosMcp::SkillSets::GenomicschainCore

class Tier4StubAttestor
  attr_reader :registry

  def initialize(registry:)
    @registry = registry
  end

  # Exercises SubmitCore's orchestration, not signing (as in tier3_submit_test).
  def issue(**kw)
    engine = ::Synoptis::AttestationEngine.new(registry: @registry, config: { 'require_signature' => false })
    result = engine.create_attestation(
      attester_id: 'ed25519:stub', subject_ref: kw[:subject_ref], claim: kw[:claim],
      evidence: kw[:evidence], actor_role: kw[:actor_role]
    )
    { status: result[:status], synoptis_proof_id: result[:proof_id] }
  end
end

class Tier4SpecTest < Minitest::Test
  FILES = [
    { 'relative_path' => 'SKILL.md', 'sha256' => '1' * 64 },
    { 'relative_path' => 'Snakefile', 'sha256' => '2' * 64 },
    { 'relative_path' => 'scripts/deseq2.R', 'sha256' => '3' * 64 }
  ].freeze

  def setup
    KairosMcp::Manifest::Signer.instance_variable_set(:@global_reservation, nil)
  end

  def digest(files = FILES) = KairosMcp::Manifest::Tier4Builder.package_digest(files)

  def tier3(verdict = 'match_exact', extra = {})
    { 'jobspec_digest' => 'a' * 64, 'result_hash' => 'b' * 64, 'execution_verdict' => 'completed',
      'comparison_verdict' => verdict, 'tier3_record_ref' => nil }.merge(extra)
  end

  def distillation(reversion: 'match_exact', other: :performed, seed_at: '2026-10-03T10:39:08.062Z')
    other_data = if other == :performed
                   tier3('match_exact', 'performed' => true, 'seed' => 589_926_546, 'seed_drawn_at' => seed_at,
                                        'reference_sha256' => 'c' * 64, 'reference_fixed_at' => '2026-10-03T10:45:30.076Z')
                 else
                   { 'performed' => false, 'reason' => 'reference tables differed' }
                 end
    {
      'subject_ref' => 'skill://selfapp/tier4/stage0/rnaseq_two_group_de', 'stage' => 'stage0',
      'package_digest' => digest, 'package_files' => FILES,
      'package_digest_recorded_at' => '2026-10-03T10:39:03.885Z',
      'distiller' => { 'model' => 'claude-opus-5-5', 'context' => 'subagent' },
      'acceptance' => { 'version' => 'tier4-acceptance-v1', 'sha256' => 'd' * 64 },
      'source' => { 'jobspec_digest' => 'e' * 64, 'result_hash' => 'f' * 64, 'tier3_record_ref' => nil },
      'reversion' => tier3(reversion, 'expected_output_sha256' => '9' * 64, 'expected_output_source' => 'paper_declared'),
      'other_data' => other_data
    }
  end

  def spec(d = distillation, files_json: JSON.generate(FILES))
    T4Core::VerdictSpec::Tier4.new(distillation: d, package_files_json: files_json)
  end

  def signed_operator(tip_source, sp)
    sk = Ed25519::SigningKey.generate
    nonce = SecureRandom.hex(16)
    tip = tip_source.latest_tip_hash
    payload = KairosMcp::Manifest.canonical_json(
      'mcp_tool_name' => 'gc_tier4_submit', 'params' => sp.signed_identity_params, 'nonce' => nonce, 'chain_tip_hash' => tip
    )
    pubkey = 'ed25519:' + Base64.urlsafe_encode64(sk.verify_key.to_bytes, padding: false)
    op = { 'mode' => 'signed', 'pubkey' => pubkey,
           'signature' => { 'algorithm' => 'ed25519', 'signed_fields' => %w[mcp_tool_name params nonce chain_tip_hash],
                            'value' => Base64.urlsafe_encode64(sk.sign(payload), padding: false),
                            'nonce' => nonce, 'chain_tip_hash' => tip } }
    [op, Digest::SHA256.hexdigest(pubkey)]
  end

  def submit(sp)
    Dir.mktmpdir do |tmp|
      registry, tip_source, = ProofsSandbox.context(tmp)
      KairosMcp::Manifest::Signer.bootstrap_seen_list!(tip_source: tip_source)
      op, pkhash = signed_operator(tip_source, sp)
      out = T4Core::SubmitCore.submit(spec: sp, operator: op, bearer_pubkey_hash: pkhash, tip_source: tip_source,
                                      registry: registry, attestor: Tier4StubAttestor.new(registry: registry))
      manifest = out[:status] == 'recorded' ? T4Core::ProofLookup.parse_manifest_from_record(registry.read(:proofs).first) : nil
      return [out, manifest]
    end
  end

  def test_records_both_checks_with_derived_flags
    out, manifest = submit(spec)
    assert_equal 'recorded', out[:status]
    assert_equal "tier4:stage0:reversion_passed:other_data_passed:#{digest}:#{out[:submission_key]}", out[:claim]
    assert_equal 'tier4_distillation', manifest['record_type']
    assert_equal true, manifest['reversion_passed']
    assert_equal true, manifest['other_data_passed']
    assert_equal false, manifest['leaderboard_eligible']
    assert_equal false, out[:leaderboard_eligible]
    assert_nil manifest.dig('reversion', 'tier3_record_ref')
    assert KairosMcp::Manifest.validate_tier4!(manifest)
  end

  def test_package_list_that_does_not_hash_to_the_claim_is_refused
    tampered = FILES.map(&:dup).tap { |f| f[1]['sha256'] = '0' * 64 }
    assert_raises(T4Core::SubmitCore::DigestMismatch) { submit(spec(files_json: JSON.generate(tampered))) }
  end

  def test_a_supplied_pass_flag_is_refused
    assert_raises(T4Core::SubmitCore::IdentityMismatch) { submit(spec(distillation.merge('reversion_passed' => true))) }
    err = assert_raises(KairosMcp::Manifest::ManifestError) do
      KairosMcp::Manifest.build_tier4_distillation(distillation.merge('other_data_passed' => true, 'operator' => anon))
    end
    assert_match(/derived, not supplied/, err.message)
  end

  def test_seed_drawn_before_the_package_was_fixed_is_refused
    err = assert_raises(KairosMcp::Manifest::ManifestError) do
      KairosMcp::Manifest.build_tier4_distillation(
        distillation(seed_at: '2026-10-03T10:39:00.000Z').merge('operator' => anon)
      )
    end
    assert_match(/INV-S4 order violated/, err.message)
  end

  def test_a_failed_reversion_is_recorded_as_failed
    record = KairosMcp::Manifest.build_tier4_distillation(distillation(reversion: 'mismatch').merge('operator' => anon))
    assert_equal false, record['reversion_passed']
    assert KairosMcp::Manifest.validate_tier4!(record)
    assert_match(/:reversion_failed:other_data_passed:/, spec(distillation(reversion: 'mismatch')).claim_for(submission_key: 'k'))
  end

  def test_other_data_not_performed_is_null_not_false
    record = KairosMcp::Manifest.build_tier4_distillation(distillation(other: :not_performed).merge('operator' => anon))
    assert_nil record['other_data_passed']
    assert KairosMcp::Manifest.validate_tier4!(record)
    assert_match(/:other_data_not_performed:/, spec(distillation(other: :not_performed)).claim_for(submission_key: 'k'))
  end

  def test_schema_refuses_a_leaderboard_eligible_distillation
    record = KairosMcp::Manifest.build_tier4_distillation(distillation.merge('operator' => anon))
    assert_raises(KairosMcp::Manifest::SchemaViolation) do
      KairosMcp::Manifest.validate_tier4!(record.merge('leaderboard_eligible' => true))
    end
  end

  def test_digest_uses_the_s_minus_1_tree_rule
    lines = FILES.sort_by { |f| f['relative_path'].b }.map { |f| "#{f['sha256']}  #{f['relative_path']}\n" }.join
    assert_equal Digest::SHA256.hexdigest(lines), digest
    assert_equal digest, digest(FILES.reverse)
  end

  private

  def anon = { 'mode' => 'anonymous', 'anonymous_id' => 'anonymous-0123456789abcdef' }
end
