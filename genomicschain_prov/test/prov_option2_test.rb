# frozen_string_literal: true

# Tier 2.5 v0.1.16, option 2 — salted fingerprints and gc-zk-journal-0.2
# (design docs/design/prov_v0_1_16_zk_confidentiality_draft.md §5–§7, §10).
#
# Two kinds of test sit here. The logic of ③④⑤, the refusals and the S4
# setting is exercised with a stubbed verifier, so it never goes untested.
# The tests that need a real receipt use the TEST-ONLY fixture
# fixtures/zk_sizefactor_s1_v02 (made by the parallel Rust work, keys are
# 0x00..0x1f and 0x20..0x3f) and the gc_zk_verify binary; without the binary
# they skip, and per §10 a skipped proof-dependent test counts as NOT passed.
#
# Run: ruby -Ilib -Itest -I../genomicschain_core/lib -I../genomicschain_tier2/lib \
#        -I"$T/synoptis/lib" -I"$T/mmp/lib" test/prov_option2_test.rb
require 'minitest/autorun'
require 'minitest/mock'
require 'tmpdir'
require 'json'
require 'digest'
require 'securerandom'
require 'base64'
require 'fileutils'
require 'open3'
require 'rbconfig'
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
require 'genomicschain_prov/commitment'
require 'genomicschain_prov/writer/environment'
require 'genomicschain_prov/prov_submit'
require 'genomicschain_prov/place_extension'
require 'genomicschain_prov/verifier'
require_relative '../tools/gc_prov_submit'
require_relative 'confidentiality_scan'

class ProvOption2Test < Minitest::Test
  GC = KairosMcp::SkillSets::GenomicschainCore
  W = GenomicsChainProv::Writer
  Env = W::Environment
  Bco = GenomicsChainProv::Adapters::Bco
  Identity = GenomicsChainProv::Identity
  Prov = GenomicsChainProv::VerdictSpec::Prov
  ProvSubmit = GenomicsChainProv::ProvSubmit
  C = GenomicsChainProv::Commitment
  ZkV = GenomicsChainProv::ZkVerifier
  FIX = File.expand_path('fixtures/zk_sizefactor_s1_v02', __dir__)
  KEY_A = File.binread(File.join(FIX, 'test_key.bin'))
  KEY_B = File.binread(File.join(FIX, 'test_key_b.bin'))
  IMAGE_V02 = File.read(File.join(FIX, 'image_id_v02.txt')).strip
  IMAGE_V01 = File.read(File.join(FIX, 'image_id_v01.txt')).strip
  INPUT = File.binread(File.join(FIX, 'S1_odd.kmat'))
  OUTPUT = File.binread(File.join(FIX, 'S1_odd__valid_exact.sfq3'))
  ALTERED = File.binread(File.join(FIX, 'S1_odd__altered_output.sfq3'))
  EXPECTED = JSON.parse(File.read(File.join(FIX, 'expected_journal_v02.json')))
  ON = { 'genomicschain' => { 'zk' => { 'confidential_receipts' => true } } }.freeze
  OFF = { 'genomicschain' => { 'zk' => { 'confidential_receipts' => false } } }.freeze
  IN = 'S1_odd.kmat'
  OUT = 'S1_odd__valid_exact.sfq3'

  def setup
    KairosMcp::Manifest::Signer.instance_variable_set(:@global_reservation, nil)
  end

  def receipt(name) = File.binread(File.join(FIX, name))

  # --- bundles ---------------------------------------------------------------------

  def plan(receipt_file:, image_id:, description: 'size factors for the matrix')
    W.normalise_plan(
      'name' => 'size-factor-check', 'version' => '0.1.0', 'script' => 'run.sh',
      'runtime' => { 'engine' => 'sh', 'version' => '5.2.21', 'uri' => '/bin/sh', 'path' => '/bin/sh' },
      'platform' => { 'cpu_architecture' => 'arm64', 'os_name' => 'Darwin', 'os_release' => '23.6.0' },
      'stages' => [{ 'name' => 'sizefactor', 'description' => description, 'inputs' => [IN], 'outputs' => [OUT],
                     'tools' => [{ 'name' => 'checker.sh', 'version' => '0.1.0', 'uri' => 'tools/checker.sh' }] }],
      'zk_receipts' => [{ 'receipt' => receipt_file, 'image_id' => image_id, 'zkvm_version' => '3.0.6',
                          'step_number' => 1, 'input' => IN, 'output' => OUT }]
    )
  end

  # The computation's files in a directory, then the bundle as the writer
  # library writes it. key: nil gives an option-1 bundle.
  def bundle(key: KEY_A, receipt_name: 'receipt_v02.bin', image_id: IMAGE_V02, input: INPUT, output: OUTPUT,
             object_id: '00000000-0000-4000-8000-000000000116', description: 'size factors for the matrix')
    in_run(input: input, output: output, receipt_name: receipt_name) do |dir|
      pl = plan(receipt_file: receipt_name, image_id: image_id, description: description)
      r = Env.resolve!(pl, base_dir: dir, docker: false, commitment_key: key)
      d = Env.zk_declarations(pl['zk_receipts'], base_dir: dir, journal: key ? W::ZK_JOURNAL_V02 : W::ZK_JOURNAL)
      JSON.generate(W.build(pl, checksums: r['checksums'], object_id: "urn:uuid:#{object_id}",
                                created: '2026-10-19T00:00:00Z', platform: pl['platform'],
                                zk_receipts: d['zk_receipts'], commitment: key && C.declaration(key)))
    end
  end

  def in_run(input:, output:, receipt_name:)
    Dir.mktmpdir('prov_option2') do |dir|
      FileUtils.mkdir_p(File.join(dir, 'tools'))
      File.binwrite(File.join(dir, IN), input)
      File.binwrite(File.join(dir, OUT), output)
      File.binwrite(File.join(dir, receipt_name), receipt(receipt_name))
      File.write(File.join(dir, 'tools', 'checker.sh'), "#!/bin/sh\n# runs the zk checker host\n")
      File.write(File.join(dir, 'run.sh'), "#!/bin/sh\nsh tools/checker.sh\n")
      yield dir
    end
  end

  # The files the bundle fingerprints (for T1 and T3).
  def bundle_files(input: INPUT, output: OUTPUT)
    { IN => input, OUT => output, 'tools/checker.sh' => "#!/bin/sh\n# runs the zk checker host\n",
      'run.sh' => "#!/bin/sh\nsh tools/checker.sh\n", '/bin/sh' => File.binread('/bin/sh') }
  end

  def ext(text) = JSON.parse(text)['extension_domain'].first['genomicschain_extension']

  def edit(text)
    j = JSON.parse(text)
    yield j, j['extension_domain'].first['genomicschain_extension']
    JSON.generate(j)
  end

  def receipt_bytes(bytes)
    { Digest::SHA256.hexdigest(bytes) => Base64.strict_encode64(bytes) }
  end

  # --- a stubbed verifier: the binary's answer, chosen by the test --------------------

  class FakeZk < GenomicsChainProv::ZkVerifier
    attr_reader :calls

    def initialize(answer)
      super(bin: '/nonexistent/gc_zk_verify')
      @answer = answer
      @calls = []
    end

    def run(_bytes, _image_id, journal = nil)
      @calls << journal
      @answer
    end
  end

  # What an honest checker's journal holds for this bundle: the values a
  # verified gc-zk-journal-0.2 receipt for key A and the valid claim reports.
  def v02_answer(**over)
    { 'tool' => 'gc_zk_verify', 'version' => '0.2.0', 'risc0_zkvm' => '3.0.6',
      'journal_convention' => 'gc-zk-journal-0.2', 'verified' => true, 'journal_ok' => true,
      'receipt_kind' => 'succinct', 'journal_input_sha256' => nil, 'journal_output_sha256' => nil,
      'error' => nil }.merge(EXPECTED).merge(over.transform_keys(&:to_s))
  end

  # A verifier that must not be reached.
  class NeverZk < GenomicsChainProv::ZkVerifier
    def initialize = super(bin: '/nonexistent/gc_zk_verify')
    def run(*) = raise('the verifier was called')
  end

  def real_verifier
    unless GenomicsChainProv::ZkVerifier.available?
      skip 'gc_zk_verify not built (cargo build --release in genomicschain_prov/zk_verifier) — per design §10 this ' \
           'test is NOT passed'
    end
    GenomicsChainProv::ZkVerifier.new
  end

  # --- the anchor's context ---------------------------------------------------------

  def with_proofs
    Dir.mktmpdir do |tmp|
      registry = ::Synoptis::Registry::FileRegistry.new(data_dir: tmp)
      tip_source = GC::TipSource.new(registry: registry)
      KairosMcp::Manifest::Signer.bootstrap_seen_list!(tip_source: tip_source)
      yield registry, tip_source, tmp
    end
  end

  def signed_operator(tip_source, params, sk: Ed25519::SigningKey.generate)
    nonce = SecureRandom.hex(16)
    tip = tip_source.latest_tip_hash
    payload = KairosMcp::Manifest.canonical_json('mcp_tool_name' => 'gc_prov_submit', 'params' => params,
                                                 'nonce' => nonce, 'chain_tip_hash' => tip)
    pubkey = 'ed25519:' + Base64.urlsafe_encode64(sk.verify_key.to_bytes, padding: false)
    op = { 'mode' => 'signed', 'pubkey' => pubkey,
           'signature' => { 'algorithm' => 'ed25519', 'signed_fields' => %w[mcp_tool_name params nonce chain_tip_hash],
                            'value' => Base64.urlsafe_encode64(sk.sign(payload), padding: false),
                            'nonce' => nonce, 'chain_tip_hash' => tip } }
    [op, Digest::SHA256.hexdigest(pubkey)]
  end

  class StubAttestor
    attr_reader :registry

    def initialize(registry:) = @registry = registry

    def issue(**kw)
      engine = ::Synoptis::AttestationEngine.new(registry: @registry,
                                                 config: { 'require_signature' => false, 'default_ttl' => 86_400 })
      r = engine.create_attestation(attester_id: 'ed25519:stub', subject_ref: kw[:subject_ref], claim: kw[:claim],
                                    evidence: kw[:evidence], actor_role: kw[:actor_role], ttl: kw[:ttl],
                                    actor_user_id: 'customer')
      { status: r[:status], synoptis_proof_id: r[:proof_id] }
    end
  end

  def record(registry, text, bytes:, verifier:, config: ON, tip_source: nil)
    tip_source ||= GC::TipSource.new(registry: registry)
    identity = ProvSubmit.signed_params_for(text)
    op, pkhash = signed_operator(tip_source, identity)
    ProvSubmit.submit(bundle: text, identity: identity, operator: op, bearer_pubkey_hash: pkhash,
                      tip_source: tip_source, attestor: StubAttestor.new(registry: registry), registry: registry,
                      zk_receipt_bytes: bytes, zk_verifier: verifier, config: config)
  end

  def manifests(registry)
    registry.read(:proofs).map { |r| GC::ProofLookup.parse_manifest_from_record(r) }
  end

  def refused(code, &block)
    err = assert_raises(GC::SubmitCore::SubmitError, &block)
    assert_includes err.message, code
    err
  end

  # ===================================================================================
  # Step 7 — the writer (prov-writer-0.4.0)
  # ===================================================================================

  def test_an_option2_bundle_carries_only_salted_fingerprints_and_never_the_key
    text = bundle
    e = ext(text)
    assert_equal 'prov-writer-0.4.0', e.dig('producer', 'version')
    assert_equal({ 'rule' => 'gc-commitment-0.1', 'key_id' => EXPECTED['journal_key_id'] }, e['commitment'])
    assert(e['checksums'].all? { |c| c.keys.sort == %w[hmac_sha256 uri] }, 'every item is exactly {uri, hmac_sha256}')
    assert_equal 5, e['checksums'].length, 'input, output, tool, script, runtime'
    by = e['checksums'].to_h { |c| [c['uri'], c['hmac_sha256']] }
    assert_equal EXPECTED['journal_input_commitment'], by[IN]
    assert_equal EXPECTED['journal_output_commitment'], by[OUT]
    refute_includes text, 'sha1_checksum'
    assert_equal ['gc-zk-journal-0.2'], e['zk_receipts'].map { |r| r['journal'] }
    hits = ConfidentialityScan.scan(ConfidentialityScan.probes(files: bundle_files, output: OUTPUT, key: KEY_A),
                                    'bundle' => text)
    assert_empty hits, 'no plain fingerprint, no output bytes and no key in the bundle'
  end

  def test_the_adapter_grades_an_option2_bundle_as_it_grades_the_same_bundle_in_option1
    salted = Identity.derive(bundle)
    plain = Identity.derive(bundle(key: nil, receipt_name: 'receipt_v01.bin', image_id: IMAGE_V01))
    assert_empty salted['np'].refusals
    assert_empty plain['np'].refusals
    keys = Identity::COUNT_FIELDS - ['outputs_digest']
    assert_equal plain['signed'].slice(*keys), salted['signed'].slice(*keys)
    %w[grade_overall grade_inputs grade_workflow grade_runtime grade_software].each do |k|
      assert_equal plain['signed'][k], salted['signed'][k], k
    end
    assert_equal 'immutable', salted['signed']['grade_inputs']
    # §6.1: the outputs_digest rows name the field, so the method is hmac_sha256
    rows = [[OUT, 'hmac_sha256', EXPECTED['journal_output_commitment']]]
    assert_equal Digest::SHA256.hexdigest(JSON.generate(rows)), salted['signed']['outputs_digest']
    assert_equal 'prov-adapter-bco-0.5.0', salted['signed']['adapter_version']
  end

  def test_the_writer_refuses_to_mix_the_two_options
    pl = plan(receipt_file: 'r.bin', image_id: IMAGE_V02)
    v02 = [{ 'journal' => 'gc-zk-journal-0.2' }]
    v01 = [{ 'journal' => 'gc-zk-journal-0.1' }]
    salted = { IN => { 'hmac_sha256' => 'a' * 64 } }
    plain = { IN => { 'sha1' => 'b' * 40, 'sha256' => 'c' * 64 } }
    decl = C.declaration(KEY_A)
    assert_raises(W::PlanError) { W.build(pl, checksums: salted, zk_receipts: [], commitment: decl) }
    assert_raises(W::PlanError) { W.build(pl, checksums: salted, zk_receipts: v01, commitment: decl) }
    assert_raises(W::PlanError) { W.build(pl, checksums: plain, zk_receipts: v02, commitment: decl) }
    assert_raises(W::PlanError) { W.build(pl, checksums: plain, zk_receipts: v02) }
    assert_raises(W::PlanError) { W.build(pl, checksums: salted, zk_receipts: v01) }
    whole = W.zk_declaration({ 'image_id' => IMAGE_V02, 'zkvm_version' => '3.0.6', 'step_number' => 1, 'input' => IN,
                               'output' => OUT }, 'f' * 64, journal: W::ZK_JOURNAL_V02)
    both = { IN => { 'hmac_sha256' => 'a' * 64 }, OUT => { 'hmac_sha256' => 'b' * 64 } }
    assert W.build(pl, checksums: both, zk_receipts: [whole], commitment: decl)
  end

  # H2 (round-1 implementation review): in option 2 the writer reads the
  # bundle it made with the adapter's own admission and refuses, before
  # anything is written, a bundle the anchor would refuse — here a 0.2
  # declaration whose output has no hmac_sha256 (Sonnet P3, --no-checksums).
  def test_r1_h2_build_refuses_an_option2_bundle_with_a_declaration_defect
    pl = plan(receipt_file: 'r.bin', image_id: IMAGE_V02)
    whole = W.zk_declaration({ 'image_id' => IMAGE_V02, 'zkvm_version' => '3.0.6', 'step_number' => 1, 'input' => IN,
                               'output' => OUT }, 'f' * 64, journal: W::ZK_JOURNAL_V02)
    only_in = { IN => { 'hmac_sha256' => 'a' * 64 } }
    err = assert_raises(W::PlanError) { W.build(pl, checksums: only_in, zk_receipts: [whole], commitment: C.declaration(KEY_A)) }
    assert_includes err.message, 'output_has_no_hmac_sha256'
    refute_includes err.message, 'a' * 64
    err = assert_raises(W::PlanError) { W.build(pl, checksums: {}, zk_receipts: [whole], commitment: C.declaration(KEY_A)) }
    assert_includes err.message, 'input_has_no_hmac_sha256'
  end

  # The enricher in option 2: a sha1_checksum the producer already wrote is
  # removed, and only salted rows and the commitment are written.
  def test_the_nextflow_enricher_in_option2_strips_sha1_and_writes_salted_rows
    require 'genomicschain_prov/writer/nextflow_run'
    nf = GenomicsChainProv::Writer::NextflowRun
    thin = JSON.parse(bundle(key: nil, receipt_name: 'receipt_v01.bin', image_id: IMAGE_V01))
    thin['extension_domain'] = []
    thin['io_domain']['input_subdomain'].first['uri']['sha1_checksum'] = Digest::SHA1.hexdigest(INPUT)
    decl = W.zk_declaration({ 'image_id' => IMAGE_V02, 'zkvm_version' => '3.0.6', 'step_number' => 1, 'input' => IN,
                              'output' => OUT }, 'f' * 64, journal: W::ZK_JOURNAL_V02)
    out, notes = nf.enrich(thin, checksums: { IN => { 'hmac_sha256' => C.commit(KEY_A, INPUT) } }, zk_receipts: [decl],
                                 commitment: C.declaration(KEY_A))
    text = JSON.generate(out)
    refute_includes text, 'sha1_checksum'
    before = JSON.generate(thin).scan('"sha1_checksum"').length
    assert_operator before, :>=, 1
    assert(notes.any? { |n| n.include?("removed #{before} sha1_checksum") }, notes.inspect)
    assert_equal [{ 'uri' => IN, 'hmac_sha256' => C.commit(KEY_A, INPUT) }], ext(text)['checksums']
    assert_equal C.declaration(KEY_A), ext(text)['commitment']
    assert_empty refusals(text)
  end

  def test_the_extension_schema_accepts_what_the_writer_writes_in_both_options
    begin
      require 'json_schemer'
    rescue LoadError
      skip 'json_schemer not installed'
    end
    path = File.expand_path('../../genomicschain_core/schemas/bco_extension_genomicschain_v0_1.json', __dir__)
    schemer = JSONSchemer.schema(JSON.parse(File.read(path)))
    [bundle, bundle(key: nil, receipt_name: 'receipt_v01.bin', image_id: IMAGE_V01)].each do |t|
      assert_empty schemer.validate(ext(t)).map { |x| x['error'] }
    end
    both = ext(bundle).merge('checksums' => [{ 'uri' => 'x', 'sha256' => 'a' * 64, 'hmac_sha256' => 'b' * 64 }])
    refute schemer.valid?(both), 'exactly one of sha256 | hmac_sha256'
    neither = ext(bundle).merge('checksums' => [{ 'uri' => 'x' }])
    refute schemer.valid?(neither)
  end

  def test_gc_prov_write_makes_a_key_alone_then_writes_an_option2_bundle_without_it
    script = File.expand_path('../bin/gc_prov_write.rb', __dir__)
    in_run(input: INPUT, output: OUTPUT, receipt_name: 'receipt_v02.bin') do |dir|
      key_path = File.join(dir, 'keys', 'run.key')
      FileUtils.mkdir_p(File.dirname(key_path))
      _o, e, st = Open3.capture3(RbConfig.ruby, script, '--new-commitment-key', key_path)
      assert st.success?, e
      key = File.binread(key_path)
      assert_equal 32, key.bytesize
      refute_includes e, key.unpack1('H*'), 'the key is not printed'
      _o, _e, st = Open3.capture3(RbConfig.ruby, script, '--new-commitment-key', key_path)
      refute st.success?, 'an existing key is never overwritten'
      assert_equal key, File.binread(key_path)

      File.write(File.join(dir, 'plan.json'), JSON.generate(
        'name' => 'x', 'script' => 'run.sh',
        'stages' => [{ 'name' => 's', 'inputs' => [IN], 'outputs' => [OUT] }],
        'zk_receipts' => [{ 'receipt' => 'receipt_v02.bin', 'image_id' => IMAGE_V02, 'zkvm_version' => '3.0.6',
                            'step_number' => 1, 'input' => IN, 'output' => OUT }]
      ))
      out_path = File.join(dir, 'bco.json')
      _o, e, st = Open3.capture3(RbConfig.ruby, script, '--plan', File.join(dir, 'plan.json'), '--commitment-key',
                                 key_path, '--out', out_path, '--no-machine', '--no-platform', '--no-docker')
      assert st.success?, e
      text = File.read(out_path)
      assert_equal C.key_id(key), ext(text).dig('commitment', 'key_id')
      assert_equal C.commit(key, OUTPUT), ext(text)['checksums'].find { |c| c['uri'] == OUT }['hmac_sha256']
      [key, key.unpack1('H*'), Base64.strict_encode64(key)].each do |k|
        refute_includes text.b, k.b
        refute_includes e.b, k.b
      end
      _o, e, st = Open3.capture3(RbConfig.ruby, script, '--plan', File.join(dir, 'plan.json'), '--commitment-key',
                                 key_path, '--out', key_path, '--no-machine', '--no-platform', '--no-docker')
      refute st.success?
      assert_includes e, 'cannot be the same file'
      File.binwrite(File.join(dir, 'short.key'), key[0, 31])
      _o, e, st = Open3.capture3(RbConfig.ruby, script, '--plan', File.join(dir, 'plan.json'), '--commitment-key',
                                 File.join(dir, 'short.key'), '--no-machine', '--no-platform', '--no-docker')
      refute st.success?
      assert_includes e, 'exactly 32 bytes'
    end
  end

  # ===================================================================================
  # Step 3 — the adapter's refusals (§6.1, S2, S3 (vii))
  # ===================================================================================

  def refusals(text) = Identity.admission(Identity.derive(text))['bundle_refusals']

  def test_the_adapter_refusals_by_code
    v1 = bundle(key: nil, receipt_name: 'receipt_v01.bin', image_id: IMAGE_V01)
    assert_empty refusals(bundle)
    assert_empty refusals(v1)

    mixed = edit(bundle) { |_j, e| e['zk_receipts'] << e['zk_receipts'].first.merge('journal' => 'gc-zk-journal-0.1', 'sha256' => 'e' * 64) }
    assert_includes refusals(mixed), 'mixed_journal_conventions'

    plain_item = edit(bundle) { |_j, e| e['checksums'] << { 'uri' => 'other', 'sha256' => 'a' * 64 } }
    assert_equal ['plain_fingerprint_in_option2_bundle'], refusals(plain_item)
    extra_field = edit(bundle) { |_j, e| e['checksums'].first['md5'] = 'b' * 32 }
    assert_equal ['plain_fingerprint_in_option2_bundle'], refusals(extra_field), 'an allow-list, not a deny-list'
    sha1 = edit(bundle) { |j, _e| j['io_domain']['output_subdomain'].first['uri']['sha1_checksum'] = 'c' * 40 }
    assert_equal ['plain_fingerprint_in_option2_bundle'], refusals(sha1)
    sha1_tool = edit(bundle) do |j, _e|
      j['description_domain']['pipeline_steps'].first['prerequisite'].first['uri']['sha1_checksum'] = 'd' * 40
    end
    assert_equal ['plain_fingerprint_in_option2_bundle'], refusals(sha1_tool), 'anywhere in the bundle'
    second_block = edit(bundle) do |j, _e|
      j['extension_domain'] << { 'genomicschain_extension' => { 'checksums' => [{ 'uri' => 'copy', 'sha256' => 'a' * 64 }] } }
    end
    assert_equal ['plain_fingerprint_in_option2_bundle'], refusals(second_block), 'in any extension block'

    hmac_in_v1 = edit(v1) { |_j, e| e['checksums'] << { 'uri' => 'other', 'hmac_sha256' => 'a' * 64 } }
    assert_equal ['commitment_outside_option2'], refusals(hmac_in_v1)
    commit_in_v1 = edit(v1) { |_j, e| e['commitment'] = C.declaration(KEY_A) }
    assert_equal ['commitment_outside_option2'], refusals(commit_in_v1)
    no_receipt = edit(bundle) { |_j, e| e.delete('zk_receipts') }
    assert_equal ['commitment_outside_option2'], refusals(no_receipt), 'salted fingerprints need a 0.2 receipt'

    adm = Identity.admission(Identity.derive(plain_item))
    refute adm['issuable']
    refute_includes JSON.generate(adm), 'a' * 64, 'codes, never values'
  end

  def test_two_extension_blocks_with_different_commitments_record_neither
    two = edit(bundle) { |j, _e| j['extension_domain'] << { 'genomicschain_extension' => { 'commitment' => C.declaration(KEY_B) } } }
    np = Identity.derive(two)['np']
    assert_equal({ 'state' => 'conflict', 'key_id' => nil }, np.commitment)
    assert_empty np.refusals, 'not a refusal of the bundle: the 0.2 receipts fail ⑤'
    same = edit(bundle) { |j, _e| j['extension_domain'] << { 'genomicschain_extension' => { 'commitment' => C.declaration(KEY_A) } } }
    assert_equal 'ok', Identity.derive(same)['np'].commitment['state'], 'two blocks saying the same thing agree'
  end

  # ===================================================================================
  # Step 5 — the anchor: S4, ③④⑤ (stubbed verifier)
  # ===================================================================================

  def test_with_the_setting_off_a_02_bundle_is_refused_before_any_receipt_is_verified
    with_proofs do |registry, tip_source|
      b = bundle
      [nil, {}, OFF, { 'genomicschain' => { 'zk' => { 'confidential_receipts' => 'true' } } }].each do |cfg|
        refused('convention_not_offered') do
          record(registry, b, bytes: receipt_bytes(receipt('receipt_v02.bin')), verifier: NeverZk.new,
                              config: cfg || {}, tip_source: tip_source)
        end
      end
      assert_empty registry.read(:proofs)
      # the same anchor still records option 1 (the setting is about 0.2 only)
      v1 = bundle(key: nil, receipt_name: 'receipt_v01.bin', image_id: IMAGE_V01)
      answer = { 'tool' => 'gc_zk_verify', 'version' => '0.2.0', 'risc0_zkvm' => '3.0.6',
                 'journal_convention' => 'gc-zk-journal-0.1', 'verified' => true, 'journal_ok' => true,
                 'journal_input_sha256' => Digest::SHA256.hexdigest(INPUT),
                 'journal_output_sha256' => Digest::SHA256.hexdigest(OUTPUT) }
      fake = FakeZk.new(answer)
      out = record(registry, v1, bytes: receipt_bytes(receipt('receipt_v01.bin')), verifier: fake, config: OFF,
                                 tip_source: tip_source)
      assert_equal 'recorded', out[:status]
      assert_equal [nil], fake.calls, 'a 0.1 receipt is verified without --journal (§9 deployment note)'
    end
  end

  def test_the_customer_check_says_issuable_for_a_bundle_an_anchor_with_the_setting_off_refuses
    adm = Identity.admission(Identity.derive(bundle))
    assert adm['issuable'], 'Identity.admission reads no configuration (S4)'
    assert_equal ['gc-zk-journal-0.2'], adm['journal_conventions']
  end

  def test_with_the_setting_on_an_honest_02_answer_is_recorded_without_its_values
    with_proofs do |registry, tip_source, dir|
      fake = FakeZk.new(v02_answer)
      out = record(registry, bundle, bytes: receipt_bytes(receipt('receipt_v02.bin')), verifier: fake,
                                     tip_source: tip_source)
      assert_equal 'recorded', out[:status]
      assert_equal ['gc-zk-journal-0.2'], fake.calls
      m = manifests(registry).first
      assert_equal '0.5', m['record_version']
      assert_equal 'gc-zk-journal-0.2', m['zk_receipts'].first['journal_convention']
      assert_equal({ 'verifier' => 'gc_zk_verify-0.2.0', 'risc0_zkvm' => '3.0.6',
                     'journal_convention' => 'gc-zk-journal-0.2', 'receipts_verified' => 1 }, m['zk_verification'])
      stored = Dir[File.join(dir, '**', '*')].select { |f| File.file?(f) }.map { |f| File.binread(f) }.join
      EXPECTED.each_value { |v| refute_includes stored, v, 'key_id and commitments are never recorded (C5)' }
    end
  end

  # T4: change the input, the output or the key, and one of ③④⑤ fails.
  def test_each_of_three_four_five_fails_on_its_own_change
    with_proofs do |registry, tip_source|
      bytes = receipt_bytes(receipt('receipt_v02.bin'))
      {
        bundle(input: "#{INPUT}x") => 'journal_input_mismatch',              # ③
        bundle(output: ALTERED) => 'journal_output_mismatch',                # ④
        bundle(key: KEY_B) => 'journal_input_mismatch'                       # another key moves every value; ③ is first
      }.each do |b, code|
        refused(code) { record(registry, b, bytes: bytes, verifier: FakeZk.new(v02_answer), tip_source: tip_source) }
      end
      # ⑤ alone: the bundle's values stay, its commitment names another key
      only_key_id = edit(bundle) { |_j, e| e['commitment'] = C.declaration(KEY_B) }
      refused('journal_key_id_mismatch') do
        record(registry, only_key_id, bytes: bytes, verifier: FakeZk.new(v02_answer), tip_source: tip_source)
      end
      two = edit(bundle) { |j, _e| j['extension_domain'] << { 'genomicschain_extension' => { 'commitment' => C.declaration(KEY_B) } } }
      refused('commitment_declared_twice') do
        record(registry, two, bytes: bytes, verifier: FakeZk.new(v02_answer), tip_source: tip_source)
      end
      none = edit(bundle) { |_j, e| e.delete('commitment') }
      refused('commitment_missing') do
        record(registry, none, bytes: bytes, verifier: FakeZk.new(v02_answer), tip_source: tip_source)
      end
      bad = edit(bundle) { |_j, e| e['commitment'] = { 'rule' => 'gc-commitment-0.0', 'key_id' => EXPECTED['journal_key_id'] } }
      refused('commitment_unreadable') do
        record(registry, bad, bytes: bytes, verifier: FakeZk.new(v02_answer), tip_source: tip_source)
      end
      { { 'receipt_kind' => 'composite', 'error' => 'receipt_not_succinct' } => 'receipt_not_succinct',
        { 'receipt_kind' => 'composite' } => 'receipt_not_succinct',
        { 'verified' => false, 'error' => 'verification_failed' } => 'receipt_not_verified',
        { 'journal_ok' => false, 'error' => 'journal_not_convention' } => 'journal_not_convention',
        { 'journal_convention' => 'gc-zk-journal-0.1' } => 'journal_not_convention' }.each do |over, code|
        refused(code) do
          record(registry, bundle, bytes: bytes, verifier: FakeZk.new(v02_answer(**over.transform_keys(&:to_sym))),
                                   tip_source: tip_source)
        end
      end
      assert_empty registry.read(:proofs)
    end
  end

  def test_the_adapter_refusals_stop_the_anchor_before_verification
    with_proofs do |registry, tip_source|
      bytes = receipt_bytes(receipt('receipt_v02.bin'))
      plain = edit(bundle) { |_j, e| e['checksums'] << { 'uri' => 'copy', 'sha256' => 'a' * 64 } }
      refused('plain_fingerprint_in_option2_bundle') { record(registry, plain, bytes: bytes, verifier: NeverZk.new, tip_source: tip_source) }
      mixed = edit(bundle) { |_j, e| e['zk_receipts'] << e['zk_receipts'].first.merge('journal' => 'gc-zk-journal-0.1', 'sha256' => 'e' * 64) }
      refused('mixed_journal_conventions') { record(registry, mixed, bytes: bytes, verifier: NeverZk.new, tip_source: tip_source) }
      v1 = bundle(key: nil, receipt_name: 'receipt_v01.bin', image_id: IMAGE_V01)
      outside = edit(v1) { |_j, e| e['commitment'] = C.declaration(KEY_A) }
      refused('commitment_outside_option2') do
        record(registry, outside, bytes: receipt_bytes(receipt('receipt_v01.bin')), verifier: NeverZk.new, tip_source: tip_source)
      end
      assert_empty registry.read(:proofs)
    end
  end

  # §9: an old 0.1.0 binary given --journal exits 2 with its usage line. The
  # Ruby side then refuses the 0.2 receipt only; option 1 keeps working.
  def test_an_old_binary_still_serves_option1_and_refuses_option2_only
    Dir.mktmpdir do |d|
      bin = File.join(d, 'gc_zk_verify')
      answer = JSON.generate('tool' => 'gc_zk_verify', 'version' => '0.1.0', 'risc0_zkvm' => '3.0.6',
                             'journal_convention' => 'gc-zk-journal-0.1', 'verified' => true, 'journal_ok' => true,
                             'journal_input_sha256' => Digest::SHA256.hexdigest(INPUT),
                             'journal_output_sha256' => Digest::SHA256.hexdigest(OUTPUT))
      File.write(bin, "#!/bin/sh\nif [ \"$#\" -ne 1 ]; then echo 'usage: gc_zk_verify <image_id_hex>' >&2; exit 2; fi\n" \
                      "cat >/dev/null\necho '#{answer}'\n")
      File.chmod(0o755, bin)
      old = GenomicsChainProv::ZkVerifier.new(bin: bin)
      with_proofs do |registry, tip_source|
        v1 = bundle(key: nil, receipt_name: 'receipt_v01.bin', image_id: IMAGE_V01)
        out = record(registry, v1, bytes: receipt_bytes(receipt('receipt_v01.bin')), verifier: old, tip_source: tip_source)
        assert_equal 'recorded', out[:status]
        assert_equal 'gc_zk_verify-0.1.0', manifests(registry).first.dig('zk_verification', 'verifier')
        refused('journal_convention_not_supported') do
          record(registry, bundle, bytes: receipt_bytes(receipt('receipt_v02.bin')), verifier: old, tip_source: tip_source)
        end
      end
    end
  end

  # ===================================================================================
  # T4 with real receipts (the parallel Rust fixture and the 0.2.0 binary)
  # ===================================================================================

  def test_real_02_receipt_is_recorded_and_its_identity_only
    verifier = real_verifier
    with_proofs do |registry, tip_source|
      out = record(registry, bundle, bytes: receipt_bytes(receipt('receipt_v02.bin')), verifier: verifier,
                                     tip_source: tip_source)
      assert_equal 'recorded', out[:status]
      m = manifests(registry).first
      assert_equal [{ 'receipt_sha256' => Digest::SHA256.hexdigest(receipt('receipt_v02.bin')), 'image_id' => IMAGE_V02,
                      'zkvm_name' => 'risc0-zkvm', 'zkvm_version' => '3.0.6', 'stage' => 1,
                      'journal_convention' => 'gc-zk-journal-0.2' }], m['zk_receipts']
      assert_equal({ 'verifier' => 'gc_zk_verify-0.2.0', 'risc0_zkvm' => '3.0.6',
                     'journal_convention' => 'gc-zk-journal-0.2', 'receipts_verified' => 1 }, m['zk_verification'])
      assert_includes m['not_checked'], 'zk_zero_knowledge_property'
    end
  end

  def test_real_receipts_fail_on_changed_input_output_key_and_composite
    verifier = real_verifier
    with_proofs do |registry, tip_source|
      valid = receipt_bytes(receipt('receipt_v02.bin'))
      cases = [
        [bundle(input: "#{INPUT}x"), valid, 'journal_input_mismatch'],                                # ③
        # ④: the bundle declares the valid claim; the receipt was proved for the altered one
        [bundle(receipt_name: 'receipt_v02_altered_output.bin'), receipt_bytes(receipt('receipt_v02_altered_output.bin')),
         'journal_output_mismatch'],
        [bundle(key: KEY_B), valid, 'journal_input_mismatch'],                                        # key B bundle, key A receipt
        [edit(bundle) { |_j, e| e['commitment'] = C.declaration(KEY_B) }, valid, 'journal_key_id_mismatch'], # ⑤
        [bundle(receipt_name: 'receipt_v02_composite.bin'), receipt_bytes(receipt('receipt_v02_composite.bin')),
         'receipt_not_succinct']
      ]
      cases.each do |b, bytes, code|
        refused(code) { record(registry, b, bytes: bytes, verifier: verifier, tip_source: tip_source) }
      end
      # key B consistently: its own receipt, its own bundle — passes
      out = record(registry, bundle(key: KEY_B, receipt_name: 'receipt_v02_key_b.bin'),
                   bytes: receipt_bytes(receipt('receipt_v02_key_b.bin')), verifier: verifier, tip_source: tip_source)
      assert_equal 'recorded', out[:status]
    end
  end

  # T4: a genuine receipt relabelled as the other convention fails, with a
  # bundle that is otherwise consistent with the label (review r2 N5).
  def test_real_receipts_relabelled_as_the_other_convention_fail
    verifier = real_verifier
    with_proofs do |registry, tip_source|
      # a 0.1 receipt declared 0.2, in an option-2 bundle
      v01_as_v02 = bundle(receipt_name: 'receipt_v01.bin', image_id: IMAGE_V01)
      refused('journal_not_convention') do
        record(registry, v01_as_v02, bytes: receipt_bytes(receipt('receipt_v01.bin')), verifier: verifier, tip_source: tip_source)
      end
      # the 0.1 receipt whose journal is 388 bytes, the 0.2 length: only the tag separates them
      out = verifier.run(receipt('receipt_v01_64byte_output.bin'), IMAGE_V01, 'gc-zk-journal-0.2')
      assert_equal true, out['verified']
      assert_equal 'journal_not_convention', out['error']
      # a 0.2 receipt declared 0.1, in an option-1 bundle: the 0.1 decode
      # cannot read its first word as one byte (§6.2), so the reason is
      # journal_not_convention and nothing else (round-1 review, zk-binding)
      v02_as_v01 = bundle(key: nil, receipt_name: 'receipt_v02.bin', image_id: IMAGE_V02)
      err = refused('journal_not_convention') do
        record(registry, v02_as_v01, bytes: receipt_bytes(receipt('receipt_v02.bin')), verifier: verifier, tip_source: tip_source)
      end
      refute_includes err.message, 'journal_input_mismatch'
      assert_empty registry.read(:proofs)
    end
  end

  # §6.3: the record shows the submitter's bundle carries values equal to a
  # verified journal, not who made the receipt. The same receipt therefore
  # also passes for another bundle carrying the same values. Recorded here
  # as a property that holds, not a defect fixed.
  def test_the_same_receipt_copied_to_another_bundle_passes
    with_proofs do |registry, tip_source|
      bytes = receipt_bytes(receipt('receipt_v02.bin'))
      first = bundle
      copy = bundle(object_id: '00000000-0000-4000-8000-0000000000c0', description: 'another bundle, same values')
      refute_equal Identity.bundle_digest(first), Identity.bundle_digest(copy)
      verifier = GenomicsChainProv::ZkVerifier.available? ? GenomicsChainProv::ZkVerifier.new : FakeZk.new(v02_answer)
      [first, copy].each do |b|
        assert_equal 'recorded', record(registry, b, bytes: bytes, verifier: verifier, tip_source: tip_source)[:status]
      end
      assert_equal 2, manifests(registry).length
      assert_equal 1, manifests(registry).map { |m| m['zk_receipts'].first['receipt_sha256'] }.uniq.length
    end
  end

  # ===================================================================================
  # T3 — what reaches the anchor's record, logs, replies and temp files
  # ===================================================================================

  # The real path: the MCP tool, the anchor's own config file, the real
  # binary, TMPDIR pointed at an empty directory so every temporary file is
  # seen. Returns the places to scan.
  #
  # The attestor is STUBBED (StubAttestor: Synoptis' engine with
  # require_signature false), not the anchor's signing attestor: T3 covers
  # what the admission, the verifier and the store write, not what a
  # signing key adds (round-1 implementation review, Sonnet P2).
  #
  # setting: the `confidential_receipts` value written into the real config
  # file; :absent writes no `zk` section, so the real loader's default
  # decides. dry_run: the tool's dry run instead of a submit. plant: called
  # with (data_dir, tmp_dir) after the call and before the places are
  # collected — the positive control writes its planted leaks there.
  def admit_through_the_tool(text, receipt_name, setting: true, dry_run: false, plant: nil)
    previous_data = KairosMcp.instance_variable_get(:@data_dir)
    previous_tmp = ENV.fetch('TMPDIR', nil)
    Dir.mktmpdir('prov_t3') do |dir|
      tmp = File.join(dir, 'tmp')
      FileUtils.mkdir_p(tmp)
      KairosMcp.data_dir = File.join(dir, 'data')
      cfg = File.join(KairosMcp.skillsets_dir, 'genomicschain_core', 'config')
      FileUtils.mkdir_p(cfg)
      zk = setting == :absent ? '' : "  zk:\n    confidential_receipts: #{setting}\n"
      File.write(File.join(cfg, 'genomicschain_core.yml'), "genomicschain:\n  anchor_profile: true\n#{zk}")
      registry = ::Synoptis::Registry::FileRegistry.new(data_dir: File.join(KairosMcp.data_dir, 'synoptis_data'))
      tip_source = GC::TipSource.new(registry: registry)
      KairosMcp::Manifest::Signer.bootstrap_seen_list!(tip_source: tip_source)
      identity = ProvSubmit.signed_params_for(text)
      op, pkhash = signed_operator(tip_source, identity)
      stub = StubAttestor.new(registry: registry)
      safety = Object.new
      safety.define_singleton_method(:current_user) { { user: 'customer', pubkey_hash: pkhash } }
      reply = nil
      out, err = capture_io do
        GC::Attestation::SynoptisAttestor.stub(:build, ->(**) { stub }) do
          ENV['TMPDIR'] = tmp
          tool = KairosMcp::SkillSets::GenomicschainProv::Tools::GcProvSubmit.new(safety)
          args = { 'bundle' => text, 'identity' => identity, 'operator' => op,
                   'zk_receipt_bytes' => receipt_bytes(receipt(receipt_name)) }
          args['dry_run'] = true if dry_run
          reply = tool.call(args).first[:text]
        ensure
          ENV['TMPDIR'] = previous_tmp
        end
      end
      plant&.call(KairosMcp.data_dir, tmp)
      places = ConfidentialityScan.files_under('data' => KairosMcp.data_dir, 'tmp' => tmp)
      places.merge('reply' => reply, 'stdout' => out, 'stderr' => err, 'bundle' => text,
                   'receipt' => receipt(receipt_name))
    end
  ensure
    KairosMcp.instance_variable_set(:@data_dir, previous_data)
    KairosMcp.instance_variable_set(:@path_cache, {})
  end

  def test_t3_nothing_plain_and_no_key_reaches_any_place_after_a_02_admission
    real_verifier
    places = admit_through_the_tool(bundle, 'receipt_v02.bin')
    assert_includes places['reply'], '"status": "recorded"'
    assert(places.any? { |k, v| k.end_with?('proofs.jsonl') && v.include?('gc-zk-journal-0.2') },
           'the ledger holding the record is among the places scanned')
    probes = ConfidentialityScan.probes(files: bundle_files, output: OUTPUT, key: KEY_A, salted: EXPECTED)
    assert_empty ConfidentialityScan.scan(probes, places)
  end

  # Positive control: the same scan over an option-1 admission finds the
  # plain fingerprints (in the bundle) and the output and input digest (in
  # the 0.1 journal, word-expanded) — the scan can fail.
  def test_t3_positive_control_the_same_scan_finds_the_plain_fingerprints_of_option1
    real_verifier
    places = admit_through_the_tool(bundle(key: nil, receipt_name: 'receipt_v01.bin', image_id: IMAGE_V01),
                                    'receipt_v01.bin')
    assert_includes places['reply'], '"status": "recorded"'
    probes = ConfidentialityScan.probes(files: bundle_files, output: OUTPUT)
    hits = ConfidentialityScan.scan(probes, places)
    assert_includes hits, "sha256(#{IN}) in bundle"
    assert_includes hits, "sha1(#{OUT}) in bundle"
    assert_includes hits, 'output bytes, word-expanded in receipt'
    refute(hits.any? { |h| h.start_with?('key') })
    refute(hits.any? { |h| h.end_with?(' in reply', ' in stdout', ' in stderr') || h.include?(' in data:') },
           "option 1 too keeps file digests out of the record and logs: #{hits.inspect}")
  end

  # ===================================================================================
  # T1 — the guessing test (§10)
  # ===================================================================================

  # One real candidate and N fakes per covered file, the S1 example. The same
  # procedure on both bundles: compare each candidate's SHA-256 and SHA-1
  # with every fingerprint value in the bundle, and with a key, its C(f).
  def guess(text, candidates, key: nil)
    values = []
    walk = lambda do |n|
      case n
      when Hash then n.each { |k, v| %w[sha256 hmac_sha256 sha1_checksum].include?(k) && v.is_a?(String) ? values << v.downcase : walk.call(v) }
      when Array then n.each { |v| walk.call(v) }
      end
    end
    walk.call(JSON.parse(text))
    candidates.select do |c|
      tries = [Digest::SHA256.hexdigest(c), Digest::SHA1.hexdigest(c)]
      tries << C.commit(key, c) if key
      tries.any? { |t| values.include?(t) }
    end
  end

  def candidates(real, n = 50)
    fakes = Array.new(n) do |i|
      b = real.b.dup
      at = i % b.bytesize
      b.setbyte(at, (b.getbyte(at) + 1 + (i / b.bytesize)) % 256)
      b
    end
    ([real] + fakes).uniq
  end

  def test_t1_guessing
    inputs = candidates(INPUT)
    outputs = candidates(OUTPUT)
    assert_equal 51, inputs.length
    v1 = bundle(key: nil, receipt_name: 'receipt_v01.bin', image_id: IMAGE_V01)
    v2 = bundle
    # positive control: on the plain bundle the real files are picked out
    assert_equal [INPUT], guess(v1, inputs)
    assert_equal [OUTPUT], guess(v1, outputs)
    # option 2: without the key nothing matches; with key B nothing; with key A only the real ones
    assert_empty guess(v2, inputs)
    assert_empty guess(v2, outputs)
    assert_empty guess(v2, inputs, key: KEY_B)
    assert_equal [INPUT], guess(v2, inputs, key: KEY_A)
    assert_equal [OUTPUT], guess(v2, outputs, key: KEY_A)
  end

  # ===================================================================================
  # Step 8 — the verifier: statements, opening with the key
  # ===================================================================================

  def recorded_route(text, receipt_name, verifier)
    with_proofs do |registry, tip_source|
      out = record(registry, text, bytes: receipt_bytes(receipt(receipt_name)), verifier: verifier, tip_source: tip_source)
      assert_equal 'recorded', out[:status]
      yield JSON.parse(JSON.generate(GenomicsChainProv::PlaceExtension.new(nil, registry: registry)
                                                                       .lookup(out[:synoptis_proof_id])))
    end
  end

  def verify(text, route, **kw)
    GenomicsChainProv::Verifier.new(bundle_text: text, route: route, zk_verifier: ZkV.new(bin: '/nonexistent'), **kw).run
  end

  def test_a_02_record_carries_the_option2_statement_and_not_the_option1_one
    text = bundle
    recorded_route(text, 'receipt_v02.bin', FakeZk.new(v02_answer)) do |route|
      res = verify(text, route)
      assert_equal 'consistent', res['state']
      st = GenomicsChainProv::Verifier::JOURNAL_STATEMENTS
      assert_equal Identity::STATEMENTS + [st['gc-zk-journal-0.2']], res['statements']
      assert_includes res['not_checked'].join("\n"), 'zero-knowledge'
      assert(res['confirmed'].any? { |c| c['check'] == 'grades_and_counts' && c['ok'] })
    end
  end

  def test_a_key_holder_opens_the_salted_fingerprints_and_nothing_is_echoed
    text = bundle
    recorded_route(text, 'receipt_v02.bin', FakeZk.new(v02_answer)) do |route|
      Dir.mktmpdir do |d|
        good_in = File.join(d, 'in')
        good_out = File.join(d, 'out')
        wrong = File.join(d, 'wrong')
        File.binwrite(good_in, INPUT)
        File.binwrite(good_out, OUTPUT)
        File.binwrite(wrong, ALTERED)
        opens = [[good_in, IN], [good_out, OUT], [wrong, OUT], [good_in, 'not-a-locator'], [File.join(d, 'none'), IN]]
        res = verify(text, route, commitment_key: KEY_A, opens: opens)
        o = res['opened']
        assert_equal "the key is 32 bytes and its key_id is the bundle's", o['key']
        assert_equal [IN, OUT], o['match']
        assert_equal [OUT], o['mismatch']
        assert_equal ['not-a-locator'], o['not_in_bundle']
        assert_equal [IN], o['unreadable']
        dump = JSON.generate(res).b
        [KEY_A, KEY_A.unpack1('H*'), C.commit(KEY_A, INPUT)].each { |v| refute_includes dump, v.b }

        assert_match(/not this bundle's key/, verify(text, route, commitment_key: KEY_B, opens: opens)['opened']['key'])
        assert_match(/exactly 32 bytes/, verify(text, route, commitment_key: KEY_A[0, 31], opens: opens)['opened']['key'])
        other = edit(text) { |j, _e| j['usability_domain'] = ['edited'] }
        assert_match(/bundle_digest differs/, verify(other, route, commitment_key: KEY_A, opens: opens)['opened']['key'])
      end
    end
  end

  def test_gc_prov_verify_opens_with_the_key_from_the_command_line
    text = bundle
    recorded_route(text, 'receipt_v02.bin', FakeZk.new(v02_answer)) do |route|
      Dir.mktmpdir do |d|
        File.write(File.join(d, 'bco.json'), text)
        File.write(File.join(d, 'route.json'), JSON.generate(route))
        File.binwrite(File.join(d, 'k'), KEY_A)
        File.binwrite(File.join(d, 'in'), INPUT)
        File.binwrite(File.join(d, 'wrong'), ALTERED)
        script = File.expand_path('../bin/gc_prov_verify.rb', __dir__)
        env = { 'GC_ZK_VERIFY_BIN' => '/nonexistent' }
        out, _e, st = Open3.capture3(env, RbConfig.ruby, script, File.join(d, 'bco.json'), '--envelope',
                                     File.join(d, 'route.json'), '--commitment-key', File.join(d, 'k'),
                                     '--open', "#{File.join(d, 'in')}=#{IN}")
        assert_equal 0, st.exitstatus, out
        assert_includes out, "[ok] #{IN}: matches the bundle"
        refute_includes out, KEY_A.unpack1('H*')
        out, _e, st = Open3.capture3(env, RbConfig.ruby, script, File.join(d, 'bco.json'), '--envelope',
                                     File.join(d, 'route.json'), '--commitment-key', File.join(d, 'k'),
                                     '--open', "#{File.join(d, 'wrong')}=#{OUT}")
        assert_equal 1, st.exitstatus
        assert_includes out, "[MISMATCH] #{OUT}: does NOT match the bundle"
      end
    end
  end

  def test_gc_prov_check_reports_refusals_and_the_anchor_setting_caveat
    Dir.mktmpdir do |d|
      script = File.expand_path('../bin/gc_prov_check.rb', __dir__)
      File.write(File.join(d, 'ok.json'), bundle)
      out, _e, st = Open3.capture3(RbConfig.ruby, script, File.join(d, 'ok.json'))
      assert_equal 0, st.exitstatus, out
      assert_includes out, 'convention_not_offered'
      File.write(File.join(d, 'bad.json'), edit(bundle) { |_j, e| e['checksums'] << { 'uri' => 'c', 'sha256' => 'a' * 64 } })
      out, _e, st = Open3.capture3(RbConfig.ruby, script, File.join(d, 'bad.json'))
      assert_equal 1, st.exitstatus
      assert_includes out, 'bundle refused: plain_fingerprint_in_option2_bundle'
    end
  end

  # ===================================================================================
  # Round-1 implementation review (log/mlr_tier25_v0116_impl_20261019/synthesis_r1.md)
  # ===================================================================================

  # --- H1 / F1: the option-2 shape scan reads the bundle as written -----------------

  # Normalisation empties or drops content it cannot read (a list where an
  # object belongs, a non-object list element). A sha1_checksum hidden there
  # survived into an accepted option-2 bundle (Codex, reproduced with
  # `platform`). The scan now runs on the bundle as parsed, before that.
  def test_r1_h1_the_option2_scan_sees_what_normalisation_drops
    sha1 = 'c' * 40
    hidden = { 'sha1_checksum' => sha1 }
    cases = {
      'platform written as a list (Codex)' => edit(bundle) { |_j, e| e['platform'] = [hidden] },
      'scm_extension written as a list' =>
        edit(bundle) { |j, _e| j['extension_domain'] << { 'scm_extension' => [hidden] } },
      'an extension_domain element that is a list' => edit(bundle) { |j, _e| j['extension_domain'] << [hidden] },
      'an input entry that is a list' =>
        edit(bundle) { |j, _e| j['io_domain']['input_subdomain'] << [{ 'uri' => { 'uri' => 'x' }.merge(hidden) }] },
      'a prerequisite that is a list' =>
        edit(bundle) { |j, _e| j['description_domain']['pipeline_steps'].first['prerequisite'] << [hidden] },
      'a script entry that is a list' => edit(bundle) { |j, _e| j['execution_domain']['script'] << [hidden] }
    }
    cases.each do |name, text|
      assert_includes text, 'sha1_checksum', name
      assert_equal ['plain_fingerprint_in_option2_bundle'], refusals(text), name
    end
  end

  # F1 (confidentiality LOW): an item's two keys must also hold strings — a
  # plain SHA-256 nested inside `uri` was accepted.
  def test_r1_f1_an_option2_item_holds_two_strings
    nested_uri = edit(bundle) { |_j, e| e['checksums'].first['uri'] = { 'uri' => e['checksums'].first['uri'], 'sha256' => '7' * 64 } }
    object_hmac = edit(bundle) { |_j, e| e['checksums'].first['hmac_sha256'] = { 'sha256' => '7' * 64 } }
    { 'uri holding an object' => nested_uri, 'hmac_sha256 holding an object' => object_hmac }.each do |name, text|
      assert_equal ['plain_fingerprint_in_option2_bundle'], refusals(text), name
    end
  end

  # --- H2 / F2: the writer refuses, before writing, what the anchor would refuse --------

  NFCORE = File.expand_path('fixtures/nfcore_demo_1_2_0', __dir__)
  NF_IN = 'work/tmp/b9/14035f8708be787a9f59573d06b2c4/workflow_summary_mqc.yaml'
  NF_OUT = 'work/7a/51f65ba6cac4d8e3dd04ef13e17f52/SAMPLE1_PE_1_fastqc.html'

  def nf
    require 'genomicschain_prov/writer/nextflow_run'
    GenomicsChainProv::Writer::NextflowRun
  end

  # The nf-core demo fixture as a launch directory, with the two edits a
  # covered step needs and nothing else: step 2 also lists a local input
  # (one the bundle already names), and that step's first output's io entry
  # names the file by its work-directory path, so both can be fingerprinted
  # here. The fixture's own io entries point at /tmp/gc_u0_demo, gone.
  def with_nfcore_launch(extra_blocks: [])
    Dir.mktmpdir('prov_option2_nf') do |dir|
      bco = JSON.parse(File.read(File.join(NFCORE, 'bco.json')))
      step = bco['description_domain']['pipeline_steps'].find { |s| s['step_number'] == 2 }
      step['input_list'] << { 'uri' => NF_IN }
      bco['io_domain']['output_subdomain'].find { |o| o['uri']['filename'] == NF_OUT }['uri']['uri'] = NF_OUT
      bco['extension_domain'].concat(extra_blocks)
      { NF_IN => "local input\n", NF_OUT => "<html>fastqc</html>\n" }.each do |rel, bytes|
        FileUtils.mkdir_p(File.dirname(File.join(dir, rel)))
        File.write(File.join(dir, rel), bytes)
      end
      File.write(File.join(dir, 'nextflow-26.04.6-one.jar'), 'not really a jar, but bytes this machine can name')
      File.binwrite(File.join(dir, 'r.bin'), receipt('receipt_v02.bin'))
      File.write(File.join(dir, 'bco.json'), JSON.generate(bco))
      yield dir, bco
    end
  end

  def nf_decl
    W.zk_declaration({ 'image_id' => IMAGE_V02, 'zkvm_version' => '3.0.6', 'step_number' => 2, 'input' => NF_IN,
                       'output' => NF_OUT }, Digest::SHA256.hexdigest(receipt('receipt_v02.bin')), journal: W::ZK_JOURNAL_V02)
  end

  def nf_read(dir, bco)
    nf.read(dir, bco: bco, docker: false, digest_map: nf.digests_from(File.read(File.join(NFCORE, 'container_digests.txt'))),
                 jar_path: File.join(dir, 'nextflow-26.04.6-one.jar'), zk_receipts: [nf_decl], commitment_key: KEY_A)
  end

  # Fable #1: the Nextflow option-2 path, through `read`, on the real fixture.
  def test_r1_h2_the_nextflow_reader_in_option2_writes_only_salted_rows_on_the_nfcore_fixture
    with_nfcore_launch do |dir, bco|
      text = JSON.generate(nf_read(dir, bco)['bco'])
      j = JSON.parse(text)
      items = j['extension_domain'].filter_map { |x| x['genomicschain_extension'] }.flat_map { |b| Array(b['checksums']) }
      assert_operator items.length, :>=, 3, 'the input, the output and the jar'
      assert(items.all? { |c| c.keys.sort == %w[hmac_sha256 uri] && c.values.all?(String) }, items.inspect)
      assert_equal C.commit(KEY_A, "<html>fastqc</html>\n"), items.find { |c| c['uri'] == NF_OUT }['hmac_sha256']
      refute_includes text, 'sha1_checksum'
      assert_equal 1, text.scan('"commitment"').length, 'commitment written once'
      adm = Identity.admission(Identity.derive(text))
      assert_empty adm['bundle_refusals']
      assert_empty adm['zk_defects']
      assert adm['issuable']
    end
  end

  # H2: own blocks beyond the first, and other producers' blocks, kept their
  # plain fingerprints and the enricher said nothing (Codex, confidentiality F1).
  def test_r1_h2_the_nextflow_reader_refuses_plain_fingerprints_it_did_not_replace
    own = ->(uri, hex) { { 'genomicschain_extension' => { 'producer' => { 'name' => 'gc_prov_write', 'version' => '0.3.0' },
                                                           'checksums' => [{ 'uri' => uri, 'sha256' => hex }] } } }
    other = ->(item) { { 'genomicschain_extension' => { 'producer' => { 'name' => 'someone_else', 'version' => '1' },
                                                         'checksums' => [item] } } }
    {
      'two own blocks' => [own.call('a', 'a' * 64), own.call('b', 'b' * 64)],
      'a third-party sha256' => [other.call('uri' => 'c', 'sha256' => 'c' * 64)],
      'a third-party md5' => [other.call('uri' => 'c', 'md5' => 'd' * 32)]
    }.each do |name, blocks|
      with_nfcore_launch(extra_blocks: blocks) do |dir, bco|
        err = assert_raises(W::PlanError, name) { nf_read(dir, bco) }
        assert_includes err.message, 'plain_fingerprint_in_option2_bundle', name
        %w[a b c d].each { |x| refute_includes err.message, x * 32, "#{name}: codes, never values" }
      end
    end
  end

  # The same through the command line: exit non-zero and no bundle written.
  def test_r1_h2_gc_prov_write_writes_nothing_when_the_anchor_would_refuse
    script = File.expand_path('../bin/gc_prov_write.rb', __dir__)
    md5 = { 'genomicschain_extension' => { 'producer' => { 'name' => 'someone_else' }, 'checksums' => [{ 'uri' => 'c', 'md5' => 'd' * 32 }] } }
    with_nfcore_launch(extra_blocks: [md5]) do |dir, _bco|
      File.binwrite(File.join(dir, 'k'), KEY_A)
      File.write(File.join(dir, 'zk.json'), JSON.generate([{ 'receipt' => 'r.bin', 'image_id' => IMAGE_V02, 'zkvm_version' => '3.0.6',
                                                             'step_number' => 2, 'input' => NF_IN, 'output' => NF_OUT }]))
      out_path = File.join(dir, 'out.json')
      _o, e, st = Open3.capture3(RbConfig.ruby, script, '--from-nextflow-run', dir, '--no-docker', '--container-digests',
                                 File.join(NFCORE, 'container_digests.txt'), '--nextflow-jar',
                                 File.join(dir, 'nextflow-26.04.6-one.jar'), '--zk-receipts', File.join(dir, 'zk.json'),
                                 '--commitment-key', File.join(dir, 'k'), '--out', out_path)
      refute st.success?, e
      assert_includes e, 'plain_fingerprint_in_option2_bundle'
      refute File.exist?(out_path), 'nothing written'
    end
    # --plan with --no-checksums: the declaration's files carry no hmac_sha256 (Sonnet P3)
    in_run(input: INPUT, output: OUTPUT, receipt_name: 'receipt_v02.bin') do |dir|
      File.binwrite(File.join(dir, 'k'), KEY_A)
      File.write(File.join(dir, 'plan.json'), JSON.generate(
        'name' => 'x', 'script' => 'run.sh', 'stages' => [{ 'name' => 's', 'inputs' => [IN], 'outputs' => [OUT] }],
        'zk_receipts' => [{ 'receipt' => 'receipt_v02.bin', 'image_id' => IMAGE_V02, 'zkvm_version' => '3.0.6',
                            'step_number' => 1, 'input' => IN, 'output' => OUT }]
      ))
      out_path = File.join(dir, 'bco.json')
      _o, e, st = Open3.capture3(RbConfig.ruby, script, '--plan', File.join(dir, 'plan.json'), '--commitment-key',
                                 File.join(dir, 'k'), '--out', out_path, '--no-checksums', '--no-machine', '--no-platform',
                                 '--no-docker')
      refute st.success?, e
      assert_includes e, 'input_has_no_hmac_sha256'
      refute File.exist?(out_path), 'nothing written'
    end
  end

  # --- H3: the bundle never overwrites the key through another name -----------------

  def test_r1_h3_out_naming_the_key_file_by_another_path_is_refused_and_the_key_survives
    script = File.expand_path('../bin/gc_prov_write.rb', __dir__)
    in_run(input: INPUT, output: OUTPUT, receipt_name: 'receipt_v02.bin') do |dir|
      FileUtils.mkdir_p(File.join(dir, 'keys'))
      key_path = File.join(dir, 'keys', 'run.key')
      C.write_key_file(key_path, KEY_A)
      File.write(File.join(dir, 'plan.json'), JSON.generate(
        'name' => 'x', 'script' => 'run.sh', 'stages' => [{ 'name' => 's', 'inputs' => [IN], 'outputs' => [OUT] }],
        'zk_receipts' => [{ 'receipt' => 'receipt_v02.bin', 'image_id' => IMAGE_V02, 'zkvm_version' => '3.0.6',
                            'step_number' => 1, 'input' => IN, 'output' => OUT }]
      ))
      symlink = File.join(dir, 'link.json')
      File.symlink(key_path, symlink)
      hardlink = File.join(dir, 'hard.json')
      File.link(key_path, hardlink)
      outs = { 'symlink' => symlink, 'hardlink' => hardlink, 'dot path' => File.join(dir, 'keys', '.', 'run.key') }
      variant = File.join(dir, 'keys', 'RUN.KEY')
      outs['case variant'] = variant if File.exist?(variant) # a case-insensitive file system (macOS default)
      outs.each do |name, out|
        _o, e, st = Open3.capture3(RbConfig.ruby, script, '--plan', File.join(dir, 'plan.json'), '--commitment-key',
                                   key_path, '--out', out, '--no-machine', '--no-platform', '--no-docker')
        refute st.success?, name
        assert_includes e, 'cannot be the same file', name
        assert_equal KEY_A, File.binread(key_path), "#{name}: the key is intact"
      end
    end
  end

  # --- F4: T3's power ---------------------------------------------------------------

  # Every place T3 scans, on the paths that hold the most sensitive material
  # and are not the success path: ⑤ after the binary returned the journal,
  # ③ with a key-B receipt, the setting off, the setting absent (the real
  # loader's default), an adapter refusal, and the dry run. Each reply is a
  # structured error naming its code (Sonnet P2).
  def test_r1_f4_t3_refusal_paths_and_the_dry_run_leak_nothing
    real_verifier
    probes = ConfidentialityScan.probes(files: bundle_files, output: OUTPUT, key: KEY_A, salted: EXPECTED)
    key_b_commitment = edit(bundle) { |_j, e| e['commitment'] = C.declaration(KEY_B) }
    plain_item = edit(bundle) { |_j, e| e['checksums'] << { 'uri' => 'copy', 'sha256' => 'a' * 64 } }
    [
      ['⑤ key_id', key_b_commitment, 'receipt_v02.bin', {}, 'journal_key_id_mismatch'],
      ['③ key-B receipt', bundle(receipt_name: 'receipt_v02_key_b.bin'), 'receipt_v02_key_b.bin', {}, 'journal_input_mismatch'],
      ['setting false', bundle, 'receipt_v02.bin', { setting: false }, 'convention_not_offered'],
      ['setting absent', bundle, 'receipt_v02.bin', { setting: :absent }, 'convention_not_offered'],
      ['adapter refusal', plain_item, 'receipt_v02.bin', {}, 'plain_fingerprint_in_option2_bundle']
    ].each do |name, text, receipt_name, kw, code|
      places = admit_through_the_tool(text, receipt_name, **kw)
      assert_match(/\AError: \w+: .*\b#{code}\b/, places['reply'], name)
      refute(places.any? { |k, _| k.end_with?('proofs.jsonl') }, "#{name}: nothing recorded")
      assert_empty ConfidentialityScan.scan(probes, places), name
    end
    places = admit_through_the_tool(bundle, 'receipt_v02.bin', dry_run: true)
    dry = JSON.parse(places['reply'])
    assert_equal 'dry_run', dry['status']
    assert_equal 'ok', dry.dig('checks', 'gates'), 'the dry run ran the receipt checks'
    assert_empty ConfidentialityScan.scan(probes, places), 'dry run'
    places = admit_through_the_tool(key_b_commitment, 'receipt_v02.bin', dry_run: true)
    assert_includes JSON.parse(places['reply']).dig('checks', 'rejected'), 'journal_key_id_mismatch'
    assert_empty ConfidentialityScan.scan(probes, places), 'dry run, refused'
  end

  # Positive control (Cursor P2, confidentiality F2): leaks planted in every
  # kind of place T3 scans — a copy of the ledger, the reply, a log file, a
  # temp file — in every spelling a leak could take, are found. The planted
  # spellings are made here, independently of the scanner's own list.
  def test_r1_f4_t3_positive_control_planted_leaks_are_found_in_every_place
    real_verifier
    encodings = lambda do |raw|
      hex = raw.unpack1('H*')
      out = { 'raw' => raw.b, 'hex' => hex, 'HEX' => hex.upcase, 'base64' => Base64.strict_encode64(raw),
              'base64url' => Base64.urlsafe_encode64(raw), 'inspect' => raw.b.inspect, 'bytes' => raw.bytes.inspect,
              'json bytes' => JSON.generate(raw.bytes) }
      utf8 = raw.dup.force_encoding('UTF-8')
      out['json string'] = JSON.generate(utf8) if utf8.valid_encoding?
      out['inspect utf8'] = utf8.inspect if utf8.valid_encoding?
      out
    end
    planted = {}
    encodings.call(OUTPUT).each { |enc, v| planted["output #{enc}"] = ['output bytes', v] }
    encodings.call(KEY_A).each { |enc, v| planted["key #{enc}"] = ['key', v] }
    word = OUTPUT.bytes.pack('V*')
    %w[hex base64].each { |enc| planted["output word-expanded #{enc}"] = ['output bytes, word-expanded', encodings.call(word)[enc]] }
    planted['input sha256'] = ["sha256(#{IN})", Digest::SHA256.hexdigest(INPUT)]
    planted['output sha1 HEX'] = ["sha1(#{OUT})", Digest::SHA1.hexdigest(OUTPUT).upcase]
    planted['key_id'] = ['journal_key_id', EXPECTED['journal_key_id']]
    assert planted.key?('key json string'), 'the key is valid UTF-8, so its JSON-string form is planted'

    plant = lambda do |data, tmp|
      ledger = Dir[File.join(data, '**', 'proofs.jsonl')].first
      planted.each_with_index do |(_name, (_label, value)), i|
        dir = File.join(data, 'planted', i.to_s)
        FileUtils.mkdir_p(dir)
        File.binwrite(File.join(dir, 'ledger_copy.jsonl'), File.binread(ledger) + value.b + "\n")
        File.binwrite(File.join(dir, 'gc.log'), "I, [2026-10-19] INFO -- : admitted #{value.b}\n".b)
        File.binwrite(File.join(tmp, "planted_#{i}.tmp"), value.b)
      end
    end
    places = admit_through_the_tool(bundle, 'receipt_v02.bin', plant: plant)
    assert_includes places['reply'], '"status": "recorded"'
    probes = ConfidentialityScan.probes(files: bundle_files, output: OUTPUT, key: KEY_A, salted: EXPECTED)
    clean = places.reject { |k, _| k.include?('/planted') }
    assert_empty ConfidentialityScan.scan(probes, clean), 'the real places stay clean'
    planted.each_with_index do |(name, (label, value)), i|
      reply_copy = { "reply_#{i}" => "#{places['reply']}#{value.b}".b }
      hits = ConfidentialityScan.scan(probes, places.select { |k, _| k.include?("/planted/#{i}/") || k.include?("planted_#{i}.") }
                                                    .merge(reply_copy))
      %W[data:/planted/#{i}/ledger_copy.jsonl data:/planted/#{i}/gc.log tmp:/planted_#{i}.tmp reply_#{i}].each do |where|
        assert_includes hits, "#{label} in #{where}", "#{name} planted in #{where}"
      end
    end
  end

  # --- F5: local tools ---------------------------------------------------------------

  # The 0.1 path takes gc-zk-journal-0.1 only (Sonnet P3). Admission refuses
  # an unknown convention first, so this is defence for a caller that did not.
  def test_r1_f5_zk_verifier_sends_only_01_to_the_01_path
    v1 = bundle(key: nil, receipt_name: 'receipt_v01.bin', image_id: IMAGE_V01)
    declared = Bco.parse(v1).zk_receipts.first
    bytes = receipt('receipt_v01.bin')
    [nil, 'gc-zk-journal-0.9', ''].each do |conv|
      fake = FakeZk.new(v02_answer)
      out = fake.check([declared.merge('journal_convention' => conv)], { Digest::SHA256.hexdigest(bytes) => bytes })
      assert_equal 'journal_convention_unknown', out['results'].first['code'], conv.inspect
      assert_empty fake.calls, 'the binary is not run'
    end
  end

  # opened_ok? reads a boolean, not the wording of a message (Sonnet P3).
  def test_r1_f5_the_opened_result_carries_a_boolean_and_gc_prov_verify_reads_it
    load File.expand_path('../bin/gc_prov_verify.rb', __dir__) unless defined?(GcProvVerify)
    text = bundle
    recorded_route(text, 'receipt_v02.bin', FakeZk.new(v02_answer)) do |route|
      Dir.mktmpdir do |d|
        File.binwrite(File.join(d, 'in'), INPUT)
        good = verify(text, route, commitment_key: KEY_A, opens: [[File.join(d, 'in'), IN]])['opened']
        assert_equal true, good['key_ok']
        assert GcProvVerify.opened_ok?(good)
        bad = verify(text, route, commitment_key: KEY_B, opens: [[File.join(d, 'in'), IN]])['opened']
        assert_equal false, bad['key_ok']
        refute GcProvVerify.opened_ok?(bad)
      end
    end
    worded = { 'key' => 'the key is 32 bytes and its key_id is the bundle\'s', 'key_ok' => false,
               'match' => [], 'mismatch' => [], 'not_in_bundle' => [], 'unreadable' => [] }
    refute GcProvVerify.opened_ok?(worded), 'the wording alone does not open'
  end

  # --commitment-key / --open with a record that is not a prov record were
  # silently ignored (Sonnet P2, Fable #5).
  def test_r1_f5_gc_prov_verify_refuses_the_key_on_a_reachability_record
    Dir.mktmpdir do |d|
      File.write(File.join(d, 'bco.json'), bundle)
      route = { 'evidence' => JSON.generate('manifest' => { 'record_type' => 'prov_reachability' }) }
      File.write(File.join(d, 'route.json'), JSON.generate(route))
      File.binwrite(File.join(d, 'k'), KEY_A)
      File.binwrite(File.join(d, 'in'), INPUT)
      script = File.expand_path('../bin/gc_prov_verify.rb', __dir__)
      [['--commitment-key', File.join(d, 'k')],
       ['--commitment-key', File.join(d, 'k'), '--open', "#{File.join(d, 'in')}=#{IN}"]].each do |extra|
        _o, e, st = Open3.capture3({ 'GC_ZK_VERIFY_BIN' => '/nonexistent' }, RbConfig.ruby, script, File.join(d, 'bco.json'),
                                   '--envelope', File.join(d, 'route.json'), *extra)
        refute st.success?
        assert_includes e, 'only with a prov_attestation record', extra.inspect
      end
    end
  end

  # A customer with the old 0.1.0 binary checking a 0.2 receipt: the receipt
  # is not shown wrong, the tool cannot check it (separation-compat LOW).
  def test_r1_f5_an_old_binary_on_a_02_receipt_is_not_checked_here_rather_than_failed
    Dir.mktmpdir do |d|
      bin = File.join(d, 'gc_zk_verify')
      File.write(bin, "#!/bin/sh\nif [ \"$#\" -ne 1 ]; then echo 'usage: gc_zk_verify <image_id_hex>' >&2; exit 2; fi\nexit 1\n")
      File.chmod(0o755, bin)
      File.write(File.join(d, 'bco.json'), bundle)
      File.binwrite(File.join(d, 'r.bin'), receipt('receipt_v02.bin'))
      check = File.expand_path('../bin/gc_prov_check.rb', __dir__)
      out, _e, st = Open3.capture3({ 'GC_ZK_VERIFY_BIN' => bin }, RbConfig.ruby, check, File.join(d, 'bco.json'),
                                   '--zk-receipt', File.join(d, 'r.bin'))
      assert_equal 0, st.exitstatus, out
      assert_includes out, 'local check: not_checked (this gc_zk_verify does not verify gc-zk-journal-0.2)'

      text = bundle
      recorded_route(text, 'receipt_v02.bin', FakeZk.new(v02_answer)) do |route|
        res = GenomicsChainProv::Verifier.new(bundle_text: text, route: route, zk_verifier: ZkV.new(bin: bin),
                                              receipts: receipt_bytes(receipt('receipt_v02.bin'))
                                                          .transform_values { |b64| Base64.strict_decode64(b64) }).run
        assert_equal 'consistent', res['state']
        refute(res['confirmed'].any? { |c| c['check'] == 'zk_receipts' })
        assert_includes res['record_notes'].join("\n"), 'this gc_zk_verify does not verify gc-zk-journal-0.2'
      end
    end
  end
  # ===================================================================================
  # Pre-flight round 2 follow-ups
  # ===================================================================================

  # Refuted F1: an extension block written as a list (an extension_domain
  # element that is a list wrapping the block, or `genomicschain_extension`
  # itself a list) escaped the item scan; only a sha1_checksum there was caught.
  def list_shaped_blocks(item)
    block = { 'producer' => { 'name' => 'someone_else' }, 'checksums' => [item] }
    { 'an extension_domain element that is a list wrapping a block' => [{ 'genomicschain_extension' => block }],
      'genomicschain_extension written as a list' => { 'genomicschain_extension' => [block] } }
  end

  def test_r2_f1_list_shaped_extension_blocks_are_refused_in_option2
    { 'sha256' => { 'uri' => 'c', 'sha256' => 'e' * 64 }, 'md5' => { 'uri' => 'c', 'md5' => 'd' * 32 } }.each do |kind, item|
      list_shaped_blocks(item).each do |shape, element|
        text = edit(bundle) { |j, _e| j['extension_domain'] << element }
        assert_equal ['plain_fingerprint_in_option2_bundle'], refusals(text), "#{shape}, #{kind}"
      end
    end
    # option 1 is not touched: the same shapes in a bundle declaring no 0.2 receipt
    v1 = bundle(key: nil, receipt_name: 'receipt_v01.bin', image_id: IMAGE_V01)
    list_shaped_blocks('uri' => 'c', 'sha256' => 'e' * 64).each do |shape, element|
      assert_empty refusals(edit(v1) { |j, _e| j['extension_domain'] << element }), "option 1, #{shape}"
    end
  end

  def test_r2_f1_the_enricher_counts_list_shaped_blocks_in_its_warning
    list_shaped_blocks('uri' => 'c', 'sha256' => 'e' * 64).each do |shape, element|
      bco = JSON.parse(File.read(File.join(NFCORE, 'bco.json')))
      bco['extension_domain'] << element
      _out, refused = nf.enrich(bco, commitment: C.declaration(KEY_A))
      assert(refused.any? { |r| r.include?('1 extension block(s)') && r.include?('plain_fingerprint_in_option2_bundle') },
             "#{shape}: #{refused.inspect}")
    end
  end

  def test_r2_f1_gc_prov_write_refuses_a_list_wrapped_block_and_leaves_out_intact
    script = File.expand_path('../bin/gc_prov_write.rb', __dir__)
    list_shaped_blocks('uri' => 'c', 'sha256' => 'e' * 64).each do |shape, element|
      with_nfcore_launch(extra_blocks: [element]) do |dir, _bco|
        File.binwrite(File.join(dir, 'k'), KEY_A)
        File.write(File.join(dir, 'zk.json'), JSON.generate([{ 'receipt' => 'r.bin', 'image_id' => IMAGE_V02, 'zkvm_version' => '3.0.6',
                                                               'step_number' => 2, 'input' => NF_IN, 'output' => NF_OUT }]))
        out_path = File.join(dir, 'out.json')
        File.binwrite(out_path, "PREEXISTING\n")
        _o, e, st = Open3.capture3(RbConfig.ruby, script, '--from-nextflow-run', dir, '--no-docker', '--container-digests',
                                   File.join(NFCORE, 'container_digests.txt'), '--nextflow-jar',
                                   File.join(dir, 'nextflow-26.04.6-one.jar'), '--zk-receipts', File.join(dir, 'zk.json'),
                                   '--commitment-key', File.join(dir, 'k'), '--out', out_path)
        refute st.success?, "#{shape}: #{e}"
        assert_includes e, 'plain_fingerprint_in_option2_bundle', shape
        refute_includes e, 'e' * 64, "#{shape}: codes, never values"
        assert_equal "PREEXISTING\n", File.binread(out_path), "#{shape}: --out byte-identical"
      end
    end
  end

  # Imprecise F5-1: one receipt the older binary cannot check hid another
  # receipt's real failure. A bundle with two 0.2 receipts, the second
  # tampered with.
  OLD_BIN = "#!/bin/sh\nif [ \"$#\" -ne 1 ]; then echo 'usage: gc_zk_verify <image_id_hex>' >&2; exit 2; fi\nexit 1\n"
  SECOND = "a second receipt\n"

  def two_receipt_bundle
    in_run(input: INPUT, output: OUTPUT, receipt_name: 'receipt_v02.bin') do |dir|
      File.binwrite(File.join(dir, 'receipt_b.bin'), SECOND)
      decl = ->(file, step) { { 'receipt' => file, 'image_id' => IMAGE_V02, 'zkvm_version' => '3.0.6', 'step_number' => step,
                                'input' => IN, 'output' => OUT } }
      pl = W.normalise_plan(
        'name' => 'two', 'version' => '0.1.0', 'script' => 'run.sh',
        'runtime' => { 'engine' => 'sh', 'version' => '5.2.21', 'uri' => '/bin/sh', 'path' => '/bin/sh' },
        'platform' => { 'cpu_architecture' => 'arm64', 'os_name' => 'Darwin', 'os_release' => '23.6.0' },
        'stages' => [{ 'name' => 'a', 'inputs' => [IN], 'outputs' => [OUT] }, { 'name' => 'b', 'inputs' => [IN], 'outputs' => [OUT] }],
        'zk_receipts' => [decl.call('receipt_v02.bin', 1), decl.call('receipt_b.bin', 2)]
      )
      r = Env.resolve!(pl, base_dir: dir, docker: false, commitment_key: KEY_A)
      d = Env.zk_declarations(pl['zk_receipts'], base_dir: dir, journal: W::ZK_JOURNAL_V02)
      JSON.generate(W.build(pl, checksums: r['checksums'], object_id: 'urn:uuid:00000000-0000-4000-8000-000000000117',
                                created: '2026-10-19T00:00:00Z', platform: pl['platform'],
                                zk_receipts: d['zk_receipts'], commitment: C.declaration(KEY_A)))
    end
  end

  def test_r2_f5_an_unsupported_receipt_does_not_hide_another_receipts_failure
    text = two_receipt_bundle
    assert_equal 2, Bco.parse(text).zk_receipts.length
    Dir.mktmpdir do |d|
      bin = File.join(d, 'gc_zk_verify')
      File.write(bin, OLD_BIN)
      File.chmod(0o755, bin)
      File.write(File.join(d, 'bco.json'), text)
      File.binwrite(File.join(d, 'r.bin'), receipt('receipt_v02.bin'))
      File.binwrite(File.join(d, 'b.bin'), 'tampered')
      check = File.expand_path('../bin/gc_prov_check.rb', __dir__)
      out, _e, st = Open3.capture3({ 'GC_ZK_VERIFY_BIN' => bin }, RbConfig.ruby, check, File.join(d, 'bco.json'),
                                   '--zk-receipt', File.join(d, 'r.bin'), '--zk-receipt', File.join(d, 'b.bin'))
      refute_equal 0, st.exitstatus, out
      assert_includes out, 'local check: failed'
      assert_includes out, 'journal_convention_not_supported'
      # the check keys receipts by their own SHA-256, so a tampered file shows as the declared one missing
      assert_includes out, 'receipt_bytes_missing'

      second = Digest::SHA256.hexdigest(SECOND)
      with_proofs do |registry, tip_source|
        bytes = receipt_bytes(receipt('receipt_v02.bin')).merge(second => Base64.strict_encode64(SECOND))
        rec = record(registry, text, bytes: bytes, verifier: FakeZk.new(v02_answer), tip_source: tip_source)
        assert_equal 'recorded', rec[:status]
        route = JSON.parse(JSON.generate(GenomicsChainProv::PlaceExtension.new(nil, registry: registry)
                                                                          .lookup(rec[:synoptis_proof_id])))
        given = { Digest::SHA256.hexdigest(receipt('receipt_v02.bin')) => receipt('receipt_v02.bin'), second => 'tampered' }
        res = GenomicsChainProv::Verifier.new(bundle_text: text, route: route, zk_verifier: ZkV.new(bin: bin),
                                              receipts: given).run
        zk = res['confirmed'].find { |c| c['check'] == 'zk_receipts' }
        refute_nil zk, res.inspect
        assert_equal false, zk['ok']
        assert_includes zk['detail'], 'receipt_sha256_mismatch'
        assert_includes zk['detail'], 'journal_convention_not_supported'
        refute_includes res['record_notes'].join("\n"), 'zk receipts not checked here'
      end
    end
  end

  # Imprecise F5-2: the key was refused only on a prov_reachability record; a
  # record of any other stated type now refuses it too.
  def test_r2_f5_gc_prov_verify_refuses_the_key_on_any_non_prov_record_type
    Dir.mktmpdir do |d|
      File.write(File.join(d, 'bco.json'), bundle)
      File.binwrite(File.join(d, 'k'), KEY_A)
      script = File.expand_path('../bin/gc_prov_verify.rb', __dir__)
      run = lambda do |route|
        File.write(File.join(d, 'route.json'), JSON.generate(route))
        Open3.capture3({ 'GC_ZK_VERIFY_BIN' => '/nonexistent' }, RbConfig.ruby, script, File.join(d, 'bco.json'),
                       '--envelope', File.join(d, 'route.json'), '--commitment-key', File.join(d, 'k'))
      end
      _o, e, st = run.call('evidence' => JSON.generate('manifest' => { 'record_type' => 'tier1_assessment' }))
      assert_equal 2, st.exitstatus
      assert_includes e, 'only with a prov_attestation record'
      assert_includes e, 'tier1_assessment'
      # no stated record_type: left to the prov verifier, as before
      _o, e, _st = run.call('evidence' => JSON.generate('manifest' => {}))
      refute_includes e, 'only with a prov_attestation record'
    end
  end

  # ===================================================================================
  # Round-2 M1/M2 (log/mlr_tier25_v0116_impl_20261019/synthesis_r2.md)
  # ===================================================================================

  R2_PLAIN = '7' * 64
  R2_SHA1 = 'c' * 40

  # M1: a repeated object key. json 2.9.1 keeps the last value, so a plain
  # fingerprint in an earlier one is in the bytes and never in the parse.
  # v1: the option-1 bundle, whose items carry sha256.
  def r2_m1_shapes(base, v1: false)
    j = JSON.parse(base)
    item = j['extension_domain'].first['genomicschain_extension']['checksums'].first
    field = v1 ? 'sha256' : 'hmac_sha256'
    o = j['io_domain']['output_subdomain'].first
    u = JSON.generate(o['uri'])
    hid = u.sub(/\A\{/, %({"sha1_checksum":"#{R2_SHA1}",))
    plain = %({"uri":"#{IN}","sha256":"#{R2_PLAIN}"})
    shapes = {
      'duplicate checksums key' => base.sub('"checksums":[', %("checksums":[#{plain}],"checksums":[)),
      "duplicate #{field} inside an item" =>
        base.sub(JSON.generate(item), JSON.generate(item).sub(%("#{field}":), %("#{field}":"#{R2_PLAIN}","#{field}":))),
      'duplicate io uri hiding sha1_checksum' =>
        base.sub(JSON.generate(o), JSON.generate(o).sub(%("uri":#{u}), %("uri":#{hid},"uri":#{u}))),
      'duplicate extension_domain key' =>
        base.sub('"extension_domain":[', %("extension_domain":[{"genomicschain_extension":{"checksums":[#{plain}]}}],"extension_domain":[))
    }
    shapes.each { |name, text| refute_equal base, text, "#{name}: the shape was applied" }
    shapes
  end

  # M2: a `checksums` key anywhere but the top level of a genomicschain_extension
  # block in a top-level extension_domain element.
  def r2_m2_shapes(base)
    plain = [{ 'uri' => IN, 'sha256' => R2_PLAIN }]
    {
      'checksums under another extension name' =>
        edit(base) { |j, _e| j['extension_domain'] << { 'other_extension' => { 'checksums' => plain } } },
      'checksums as a sibling key in an extension_domain element' =>
        edit(base) { |j, _e| j['extension_domain'].first['checksums'] = plain },
      'checksums under a nested extension_domain' =>
        edit(base) { |_j, e| e['extension_domain'] = [{ 'genomicschain_extension' => { 'checksums' => plain } }] },
      'checksums inside a zk declaration' =>
        edit(base) { |_j, e| e['zk_receipts'].first['checksums'] = plain }
    }
  end

  def test_r2_m1_m2_the_adapter_refuses_each_shape_in_option2
    r2_m1_shapes(bundle).merge(r2_m2_shapes(bundle)).each do |name, text|
      assert(text.include?(R2_PLAIN) || text.include?(R2_SHA1), "#{name}: the bytes carry the plain fingerprint")
      assert_equal ['plain_fingerprint_in_option2_bundle'], refusals(text), name
      adm = Identity.admission(Identity.derive(text))
      refute adm['issuable'], name
      refute_includes JSON.generate(adm), R2_PLAIN, "#{name}: codes, never values"
    end
  end

  # Option 1 is untouched: the same shapes give what they gave on r2_code —
  # no refusal, issuable (values recorded from r2_code; the full identity,
  # grade, signed params and admission are compared across processes in
  # fix_evidence_r1.md § Round-2 M1/M2).
  def test_r2_m1_m2_option1_controls_are_unchanged
    v1 = bundle(key: nil, receipt_name: 'receipt_v01.bin', image_id: IMAGE_V01)
    r2_m1_shapes(v1, v1: true).merge(r2_m2_shapes(v1)).each do |name, text|
      assert_empty refusals(text), "option 1, #{name}"
      assert Identity.admission(Identity.derive(text))['issuable'], "option 1, #{name}"
    end
    # and the normalised parse ignores the earlier duplicate exactly as before:
    # the earlier duplicate leaves the identity, the bundle digest included,
    # unchanged — the digest is canonical JSON of the parsed object, in which
    # the earlier value no longer exists (the collapse round-3 C2 rests on)
    dup = r2_m1_shapes(v1, v1: true)['duplicate checksums key']
    assert_equal ProvSubmit.signed_params_for(v1), ProvSubmit.signed_params_for(dup),
                 'the identity, bundle digest included, is unchanged by the earlier duplicate'
  end

  # The anchor refuses before any receipt is verified, through the store
  # (NeverZk) and through the real MCP tool and config file.
  def test_r2_m1_m2_the_anchor_refuses_before_verification
    texts = { 'duplicate checksums key' => r2_m1_shapes(bundle)['duplicate checksums key'],
              'checksums under another extension name' => r2_m2_shapes(bundle)['checksums under another extension name'] }
    with_proofs do |registry, tip_source|
      bytes = receipt_bytes(receipt('receipt_v02.bin'))
      texts.each_value do |text|
        refused('plain_fingerprint_in_option2_bundle') do
          record(registry, text, bytes: bytes, verifier: NeverZk.new, tip_source: tip_source)
        end
      end
      assert_empty registry.read(:proofs)
    end
    texts.each do |name, text|
      places = admit_through_the_tool(text, 'receipt_v02.bin')
      assert_match(/\AError: \w+: .*\bplain_fingerprint_in_option2_bundle\b/, places['reply'], name)
      refute(places.any? { |k, _| k.end_with?('proofs.jsonl') }, "#{name}: nothing recorded")
      refute_includes places['reply'], R2_PLAIN, "#{name}: codes, never values"
    end
  end

  # The writer: an input bundle carrying another extension's plain checksums
  # is refused before writing, and an existing --out is left byte-identical.
  def test_r2_m2_gc_prov_write_refuses_another_extensions_plain_checksums_and_leaves_out_intact
    script = File.expand_path('../bin/gc_prov_write.rb', __dir__)
    other = { 'other_extension' => { 'checksums' => [{ 'uri' => NF_OUT, 'sha256' => R2_PLAIN }] } }
    with_nfcore_launch(extra_blocks: [other]) do |dir, _bco|
      File.binwrite(File.join(dir, 'k'), KEY_A)
      File.write(File.join(dir, 'zk.json'), JSON.generate([{ 'receipt' => 'r.bin', 'image_id' => IMAGE_V02, 'zkvm_version' => '3.0.6',
                                                             'step_number' => 2, 'input' => NF_IN, 'output' => NF_OUT }]))
      out_path = File.join(dir, 'out.json')
      File.binwrite(out_path, "PREEXISTING\n")
      _o, e, st = Open3.capture3(RbConfig.ruby, script, '--from-nextflow-run', dir, '--no-docker', '--container-digests',
                                 File.join(NFCORE, 'container_digests.txt'), '--nextflow-jar',
                                 File.join(dir, 'nextflow-26.04.6-one.jar'), '--zk-receipts', File.join(dir, 'zk.json'),
                                 '--commitment-key', File.join(dir, 'k'), '--out', out_path)
      refute st.success?, e
      assert_includes e, 'plain_fingerprint_in_option2_bundle'
      refute_includes e, R2_PLAIN, 'codes, never values'
      assert_equal "PREEXISTING\n", File.binread(out_path), '--out byte-identical'
    end
  end

  # ===================================================================================
  # Round-3 C1–C3 — bytes the parser drops: comments; the verifier re-checks the
  # bytes it holds; the option-2 sentence pinned to the checks
  # ===================================================================================

  # C1: json 2.9.1 accepts /* */ and // comments (no option turns them off), and
  # drops them; a plain fingerprint written in one is in the bytes only.
  def r3_c1_shapes(base)
    plain = %({"uri":"#{IN}","sha256":"#{R2_PLAIN}"})
    shapes = {
      'block comment with sha1_checksum at top level' => base.sub(/\A\{/, %({/* "sha1_checksum":"#{R2_SHA1}" */)),
      'block comment with sha1_checksum nested in io_domain' =>
        base.sub('"io_domain":{', %("io_domain":{/* "sha1_checksum":"#{R2_SHA1}" */)),
      'block comment with a plain item inside checksums' => base.sub('"checksums":[', %("checksums":[/* #{plain}, */)),
      'line comment with plain checksums at top level' => base.sub(/\A\{/, %({// "checksums":[#{plain}]\n)),
      'line comment with plain checksums nested in io_domain' =>
        base.sub('"io_domain":{', %("io_domain":{// "checksums":[#{plain}]\n)),
      'line comment after the document' => base + %(\n// "sha1_checksum":"#{R2_SHA1}"\n)
    }
    shapes.each do |name, text|
      refute_equal base, text, "#{name}: the shape was applied"
      assert_equal JSON.parse(base), JSON.parse(text), "#{name}: the parse drops the comment"
    end
    shapes
  end

  def test_r3_c1_the_adapter_refuses_a_comment_in_option2
    base = bundle
    r3_c1_shapes(base).each do |name, text|
      assert(text.include?(R2_PLAIN) || text.include?(R2_SHA1), "#{name}: the bytes carry the plain fingerprint")
      assert_equal Identity.bundle_digest(base), Identity.bundle_digest(text), "#{name}: same digest as the clean bundle"
      assert_equal ['plain_fingerprint_in_option2_bundle'], refusals(text), name
      refute_includes JSON.generate(Identity.admission(Identity.derive(text))), R2_PLAIN, "#{name}: codes, never values"
    end
  end

  # A '/' inside a string token is not a comment: URLs, an escaped \/, comment
  # markers inside a value, and a value ending in an escaped backslash (which
  # a scanner that mishandles escapes would read as the string not closing).
  def test_r3_c1_a_slash_inside_a_string_is_not_a_comment
    text = edit(bundle) do |j, _e|
      j['usability_domain'] = ['C:\\', 'https://example.org/a/*b*/ // c', '"/* quoted */"', 'end\\']
    end
    text = text.sub('"https://example.org/a/', '"https:\/\/example.org\/a/')
    assert_includes text, '\/\/example.org'
    assert_includes text, '"C:\\\\"'
    assert_empty refusals(text)
  end

  # Option 1 is not read for comments (its behaviour is unchanged), and a
  # bundle given as an object is re-serialised: it cannot carry a comment.
  def test_r3_c1_option1_and_object_input_are_unchanged
    v1 = bundle(key: nil, receipt_name: 'receipt_v01.bin', image_id: IMAGE_V01)
    r3_c1_shapes(v1).each { |name, text| assert_empty refusals(text), "option 1, #{name}" }
    r3_c1_shapes(bundle).each do |name, text|
      hash = JSON.parse(text)
      refute_includes JSON.generate(hash), '/*', name
      assert_empty Bco.parse(hash).refusals, "object input, #{name}"
    end
  end

  def test_r3_c1_the_anchor_refuses_a_comment_before_verification
    shapes = r3_c1_shapes(bundle)
    with_proofs do |registry, tip_source|
      bytes = receipt_bytes(receipt('receipt_v02.bin'))
      shapes.each_value do |text|
        refused('plain_fingerprint_in_option2_bundle') do
          record(registry, text, bytes: bytes, verifier: NeverZk.new, tip_source: tip_source)
        end
      end
      assert_empty registry.read(:proofs)
    end
    %w[block\ comment\ with\ sha1_checksum\ nested\ in\ io_domain line\ comment\ with\ plain\ checksums\ nested\ in\ io_domain].each do |name|
      places = admit_through_the_tool(shapes.fetch(name), 'receipt_v02.bin')
      assert_match(/\AError: \w+: .*\bplain_fingerprint_in_option2_bundle\b/, places['reply'], name)
      refute(places.any? { |k, _| k.end_with?('proofs.jsonl') }, "#{name}: nothing recorded")
      refute_includes places['reply'], R2_PLAIN, "#{name}: codes, never values"
      refute_includes places['reply'], R2_SHA1, "#{name}: codes, never values"
    end
  end

  # C2: the record's subject is the canonical digest, which cannot tell the
  # clean bytes from the same bundle with a repeated key or a comment. A
  # verifier holding such bytes re-runs the refusals and withholds the
  # option-2 statement.
  def test_r3_c2_the_verifier_rechecks_the_bytes_it_holds
    clean = bundle
    st = GenomicsChainProv::Verifier::JOURNAL_STATEMENTS['gc-zk-journal-0.2']
    dirty = {
      'repeated key' => clean.sub('"checksums":[', %("checksums":[{"uri":"#{IN}","sha256":"#{R2_PLAIN}"}],"checksums":[)),
      'comment' => clean.sub('"io_domain":{', %("io_domain":{/* "sha1_checksum":"#{R2_SHA1}" */))
    }
    recorded_route(clean, 'receipt_v02.bin', FakeZk.new(v02_answer)) do |route|
      res = verify(clean, route)
      assert_equal 'consistent', res['state']
      assert_includes res['statements'], st
      refute(res['confirmed'].any? { |c| c['check'] == 'option2_shape' })
      dirty.each do |name, text|
        assert_equal Identity.bundle_digest(clean), Identity.bundle_digest(text), "#{name}: same digest"
        res = verify(text, route)
        assert_equal 'mismatch', res['state'], name
        refute_includes res['statements'], st, name
        line = res['confirmed'].find { |c| c['check'] == 'option2_shape' }
        refute_nil line, name
        refute line['ok'], name
        assert_includes line['detail'], 'plain_fingerprint_in_option2_bundle', name
        refute_includes JSON.generate(res), R2_PLAIN, "#{name}: codes, never values"
        refute_includes JSON.generate(res), R2_SHA1, "#{name}: codes, never values"
      end
      Dir.mktmpdir do |d|
        script = File.expand_path('../bin/gc_prov_verify.rb', __dir__)
        File.write(File.join(d, 'route.json'), JSON.generate(route))
        { 'clean' => [clean, 0] }.merge(dirty.transform_values { |t| [t, 1] }).each do |name, (text, code)|
          File.write(File.join(d, 'bco.json'), text)
          out, _e, s = Open3.capture3({ 'GC_ZK_VERIFY_BIN' => '/nonexistent' }, RbConfig.ruby, script,
                                      File.join(d, 'bco.json'), '--envelope', File.join(d, 'route.json'))
          assert_equal code, s.exitstatus, "#{name}: #{out}"
          assert_equal code.zero?, out.include?(st), "#{name}: the 0.2 statement"
        end
      end
    end
  end

  # C3: each listed clause of the option-2 sentence, and a bundle built to
  # break that clause alone. A listed clause that loses its wording or its
  # check fails here. Not pinned: a new check added without a clause, and the
  # clause "this verifier checked the same" (its behaviour is test_r3_c2's).
  def test_r3_c3_the_option2_sentence_names_exactly_what_is_checked
    st = GenomicsChainProv::Verifier::JOURNAL_STATEMENTS['gc-zk-journal-0.2']
    base = bundle
    code = ['plain_fingerprint_in_option2_bundle']
    clauses = {
      'every checksums item is exactly a uri and an hmac_sha256, both text' => [
        [edit(base) { |_j, e| e['checksums'].first['note'] = 'x' }, code],
        [edit(base) { |_j, e| e['checksums'].first['hmac_sha256'] = 7 }, code]
      ],
      'a checksums key, with any value, appears nowhere except at the top level of a genomicschain_extension ' \
      'block in a top-level extension_domain element' => [
        [edit(base) { |_j, e| e['platform']['checksums'] = 'x' }, code],
        [edit(base) { |j, _e| j['checksums'] = [] }, code]
      ],
      'every top-level extension_domain element, and any genomicschain_extension value in one, is an object' => [
        [edit(base) { |j, _e| j['extension_domain'] << 'x' }, code],
        [edit(base) { |j, _e| j['extension_domain'] << { 'genomicschain_extension' => [] } }, code]
      ],
      'no sha1_checksum field' => [
        [edit(base) { |j, _e| j['io_domain']['output_subdomain'].first['uri']['sha1_checksum'] = R2_SHA1 }, code]
      ],
      'no repeated key' => [[base.sub(/\A\{/, '{"x":1,"x":1,'), code]],
      'no comment' => [[base.sub(/\A\{/, '{/**/'), code]],
      'A fingerprint written under any other field name is not looked at' => [
        [edit(base) { |j, _e| j['io_domain']['output_subdomain'].first['uri']['md5_checksum'] = R2_PLAIN }, []]
      ]
    }
    assert_empty refusals(base), 'the clean bundle'
    clauses.each do |clause, cases|
      assert_includes st, clause, 'the sentence names the clause'
      cases.each_with_index do |(text, want), i|
        refute_equal base, text, "#{clause} [#{i}]: the shape was applied"
        assert_equal want, refusals(text), "#{clause} [#{i}]"
      end
    end
  end

  # Separation-compat LOW: option-1 signed values pinned (recorded on r3_code,
  # separate process; the bundle's other digests depend on the host's /bin/sh).
  R3_OPTION1_PIN = { 'grade_overall' => 'immutable', 'adapter_version' => 'prov-adapter-bco-0.5.0',
                     'software_total' => 1, 'inputs_with_checksum' => 1, 'outputs_with_checksum' => 1 }.freeze

  # Sonnet P3: a harmless repeat is refused in option 2 and not in option 1.
  def test_r3_option1_pinned_value_and_a_harmless_repeat
    v1 = bundle(key: nil, receipt_name: 'receipt_v01.bin', image_id: IMAGE_V01)
    p1 = ProvSubmit.signed_params_for(v1)
    assert_equal R3_OPTION1_PIN, p1.slice(*R3_OPTION1_PIN.keys)
    assert_equal ['plain_fingerprint_in_option2_bundle'], refusals(bundle.sub(/\A\{/, '{"x":1,"x":1,'))
    assert_empty refusals(v1.sub(/\A\{/, '{"x":1,"x":1,'))
  end
end
