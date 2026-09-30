# frozen_string_literal: true

# Unit S4 of the self-application design: the DDC harness and comparer, run
# on small fixtures — never on the subject under selfapp/, which no checker
# may touch before the expectations are fixed (INV-S2).
#
#   bundle exec ruby selfapp/test/ddc_harness_test.rb

require 'minitest/autorun'
require 'digest'
require 'fileutils'
require 'json'
require 'rbconfig'
require 'tmpdir'

REPO = File.expand_path('../..', __dir__)
%w[genomicschain_core genomicschain_tier1 genomicschain_tier2 genomicschain_tier3 genomicschain_prov].each do |p|
  $LOAD_PATH.unshift(File.join(REPO, p, 'lib'))
end
require 'kairos_mcp/version'
require 'genomicschain_tier1'
require 'genomicschain_prov'
require_relative '../../scripts/selfapp/ddc_common'

class DdcHarnessTest < Minitest::Test
  HARNESS = File.join(REPO, 'scripts/selfapp/ddc_harness.rb')
  COMPARE = File.join(REPO, 'scripts/selfapp/ddc_compare.rb')
  TEXT = "Methods. Reads were trimmed and quantified.\n"

  def llm_fields
    { 'paper_type' => 'pure-computational', 'reproduction_target' => 'fixture', 'step_source' => 'prose-methods',
      'steps' => [{ 'step_id' => 'C1', 'label' => 'quantify', 'layer' => 'C',
                    'axes' => { 'data' => 2, 'code' => 2, 'version' => 1, 'params' => 2 }, 'verdict' => 'R' }],
      'gaps' => [], 'liveness' => [], 'assessable' => { 'is_assessable' => true }, 'capture_claim' => 'floating' }
  end

  def write(path, text)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, text)
  end

  # A recorded Tier-1 exchange, a two-file repository, a BCO and two frozen
  # Tier-3 run directories, with the manifest the harness checks them against.
  def build_inputs(dir)
    args = { 'canonical_id' => { 'value' => Digest::SHA256.hexdigest(TEXT), 'kind' => 'text_sha256' },
             'sources' => [{ 'kind' => 'paper_text', 'ref' => 'manuscript', 'content' => TEXT }],
             'funnel_stage' => 'stage1-prose-only', 'assessor_id' => 'fixture', 'operator_id' => 'fixture',
             'assessed_at' => '2026-10-01' }
    response = { 'status' => 'ok', 'model' => 'm', 'provider' => 'p', 'fields' => llm_fields }
    sent = nil
    KairosMcp::SkillSets::GenomicschainTier1::Assess::Assessor.new(llm: ->(req) { sent = req; response }).run(args)
    write("#{dir}/tier1/V0/args.json", JSON.generate(args))
    write("#{dir}/tier1/V0/exchange.json", JSON.generate('request' => sent.compact, 'response' => response))

    write("#{dir}/repo/Snakefile", "rule a:\n    container: \"docker://quay.io/fixture/tool:1.0@sha256:#{'1' * 64}\"\n")
    write("#{dir}/repo/envs/env.yml", "dependencies:\n  - tool=1.0=h0\n")

    w = GenomicsChainProv::Writer
    plan = w.normalise_plan('name' => 'fixture', 'stages' => [{ 'name' => 's', 'tools' => [{ 'name' => 'tool', 'version' => '1.0' }] }])
    write("#{dir}/bco/v0.json", JSON.generate(w.build(plan, object_id: 'urn:uuid:00000000-0000-4000-8000-000000000000',
                                                            created: '2026-10-01T00:00:00Z')))

    %w[run1 run2].each { |r| write("#{dir}/tier3/V0/#{r}/results/out.tsv", "gene\tvalue\nG1\t1\n") }
    manifest = {
      'tier1' => [{ 'variant' => 'V0', 'args' => 'tier1/V0/args.json', 'exchange' => 'tier1/V0/exchange.json' }],
      'tier2_scan' => [{ 'variant' => 'V0', 'repo' => 'repo' }],
      'tier2_adjudication' => { 'variant' => 'V0', 'tier1' => 'V0', 'scan' => 'V0' },
      'tier25' => [{ 'variant' => 'V0', 'bco' => 'bco/v0.json' }],
      'tier3' => [{ 'variant' => 'V0', 'workdirs' => %w[tier3/V0/run1 tier3/V0/run2],
                    'expected_output' => { 'target' => 'file:results/out.tsv', 'source' => 'paper_declared',
                                           'sha256' => Digest::SHA256.hexdigest("gene\tvalue\nG1\t1\n") } }]
    }
    manifest['files'] = DdcCommon.tree_files(dir)
    File.write("#{dir}/inputs_manifest.json", JSON.generate(manifest))
  end

  def harness(inputs, out)
    system(RbConfig.ruby, HARNESS, '--checker-root', REPO, '--inputs', inputs, '--out', out, out: File::NULL, err: File::NULL)
  end

  def compare(a, t, report, source: REPO)
    system(RbConfig.ruby, COMPARE, '--a', a, '--t', t, '--source-tree', source, '--out', report, out: File::NULL)
    JSON.parse(File.read(report))
  end

  def test_two_runs_of_one_checker_agree_on_every_body
    Dir.mktmpdir do |tmp|
      build_inputs("#{tmp}/in")
      assert harness("#{tmp}/in", "#{tmp}/A"), File.read("#{tmp}/A/errors.json")
      assert harness("#{tmp}/in", "#{tmp}/T")
      r = compare("#{tmp}/A", "#{tmp}/T", "#{tmp}/report.json")

      assert_equal 5, r['bodies_total'] # tier1, scan, adjudication, grade, tier3 — none missing
      assert_equal r['bodies_total'], r['bodies_matching']
      assert r['counted']
      assert(r['tier1_requests'].all? { |q| q['match'] })
      assert_empty r['loaded_files_differing']
      assert r['inv_s9']['holds']
      refute_empty File.read("#{tmp}/A/loaded_files.txt").lines.grep(/rubric|schema/i), 'read-only files are listed'
      assert_includes JSON.parse(File.read("#{tmp}/A/environment.json"))['gems_loaded'].keys, 'json', '§6.4 needs the json version'
    end
  end

  def test_an_input_that_differs_from_the_manifest_stops_the_harness
    Dir.mktmpdir do |tmp|
      build_inputs("#{tmp}/in")
      File.write("#{tmp}/in/repo/Snakefile", "rule a:\n    container: \"tool:latest\"\n")
      refute harness("#{tmp}/in", "#{tmp}/A")
      refute File.exist?("#{tmp}/A/bodies")
    end
  end

  def test_a_changed_or_missing_body_is_not_counted_as_agreement
    Dir.mktmpdir do |tmp|
      build_inputs("#{tmp}/in")
      harness("#{tmp}/in", "#{tmp}/A")
      harness("#{tmp}/in", "#{tmp}/T")
      File.write("#{tmp}/T/bodies/tier2_scan__V0.json", '{}')
      File.delete("#{tmp}/T/bodies/tier3_compare__V0.json")
      env = JSON.parse(File.read("#{tmp}/T/environment.json"))
      env['gems_loaded']['json'] = '0.0.0'
      env['checker_packages_tree_sha256'] = '0' * 64
      File.write("#{tmp}/T/environment.json", JSON.generate(env))
      requests = JSON.parse(File.read("#{tmp}/T/tier1_requests.json"))
      requests.first['replayed_request_sha256'] = '0' * 64
      File.write("#{tmp}/T/tier1_requests.json", JSON.generate(requests))
      r = compare("#{tmp}/A", "#{tmp}/T", "#{tmp}/report.json")

      assert_equal r['bodies_total'] - 2, r['bodies_matching']
      assert_equal %w[tier2_scan__V0.json tier3_compare__V0.json], r['bodies'].reject { |b| b['match'] }.map { |b| b['body'] }
      refute r['counted'], 'a gem version that differs keeps the pair out of the count'
      assert_includes r['gem_differences'].keys, 'json'
      refute r['tier1_requests'].first['match']
      refute r['inv_s9']['holds']
    end
  end
end
