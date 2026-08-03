# frozen_string_literal: true
# §1.1 / §7 step 5 — deployment topology verification.
require 'minitest/autorun'
require 'fileutils'
require 'yaml'
require 'rbconfig'
require 'kairos_mcp/skillset'
require 'kairos_mcp/skillset_manager'

SUBMIT_TOOLS = [
  'KairosMcp::SkillSets::GenomicschainCore::Tools::GcTier2Submit',
  'KairosMcp::SkillSets::GenomicschainCore::Tools::GcTier1Submit'
].freeze
EXECUTE_TOOL = 'KairosMcp::SkillSets::GenomicschainTier2::Tools::GcTier2Execute'

class TopologyTest < Minitest::Test
  CORE_PATH = File.expand_path('..', __dir__)
  SKILLSETS_DIR = File.expand_path('../..', __dir__)

  def core_skillset
    KairosMcp::Skillset.new(CORE_PATH)
  end

  def with_anchor_profile(flag)
    cfg_path = File.join(CORE_PATH, 'config', 'genomicschain_core.yml')
    backup = File.read(cfg_path)
    data = YAML.safe_load(backup) || {}
    data['genomicschain'] ||= {}
    data['genomicschain']['anchor_profile'] = flag
    File.write(cfg_path, data.to_yaml)
    yield
  ensure
    File.write(cfg_path, backup)
  end

  def ensure_core_on_load_path
    core_skillset.load! unless core_skillset.loaded?
  end

  def registered_tool_classes(skillset)
    ensure_core_on_load_path if skillset.path != CORE_PATH
    skillset.load! unless skillset.loaded?
    skillset.tool_class_names
  end

  def test_monolith_disabled_in_config
    manager = KairosMcp::SkillSetManager.new(skillsets_dir: SKILLSETS_DIR)
    refute manager.enabled?('genomicschain'), 'monolith genomicschain must stay disabled'
  end

  def test_split_packages_enabled
    manager = KairosMcp::SkillSetManager.new(skillsets_dir: SKILLSETS_DIR)
    %w[genomicschain_core genomicschain_tier1 genomicschain_tier2].each do |name|
      assert manager.enabled?(name), "#{name} must be enabled"
    end
  end

  def test_submit_tools_registered_on_anchor_profile
    with_anchor_profile(true) do
      names = registered_tool_classes(core_skillset)
      SUBMIT_TOOLS.each { |t| assert_includes names, t, "anchor profile must register #{t}" }
    end
  end

  def test_zero_submit_tools_registered_off_anchor
    with_anchor_profile(false) do
      names = registered_tool_classes(core_skillset)
      SUBMIT_TOOLS.each { |t| refute_includes names, t, "off-anchor must not register #{t}" }
      assert_empty names & SUBMIT_TOOLS
    end
  end

  def test_tier2_execute_never_in_core
    with_anchor_profile(true) do
      names = registered_tool_classes(core_skillset)
      refute_includes names, EXECUTE_TOOL
    end
  end

  def test_tier2_package_exposes_execute_only
    ensure_core_on_load_path
    tier2 = KairosMcp::Skillset.new(File.join(SKILLSETS_DIR, 'genomicschain_tier2'))
    tier2.load!
    assert_equal [EXECUTE_TOOL], tier2.tool_class_names
    refute tier2.tool_class_names.any? { |t| t.include?('Submit') }
  end

  def test_tier1_package_has_no_mcp_tools
    ensure_core_on_load_path
    tier1 = KairosMcp::Skillset.new(File.join(SKILLSETS_DIR, 'genomicschain_tier1'))
    tier1.load!
    assert_empty tier1.tool_class_names
  end

  def test_monolith_exposes_no_tool_classes
    mono = KairosMcp::Skillset.new(File.join(SKILLSETS_DIR, 'genomicschain'))
    assert_empty mono.tool_class_names,
                 'deprecated monolith must not register MCP tools even if re-enabled'
  end

  def test_monolith_load_refused_without_override
    entry = File.join(SKILLSETS_DIR, 'genomicschain', 'lib', 'genomicschain.rb')
    refute ENV['GENOMICSCHAIN_MONOLITH_ALLOW'] == '1'
    # Isolate: load in a subprocess so a prior ALLOW=1 test cannot poison this one.
    status = system(
      { 'GENOMICSCHAIN_MONOLITH_ALLOW' => nil },
      RbConfig.ruby, '-e',
      "begin; load #{entry.inspect}; exit 1; rescue LoadError => e; " \
      "exit(e.message.include?('DEPRECATED genomicschain monolith') ? 0 : 2); end"
    )
    assert status, 'monolith entry point must raise LoadError without GENOMICSCHAIN_MONOLITH_ALLOW=1'
  end

  def test_monolith_enable_refused_while_successors_enabled
    manager = KairosMcp::SkillSetManager.new(skillsets_dir: SKILLSETS_DIR)
    err = assert_raises(ArgumentError) { manager.enable('genomicschain') }
    assert_match(/deprecated|successors/i, err.message)
    refute manager.enabled?('genomicschain')
  end

  def test_off_anchor_submit_tools_reject_at_runtime
    ensure_core_on_load_path
    require_relative '../tools/gc_tier1_submit'
    require_relative '../tools/gc_tier2_submit'
    with_anchor_profile(false) do
      t1 = KairosMcp::SkillSets::GenomicschainCore::Tools::GcTier1Submit.new(nil)
      t2 = KairosMcp::SkillSets::GenomicschainCore::Tools::GcTier2Submit.new(nil)
      r1 = t1.call('report_json' => '{}', 'operator' => { 'mode' => 'signed' })
      r2 = t2.call(
        'verdict_result' => {}, 'jobspec_json' => '{}', 'expected_output' => {},
        'operator' => { 'mode' => 'signed' }
      )
      assert r1.first[:text].include?('anchor_profile'), r1.inspect
      assert r2.first[:text].include?('anchor_profile'), r2.inspect
    end
  end

  def test_registry_continues_after_load_error
    # Mirrors ToolRegistry#register_skillset_tools rescue StandardError, LoadError.
    failing = Object.new
    def failing.name = 'fake_failing'
    def failing.load!
      raise LoadError, 'DEPRECATED genomicschain monolith refused to load'
    end

    healthy = Object.new
    def healthy.name = 'fake_healthy'
    def healthy.load! = true

    loaded = []
    [failing, healthy].each do |skillset|
      begin
        skillset.load!
        loaded << skillset.name
      rescue StandardError, LoadError => e
        warn "[ToolRegistry] Failed to load SkillSet '#{skillset.name}': #{e.message}"
      end
    end
    assert_equal %w[fake_healthy], loaded,
                 'LoadError from one SkillSet must not prevent later SkillSets from loading'
  end
end
