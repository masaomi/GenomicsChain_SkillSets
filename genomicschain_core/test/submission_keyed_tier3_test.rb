# frozen_string_literal: true
# Tier 3 v0.1 §9-1, §9-7 (design docs/design/tier3_design_v0_1.md): the two
# new record types join SubmitCore::SUBMISSION_KEYED (19:26, 19:247), so their
# idempotency key is sha256(submission_key) (36:247–249) instead of the
# Tier 1–4 derivation, which would make it a per-key constant (19:257–262).
# Every other type keeps its key (fixtures/idempotency_keys_r0.json, pinned).
#
# A minimal spec stands in for the Tier 3 ones so this file judges the core
# change alone.
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

class SubmissionKeyedTier3Test < Minitest::Test
  GCK = KairosMcp::SkillSets::GenomicschainCore
  R0_FIXTURE = File.expand_path('fixtures/idempotency_keys_r0.json', __dir__)
  R0_FIXTURE_SHA256 = '9c06245f04cd5d852034ce35b6c3d193d074a5b419cfab5c313eeb0df332f368'

  class Stub
    attr_reader :registry

    def initialize(registry:) = (@registry = registry)

    def issue(**kw)
      engine = ::Synoptis::AttestationEngine.new(registry: @registry, config: { 'require_signature' => false })
      r = engine.create_attestation(attester_id: 'ed25519:stub', subject_ref: kw[:subject_ref], claim: kw[:claim],
                                    evidence: kw[:evidence], actor_role: kw[:actor_role])
      { status: r[:status], synoptis_proof_id: r[:proof_id] }
    end
  end

  # The SubmitCore hooks, nothing else: the manifest carries the record_type
  # under test and the two fields the legacy derivation reads.
  class KeyedSpec
    MCP_TOOL = 'gc_submission_keyed_fixture'

    def initialize(record_type, params)
      @record_type = record_type
      @params = params
    end

    def subject_ref = 'fixture:submission-keyed'
    def trust_tier_gate!; end
    def parse_digest_subject! = @params
    def apply_gates!(_parsed); end
    def recompute_digest!(parsed) = KairosMcp::Manifest.canonical_json_sha256(parsed)
    def claimed_digest = KairosMcp::Manifest.canonical_json_sha256(@params)
    def assert_submitted_matches_signed!; end
    def reject_client_server_set_fields!(_parsed); end
    def signed_identity_params = @params
    def server_set_fields(_pubkey) = {}

    def build_manifest(operator:, submission_key:, server_fields:)
      { 'record_type' => @record_type, 'jobspec_digest' => 'a' * 64, 'result_hash' => 'b' * 64,
        'submission_key' => submission_key, 'operator' => operator }.merge(server_fields)
    end

    def claim_for(submission_key:) = "fixture:#{@record_type}:#{submission_key}"
  end

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

  def submit_twice(record_type)
    with_proofs do |registry, tip_source|
      sk = Ed25519::SigningKey.generate
      pubkey = 'ed25519:' + Base64.urlsafe_encode64(sk.verify_key.to_bytes, padding: false)
      params = { 'record' => record_type, 'n' => SecureRandom.hex(8) }
      nonce = SecureRandom.hex(16)
      tip = tip_source.latest_tip_hash
      payload = KairosMcp::Manifest.canonical_json('mcp_tool_name' => KeyedSpec::MCP_TOOL, 'params' => params,
                                                   'nonce' => nonce, 'chain_tip_hash' => tip)
      op = { 'mode' => 'signed', 'pubkey' => pubkey,
             'signature' => { 'algorithm' => 'ed25519', 'signed_fields' => %w[mcp_tool_name params nonce chain_tip_hash],
                              'value' => Base64.urlsafe_encode64(sk.sign(payload), padding: false),
                              'nonce' => nonce, 'chain_tip_hash' => tip } }
      run = lambda do
        GCK::SubmitCore.submit(spec: KeyedSpec.new(record_type, params), operator: op,
                               bearer_pubkey_hash: Digest::SHA256.hexdigest(pubkey), tip_source: tip_source,
                               registry: registry, attestor: Stub.new(registry: registry))
      end
      yield run.call, run.call, pubkey
    end
  end

  def test_the_two_tier3_record_types_are_submission_keyed
    assert_equal %w[prov_attestation prov_reachability tier3_declaration tier3_attestation].sort,
                 GCK::SubmitCore::SUBMISSION_KEYED.sort
  end

  %w[tier3_declaration tier3_attestation].each do |type|
    define_method("test_#{type}_is_keyed_by_the_sha256_of_its_submission_key_fresh_and_recovered") do
      submit_twice(type) do |fresh, recovered, _|
        assert_equal [false, true], [fresh[:recovered], recovered[:recovered]]
        assert_equal fresh[:submission_key], recovered[:submission_key]
        assert_equal Digest::SHA256.hexdigest(fresh[:submission_key]), fresh[:idempotency_key]
        assert_equal fresh[:idempotency_key], recovered[:idempotency_key]
      end
    end
  end

  # Record 0.3 keeps the Tier 1–4 branch: jobspec_digest | result_hash | pubkey.
  def test_record_0_3_keeps_its_legacy_idempotency_key
    refute_includes GCK::SubmitCore::SUBMISSION_KEYED, 'tier3_verdict'
    submit_twice('tier3_verdict') do |fresh, recovered, pubkey|
      want = Digest::SHA256.hexdigest(['a' * 64, 'b' * 64, pubkey].join('|'))
      assert_equal [want, want], [fresh[:idempotency_key], recovered[:idempotency_key]]
    end
  end

  def test_no_other_existing_type_joined_the_list
    %w[tier1_report tier2_adjudication tier3_verdict tier4_distillation].each do |t|
      refute_includes GCK::SubmitCore::SUBMISSION_KEYED, t
    end
  end

  def test_the_r0_idempotency_fixture_is_untouched
    assert_equal R0_FIXTURE_SHA256, Digest::SHA256.file(R0_FIXTURE).hexdigest
  end
end
