# frozen_string_literal: true

# Tier 3 v0.1 §9-7 — registration of the execution package. tier3 0.6.0 lists
# its three execution tools in tool_classes in every profile and no
# anchor-profile tool (the record tool lives in genomicschain_tier3_record,
# operator 2026-10-21, question 5); it depends on core, prov and tier3_record;
# core's skillset.json changed in its version line only. The two tool skins
# are exercised together once on a disposable anchor.
require_relative 't3_helper'
require 'kairos_mcp/storage/file_backend' # defines KairosMcp.data_dir= (the gc_prov_reach test loads it the same way)

class RegistrationTest < Minitest::Test
  include T3Helpers

  TIER3_DIR = File.expand_path('..', __dir__)
  EXECUTION_TOOLS = %w[GcTier3Execute GcTier3Estimate GcTier3Attest].map do |c|
    "KairosMcp::SkillSets::GenomicschainTier3::Tools::#{c}"
  end.freeze

  def setup = reset_nonces

  def tier3_json = JSON.parse(File.read(File.join(TIER3_DIR, 'skillset.json')))

  def load_tools
    require 'genomicschain_tier3_record/record_submit'
    require_relative '../tools/gc_tier3_attest'
    require_relative '../../genomicschain_tier3_record/tools/gc_tier3_record_submit'
  end

  # --- skillset.json ---------------------------------------------------------------------

  def test_tier3_version_and_depends_on
    assert_equal '0.6.0', tier3_json['version']
    deps = tier3_json['depends_on'].to_h { |d| [d['name'], d['version']] }
    assert_equal({ 'genomicschain_core' => '>= 0.6.4', 'genomicschain_prov' => '>= 0.6.0',
                   'genomicschain_tier3_record' => '>= 0.1.0' }, deps)
  end

  def test_tier3_lists_the_three_execution_tools_and_no_anchor_profile_tool
    assert_equal EXECUTION_TOOLS.sort, tier3_json['tool_classes'].sort
    refute tier3_json.key?('anchor_profile_tool_classes'), 'the execution package carries no anchor-profile tool'
  end

  # The execution package carries no submit path in any profile.
  def test_tier3_registers_the_same_three_tools_on_and_off_the_anchor
    tier3 = KairosMcp::Skillset.new(TIER3_DIR)
    [true, false].each do |profile|
      GC::Config.stub(:anchor_profile?, profile) do
        assert_equal EXECUTION_TOOLS.sort, tier3.tool_class_names.sort, "anchor_profile #{profile}"
      end
    end
  end

  # Fixed decision 1 as amended 2026-10-20: core's skillset.json changes in
  # one line only, the version 0.6.3 → 0.6.4; everything else is as at 2e36122.
  # The base is a pinned copy (fixtures/core_skillset_2e36122.json, written
  # once from `git show 2e36122:…`, sha256 72fa5027…), so no git history is
  # needed (review r2, fix group G3).
  CORE_BASE_FIXTURE = File.expand_path('fixtures/core_skillset_2e36122.json', __dir__)
  CORE_BASE_SHA256 = '72fa5027e6d28798d7ce8052f116eb2ab8b7cfbd4d450eb0c9b2aff68f3473df'

  def test_core_skillset_json_changes_only_its_version
    assert_equal CORE_BASE_SHA256, Digest::SHA256.file(CORE_BASE_FIXTURE).hexdigest, 'the pinned base is intact'
    path = File.join(WORKTREE, 'genomicschain_core', 'skillset.json')
    base = File.read(CORE_BASE_FIXTURE)
    now = File.read(path)
    assert_equal '0.6.4', JSON.parse(now)['version']
    assert_equal JSON.parse(base).merge('version' => '0.6.4'), JSON.parse(now)
    changed = base.lines.zip(now.lines).reject { |a, b| a == b }
    assert_equal base.lines.length, now.lines.length
    assert_equal [[%(  "version": "0.6.3",\n), %(  "version": "0.6.4",\n)]], changed
  end

  # --- the tool skins --------------------------------------------------------------------

  def test_the_attest_tool_input_schema_names_its_actions
    load_tools
    attest = T3::Tools::GcTier3Attest.new(nil)
    assert_equal 'gc_tier3_attest', attest.name
    assert_equal %w[declare attempt attest], attest.input_schema.dig(:properties, :action, :enum)
    assert_includes attest.input_schema[:required].map(&:to_s), 'action'
  end

  # An anchor-profile instance in a temporary data dir (the gc_prov_reach
  # precedent): the attestor is the stub, built the way SynoptisAttestor.build
  # is (its operator_pubkey becomes the envelope submitter); the Bearer
  # follows the signing key.
  def with_anchor_tool
    require 'fileutils'
    load_tools
    previous = KairosMcp.instance_variable_get(:@data_dir)
    Dir.mktmpdir('t3_tool') do |dir|
      KairosMcp.data_dir = dir
      cfg = File.join(KairosMcp.skillsets_dir, 'genomicschain_core', 'config')
      FileUtils.mkdir_p(cfg)
      File.write(File.join(cfg, 'genomicschain_core.yml'), "genomicschain:\n  anchor_profile: true\n")
      registry = ::Synoptis::Registry::FileRegistry.new(data_dir: File.join(dir, 'synoptis_data'))
      tip = GC::TipSource.new(registry: registry)
      KairosMcp::Manifest::Signer.bootstrap_seen_list!(tip_source: tip)
      holder = {}
      build = ->(**kw) { T3StubAttestor.new(registry: registry, submitter_pubkey: kw[:operator_pubkey]) }
      GC::Attestation::SynoptisAttestor.stub(:build, build) do
        safety = Object.new
        safety.define_singleton_method(:current_user) { { user: 'executor', pubkey_hash: holder[:bearer] } }
        tool = T3R::Tools::GcTier3RecordSubmit.new(safety)
        caller = Object.new
        caller.define_singleton_method(:call) do |args|
          pk = args.dig('operator', 'pubkey')
          holder[:bearer] = pk && Digest::SHA256.hexdigest(pk)
          tool.call(args)
        end
        yield caller, registry, tip, dir
      end
    end
  ensure
    KairosMcp.instance_variable_set(:@data_dir, previous)
    KairosMcp.instance_variable_set(:@path_cache, {})
  end

  # gc_tier3_attest → gc_tier3_record_submit, through both MCP skins.
  def test_both_tools_record_a_declaration_and_its_attestation
    with_anchor_tool do |record, registry, tip, dir|
      skp, = write_signing_key(dir)
      d = ok!(declare_args(dir, skp, tip.latest_tip_hash))
      dres = JSON.parse(record.call(d.dig('submit', 'arguments')).first[:text])
      assert_equal 'recorded', dres['status'], dres.inspect
      assert_equal Digest::SHA256.hexdigest(dres['submission_key']), dres['idempotency_key']
      assert_match ISO, dres.dig('declaration_ref', 'recorded_at')
      ok!(attempt_args(dir))
      a = ok!(attest_args(dir, skp, dres['declaration_ref'], tip.latest_tip_hash))
      ares = JSON.parse(record.call(a.dig('submit', 'arguments')).first[:text])
      assert_equal 'recorded', ares['status'], ares.inspect
      types = registry.read(:proofs).map { |r| GC::ProofLookup.parse_manifest_from_record(r)['record_type'] }
      assert_equal %w[tier3_declaration tier3_attestation], types
      [dres, ares].each { |r| FORBIDDEN.each { |w| refute_includes JSON.generate(r), w } }
      again = JSON.parse(record.call(a.dig('submit', 'arguments')).first[:text])
      assert_equal [true, ares['synoptis_proof_id']], again.values_at('recovered', 'synoptis_proof_id'),
                   'an identical resend recovers the existing proof through the tool'
      ok!(attempt_args(dir))
      b = ok!(attest_args(dir, skp, dres['declaration_ref'], tip.latest_tip_hash))
      second = record.call(b.dig('submit', 'arguments')).first[:text]
      assert second.start_with?('Error:'), 'an attestation with other attempts is refused through the tool'
      assert_includes second, 'AlreadyAttested'
      assert_equal 1, registry.read(:proofs).count { |r| GC::ProofLookup.parse_manifest_from_record(r)['record_type'] == 'tier3_attestation' }
    end
  end

  # Review r4 LOW (Fable L3): a route-B declaration and its attestation pass
  # through both MCP skins, over the v0.3 fixture bundle's Tier-2.5 record in
  # the anchor's own registry; the route_proof_id travels only in the submit
  # arguments and never reaches a record.
  def test_both_tools_record_a_route_b_declaration_and_its_attestation
    with_anchor_tool do |record, registry, tip, dir|
      prov_id = prov_record(registry, tip)
      skp, = write_signing_key(dir)
      d = ok!(declare_args(dir, skp, tip.latest_tip_hash, route: 'B',
                                     'pipeline' => { 'command' => write_command('counts.tsv' => V03_OUTPUT) },
                                     **route_b_args(rows: v03_rows, route_proof_id: prov_id,
                                                    bundle_digest: v03_signed['bundle_digest'])))
      assert_equal prov_id, d.dig('submit', 'arguments', 'route_proof_id')
      dres = JSON.parse(record.call(d.dig('submit', 'arguments')).first[:text])
      assert_equal 'recorded', dres['status'], dres.inspect
      row = ok!(attempt_args(dir))['attempt']
      assert_equal [1, 1, 'match_exact'], row.values_at('m', 'n', 'comparison_verdict')
      a = ok!(attest_args(dir, skp, dres['declaration_ref'], tip.latest_tip_hash))
      ares = JSON.parse(record.call(a.dig('submit', 'arguments')).first[:text])
      assert_equal 'recorded', ares['status'], ares.inspect
      decl = GC::ProofLookup.parse_evidence(registry.find_proof(dres['synoptis_proof_id']).evidence)['manifest']
      assert_equal %w[tier2_5_bundle procedure_checked procedure_checked],
                   [decl.dig('targets', 'kind'), decl.dig('backing', 'route_ref'), decl.dig('backing', 'outputs_digest')]
      [dres['synoptis_proof_id'], ares['synoptis_proof_id']].each do |id|
        refute_includes registry.find_proof(id).evidence.to_s, prov_id
      end
    end
  end
end
