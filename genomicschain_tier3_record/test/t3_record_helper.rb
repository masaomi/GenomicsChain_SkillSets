# frozen_string_literal: true

# Shared fixtures for the Tier 3 v0.1 record-side tests (design
# docs/design/tier3_design_v0_1.md §9; names fixed in
# log/tier3_impl_20261020/interface_v0_1.md). Not a test file. The executor
# side's helper (genomicschain_tier3/test/t3_helper.rb) builds on this one.
#
# The anchor is a disposable one: a real Synoptis FileRegistry in a tmpdir,
# real SubmitCore, a stub attestor that stores without signing but names the
# submitter the way SynoptisAttestor.build does (operator_pubkey →
# envelope.submitter_pubkey). Prov records are either made by ProvSubmit from
# a fixture bundle, or planted as a manifest when a test needs a record shape
# the fixtures do not hold (option 2, another record type, another writer).
#
# genomicschain_tier3 is deliberately NOT on this helper's load path: the
# anchor installs core + prov + tier3_record only (operator 2026-10-21, Q5).
#
# Run one file: ruby -Ilib -Itest -I../genomicschain_core/lib -I../genomicschain_tier2/lib \
#   -I../genomicschain_prov/lib -I"$T/synoptis/lib" -I"$T/mmp/lib" test/<file>.rb
require 'minitest/autorun'
require 'minitest/mock'
require 'tmpdir'
require 'json'
require 'digest'
require 'securerandom'
require 'base64'
require 'fileutils'
require 'time'
require 'ed25519'
require 'kairos_mcp/version'
require 'kairos_mcp/skillset'
require 'kairos_mcp/tools/base_tool'
require 'synoptis/proof_envelope'
require 'synoptis/verifier'
require 'synoptis/attestation_engine'
require 'synoptis/registry/file_registry'

%w[genomicschain_core genomicschain_tier2 genomicschain_prov genomicschain_tier3_record].each do |pkg|
  lib = File.expand_path("../../#{pkg}/lib", __dir__)
  $LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
end
require 'genomicschain_core'
require 'genomicschain_prov'
require 'genomicschain_prov/commitment'
require 'genomicschain_prov/prov_submit'

# The record package's namespace, opened so constants below can name it
# before its files load (the tests require those themselves).
module KairosMcp
  module SkillSets
    module GenomicschainTier3Record; end
  end
end

# Stores what SubmitCore hands it, unsigned, keeping the ttl it is given and
# the submitter's pubkey, as SynoptisAttestor.build(operator_pubkey:) does.
# Mirrors SynoptisAttestor#issue's store-time duplicate branch: when Synoptis
# already holds an active proof with the same (attester_id, subject_ref,
# claim), it answers status 'existing' with THAT proof's id (review r3 D2).
class T3StubAttestor
  ATTESTER = 'ed25519:stub'
  attr_reader :registry, :calls

  def initialize(registry:, submitter_pubkey: nil)
    @registry = registry
    @submitter_pubkey = submitter_pubkey
    @calls = []
  end

  def issue(**kw)
    @calls << kw
    engine = ::Synoptis::AttestationEngine.new(registry: @registry,
                                               config: { 'require_signature' => false, 'default_ttl' => 86_400 })
    r = engine.create_attestation(attester_id: ATTESTER, subject_ref: kw[:subject_ref], claim: kw[:claim],
                                  evidence: kw[:evidence], actor_role: kw[:actor_role], ttl: kw[:ttl],
                                  submitter_pubkey: @submitter_pubkey)
    return { status: 'existing', synoptis_proof_id: r[:existing_proof_id] } if r[:status] == 'error' && r[:existing_proof_id]

    { status: r[:status], synoptis_proof_id: r[:proof_id] }
  end
end

module T3RecordHelpers
  T3R = KairosMcp::SkillSets::GenomicschainTier3Record
  GC = KairosMcp::SkillSets::GenomicschainCore
  C = GenomicsChainProv::Commitment
  M = KairosMcp::Manifest
  WORKTREE = File.expand_path('../..', __dir__)
  V03_BUNDLE = File.read(File.join(WORKTREE, 'genomicschain_prov', 'test', 'fixtures', 'record_v0_3', 'bundle.json'))
  # The bytes of counts.tsv the v0.3 fixture bundle fingerprints (its generator, line 50).
  V03_OUTPUT = "gene\tcount\nG1\t1\n"
  TOOL = 'gc_tier3_record_submit'
  ISO = /\A\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ\z/
  PROOF_TTL = 3_153_600_000
  BINDING = %w[subject_ref job_identity inputs_commitment targets comparator tolerance build_plan_digest route_ref
               fingerprint_form data_class].freeze
  NOT_CHECKED = %w[ran_as_stated inputs_are_the_real_data runs_outside_the_record machine
                   route_a_targets_complete].freeze
  # Design §6.2, lines 360 and 362 (label excluded) and 364 (the quoted line).
  ZK_SENTENCE = '証明が示すのは、指定した段の計算が、記録された入力から正しく行われたことだけ。' \
                '対象は指定した段だけで、入力が本当にその生データであるかは示さない。'
  T3_SENTENCE = '保証するのは私たちの手順と記録まで。Tier 3 の記録は「その日、宣言どおりの結果になった」' \
                'という日付つきの観察であり、将来も再現することの約束ではない。'
  TIMES_LINE = '記録にあるのは、宣言が anchor の時刻 T_d に、attestation が T_a に記録されたことと、' \
               '実行者がそう申告したことである。組んだ時刻も走った時刻も記録に無い。'
  # Design §9-5, line 417: what a declaration without an attestation reads.
  NOT_ATTESTED_LINE = '宣言されたが attestation されていない'
  FORBIDDEN = %w[検証済み 再現された].freeze
  OPTION2_JOURNAL = 'gc-zk-journal-0.2'

  def reset_nonces
    KairosMcp::Manifest::Signer.instance_variable_set(:@global_reservation, nil)
  end

  # --- values ----------------------------------------------------------------------

  def hex(label = SecureRandom.hex(4)) = Digest::SHA256.hexdigest(label.to_s)
  def sha(bytes) = Digest::SHA256.hexdigest(bytes)
  def sha1(bytes) = Digest::SHA1.hexdigest(bytes)
  def h_plain(obj) = M.canonical_json_sha256(obj)
  def h_salted(key, obj) = C.commit(key, M.canonical_json(obj))

  # The Predicate rule over [name, algorithm, hex] rows (33:416–428). Each row
  # is its own output, so two outputs sharing a name keep both their rows.
  def rows_digest(rows)
    GenomicsChainProv::Predicate.outputs_digest(rows.map { |n, a, v| { 'name' => n, 'checksum' => { a => v } } })
  end

  def v03_derived = (@v03_derived ||= GenomicsChainProv::Identity.derive(V03_BUNDLE))
  def v03_signed = v03_derived['signed']

  def v03_rows
    v03_derived['np'].outputs.flat_map do |o|
      (o['checksum'] || {}).keys.sort.map { |algo| [o['name'].to_s, algo, o['checksum'][algo].to_s] }
    end
  end

  # One path per row (interface §3): the row's name for each row the
  # comparator compares, nil for the others.
  def default_paths(rows)
    algo = rows.any? { |_, a, _| a == 'hmac_sha256' } ? 'hmac_sha256' : 'sha256'
    rows.map { |n, a, _| a == algo ? n : nil }
  end

  # --- the anchor ------------------------------------------------------------------

  def with_anchor
    Dir.mktmpdir('t3_anchor') do |tmp|
      registry = ::Synoptis::Registry::FileRegistry.new(data_dir: tmp)
      tip = GC::TipSource.new(registry: registry)
      KairosMcp::Manifest::Signer.bootstrap_seen_list!(tip_source: tip)
      yield registry, tip
    end
  end

  def new_key = Ed25519::SigningKey.generate
  def pubkey(sk) = 'ed25519:' + Base64.urlsafe_encode64(sk.verify_key.to_bytes, padding: false)
  def bearer(sk) = Digest::SHA256.hexdigest(pubkey(sk))

  def envelope(sk, params, tip, tool: TOOL, nonce: SecureRandom.hex(16), mode: 'signed')
    tip_hash = tip.is_a?(String) ? tip : tip.latest_tip_hash
    payload = M.canonical_json('mcp_tool_name' => tool, 'params' => params, 'nonce' => nonce, 'chain_tip_hash' => tip_hash)
    { 'mode' => mode, 'pubkey' => pubkey(sk),
      'signature' => { 'algorithm' => 'ed25519', 'signed_fields' => %w[mcp_tool_name params nonce chain_tip_hash],
                       'value' => Base64.urlsafe_encode64(sk.sign(payload), padding: false),
                       'nonce' => nonce, 'chain_tip_hash' => tip_hash } }
  end

  def stub_attestor(registry, operator) = T3StubAttestor.new(registry: registry, submitter_pubkey: operator['pubkey'])

  def submit_declaration(registry, tip, sk, params, route_proof_id: nil, config: {}, op: nil, bearer_hash: nil)
    op ||= envelope(sk, params, tip)
    T3R::RecordSubmit.declaration(
      declaration: params, operator: op, route_proof_id: route_proof_id,
      bearer_pubkey_hash: bearer_hash || bearer(sk), tip_source: tip,
      attestor: stub_attestor(registry, op), registry: registry, config: config
    )
  end

  def submit_attestation(registry, tip, sk, params, config: {}, op: nil, bearer_hash: nil)
    op ||= envelope(sk, params, tip)
    T3R::RecordSubmit.attestation(
      attestation: params, operator: op,
      bearer_pubkey_hash: bearer_hash || bearer(sk), tip_source: tip,
      attestor: stub_attestor(registry, op), registry: registry, config: config
    )
  end

  def manifest_of(registry, proof_id)
    GC::ProofLookup.parse_evidence(registry.find_proof(proof_id).evidence)['manifest']
  end

  def evidence_text(registry, proof_id) = registry.find_proof(proof_id).evidence.to_s

  def manifests_of_type(registry, type)
    registry.read(:proofs).filter_map { |r| GC::ProofLookup.parse_manifest_from_record(r) }
            .select { |m| m['record_type'] == type }
  end

  # A record laid into the registry as a manifest, the way SubmitCore's
  # envelope carries it, under the given envelope submitter. For record
  # shapes no fixture holds and for writers other than the anchor's tool.
  # `claim:` / `subject_ref:` let it carry a victim's real claim (review r3
  # D2: Synoptis then answers the victim's store with 'existing').
  def plant(registry, manifest, submitter_pubkey: nil, claim: nil, subject_ref: nil)
    body = M.canonical_json(manifest)
    evidence = M.canonical_json('manifest' => manifest, 'manifest_body_sha256' => Digest::SHA256.hexdigest(body))
    engine = ::Synoptis::AttestationEngine.new(registry: registry,
                                               config: { 'require_signature' => false, 'default_ttl' => 86_400 })
    r = engine.create_attestation(attester_id: T3StubAttestor::ATTESTER,
                                  subject_ref: (subject_ref || manifest['subject_ref']).to_s,
                                  claim: claim || "planted:#{SecureRandom.hex(8)}", evidence: evidence,
                                  actor_role: 'automated', ttl: PROOF_TTL, submitter_pubkey: submitter_pubkey)
    r[:proof_id] or raise "plant refused: #{r.inspect}"
  end

  # A prov record planted as gc_prov_submit would have written it: the
  # manifest names that tool and its operator, and the envelope's submitter
  # is that operator (the writer rule the anchor applies, interface §2).
  def plant_as_prov_writer(registry, manifest, sk = new_key)
    m = manifest.merge('mcp_tool_name' => 'gc_prov_submit', 'operator' => { 'mode' => 'signed', 'pubkey' => pubkey(sk) })
    plant(registry, m, submitter_pubkey: pubkey(sk))
  end

  # Three writers that are not the anchor's Tier 3 tool, for a record whose
  # manifest operator is sk: another tool name, another envelope submitter,
  # no envelope submitter (as Synoptis attestation_issue stores it).
  # Each is [mcp_tool_name, envelope submitter_pubkey].
  def foreign_writers(sk) = [['gc_something_else', pubkey(sk)], [TOOL, pubkey(new_key)], [TOOL, nil]]

  # A copy of a stored manifest — same submission_key — laid in by a foreign
  # writer, with `extra` fields changed. Returns the planted proof_id.
  def plant_copy(registry, manifest, writer, extra = {})
    tool, submitter = writer
    plant(registry, manifest.merge(extra).merge('mcp_tool_name' => tool), submitter_pubkey: submitter)
  end

  # The fixture bundle's Tier-2.5 record, as gc_prov_submit makes it.
  def prov_record(registry, tip, sk = new_key, bundle = V03_BUNDLE)
    identity = GenomicsChainProv::ProvSubmit.signed_params_for(bundle)
    op = envelope(sk, identity, tip, tool: 'gc_prov_submit')
    out = GenomicsChainProv::ProvSubmit.submit(
      bundle: bundle, identity: identity, operator: op,
      bearer_pubkey_hash: bearer(sk), tip_source: tip, attestor: stub_attestor(registry, op),
      registry: registry, config: {}
    )
    raise "prov record not made: #{out.inspect}" unless out[:status] == 'recorded'

    out[:synoptis_proof_id]
  end

  # An option-2 prov record's manifest over the given hmac rows: a v0.5 record
  # shape whose one receipt declares gc-zk-journal-0.2.
  def option2_manifest(rows, bundle_digest: hex('option 2 bundle'))
    v03_signed.merge(
      'record_type' => 'prov_attestation', 'record_version' => '0.5', 'mcp_tool_name' => 'gc_prov_submit',
      'subject_ref' => "prov:sha256:#{bundle_digest}", 'bundle_digest' => bundle_digest,
      'outputs_digest' => rows_digest(rows),
      'zk_receipts' => [{ 'receipt_sha256' => hex('receipt'), 'image_id' => hex('image'), 'zkvm_name' => 'risc0',
                          'zkvm_version' => '3.0.6', 'stage' => 1, 'journal_convention' => OPTION2_JOURNAL }],
      'trust_tier' => 'self_reported', 'submission_key' => hex('prov submission')
    )
  end

  # --- hand-built params (anchor tests do not depend on the executor tool) -------------

  def route_a_targets(value: sha('hi'), path: 'out.txt')
    { 'kind' => 'paper_declared', 'items' => [{ 'path' => path, 'algorithm' => 'sha256', 'value' => value }] }
  end

  def route_b_targets(rows: v03_rows, bundle_digest: v03_signed['bundle_digest'], outputs_digest: nil, paths: nil)
    { 'kind' => 'tier2_5_bundle', 'bundle_digest' => bundle_digest,
      'outputs_digest' => outputs_digest || rows_digest(rows), 'rows' => rows, 'paths' => paths || default_paths(rows) }
  end

  def declaration(route: 'A', form: 'plain', key: nil, targets: nil, route_ref: nil, comparator: nil, **over)
    d = {
      'subject_ref' => 'repro://656122/C9',
      'job_identity' => { 'rule' => 'gc-job-identity-0.3', 'digest' => hex('job identity') },
      'inputs_commitment' => hex('inputs'),
      'targets' => targets || (route == 'A' ? route_a_targets : route_b_targets),
      'comparator' => comparator || { 'id' => 'exact_sha256', 'version' => '0.2.0' },
      'tolerance' => 'exact',
      'build_plan_digest' => hex('build plan'),
      'route' => route,
      'route_ref' => route_ref || (route == 'A' ? "tier2:#{hex('adjudication')}" : nil),
      'fingerprint_form' => form,
      'data_class' => 'non_human',
      'scored_items' => %w[rebuild rerun reproduce],
      'expires_at' => '2026-11-19T00:00:00Z',
      'attempts_max' => 3,
      'checker' => { 'tool' => 'gc_tier3_attest-0.1.0', 'tree_digest' => hex('checker tree') }
    }
    if route == 'A'
      d.merge!('source' => 'paper_declared', 'source_citation' => 'doi:10.1038/s41467-018-06108-1',
               'validated_by' => 'human:executor')
    end
    d['commitment'] = C.declaration(key) if form == 'salted'
    d.merge(over).compact
  end

  def built_row(i, backend: 'local', env_digest: hex("env #{i}"), m: 1, n: 1)
    { 'attempt' => i, 'backend_id' => backend, 'rebuild' => 'built', 'env_digest' => env_digest,
      'execution_verdict' => 'completed', 'comparison_verdict' => m == n ? 'match_exact' : 'mismatch',
      'm' => m, 'n' => n, 'output_fingerprints' => [{ 'path' => 'out.txt', 'value' => hex("out #{i}") }] }
  end

  def cannot_build_row(i, backend: 'local') = { 'attempt' => i, 'backend_id' => backend, 'rebuild' => 'cannot_build' }

  def attestation_for(decl, ref, attempts: [built_row(1)], **over)
    a = decl.slice(*BINDING, 'commitment')
    a.merge('declaration_ref' => ref, 'attempts' => attempts, 'environment_provenance' => 'declared_lock',
            'result_commitment' => hex('result'), 'process_record_digest' => hex('process'),
            'not_checked' => NOT_CHECKED).merge(over).compact
  end

  # Records a declaration and returns [params, declaration_ref, response].
  def declared(registry, tip, sk, decl = declaration, **kw)
    out = submit_declaration(registry, tip, sk, decl, **kw)
    raise "declaration not recorded: #{out.inspect}" unless out[:status] == 'recorded'

    [decl, out[:declaration_ref], out]
  end
end
