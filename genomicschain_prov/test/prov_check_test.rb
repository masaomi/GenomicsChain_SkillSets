# frozen_string_literal: true

# gc_prov_check (design §7, §9 U4; v0.1.12 §6.1): the customer's look at a
# bundle before submitting. It must give the anchor's answers — the same
# signed params, the same admission — because it runs the same code, and it
# must say plainly when the anchor would refuse and why.
require 'minitest/autorun'
require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'
require 'fileutils'
require 'digest'

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'genomicschain_prov'
require 'genomicschain_prov/writer/environment'
require_relative '../bin/gc_prov_check'

class ProvCheckTest < Minitest::Test
  W = GenomicsChainProv::Writer
  Env = GenomicsChainProv::Writer::Environment
  CHECK = File.expand_path('../bin/gc_prov_check.rb', __dir__)
  ZK = File.expand_path('fixtures/zk_sizefactor_s1', __dir__)
  IMAGE_ID = File.read(File.join(ZK, 'image_id.txt')).strip

  # The size-factor step, written by gc_prov_write's library from real files;
  # the receipt, when asked for, is the real one for this matrix.
  def with_bundle(checksums: true, zk: false)
    Dir.mktmpdir('prov_check') do |dir|
      FileUtils.mkdir_p(File.join(dir, 'tools'))
      %w[S1_odd.kmat S1_odd__valid_exact.sfq3].each { |f| FileUtils.cp(File.join(ZK, f), dir) }
      FileUtils.cp(File.join(ZK, 'receipt.succinct.bin'), File.join(dir, 'receipt.bin'))
      File.write(File.join(dir, 'tools', 'checker.sh'), "#!/bin/sh\n")
      File.write(File.join(dir, 'run.sh'), "#!/bin/sh\nsh tools/checker.sh\n")
      raw = {
        'name' => 'size-factor-check', 'script' => 'run.sh',
        'runtime' => { 'engine' => 'sh', 'version' => '5.2.21', 'uri' => '/bin/sh', 'path' => '/bin/sh' },
        'platform' => { 'cpu_architecture' => 'arm64', 'os_name' => 'Darwin', 'os_release' => '23.6.0' },
        'stages' => [{ 'name' => 'sizefactor', 'inputs' => ['S1_odd.kmat'], 'outputs' => ['S1_odd__valid_exact.sfq3'],
                       'tools' => [{ 'name' => 'checker.sh', 'version' => '0.1.0', 'uri' => 'tools/checker.sh' }] }]
      }
      if zk
        raw['zk_receipts'] = [{ 'receipt' => 'receipt.bin', 'image_id' => IMAGE_ID, 'zkvm_version' => '3.0.6',
                                'step_number' => 1, 'input' => 'S1_odd.kmat', 'output' => 'S1_odd__valid_exact.sfq3' }]
      end
      plan = W.normalise_plan(raw)
      resolved = Env.resolve!(plan, base_dir: dir, checksums: checksums, docker: false)
      decl = Env.zk_declarations(plan['zk_receipts'], base_dir: dir)
      path = File.join(dir, 'bco.json')
      File.write(path, JSON.pretty_generate(W.build(plan, checksums: resolved['checksums'], platform: plan['platform'],
                                                         zk_receipts: decl['zk_receipts'])))
      yield path, File.join(dir, 'receipt.bin')
    end
  end

  def run_check(*args)
    Open3.capture3(RbConfig.ruby, CHECK, *args)
  end

  def test_an_immutable_bundle_would_be_recorded_and_the_params_are_the_anchors
    with_bundle do |path|
      out, err, st = run_check(path)
      assert_equal 0, st.exitstatus, err
      assert_includes out, 'grade: immutable'
      assert_includes out, 'Tier 2.5: the anchor would issue a record'
      assert_includes out, 'platform: arm64 Darwin 23.6.0'

      json, = run_check(path, '--json')
      res = JSON.parse(json)
      assert_equal GenomicsChainProv::Identity.derive(File.read(path))['signed'], res['signed_params']
      assert_equal true, res.dig('admission', 'issuable')
      assert_equal 'none_declared', res.dig('zk_local', 'state')
    end
  end

  # No grade gate since design v0.1.13: a bundle below immutable would be
  # recorded, and the customer is told which grade the record will carry.
  def test_a_bundle_below_immutable_would_be_recorded_with_its_grade
    with_bundle(checksums: false) do |path|
      out, err, st = run_check(path, '--items')
      assert_equal 0, st.exitstatus, err
      assert_includes out, 'grade: local_path'
      assert_includes out, 'by category:'
      assert_match(/inputs=local_path/, out)
      assert_includes out, 'the anchor would issue a record for this bundle, carrying grade local_path'
      assert_includes out, 'S1_odd.kmat', 'locally, the items and their locators are shown'
    end
  end

  def test_a_real_receipt_is_checked_locally_when_the_verifier_is_installed
    skip 'gc_zk_verify not built: cargo build --release in genomicschain_prov/zk_verifier' unless GenomicsChainProv::ZkVerifier.available?

    with_bundle(zk: true) do |path, receipt|
      out, err, st = run_check(path, '--zk-receipt', receipt)
      assert_equal 0, st.exitstatus, err
      assert_includes out, 'zk receipts: 1 declared; local check: ok'

      bad = File.join(File.dirname(receipt), 'bad.bin')
      bytes = File.binread(receipt)
      bytes.setbyte(5000, bytes.getbyte(5000) ^ 1)
      File.binwrite(bad, bytes)
      out, _, st = run_check(path, '--zk-receipt', bad)
      assert_equal 1, st.exitstatus
      assert_includes out, 'receipt_bytes_missing', 'the bytes given are not the receipt the bundle declares'
    end
  end

  def test_without_a_receipt_file_the_local_check_is_said_not_to_have_run
    with_bundle(zk: true) do |path|
      res = GcProvCheck.check(File.read(path), [])
      assert_equal 'not_checked', res.dig('zk_local', 'state')
      assert_equal 'no --zk-receipt given', res.dig('zk_local', 'why')
      assert GcProvCheck.issuable?(res), 'the anchor will check; not having checked here is not a refusal'
    end
  end

  def test_an_unreadable_bundle_exits_two
    Dir.mktmpdir do |d|
      bad = File.join(d, 'x.json')
      File.write(bad, '{"@context": "not a bco"}')
      _, err, st = run_check(bad)
      assert_equal 2, st.exitstatus
      assert_includes err, 'spec_version'
    end
  end
end
