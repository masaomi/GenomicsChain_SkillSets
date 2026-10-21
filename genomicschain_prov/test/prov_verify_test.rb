# frozen_string_literal: true

# U5 (design v0.1 §8, §9; v0.1.12 §6.1): gc_prov_verify's logic, against
# records made the way the anchor makes them — SubmitCore, the real
# SynoptisAttestor, an RSA anchor key — and read back through the public
# route's own lookup. One test per row of §8's table, the version heading,
# and the two keys that move lines from "the anchor says" to "confirmed".
#
# Run: ruby -Ilib -Itest -I../genomicschain_core/lib -I../genomicschain_tier2/lib \
#        -I"$T/synoptis/lib" -I"$T/mmp/lib" test/prov_verify_test.rb
require 'minitest/autorun'
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
require 'synoptis/proof_envelope'
require 'synoptis/verifier'
require 'synoptis/attestation_engine'
require 'synoptis/registry/file_registry'
require 'mmp/crypto'

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'genomicschain_core'
require 'genomicschain_prov'
require 'genomicschain_prov/writer/environment'
require 'genomicschain_prov/prov_submit'
require 'genomicschain_prov/place_extension'
require 'genomicschain_prov/verifier'

class ProvVerifyTest < Minitest::Test
  GC = KairosMcp::SkillSets::GenomicschainCore
  W = GenomicsChainProv::Writer
  Env = W::Environment
  Verifier = GenomicsChainProv::Verifier
  ZK = File.expand_path('fixtures/zk_sizefactor_s1', __dir__)
  VERIFY = File.expand_path('../bin/gc_prov_verify.rb', __dir__)
  ANCHOR = MMP::Crypto.new(auto_generate: true)

  def setup
    KairosMcp::Manifest::Signer.instance_variable_set(:@global_reservation, nil)
  end

  # One recorded bundle (with the real ZK receipt declared) and what the
  # route returns for it. Yields bundle text, route body, receipt bytes and
  # the submitter's pubkey.
  def recorded
    Dir.mktmpdir('prov_verify') do |dir|
      run = File.join(dir, 'run')
      FileUtils.mkdir_p(File.join(run, 'tools'))
      %w[S1_odd.kmat S1_odd__valid_exact.sfq3].each { |f| FileUtils.cp(File.join(ZK, f), run) }
      FileUtils.cp(File.join(ZK, 'receipt.succinct.bin'), File.join(run, 'receipt.bin'))
      File.write(File.join(run, 'tools', 'checker.sh'), "#!/bin/sh\n")
      File.write(File.join(run, 'run.sh'), "#!/bin/sh\n")
      plan = W.normalise_plan(
        'name' => 'size-factor-check', 'script' => 'run.sh',
        'runtime' => { 'engine' => 'sh', 'version' => '5.2.21', 'uri' => '/bin/sh', 'path' => '/bin/sh' },
        'platform' => { 'cpu_architecture' => 'x86_64', 'os_name' => 'Linux', 'os_release' => '6.8.0' },
        'stages' => [{ 'name' => 'sizefactor', 'inputs' => ['S1_odd.kmat'], 'outputs' => ['S1_odd__valid_exact.sfq3'],
                       'tools' => [{ 'name' => 'checker.sh', 'version' => '0.1.0', 'uri' => 'tools/checker.sh' }] }],
        'zk_receipts' => [{ 'receipt' => 'receipt.bin', 'image_id' => File.read(File.join(ZK, 'image_id.txt')).strip,
                            'zkvm_version' => '3.0.6', 'step_number' => 1, 'input' => 'S1_odd.kmat',
                            'output' => 'S1_odd__valid_exact.sfq3' }]
      )
      r = Env.resolve!(plan, base_dir: run, docker: false)
      d = Env.zk_declarations(plan['zk_receipts'], base_dir: run)
      text = JSON.pretty_generate(W.build(plan, checksums: r['checksums'], platform: plan['platform'],
                                              zk_receipts: d['zk_receipts']))
      receipt = File.binread(File.join(run, 'receipt.bin'))

      registry = ::Synoptis::Registry::FileRegistry.new(data_dir: File.join(dir, 'proofs'))
      tip = GC::TipSource.new(registry: registry)
      KairosMcp::Manifest::Signer.bootstrap_seen_list!(tip_source: tip)
      sk = Ed25519::SigningKey.generate
      pubkey = 'ed25519:' + Base64.urlsafe_encode64(sk.verify_key.to_bytes, padding: false)
      params = GenomicsChainProv::ProvSubmit.signed_params_for(text)
      nonce = SecureRandom.hex(16)
      payload = KairosMcp::Manifest.canonical_json('mcp_tool_name' => 'gc_prov_submit', 'params' => params,
                                                   'nonce' => nonce, 'chain_tip_hash' => tip.latest_tip_hash)
      op = { 'mode' => 'signed', 'pubkey' => pubkey,
             'signature' => { 'algorithm' => 'ed25519', 'signed_fields' => %w[mcp_tool_name params nonce chain_tip_hash],
                              'value' => Base64.urlsafe_encode64(sk.sign(payload), padding: false),
                              'nonce' => nonce, 'chain_tip_hash' => tip.latest_tip_hash } }
      engine = ::Synoptis::AttestationEngine.new(registry: registry,
                                                 config: { 'require_signature' => true, 'default_ttl' => 86_400 })
      attestor = GC::Attestation::SynoptisAttestor.new(engine: engine, attester_id: 'mmp:test-anchor', crypto: ANCHOR,
                                                        submitter_pubkey: pubkey, registry: registry)
      fake = Class.new(GenomicsChainProv::ZkVerifier) do
        def run(_b, _i) = { 'verified' => true, 'journal_ok' => true, 'tool' => 'gc_zk_verify', 'version' => '0.1.0',
                            'risc0_zkvm' => '3.0.6', 'journal_convention' => 'gc-zk-journal-0.1',
                            'journal_input_sha256' => '5cb5cfc3a976faa8b8db6a8799ebc3372097833845e38d99e9247c14a86aede3',
                            'journal_output_sha256' => '7d8c053239d53b373ae09674c2bd3f1456038c414e54534762ba7592ec9b4515' }
      end.new(bin: '/nonexistent')
      out = GenomicsChainProv::ProvSubmit.submit(
        bundle: text, identity: params, operator: op, bearer_pubkey_hash: Digest::SHA256.hexdigest(pubkey),
        tip_source: tip, attestor: attestor, registry: registry,
        zk_receipt_bytes: { Digest::SHA256.hexdigest(receipt) => Base64.strict_encode64(receipt) }, zk_verifier: fake
      )
      assert_equal 'recorded', out[:status]
      route = JSON.parse(JSON.generate(GenomicsChainProv::PlaceExtension.new(nil, registry: registry)
                                                                         .lookup(out[:synoptis_proof_id])))
      yield text, route, receipt, pubkey
    end
  end

  def verify(text, route, **kw)
    Verifier.new(bundle_text: text, route: route, zk_verifier: GenomicsChainProv::ZkVerifier.new(bin: '/nonexistent'),
                 **kw).run
  end

  def details(res) = res['confirmed'].map { |c| c['detail'] }.join("\n")
  def bad(res) = res['confirmed'].reject { |c| c['ok'] }.map { |c| c['check'] }

  # --- the ordinary case --------------------------------------------------------

  def test_a_recorded_bundle_is_consistent_and_says_what_it_did_not_check
    recorded do |text, route|
      res = verify(text, route)
      assert_equal 'consistent', res['state']
      assert_equal %w[bundle_digest subject_ref manifest_body_sha256 submitter_pubkey submission_key claim
                      submitter_signature grades_and_counts resources], res['confirmed'].map { |c| c['check'] }
      assert_includes details(res), 'self-consistent with the key in the manifest — this does not show who the submitter is'
      assert(res['anchor_says'].any? { |s| s.include?('(anchor-reported)') && s.include?('mmp:test-anchor') })
      assert(res['anchor_says'].any? { |s| s.include?('zk receipts: 1 verified') && s.include?('anchor-reported') })
      assert_equal 12, res['not_checked'].length, 'eleven from the record and the one nobody can say (Tier 3)'
      # v0.1.16 §7: the two statements, and the one for a gc-zk-journal-0.1 receipt
      assert_equal GenomicsChainProv::Identity::STATEMENTS + [Verifier::JOURNAL_STATEMENTS['gc-zk-journal-0.1']],
                   res['statements']
      assert_includes res['summary'].join, 'platform as stated in the bundle: x86_64 Linux 6.8.0'
    end
  end

  def test_a_tampered_bundle_is_a_mismatch
    recorded do |text, route|
      j = JSON.parse(text)
      j['usability_domain'] = ['edited after recording']
      res = verify(JSON.generate(j), route)
      assert_equal 'mismatch', res['state']
      assert_includes bad(res), 'bundle_digest'
      assert_includes bad(res), 'subject_ref'
    end
  end

  def test_the_submitter_key_from_outside_names_who_signed
    recorded do |text, route, _, pubkey|
      res = verify(text, route, submitter_pubkey: pubkey)
      assert_equal 'consistent', res['state']
      assert_includes details(res), 'verifies under the key given'

      other = 'ed25519:' + Base64.urlsafe_encode64(Ed25519::SigningKey.generate.verify_key.to_bytes, padding: false)
      res = verify(text, route, submitter_pubkey: other)
      assert_equal ['submitter_signature'], bad(res)
    end
  end

  # The signature itself, not only the key's name: a record whose signature
  # bytes were replaced (the manifest re-hashed so nothing else trips) fails
  # here even with no key given from outside.
  def test_a_forged_submitter_signature_is_a_mismatch
    recorded do |text, route|
      ev = JSON.parse(route['evidence'])
      m = ev['manifest']
      sig = Base64.urlsafe_decode64(m.dig('operator', 'signature', 'value'))
      sig.setbyte(0, sig.getbyte(0) ^ 1)
      m['operator']['signature']['value'] = Base64.urlsafe_encode64(sig, padding: false)
      ev['manifest_body_sha256'] = Digest::SHA256.hexdigest(KairosMcp::Manifest.canonical_json(m))
      res = verify(text, route.merge('evidence' => JSON.generate(ev)))
      assert_equal ['submitter_signature'], bad(res)
      assert_includes details(res), 'does NOT verify'
    end
  end

  # --anchor-pubkey: the anchor's signature is checked, and what it covers
  # moves into "confirmed"; a wrong key is the §8 table's third row.
  def test_the_anchor_key_moves_the_witness_into_confirmed_and_a_wrong_key_is_reported
    recorded do |text, route|
      res = verify(text, route, anchor_pubkey_pem: ANCHOR.export_public_key)
      assert_equal 'consistent', res['state']
      assert_includes res['confirmed'].map { |c| c['check'] }, 'anchor_signature'
      assert(res['anchor_says'].any? { |s| s.include?('confirmed with the anchor key given') })

      res = verify(text, route, anchor_pubkey_pem: MMP::Crypto.new(auto_generate: true).export_public_key)
      assert_equal ['anchor_signature'], bad(res)
      assert_includes details(res), 'does NOT verify under the key given'
    end
  end

  def test_a_receipt_held_here_is_checked_here
    skip 'gc_zk_verify not built: cargo build --release in genomicschain_prov/zk_verifier' unless GenomicsChainProv::ZkVerifier.available?

    recorded do |text, route, receipt|
      res = Verifier.new(bundle_text: text, route: route, receipts: { Digest::SHA256.hexdigest(receipt) => receipt }).run
      assert_equal 'consistent', res['state']
      assert_includes details(res), 'zk receipts verified here and bound to their steps (stage 1: ok)'
      refute(res['anchor_says'].any? { |s| s.start_with?('zk receipts:') }, 'no longer only the anchor\'s word')
    end
  end

  # --- v0.1.14 §6.2 (6): old records and the resource rule ----------------------

  V03 = File.expand_path('fixtures/record_v0_3', __dir__)

  # (ii): a record prov 0.3.0 made, before the change (made_with.json says
  # so), read by this verifier. Everything it signed re-derives, and nothing
  # is said about resources — a 0.3 record has none.
  #
  # v0.1.16 S3 (v): the record names adapter 0.4.0 and this verifier runs
  # 0.5.0, so the grades and counts are not re-derived and the difference is
  # reported as one of version. Every other check — digest, signatures,
  # submission_key, claim — is unchanged.
  def test_a_record_made_by_prov_0_3_0_is_consistent_under_this_verifier
    route = JSON.parse(File.read(File.join(V03, 'route.json')))
    signed = JSON.parse(route['evidence'])['manifest']
    assert_equal '0.3', signed['record_version'], 'the record itself, inside the anchor-signed evidence'
    assert_equal 9, signed['not_checked'].length
    assert_nil signed['grade_resources']
    res = verify(File.read(File.join(V03, 'bundle.json')), route,
                 submitter_pubkey: File.read(File.join(V03, 'submitter_pubkey.txt')).strip,
                 anchor_pubkey_pem: File.read(File.join(V03, 'anchor_pubkey.pem')))
    assert_equal 'consistent', res['state']
    assert_equal %w[bundle_digest subject_ref manifest_body_sha256 submitter_pubkey submission_key claim
                    submitter_signature anchor_signature], res['confirmed'].map { |c| c['check'] }
    assert_includes res['version_note'], 'prov-adapter-bco-0.5.0'
    assert_includes res['version_note'], 'prov-adapter-bco-0.4.0'
    assert_includes res['version_note'], 'a difference of version, not a mismatch'
    assert_nil res['resources_version_note']
    assert_equal 10, res['not_checked'].length, 'the nine the 0.3 record carries, and the Tier 3 line'
    refute(Array(res['summary']).any? { |l| l.start_with?('resources') })
  end

  def swap_rule(version)
    R.send(:remove_const, :RULE_VERSION)
    R.const_set(:RULE_VERSION, version)
  end
  R = GenomicsChainProv::Resources

  # (v): a 0.4 record made under another resource rule. The seven grades and
  # the counts still re-derive; only the resource fields go under the
  # version heading. One gate over all four versions would have lost both.
  def test_a_different_resource_rule_affects_the_resource_fields_only
    saved = R::RULE_VERSION
    swap_rule('gc-resources-0.0')
    recorded do |text, route|
      swap_rule(saved)
      res = verify(text, route)
      assert_equal 'consistent', res['state']
      assert_includes res['confirmed'].map { |c| c['check'] }, 'grades_and_counts'
      refute_includes res['confirmed'].map { |c| c['check'] }, 'resources'
      assert_nil res['version_note']
      assert_includes res['resources_version_note'], 'gc-resources-0.0'
      assert_includes res['resources_version_note'], 'not a mismatch'
    end
  ensure
    swap_rule(saved) unless R::RULE_VERSION == saved
  end

  # A record whose fields disagree with the bundle under the same versions:
  # each gate reports its mismatch, and the verifier does not crash on a
  # field of the wrong type (implementation review r1).
  def tampered(route, changes)
    ev = JSON.parse(route['evidence'])
    ev['manifest'].merge!(changes)
    ev['manifest_body_sha256'] = Digest::SHA256.hexdigest(KairosMcp::Manifest.canonical_json(ev['manifest']))
    route.merge('evidence' => JSON.generate(ev))
  end

  def test_each_gate_reports_a_field_that_does_not_re_derive
    recorded do |text, route|
      res = verify(text, tampered(route, 'gpus_total' => '2', 'gpu_models' => [{ 'count' => 'x' }]))
      assert_equal 'mismatch', res['state']
      assert_includes bad(res), 'resources'
      refute(res['summary'].to_a.any? { |l| l.start_with?('resources:') }, 'no summary from fields that did not re-derive')

      res = verify(text, tampered(route, 'stages_total' => 7))
      assert_includes bad(res), 'grades_and_counts'
      refute_includes bad(res), 'resources'
      line = res['summary'].find { |l| l.start_with?('resources:') }
      assert_includes line, 'requested on 0/1 stages', 'the stage count comes from the bundle, not the tampered record'
    end
  end

  def test_the_summary_says_what_the_record_carries_about_resources
    recorded do |text, route|
      lines = verify(text, route)['summary']
      assert(lines.any? { |l| l.start_with?('resources: absent (gc-resources-0.1, not part of the overall grade)') })
      assert(lines.any? { |l| l.include?('machine as stated (none): GPUs not looked for') })
    end
  end

  # --- §8's table --------------------------------------------------------------------

  # row 1
  def test_revoked_is_reported_as_the_anchors_word_and_the_bundle_is_still_compared
    recorded do |text, route|
      res = verify(text, route.merge('revoked' => true), anchor_pubkey_pem: ANCHOR.export_public_key)
      assert_equal 'consistent', res['state'], 'revoking does not change the bundle\'s identity'
      assert(res['anchor_says'].any? { |s| s.include?('the anchor says it revoked this proof') && s.include?('always anchor-reported') })
    end
  end

  # row 2
  def test_a_passed_ttl_is_a_mark_of_age_not_an_invalid_record
    recorded do |text, route|
      res = verify(text, route.merge('timestamp' => '2020-01-01T00:00:00Z', 'ttl' => 60))
      assert(res['anchor_says'].any? { |s| s.include?('the TTL has passed') && s.include?('not of an invalid record') })
      assert_empty bad(res), 'every bundle check still ran and held'
      assert_includes res['confirmed'].map { |c| c['check'] }, 'grades_and_counts'
    end
  end

  # v0.1.13: the admission rule is read by its own value, so a record made
  # under the withdrawn gate is still described by the gate it was made under.
  def test_the_admission_rule_is_described_by_the_rule_the_record_names
    recorded do |text, route|
      says = ->(r) { verify(text, r)['anchor_says'].find { |s| s.start_with?('admission rule') } }
      assert_equal 'admission rule prov-admission-0.2: issued at any grade, the grade carried as computed, with ' \
                   'every declared zk receipt verified and bound to its step', says.call(route)
      with_rule = lambda do |rule|
        ev = JSON.parse(route['evidence'])
        ev['manifest']['admission_rule'] = rule
        route.merge('evidence' => JSON.generate(ev))
      end
      assert_includes says.call(with_rule.call('prov-admission-0.1')), 'issued only at grade immutable'
      assert_includes says.call(with_rule.call('prov-admission-9.9')), 'a rule this verifier does not know'
    end
  end

  # row 4
  def test_an_identity_outside_the_signature_is_ignored_and_the_manifest_key_is_used
    recorded do |text, route|
      res = verify(text, route.merge('version' => '1.0.0'))
      assert(res['record_notes'].any? { |n| n.include?('outside the signature') })
      refute_includes res['confirmed'].map { |c| c['check'] }, 'submitter_pubkey'
      assert_equal 'consistent', res['state'], 'the evidence is inside the signature at every version'
    end
  end

  # row 5
  def test_an_incomplete_envelope_is_reported_and_the_manifest_is_still_compared
    recorded do |text, route|
      res = verify(text, route.merge('attester_id' => nil))
      assert(res['record_notes'].any? { |n| n.include?('lacks attester_id') })
      assert_includes res['confirmed'].map { |c| c['check'] }, 'grades_and_counts'
    end
  end

  # row 6, in its four forms
  def test_a_record_that_is_not_readable_as_prov_prints_the_bundle_digest_only
    recorded do |text, route|
      ev = JSON.parse(route['evidence'])
      forms = {
        route.merge('evidence' => 'not json') => 'evidence is not JSON',
        route.merge('evidence' => JSON.generate(ev.merge('manifest' => ev['manifest'].merge('record_type' => 'tier2_adjudication')))) =>
          'record_type is not prov_attestation',
        route.merge('evidence' => JSON.generate(ev.merge('manifest' => ev['manifest'].merge('bundle_digest_canonicalization' => 'jcs-rfc8785')))) =>
          'unknown digest rule',
        route.merge('version' => '2.0.0') => 'unknown envelope version'
      }
      forms.each do |r, reason|
        res = verify(text, r)
        assert_equal 'not_comparable', res['state'], reason
        assert_match(/#{reason}/, res['record_notes'].join)
        assert_equal GenomicsChainProv::Identity.bundle_digest(text), res['bundle_digest']
        assert_empty res['confirmed']
      end
    end
  end

  # rows 7 and 8
  def test_a_route_that_does_not_answer_says_why_and_prints_the_digest
    recorded do |text, _route|
      { 404 => 'does not know this proof_id', 429 => 'try again later', 500 => 'HTTP 500',
        nil => 'could not be reached' }.each do |status, phrase|
        res = Verifier.new(bundle_text: text, fetch_error: { 'status' => status, 'reason' => 'x' }).run
        assert_equal 'not_comparable', res['state']
        assert_includes res['record_notes'].join, phrase
        refute_nil res['bundle_digest']
      end
    end
  end

  # --- the version heading -------------------------------------------------------------

  def test_a_different_predicate_version_is_not_re_derived_and_is_not_a_mismatch
    recorded do |text, route|
      pred = GenomicsChainProv::Predicate
      real = pred::PREDICATE_VERSION
      pred.send(:remove_const, :PREDICATE_VERSION)
      pred.const_set(:PREDICATE_VERSION, 'prov-predicate-9.9.9')
      begin
        res = verify(text, route)
      ensure
        pred.send(:remove_const, :PREDICATE_VERSION)
        pred.const_set(:PREDICATE_VERSION, real)
      end
      assert_equal 'consistent', res['state']
      assert_includes res['version_note'], 'not a mismatch'
      assert_includes res['version_note'], 'prov-predicate-0.3.7'
      refute_includes res['confirmed'].map { |c| c['check'] }, 'grades_and_counts'
      assert_includes res['confirmed'].map { |c| c['check'] }, 'submitter_signature',
                      'the signature depends on record_version, not on the procedure versions'
    end
  end

  def test_an_unknown_record_version_skips_what_depends_on_the_signed_field_set
    recorded do |text, route|
      ev = JSON.parse(route['evidence'])
      m = ev['manifest'].merge('record_version' => '9.9')
      ev = ev.merge('manifest' => m, 'manifest_body_sha256' => Digest::SHA256.hexdigest(KairosMcp::Manifest.canonical_json(m)))
      res = verify(text, route.merge('evidence' => JSON.generate(ev)))
      assert_equal 'consistent', res['state']
      assert_includes res['version_note'], 'record_version "9.9"'
      assert_equal %w[bundle_digest subject_ref manifest_body_sha256 submitter_pubkey], res['confirmed'].map { |c| c['check'] }
    end
  end

  # --- the command line ------------------------------------------------------------------

  def test_the_cli_reads_a_saved_route_body_and_exits_by_the_result
    recorded do |text, route|
      Dir.mktmpdir do |d|
        File.write(File.join(d, 'bco.json'), text)
        File.write(File.join(d, 'proof.json'), JSON.generate(route))
        out, err, st = Open3.capture3(RbConfig.ruby, VERIFY, File.join(d, 'bco.json'), '--envelope', File.join(d, 'proof.json'))
        assert_equal 0, st.exitstatus, err
        %w[CONFIRMED THE\ ANCHOR\ SAYS NOT\ CHECKED].each { |h| assert_includes out, h }
        GenomicsChainProv::Identity::STATEMENTS.each { |s| assert_includes out, s }

        File.write(File.join(d, 'bco.json'), text.sub('size-factor-check', 'another-name'))
        out, _, st = Open3.capture3(RbConfig.ruby, VERIFY, File.join(d, 'bco.json'), '--envelope', File.join(d, 'proof.json'))
        assert_equal 1, st.exitstatus
        assert_includes out, '[MISMATCH]'
      end
    end
  end
end
