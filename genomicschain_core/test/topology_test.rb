# frozen_string_literal: true
# §1.1 / §7 step 5 — deployment topology verification.
#
# One numbering everywhere (2026-09-09): tier1 reads the paper, tier2 reads the
# code, tier3 executes. Package, tool, schema and claim names all carry it.
require 'minitest/autorun'
require 'fileutils'
require 'yaml'
require 'rbconfig'
require 'kairos_mcp/skillset'
require 'kairos_mcp/skillset_manager'

SUBMIT_TOOLS = [
  'KairosMcp::SkillSets::GenomicschainCore::Tools::GcTier1Submit',
  'KairosMcp::SkillSets::GenomicschainCore::Tools::GcTier2Submit',
  'KairosMcp::SkillSets::GenomicschainCore::Tools::GcTier3Submit'
].freeze
EXECUTE_TOOL = 'KairosMcp::SkillSets::GenomicschainTier3::Tools::GcTier3Execute'
ESTIMATE_TOOL = 'KairosMcp::SkillSets::GenomicschainTier3::Tools::GcTier3Estimate'
TIER3_TOOLS = [EXECUTE_TOOL, ESTIMATE_TOOL].freeze
ASSESS_TOOL = 'KairosMcp::SkillSets::GenomicschainTier1::Tools::GcTier1Assess'
SCAN_TOOLS = [
  'KairosMcp::SkillSets::GenomicschainTier2::Tools::GcTier2Scan',
  'KairosMcp::SkillSets::GenomicschainTier2::Tools::GcTier2Adjudicate'
].freeze

class TopologyTest < Minitest::Test
  CORE_PATH = File.expand_path('..', __dir__)
  SKILLSETS_DIR = File.expand_path('../..', __dir__)

  def core_skillset
    KairosMcp::Skillset.new(CORE_PATH)
  end

  # Config.anchor_profile? reads KairosMcp.skillsets_dir, NOT the skillset's own
  # path, so this suite only tests what it thinks it tests when the two agree.
  # Run it from an installed instance with KAIROS_DATA_DIR pointing at that
  # instance. Without the guard the mismatch is silent AND can false-PASS: the
  # flag is written here while the flag actually read belongs to another
  # instance, which may independently have anchor_profile: true.
  def assert_config_path_is_the_one_read!
    written = File.expand_path(File.join(CORE_PATH, 'config', 'genomicschain_core.yml'))
    read = File.expand_path(
      File.join(KairosMcp.skillsets_dir, 'genomicschain_core', 'config', 'genomicschain_core.yml')
    )
    return if written == read

    flunk "anchor-profile tests write #{written} but Config reads #{read}. " \
          'Run from an installed instance with KAIROS_DATA_DIR set to it, e.g. ' \
          "KAIROS_DATA_DIR=#{File.expand_path(File.join(SKILLSETS_DIR, '..'))}"
  end

  def with_anchor_profile(flag)
    assert_config_path_is_the_one_read!
    cfg_path = File.join(CORE_PATH, 'config', 'genomicschain_core.yml')
    backup = File.read(cfg_path)
    data = YAML.safe_load(backup) || {}
    data['genomicschain'] ||= {}
    data['genomicschain']['anchor_profile'] = flag
    File.write(cfg_path, data.to_yaml)
    yield
  ensure
    # `backup` is nil when the guard above rejected the invocation, i.e. nothing
    # was written and there is nothing to restore. Writing unconditionally would
    # raise TypeError here and bury the guard's diagnosis under it.
    File.write(cfg_path, backup) if backup
  end

  def ensure_core_on_load_path
    core_skillset.load! unless core_skillset.loaded?
  end

  def registered_tool_classes(skillset)
    ensure_core_on_load_path if skillset.path != CORE_PATH
    skillset.load! unless skillset.loaded?
    skillset.tool_class_names
  end

  # The four monolith guards below describe a MIGRATION state: the deprecated
  # `genomicschain` monolith still installed, but disabled and refusing to load.
  # Once it is removed outright the state is strictly stronger, and the guards
  # can no longer be evaluated — `enabled?` reports an unknown name as enabled,
  # and Skillset.new raises on the missing skillset.json. So each one asserts
  # absence when the monolith is gone, and the original property when it is
  # still there. Instances mid-migration keep the protection; instances past it
  # stop failing for having finished.
  def monolith_path
    File.join(SKILLSETS_DIR, 'genomicschain')
  end

  def monolith_present?
    File.exist?(File.join(monolith_path, 'skillset.json'))
  end

  def test_monolith_disabled_in_config
    skip 'monolith removed from this instance (stronger than disabled)' unless monolith_present?

    manager = KairosMcp::SkillSetManager.new(skillsets_dir: SKILLSETS_DIR)
    refute manager.enabled?('genomicschain'), 'monolith genomicschain must stay disabled'
  end

  # Holds in BOTH states, so it is not skipped: whether the monolith is absent or
  # merely disabled, the successors must be the only genomicschain tool sources.
  def test_monolith_is_not_a_live_tool_source
    refute_path_exists File.join(monolith_path, 'tools'),
                       'the deprecated monolith must not ship a live tools/ directory'
  end

  def test_split_packages_enabled
    manager = KairosMcp::SkillSetManager.new(skillsets_dir: SKILLSETS_DIR)
    %w[genomicschain_core genomicschain_tier1 genomicschain_tier2 genomicschain_tier3].each do |name|
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

  def test_tier3_execute_never_in_core
    with_anchor_profile(true) do
      names = registered_tool_classes(core_skillset)
      refute_includes names, EXECUTE_TOOL
    end
  end

  # The invariant is the SECOND assertion: the execution package never carries a
  # submit path, so running and recording stay separable. The exact-set check is
  # deliberately strict rather than a subset check — adding a tool to tier3 should
  # require editing this list, so the surface cannot grow unreviewed. gc_tier3_estimate
  # arrived in tier3 v0.4.0 and this guard was not updated with it.
  def test_tier3_package_exposes_execution_tools_only
    ensure_core_on_load_path
    tier3 = KairosMcp::Skillset.new(File.join(SKILLSETS_DIR, 'genomicschain_tier3'))
    tier3.load!
    assert_equal TIER3_TOOLS.sort, tier3.tool_class_names.sort
    refute tier3.tool_class_names.any? { |t| t.include?('Submit') }
  end

  # The code-reading package reads and proposes. It neither executes nor submits,
  # so a scan can be re-run by the party being scanned with no side effects.
  def test_tier2_package_exposes_reading_tools_only
    ensure_core_on_load_path
    tier2 = KairosMcp::Skillset.new(File.join(SKILLSETS_DIR, 'genomicschain_tier2'))
    tier2.load!
    assert_equal SCAN_TOOLS.sort, tier2.tool_class_names.sort
    refute tier2.tool_class_names.any? { |t| t.include?('Submit') || t.include?('Execute') }
  end

  # tier1 shipped no tools until gc_tier1_assess (spec v0.2). What must stay true is
  # narrower than "no tools": assessment is off-anchor work, so tier1 may register the
  # assessor everywhere, but the submit path stays in core behind the anchor profile.
  def test_tier1_package_exposes_assess_only
    ensure_core_on_load_path
    tier1 = KairosMcp::Skillset.new(File.join(SKILLSETS_DIR, 'genomicschain_tier1'))
    tier1.load!
    assert_equal [ASSESS_TOOL], tier1.tool_class_names
    refute tier1.tool_class_names.any? { |t| t.include?('Submit') }
  end

  def test_monolith_exposes_no_tool_classes
    skip 'monolith removed from this instance (stronger than disabled)' unless monolith_present?

    mono = KairosMcp::Skillset.new(monolith_path)
    assert_empty mono.tool_class_names,
                 'deprecated monolith must not register MCP tools even if re-enabled'
  end

  def test_monolith_load_refused_without_override
    entry = File.join(monolith_path, 'lib', 'genomicschain.rb')
    unless File.exist?(entry)
      refute monolith_present?, 'monolith skillset.json present but its entry point is missing'
      skip 'monolith removed from this instance (stronger than refusing to load)'
    end
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
    unless monolith_present?
      # Still refused, but for the ordinary reason rather than the deprecation
      # rule. Asserted explicitly so the refusal is not mistaken for the guard.
      assert_match(/not found/i, err.message)
      return
    end
    assert_match(/deprecated|successors/i, err.message)
    refute manager.enabled?('genomicschain')
  end

  def test_off_anchor_submit_tools_reject_at_runtime
    ensure_core_on_load_path
    require_relative '../tools/gc_tier1_submit'
    require_relative '../tools/gc_tier2_submit'
    require_relative '../tools/gc_tier3_submit'
    with_anchor_profile(false) do
      t1 = KairosMcp::SkillSets::GenomicschainCore::Tools::GcTier1Submit.new(nil)
      t2 = KairosMcp::SkillSets::GenomicschainCore::Tools::GcTier2Submit.new(nil)
      t3 = KairosMcp::SkillSets::GenomicschainCore::Tools::GcTier3Submit.new(nil)
      r1 = t1.call('report_json' => '{}', 'operator' => { 'mode' => 'signed' })
      r2 = t2.call('adjudication' => {}, 'operator' => { 'mode' => 'signed' })
      r3 = t3.call(
        'verdict_result' => {}, 'jobspec_json' => '{}', 'expected_output' => {},
        'operator' => { 'mode' => 'signed' }
      )
      assert r1.first[:text].include?('anchor_profile'), r1.inspect
      assert r2.first[:text].include?('anchor_profile'), r2.inspect
      assert r3.first[:text].include?('anchor_profile'), r3.inspect
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
