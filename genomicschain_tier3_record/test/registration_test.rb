# frozen_string_literal: true

# Tier 3 v0.1 — the record package genomicschain_tier3_record (operator
# 2026-10-21, question 5 「記録の部分を別 package に」; implementation review r1
# H1). The anchor installs core + prov + tier3_record and never tier3, so the
# anchor's package set registers the record tool and no execution tool; off the
# anchor the record package registers nothing; it loads without tier3.
require_relative 't3_record_helper'
require 'open3'
require 'rbconfig'
require 'kairos_mcp/storage/file_backend' # defines KairosMcp.data_dir= (the gc_prov_reach test loads it the same way)

class RecordRegistrationTest < Minitest::Test
  include T3RecordHelpers

  RECORD_DIR = File.expand_path('..', __dir__)
  RECORD = 'KairosMcp::SkillSets::GenomicschainTier3Record::Tools::GcTier3RecordSubmit'
  EXECUTION_TOOLS = %w[GcTier3Execute GcTier3Estimate GcTier3Attest].map do |c|
    "KairosMcp::SkillSets::GenomicschainTier3::Tools::#{c}"
  end.freeze

  def setup = reset_nonces

  def record_json = JSON.parse(File.read(File.join(RECORD_DIR, 'skillset.json')))
  def skillset(name) = KairosMcp::Skillset.new(File.join(WORKTREE, name))

  def load_tool
    require 'genomicschain_tier3_record/record_submit'
    require_relative '../tools/gc_tier3_record_submit'
  end

  # --- skillset.json -------------------------------------------------------------------

  def test_the_record_package_manifest
    j = record_json
    assert_equal %w[genomicschain_tier3_record 0.1.0], j.values_at('name', 'version')
    assert_equal({ 'genomicschain_core' => '>= 0.6.4', 'genomicschain_prov' => '>= 0.6.0' },
                 j['depends_on'].to_h { |d| [d['name'], d['version']] })
    assert_equal [], j['tool_classes']
    assert_equal [RECORD], j['anchor_profile_tool_classes']
  end

  # --- registration by profile -------------------------------------------------------------

  def test_on_the_anchor_the_package_set_registers_the_record_tool_and_no_execution_tool
    GC::Config.stub(:anchor_profile?, true) do
      names = %w[genomicschain_core genomicschain_prov genomicschain_tier3_record].flat_map { |n| skillset(n).tool_class_names }
      assert_includes names, RECORD
      EXECUTION_TOOLS.each { |t| refute_includes names, t }
      assert_equal [RECORD], skillset('genomicschain_tier3_record').tool_class_names
    end
  end

  def test_off_the_anchor_the_record_package_registers_nothing
    GC::Config.stub(:anchor_profile?, false) do
      assert_empty skillset('genomicschain_tier3_record').tool_class_names
    end
  end

  # The anchor never loads tier3: the record package, its entry point and its
  # tool load with genomicschain_tier3 absent from the load path.
  def test_the_record_package_loads_without_tier3
    libs = %w[genomicschain_core genomicschain_tier2 genomicschain_prov genomicschain_tier3_record].map do |p|
      File.join(WORKTREE, p, 'lib')
    end
    libs += $LOAD_PATH.grep(%r{/(synoptis|mmp)/lib\z})
    tool = File.join(RECORD_DIR, 'tools', 'gc_tier3_record_submit.rb')
    script = <<~RUBY
      require 'kairos_mcp/version'
      require 'kairos_mcp/tools/base_tool'
      require 'genomicschain_tier3_record'
      require 'genomicschain_tier3_record/record_submit'
      require 'genomicschain_tier3_record/wording'
      require #{tool.inspect}
      KairosMcp::SkillSets::GenomicschainTier3Record::Tools::GcTier3RecordSubmit
      exit(defined?(KairosMcp::SkillSets::GenomicschainTier3) || $LOADED_FEATURES.grep(%r{/genomicschain_tier3/}).any? ? 3 : 0)
    RUBY
    out, status = Open3.capture2e(RbConfig.ruby, *libs.flat_map { |l| ['-I', l] }, '-e', script)
    assert_equal 0, status.exitstatus, out
  end

  # --- the tool skin --------------------------------------------------------------------

  def test_the_record_tool_input_schema_names_its_actions
    load_tool
    record = T3R::Tools::GcTier3RecordSubmit.new(nil)
    assert_equal 'gc_tier3_record_submit', record.name
    assert_equal %w[declaration attestation], record.input_schema.dig(:properties, :action, :enum)
    %i[declaration attestation operator route_proof_id].each do |k|
      assert record.input_schema[:properties].key?(k), "gc_tier3_record_submit takes #{k}"
    end
  end

  def test_the_record_tool_refuses_off_the_anchor
    load_tool
    GC::Config.stub(:anchor_profile?, false) do
      text = T3R::Tools::GcTier3RecordSubmit.new(nil).call('action' => 'declaration', 'declaration' => declaration,
                                                           'operator' => {}).first[:text]
      assert_includes text, 'requires genomicschain.anchor_profile: true'
    end
  end
end
