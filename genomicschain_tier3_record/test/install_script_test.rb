# frozen_string_literal: true

# Tier 3 v0.1 review r2 C1 (fix group G1; round-1 H1 carried over): the anchor
# gets its package set from `install.sh --anchor`, and neither path can leave
# genomicschain_tier3 on an anchor. install.sh runs for real against a stub
# `kairos-chain` first on PATH — it records its argv and answers `skillset
# list` from a file the test writes — and a temporary KAIROS_DATA_DIR. Nothing
# is installed and nothing leaves the machine. The README is read for the
# anchor's own upgrade line and the package table.
require_relative 't3_record_helper'
require 'open3'
require 'rbconfig'

class InstallScriptTest < Minitest::Test
  include T3RecordHelpers

  INSTALL = File.join(WORKTREE, 'install.sh')
  README = File.join(WORKTREE, 'README.md')
  EXECUTOR_SET = %w[genomicschain_core genomicschain_tier1 genomicschain_tier2 genomicschain_prov genomicschain_tier3_record
                    genomicschain_tier3].freeze
  ANCHOR_SET = (EXECUTOR_SET - ['genomicschain_tier3']).freeze

  # Yields a runner: run.(*args, env: {}, chdir: nil) → [output, status, argv
  # lines of every stub call], and the temp root.
  # list_fails: `kairos-chain skillset list` exits 3 with nothing on stdout.
  # core_config: the installed core config's raw text (overrides anchor_profile).
  # probe_fails: a `ruby` first on PATH that exits 1 (a crash, not an answer)
  #   whenever it is asked about the core config — any argument naming
  #   genomicschain_core.yml or anchor_profile — and runs the real ruby otherwise.
  def with_stub(listing:, anchor_profile: nil, list_fails: false, core_config: nil, probe_fails: false)
    Dir.mktmpdir('t3_install') do |tmp|
      bin = File.join(tmp, 'bin')
      FileUtils.mkdir_p(bin)
      if probe_fails
        ruby_stub = File.join(bin, 'ruby')
        File.write(ruby_stub, <<~SH)
          #!/bin/sh
          for a in "$@"; do
            case "$a" in *genomicschain_core.yml*|*anchor_profile*) echo 'ruby: simulated crash' >&2; exit 1 ;; esac
          done
          exec '#{RbConfig.ruby}' "$@"
        SH
        File.chmod(0o755, ruby_stub)
      end
      log = File.join(tmp, 'argv.log')
      File.write(log, '')
      list = File.join(tmp, 'listing.txt')
      File.write(list, listing.map { |p| "  #{p} 0.0.0\n" }.join)
      stub = File.join(bin, 'kairos-chain')
      list_branch = list_fails ? "echo 'skillset list failed' >&2; exit 3" : "cat '#{list}'"
      File.write(stub, <<~SH)
        #!/bin/sh
        printf '%s\\n' "$*" >> '#{log}'
        if [ "$1" = skillset ] && [ "$2" = list ]; then #{list_branch}; fi
        exit 0
      SH
      File.chmod(0o755, stub)
      data = File.join(tmp, 'kairos')
      core_config ||= "genomicschain:\n  anchor_profile: #{anchor_profile}\n" unless anchor_profile.nil?
      if core_config
        cfg = File.join(data, 'skillsets', 'genomicschain_core', 'config')
        FileUtils.mkdir_p(cfg)
        File.write(File.join(cfg, 'genomicschain_core.yml'), core_config)
      end
      FileUtils.mkdir_p(data)
      run = lambda do |*args, env: {}, chdir: nil|
        base = { 'PATH' => "#{bin}:#{ENV.fetch('PATH')}", 'KAIROS_DATA_DIR' => data }
        out, status = Open3.capture2e(base.merge(env), 'bash', INSTALL, *args, chdir: chdir || Dir.pwd)
        [out, status, File.readlines(log, chomp: true)]
      end
      yield run, tmp
    end
  end

  # An anchor's core config at `root` (a data dir).
  def write_anchor_config(root)
    cfg = File.join(root, 'skillsets', 'genomicschain_core', 'config')
    FileUtils.mkdir_p(cfg)
    File.write(File.join(cfg, 'genomicschain_core.yml'), "genomicschain:\n  anchor_profile: true\n")
  end

  # The packages `skillset install` was asked for, in order, by basename.
  def installed(argv) = argv.filter_map { |l| (w = l.split)[0..1] == %w[skillset install] ? File.basename(w[2]) : nil }

  # --- refusals ----------------------------------------------------------------------------

  def test_anchor_install_refuses_a_target_that_already_has_tier3
    with_stub(listing: EXECUTOR_SET + ['mmp']) do |run|
      out, status, argv = run.call('--anchor')
      refute status.success?, out
      assert_includes out, 'genomicschain_tier3'
      assert_match(/remove|uninstall/i, out, 'says how to remove it')
      assert_empty installed(argv) & EXECUTOR_SET, 'no package was installed'
    end
  end

  def test_plain_install_refuses_a_target_whose_core_is_on_the_anchor_profile
    with_stub(listing: EXECUTOR_SET + ['mmp'], anchor_profile: true) do |run|
      out, status, argv = run.call('--force')
      refute status.success?, out
      assert_includes out, '--anchor'
      assert_empty installed(argv) & EXECUTOR_SET, 'no package was installed'
    end
  end

  # --- the package lists as P1 set them ----------------------------------------------------

  def test_plain_install_installs_the_executor_set_in_dependency_order
    with_stub(listing: EXECUTOR_SET + ['mmp'], anchor_profile: false) do |run|
      out, status, argv = run.call('--force')
      assert status.success?, out
      assert_equal EXECUTOR_SET, installed(argv) - ['mmp']
      argv.select { |l| l.start_with?('skillset install') }.each { |l| assert_includes l, '--force' }
    end
  end

  def test_anchor_install_installs_the_anchor_set_without_tier3
    with_stub(listing: ANCHOR_SET + ['mmp']) do |run|
      out, status, argv = run.call('--anchor')
      assert status.success?, out
      assert_equal ANCHOR_SET, installed(argv) - ['mmp']
    end
  end

  # --- README -----------------------------------------------------------------------------

  def readme_section(heading)
    text = File.read(README)
    start = text.index("\n## #{heading}") or flunk "README has no section #{heading}"
    rest = text[(start + 1)..]
    stop = rest.index("\n## ", 1)
    stop ? rest[0...stop] : rest
  end

  def test_the_readme_upgrade_section_gives_the_anchor_its_own_anchor_line
    lines = readme_section('Upgrade').lines.select { |l| l.include?('install.sh') }
    assert(lines.any? { |l| l.include?('--anchor') && l.include?('--force') }, 'an anchor upgrade line with --anchor')
    assert(lines.any? { |l| !l.include?('--anchor') && l.include?('--force') }, 'an executor upgrade line')
  end

  def test_the_readme_package_table_lists_prov
    table = readme_section('What is here').lines.select { |l| l.start_with?('|') }
    assert(table.any? { |l| l.include?('`genomicschain_prov`') }, 'genomicschain_prov is in the package table')
  end

  # --- review r3 corrections: the guards fail closed ---------------------------------------

  # A `skillset list` that fails says nothing about tier3: stop, in both
  # modes, before anything is installed (mmp included).
  def test_a_failing_skillset_list_stops_both_modes_before_installing_anything
    [[], ['--anchor']].each do |args|
      with_stub(listing: EXECUTOR_SET + ['mmp'], list_fails: true) do |run|
        out, status, argv = run.call(*args)
        refute status.success?, "#{args.inspect}: #{out}"
        assert_empty installed(argv), "#{args.inspect}: nothing installed"
      end
    end
  end

  # An installed core config that cannot be read says nothing about
  # anchor_profile: plain install stops, naming the file, installing nothing.
  def test_an_unparsable_installed_core_config_stops_plain_install_naming_the_file
    with_stub(listing: EXECUTOR_SET + ['mmp'], core_config: "genomicschain: [unclosed\n  - : :\n") do |run|
      out, status, argv = run.call('--force')
      refute status.success?, out
      assert_includes out, 'genomicschain_core.yml'
      assert_empty installed(argv), 'nothing installed'
    end
  end

  # --- review r3 corrections: README ----------------------------------------------------------

  def test_the_readme_anchor_conversion_text_names_anchor_and_keeps_tier3_off_the_anchor
    section = readme_section('anchor_profile')
    assert_includes section, '--anchor'
    assert_match(/genomicschain_tier3[^.\n]*\b(not|never)\b|\b(not|never)\b[^.\n]*genomicschain_tier3/, section,
                 'says genomicschain_tier3 must not be on an anchor')
  end

  def test_the_readme_tools_table_lists_the_two_new_tools
    text = File.read(README)
    start = text.index("\n### Tools") or flunk 'README has no Tools table'
    rest = text[(start + 1)..]
    table = rest[0...(rest.index("\n#", 1) || rest.length)].lines.select { |l| l.start_with?('|') }
    %w[gc_tier3_attest gc_tier3_record_submit].each do |tool|
      assert(table.any? { |l| l.start_with?("| `#{tool}`") }, "#{tool} is in the Tools table")
    end
  end

  # --- review r4 M2: plain mode resolves the data dir as the gem does ------------------------
  # The gem: File.expand_path(ENV['KAIROS_DATA_DIR'] || File.join(Dir.pwd, '.kairos')).

  def assert_stopped_for_anchor(out, status, argv)
    refute status.success?, out
    assert_includes out, '--anchor'
    assert_empty installed(argv), 'nothing installed'
  end

  # A literal ~ in KAIROS_DATA_DIR is the gem's ~ (File.expand_path), so the
  # anchor's config under $HOME/x/.kairos is found.
  def test_a_tilde_data_dir_is_expanded_as_the_gem_does
    with_stub(listing: EXECUTOR_SET + ['mmp']) do |run, tmp|
      home = File.join(tmp, 'home')
      write_anchor_config(File.join(home, 'x', '.kairos'))
      assert_stopped_for_anchor(*run.call('--force', env: { 'HOME' => home, 'KAIROS_DATA_DIR' => '~/x/.kairos' }))
    end
  end

  # An empty KAIROS_DATA_DIR is, for the gem, File.expand_path('') — the
  # current directory, not ./.kairos.
  def test_an_empty_data_dir_is_the_current_directory_as_for_the_gem
    with_stub(listing: EXECUTOR_SET + ['mmp']) do |run, tmp|
      cwd = File.join(tmp, 'cwd')
      write_anchor_config(cwd)
      assert_stopped_for_anchor(*run.call('--force', env: { 'KAIROS_DATA_DIR' => '' }, chdir: cwd))
    end
  end

  # Unset, it is ./.kairos under the current directory.
  def test_an_unset_data_dir_is_dot_kairos_under_the_current_directory
    with_stub(listing: EXECUTOR_SET + ['mmp']) do |run, tmp|
      cwd = File.join(tmp, 'cwd2')
      write_anchor_config(File.join(cwd, '.kairos'))
      assert_stopped_for_anchor(*run.call('--force', env: { 'KAIROS_DATA_DIR' => nil }, chdir: cwd))
    end
  end

  # The listing says core is installed, yet no core config is at the
  # resolved path: whether this is an anchor is unknown, so plain mode stops
  # and names where it looked.
  def test_core_listed_but_no_config_found_stops_plain_install_naming_the_path
    with_stub(listing: EXECUTOR_SET + ['mmp']) do |run, tmp|
      data = File.join(tmp, 'kairos')
      out, status, argv = run.call('--force')
      refute status.success?, out
      assert_includes out, File.expand_path(data)
      assert_empty installed(argv), 'nothing installed'
    end
  end

  # A config probe that fails (ruby exits 1 with an error, not as an answer)
  # stops; it never reads as "not an anchor".
  def test_a_failing_config_probe_stops_and_never_reads_as_not_an_anchor
    with_stub(listing: EXECUTOR_SET + ['mmp'], anchor_profile: false, probe_fails: true) do |run|
      out, status, argv = run.call('--force')
      refute status.success?, out
      assert_empty installed(argv), 'nothing installed'
    end
  end

  # --- review r4 LOWs: README by-hand install, the anchor config example ----------------------

  # The genomicschain_tier3 install line sits in a code block of its own, and
  # the text before it says an anchor never runs it.
  def test_the_readme_by_hand_install_keeps_tier3_in_its_own_executor_block
    section = readme_section('Install')
    blocks = section.scan(/```[a-z]*\n(.*?)```/m).flatten
    tier3_block = blocks.find { |b| b.include?('skillset install ./genomicschain_tier3') && b !~ %r{genomicschain_tier3_record} } ||
                  blocks.find { |b| b =~ %r{skillset install \./genomicschain_tier3\s*$} }
    refute_nil tier3_block, 'a block installs genomicschain_tier3'
    installs = tier3_block.lines.grep(/skillset install/)
    assert_equal 1, installs.length, "the tier3 block holds only its own line: #{installs.inspect}"
    before = section[0...section.index(tier3_block)]
    lead = before.split('```')[-2].to_s # the text between the previous block and this one
    assert_match(/anchor/, lead)
    assert_match(/\b(never|not)\b/, lead, 'the text before it says an anchor never runs it')
  end

  def test_the_anchor_config_example_names_install_anchor_and_keeps_tier3_off
    example = File.read(File.join(WORKTREE, 'genomicschain_core', 'config', 'genomicschain_core.anchor.yml.example'))
    comments = example.lines.grep(/^\s*#/).join
    assert_includes comments, 'install.sh --anchor'
    assert_match(/genomicschain_tier3[^\n]*\b(not|never)\b|\b(not|never)\b[^\n]*genomicschain_tier3/, comments)
  end
end
