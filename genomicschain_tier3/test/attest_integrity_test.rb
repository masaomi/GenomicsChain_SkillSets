# frozen_string_literal: true

# Tier 3 v0.1 — executor-side integrity rules from implementation review round
# 1 (fix groups F3, F4, F5; interrupted attempts per operator 2026-10-21,
# question 6 「次の呼び出しで閉じる」, design §3.4). Written from the rules in
# log/tier3_impl_20261020/interface_v0_1.md, not from the implementation.
require_relative 't3_helper'
require 'open3'
require 'rbconfig'
require 'pp'
require_relative '../tools/gc_tier3_attest'

class AttestIntegrityTest < Minitest::Test
  include T3Helpers

  def setup = reset_nonces

  def tree(dir)
    Dir.glob(File.join(dir, '**', '*'), File::FNM_DOTMATCH).reject { |p| File.basename(p).match?(/\A\.\.?\z/) }
       .sort.to_h { |p| [p.delete_prefix(dir), File.file?(p) ? Digest::SHA256.file(p).hexdigest : :dir] }
  end

  def scores(dir) = jsonl(File.join(process_dir(dir), '06_scores.jsonl'))

  # Replaces a string (whole value or substring) everywhere in the
  # 01_declaration.json copy except the signed declaration and its envelope.
  # Returns how many values changed; required: true flunks when none did.
  def edit_job_copy(dir, from, to, required: true)
    path = File.join(process_dir(dir), '01_declaration.json')
    doc = JSON.parse(File.read(path))
    hits = 0
    walk = lambda do |node|
      case node
      when Hash then node.transform_values! { |v| walk.call(v) }
      when Array then node.map! { |v| walk.call(v) }
      when String
        next node unless node.include?(from)

        hits += 1
        node.gsub(from, to)
      else node
      end
    end
    doc.each_key { |k| doc[k] = walk.call(doc[k]) unless %w[declaration operator].include?(k) }
    flunk "the process record's copy holds no #{from.inspect}" if required && hits.zero?
    File.write(path, JSON.generate(doc))
    hits
  end

  def assert_nothing_ran(dir)
    assert_empty Dir.children(work_root(dir)), 'no attempt location'
    assert_empty scores(dir), 'no attempt row'
    assert_empty Dir.glob(File.join(dir, '**', 'evil.txt')), 'no edited step ran'
  end

  # --- F3 (1): policy and plan come from the signed declaration ------------------------------

  BUILD = 'File.write("tool.txt", "1.0")'
  EVIL = 'File.write("tool.txt", "1.0"); File.write("evil.txt", "x")'

  def test_an_edited_build_plan_copy_is_refused_before_anything_runs
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ok!(declare_args(dir, skp))
      edit_job_copy(dir, BUILD, EVIL)
      assert_match(/build_plan/, err!(attempt_args(dir)))
      assert_nothing_ran(dir)
    end
  end

  # Salted, so the plain target value exists only in the executor's copy.
  def test_an_edited_target_copy_is_refused_before_anything_runs
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ckp, = write_commitment_key(dir)
      ok!(declare_args(dir, skp, form: 'salted', commitment_key_path: ckp))
      edit_job_copy(dir, sha('hi'), sha('other'))
      assert_match(/targets/, err!(attempt_args(dir)))
      assert_nothing_ran(dir)
    end
  end

  def test_an_edited_pipeline_copy_is_refused_before_anything_runs
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ok!(declare_args(dir, skp))
      edit_job_copy(dir, 'File.write("out.txt", "hi")', 'File.write("out.txt", "hi"); File.write("evil.txt", "x")')
      assert_match(/job_identity|pipeline/, err!(attempt_args(dir)))
      assert_nothing_ran(dir)
    end
  end

  def test_attest_refuses_an_edited_copy_too
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ok!(declare_args(dir, skp))
      ok!(attempt_args(dir))
      edit_job_copy(dir, BUILD, EVIL)
      assert_match(/build_plan/, err!(attest_args(dir, skp, own_ref(dir))))
    end
  end

  # The copy says `job.fingerprint_form: plain` for a salted declaration (review
  # r2 N1, fix group G3) — an edit if the copy keeps the form, an addition if
  # it does not (interface §7: it need not). The signed declaration governs: a
  # thoa attempt runs nothing, and a local attempt either is refused and runs
  # nothing, or records C(f) fingerprints. If the copy's value governed, the
  # thoa attempt would make an attempt dir, or the local one would record a
  # plain SHA-256, and an assertion below fails on either branch.
  def test_the_signed_fingerprint_form_governs_whatever_the_copy_says
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ckp, key = write_commitment_key(dir)
      ok!(declare_args(dir, skp, form: 'salted', commitment_key_path: ckp))
      path = File.join(process_dir(dir), '01_declaration.json')
      doc = JSON.parse(File.read(path))
      assert_kind_of Hash, doc['job'], 'the copy has a job part (interface §7)'
      doc['job']['fingerprint_form'] = 'plain'
      File.write(path, JSON.generate(doc))
      err!(attempt_args(dir, backend: 'thoa'))
      assert_nothing_ran(dir)
      text = tool_text(attempt_args(dir))
      if text.start_with?('Error:')
        assert_nothing_ran(dir)
      else
        out = JSON.parse(text)
        produced = File.join(out['workdir'], 'out.txt')
        assert_equal [{ 'path' => 'out.txt', 'value' => C.commit_file(key, produced) }], out.dig('attempt', 'output_fingerprints')
        refute_includes text, Digest::SHA256.file(produced).hexdigest, 'no plain digest of the output'
      end
    end
  end

  # --- F3 (2): the commitment key is checked against the declared key_id --------------------

  def test_a_swapped_commitment_key_is_refused_before_an_attempt
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ckp, = write_commitment_key(dir)
      ok!(declare_args(dir, skp, form: 'salted', commitment_key_path: ckp))
      File.binwrite(ckp, C.generate_key)
      assert_includes err!(attempt_args(dir)), 'key_id'
      assert_nothing_ran(dir)
    end
  end

  def test_a_swapped_commitment_key_is_refused_before_attest
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ckp, = write_commitment_key(dir)
      ok!(declare_args(dir, skp, form: 'salted', commitment_key_path: ckp))
      ok!(attempt_args(dir))
      File.binwrite(ckp, C.generate_key)
      assert_includes err!(attest_args(dir, skp, own_ref(dir))), 'key_id'
    end
  end

  # The reading chosen: a relative path is refused (not resolved and stored).
  def test_declare_refuses_a_relative_commitment_key_path
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      write_commitment_key(dir)
      Dir.chdir(dir) do
        assert_includes err!(declare_args(dir, skp, form: 'salted', commitment_key_path: 'commitment.key')),
                        'commitment_key_path'
      end
      refute File.exist?(process_dir(dir))
    end
  end

  # --- F3 (3): one process record, one attempt at a time ---------------------------------------

  def test_concurrent_attempts_never_share_a_number_or_exceed_attempts_max
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      slow = step(command: ['ruby', '-e', 'sleep 0.3; File.write("tool.txt", "1.0")'])
      ok!(declare_args(dir, skp, 'attempts_max' => 3, 'build_plan' => plan(steps: [slow])))
      start = Queue.new
      threads = Array.new(4) do
        Thread.new do
          start.pop
          T3::Tools::GcTier3Attest.new(nil).call(attempt_args(dir)).first[:text]
        end
      end
      4.times { start << :go }
      texts = threads.map(&:value)
      done = texts.reject { |t| t.start_with?('Error:') }.map { |t| JSON.parse(t).dig('attempt', 'attempt') }
      refused = texts.select { |t| t.start_with?('Error:') }
      assert_equal [1, 2, 3], done.sort, texts.inspect
      assert_equal 1, refused.length
      assert_includes refused.first, 'attempts_max'
      assert_equal [1, 2, 3], scores(dir).map { |r| r['attempt'] }.sort
      assert_equal 3, Dir.children(work_root(dir)).length
    end
  end

  # --- F3 (4), (5): attest's own preconditions ---------------------------------------------

  def test_attest_refuses_a_declaration_ref_of_another_declaration
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ok!(declare_args(dir, skp))
      ok!(attempt_args(dir))
      other = own_ref(dir).merge('declaration_digest' => hex('another declaration'))
      assert_match(/declaration_ref|declaration_digest/, err!(attest_args(dir, skp, other)))
    end
  end

  def test_attest_refuses_when_there_is_no_attempt
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ok!(declare_args(dir, skp))
      assert_match(/attempt/, err!(attest_args(dir, skp, own_ref(dir))))
    end
  end

  # --- F3 (6): an unreadable input is refused, salted as plain ----------------------------------

  def test_an_unreadable_input_file_is_refused_in_both_forms
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ckp, = write_commitment_key(dir)
      missing = File.join(dir, 'input', 'not-there.txt')
      { 'plain' => nil, 'salted' => ckp }.each do |form, key_path|
        args = declare_args(dir, skp, form: form, commitment_key_path: key_path, 'inputs' => [missing],
                                      'process_dir' => File.join(dir, "p_#{form}"))
        err!(args)
        refute File.exist?(args['process_dir']), "#{form}: nothing is created"
      end
    end
  end

  # --- F3 (7): the process record is owner-only --------------------------------------------------

  def test_the_process_record_is_owner_only
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ok!(declare_args(dir, skp))
      ok!(attempt_args(dir))
      ok!(attest_args(dir, skp, own_ref(dir)))
      pd = process_dir(dir)
      assert_equal 0o700, File.stat(pd).mode & 0o777
      files = Dir.glob(File.join(pd, '**', '*')).select { |p| File.file?(p) }
      refute_empty files
      files.each { |f| assert_equal 0o600, File.stat(f).mode & 0o777, f }
    end
  end

  # --- F3 (8): an interrupted attempt is closed by the next call (operator Q6, §3.4) -----------

  # An exception inside the run: the build was recorded as done, no verdict was.
  def test_an_attempt_that_raised_in_the_run_is_closed_counted_and_attested
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ok!(declare_args(dir, skp, 'attempts_max' => 2))
      boom = Object.new
      def boom.call(*) = raise('the run stopped here')
      T3::Tools::GcTier3Execute.stub(:new, ->(*_a, **_k) { boom }) do
        attest_tool.call(attempt_args(dir))
      rescue StandardError
        nil
      end
      second = ok!(attempt_args(dir))['attempt']
      assert_equal 2, second['attempt'], 'the interrupted attempt consumed number 1'
      assert_includes err!(attempt_args(dir)), 'attempts_max'
      rows = ok!(attest_args(dir, skp, own_ref(dir)))['attestation']['attempts']
      assert_equal [1, 2], rows.map { |r| r['attempt'] }
      assert_equal [1, 'built', 'env_failed', 'not_attempted', 0],
                   rows.first.values_at('attempt', 'rebuild', 'execution_verdict', 'comparison_verdict', 'm')
    end
  end

  # A kill in the middle of the build: the next call closes it as cannot_build.
  def test_an_attempt_killed_during_its_build_is_closed_as_cannot_build_by_attest
    pid = nil
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      marker = File.join(dir, 'build-started')
      flag = File.join(dir, 'slow')
      File.write(flag, 'x')
      script = "File.write(#{marker.inspect}, 'x'); sleep 60 if File.exist?(#{flag.inspect}); File.write('tool.txt', '1.0')"
      ok!(declare_args(dir, skp, 'build_plan' => plan(steps: [step(command: ['ruby', '-e', script])])))
      libs = %w[genomicschain_core genomicschain_tier2 genomicschain_prov genomicschain_tier3_record genomicschain_tier3]
             .map { |p| File.join(WORKTREE, p, 'lib') } + $LOAD_PATH.grep(%r{/(synoptis|mmp)/lib\z})
      runner = <<~RUBY
        require 'json'
        require 'kairos_mcp/version'
        require 'kairos_mcp/tools/base_tool'
        require 'genomicschain_tier3'
        require #{File.expand_path('../tools/gc_tier3_attest', __dir__).inspect}
        KairosMcp::SkillSets::GenomicschainTier3::Tools::GcTier3Attest.new(nil).call(JSON.parse(ARGV[0]))
      RUBY
      pid = Process.spawn(RbConfig.ruby, *libs.flat_map { |l| ['-I', l] }, '-e', runner, JSON.generate(attempt_args(dir)),
                          pgroup: true, out: File::NULL, err: File::NULL)
      200.times { break if File.exist?(marker); sleep 0.1 }
      assert File.exist?(marker), 'the build step started'
      Process.kill('KILL', -pid)
      Process.wait(pid)
      File.delete(flag)
      rows = ok!(attest_args(dir, skp, own_ref(dir)))['attestation']['attempts']
      assert_equal 1, rows.length
      assert_equal [1, 'cannot_build'], rows.first.values_at('attempt', 'rebuild')
      %w[execution_verdict comparison_verdict m n output_fingerprints].each { |k| refute rows.first.key?(k), k }
    ensure
      begin
        Process.kill('KILL', -pid) if pid
      rescue Errno::ESRCH
        nil
      end
    end
  end

  # --- F4 (1): one target path per row ----------------------------------------------------------

  def test_two_outputs_sharing_a_basename_each_get_their_own_path
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      rows = [['quant.sf', 'sha1', sha1('A')], ['quant.sf', 'sha256', sha('A')],
              ['quant.sf', 'sha1', sha1('B')], ['quant.sf', 'sha256', sha('B')]]
      paths = [nil, 's1/quant.sf', nil, 's2/quant.sf']
      cmd = ['ruby', '-e', 'Dir.mkdir("s1"); Dir.mkdir("s2"); File.write("s1/quant.sf", "A"); File.write("s2/quant.sf", "B")']
      d = ok!(declare_args(dir, skp, route: 'B', 'pipeline' => { 'command' => cmd },
                                     **route_b_args(rows: rows, target_paths: paths)))['declaration']
      assert_equal paths, d.dig('targets', 'paths')
      assert_equal rows_digest(rows), d.dig('targets', 'outputs_digest')
      row = ok!(attempt_args(dir))['attempt']
      assert_equal [2, 2, 'match_exact'], row.values_at('m', 'n', 'comparison_verdict')
    end
  end

  # Pre-flight r2 §2.3 (orchestrator default 2026-10-21): the effective path of
  # every compared row — its target_paths entry, else its name — is distinct.
  QUANT_ROWS = [['quant.sf', 'sha1', Digest::SHA1.hexdigest('A')], ['quant.sf', 'sha256', Digest::SHA256.hexdigest('A')],
                ['quant.sf', 'sha1', Digest::SHA1.hexdigest('B')], ['quant.sf', 'sha256', Digest::SHA256.hexdigest('B')]].freeze

  def test_two_compared_rows_with_one_default_path_are_refused
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      assert_includes err!(declare_args(dir, skp, route: 'B', **route_b_args(rows: QUANT_ROWS))), 'target_paths'
      refute File.exist?(process_dir(dir))
    end
  end

  def test_duplicate_explicit_target_paths_are_refused
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      args = declare_args(dir, skp, route: 'B', **route_b_args(rows: QUANT_ROWS, target_paths: [nil, 'same', nil, 'same']))
      assert_includes err!(args), 'target_paths'
      refute File.exist?(process_dir(dir))
    end
  end

  # An explicit entry that lands on another row's default name collides too.
  def test_an_explicit_path_equal_to_another_rows_default_is_refused
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      rows = [['a.txt', 'sha256', sha('A')], ['b.txt', 'sha256', sha('B')]]
      args = declare_args(dir, skp, route: 'B', **route_b_args(rows: rows, target_paths: [nil, 'a.txt']))
      assert_includes err!(args), 'target_paths'
      refute File.exist?(process_dir(dir))
    end
  end

  # --- checker.tree_digest covers the executor's code in both packages (pre-flight r2) ----------

  # Copies of the two packages in a tmp tree (the worktree is not touched); each
  # declare runs in a fresh process from the copies. A byte changed in any of
  # tier3 lib/ or tools/, or tier3_record lib/, tools/ or schemas/, changes the
  # digest the next declare computes.
  def test_tree_digest_changes_with_a_byte_of_either_package
    Dir.mktmpdir do |root|
      %w[genomicschain_tier3 genomicschain_tier3_record].each do |pkg|
        FileUtils.mkdir_p(File.join(root, pkg))
        %w[lib tools schemas skillset.json].each do |part|
          src = File.join(WORKTREE, pkg, part)
          FileUtils.cp_r(src, File.join(root, pkg)) if File.exist?(src)
        end
      end
      libs = [File.join(root, 'genomicschain_tier3', 'lib'), File.join(root, 'genomicschain_tier3_record', 'lib')] +
             %w[genomicschain_core genomicschain_tier2 genomicschain_prov].map { |p| File.join(WORKTREE, p, 'lib') } +
             $LOAD_PATH.grep(%r{/(synoptis|mmp)/lib\z})
      tool = File.join(root, 'genomicschain_tier3', 'tools', 'gc_tier3_attest.rb')
      runner = <<~RUBY
        require 'json'
        require 'kairos_mcp/version'
        require 'kairos_mcp/tools/base_tool'
        require #{tool.inspect}
        print KairosMcp::SkillSets::GenomicschainTier3::Tools::GcTier3Attest.new(nil).call(JSON.parse(ARGV[0])).first[:text]
      RUBY
      n = 0
      digest = lambda do
        n += 1
        Dir.mktmpdir do |dir|
          skp, = write_signing_key(dir)
          out, status = Open3.capture2e(RbConfig.ruby, *libs.flat_map { |l| ['-I', l] }, '-e', runner,
                                        JSON.generate(declare_args(dir, skp)))
          assert status.success?, out
          flunk "declare #{n} failed: #{out[0, 300]}" if out.start_with?('Error:')
          JSON.parse(out).dig('declaration', 'checker', 'tree_digest')
        end
      end
      first = digest.call
      assert_equal first, digest.call, 'unchanged code, same digest'
      seen = [first]
      ['genomicschain_tier3_record/lib', 'genomicschain_tier3_record/tools', 'genomicschain_tier3_record/schemas',
       'genomicschain_tier3/lib', 'genomicschain_tier3/tools'].each do |part|
        file = Dir.glob(File.join(root, part, '**', '*')).select { |p| File.file?(p) }.min
        refute_nil file, "the copy holds a file under #{part}"
        File.open(file, 'a') { |f| f.write(file.end_with?('.json') ? "\n" : "\n# tree_digest probe\n") }
        now = digest.call
        refute_includes seen, now, "a byte changed under #{part}"
        seen << now
      end
    end
  end

  # --- F4 (2): the attempt dir's real path is fixed before the run ------------------------------

  def test_a_pipeline_that_swaps_the_attempt_dir_for_a_symlink_gets_nothing_outside_read
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      outside = File.join(dir, 'outside')
      FileUtils.mkdir_p(outside)
      File.write(File.join(outside, 'out.txt'), 'hi')
      swap = "d = Dir.pwd; o = File.expand_path('../../outside', d); File.rename(d, d + '.moved'); File.symlink(o, d)"
      ok!(declare_args(dir, skp, 'pipeline' => { 'command' => ['ruby', '-e', swap] },
                                 'targets' => [{ 'path' => 'out.txt', 'sha256' => sha('x') }]))
      text = tool_text(attempt_args(dir))
      # Either branch asserts (Fable L2): a refusal reads nothing outside either.
      if text.start_with?('Error:')
        refute_includes text, sha('hi')
        Dir.glob(File.join(process_dir(dir), '*')).select { |p| File.file?(p) }.each do |p|
          refute_includes File.read(p), sha('hi'), "#{File.basename(p)} holds no digest of the outside file"
        end
        assert(scores(dir).all? { |r| Array(r['output_fingerprints']).empty? })
      else
        row = JSON.parse(text)['attempt']
        assert_equal 0, row['m']
        assert_empty Array(row['output_fingerprints'])
        refute_includes JSON.generate(ok!(attest_args(dir, skp, own_ref(dir)))['attestation']), sha('hi')
      end
    end
  end

  # --- F4 (3): route B declares at least one row ---------------------------------------------------

  def test_declare_refuses_an_empty_bundle_rows
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      assert_includes err!(declare_args(dir, skp, route: 'B', **route_b_args(rows: []))), 'bundle_rows'
      refute File.exist?(process_dir(dir))
    end
  end

  # --- F5 (1): commands run as argv, never through a shell ------------------------------------------

  def test_a_one_element_step_command_is_not_given_to_a_shell
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ok!(declare_args(dir, skp, 'build_plan' => plan(steps: [step(command: ['touch pwned; echo 1.0 > tool.txt'])])))
      assert_equal 'cannot_build', ok!(attempt_args(dir)).dig('attempt', 'rebuild')
      assert_empty Dir.glob(File.join(dir, '**', 'pwned'))
    end
  end

  # Through a shell this observe would print 1.0 and the pin would hold.
  def test_a_one_element_observe_command_is_not_given_to_a_shell
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ok!(declare_args(dir, skp, 'build_plan' => plan(steps: [step(pins: [pin(observe: ['echo 1.0'])])])))
      assert_equal 'cannot_build', ok!(attempt_args(dir)).dig('attempt', 'rebuild')
    end
  end

  # --- F5 (2): pin output is compared as bytes -------------------------------------------------------

  def test_pin_output_that_is_not_utf8_gives_cannot_build_and_keeps_the_record_readable
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      bad = pin(observe: ['ruby', '-e', 'STDOUT.binmode; STDOUT.write("\xFF\xFE1.0".b)'])
      ok!(declare_args(dir, skp, 'build_plan' => plan(steps: [step(pins: [bad])])))
      assert_equal 'cannot_build', ok!(attempt_args(dir)).dig('attempt', 'rebuild')
      Dir.glob(File.join(process_dir(dir), '*.json*')).each do |f|
        File.readlines(f).each { |l| JSON.parse(l) unless l.strip.empty? }
      end
      assert_equal 'cannot_build', ok!(attempt_args(dir)).dig('attempt', 'rebuild'), 'the next attempt still runs'
    end
  end

  def test_pin_output_in_utf8_matches_its_bytes
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      accented = step(command: ['ruby', '-e', 'File.binwrite("tool.txt", "café".b)'],
                      pins: [pin(expected: "café", observe: ['ruby', '-e', 'STDOUT.binmode; STDOUT.write(File.binread("tool.txt"))'])])
      ok!(declare_args(dir, skp, 'build_plan' => plan(steps: [accented])))
      assert_equal 'built', ok!(attempt_args(dir)).dig('attempt', 'rebuild')
    end
  end

  # --- F5 (3): every pin is observed again after the last step ----------------------------------------

  def test_a_later_step_that_changes_a_pinned_version_cannot_build
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      later = step(name: 'upgrade', command: ['ruby', '-e', 'File.write("tool.txt", "2.0")'], pins: [])
      ok!(declare_args(dir, skp, 'build_plan' => plan(steps: [step, later])))
      assert_equal 'cannot_build', ok!(attempt_args(dir)).dig('attempt', 'rebuild')
    end
  end

  # --- review r2, fix group G4 -------------------------------------------------------------

  # (1) The attempt dir is made, and its real path fixed, before the attempt is
  # recorded as started: a work_root that cannot take it consumes no number.
  def test_a_work_root_that_cannot_take_the_attempt_dir_is_refused_and_consumes_no_number
    skip 'running as root: a read-only directory still takes a child' if Process.uid.zero?

    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ok!(declare_args(dir, skp))
      root = work_root(dir)
      File.chmod(0o500, root)
      begin
        assert_includes err!(attempt_args(dir)), 'work_root'
      ensure
        File.chmod(0o700, root)
      end
      assert_empty scores(dir), 'no row, closed or otherwise'
      assert_equal 1, ok!(attempt_args(dir)).dig('attempt', 'attempt')
      rows = ok!(attest_args(dir, skp, own_ref(dir)))['attestation']['attempts']
      assert_equal [[1, 'built']], rows.map { |r| r.values_at('attempt', 'rebuild') }
    end
  end

  # (2) Route-A target paths are distinct after Pathname#cleanpath.
  def test_route_a_target_paths_that_clean_to_one_path_are_refused
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      [%w[a.txt ./a.txt], %w[res/a.txt res/./a.txt], %w[res/a.txt res//a.txt], %w[a.txt a.txt]].each_with_index do |(p, q), i|
        args = declare_args(dir, skp, 'process_dir' => File.join(dir, "p#{i}"),
                                      'targets' => [{ 'path' => p, 'sha256' => sha('hi') }, { 'path' => q, 'sha256' => sha('ho') }])
        assert_includes err!(args), 'targets', "#{p} / #{q}"
        refute File.exist?(args['process_dir'])
      end
    end
  end

  # (3) A (step name, pin name) pair names one pin.
  def test_duplicate_step_and_pin_names_are_refused
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      [plan(steps: [step(pins: [pin, pin])]), plan(steps: [step, step])].each_with_index do |bad, i|
        args = declare_args(dir, skp, 'process_dir' => File.join(dir, "p#{i}"), 'build_plan' => bad)
        assert_includes err!(args), 'build_plan', "case #{i}"
        refute File.exist?(args['process_dir'])
      end
      ok!(declare_args(dir, skp, 'process_dir' => File.join(dir, 'p_ok'),
                                 'build_plan' => plan(steps: [step(name: 'a'), step(name: 'b')])))
    end
  end

  # (4) The attempt dir is the tool's: a pipeline may not name its own.
  def test_a_pipeline_carrying_its_own_workdir_is_refused
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      %w[workdir download_dir].each do |k|
        pipeline = { 'command' => write_command('out.txt' => 'hi'), k => File.join(dir, 'elsewhere') }
        args = declare_args(dir, skp, 'process_dir' => File.join(dir, "p_#{k}"), 'pipeline' => pipeline)
        assert_includes err!(args), 'pipeline', k
        refute File.exist?(args['process_dir'])
      end
    end
  end

  # --- review r2, fix group G5 (3): control characters in target paths, at declare -----------------

  CONTROL = ["out\u0000.txt", "out\n.txt", "out\u001b.txt", "out\u007f.txt", "out\u0085.txt", "out\u009b.txt"].freeze # C0, DEL, C1 (review r3)

  def test_a_target_path_with_a_control_character_is_refused_at_declare
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      CONTROL.each_with_index do |bad, i|
        a = declare_args(dir, skp, 'process_dir' => File.join(dir, "a#{i}"), 'targets' => [{ 'path' => bad, 'sha256' => sha('hi') }])
        assert_includes err!(a), 'targets'
        b = declare_args(dir, skp, route: 'B', 'process_dir' => File.join(dir, "b#{i}"),
                                   **route_b_args(rows: [['out.txt', 'sha256', sha('hi')]], target_paths: [bad]))
        assert_includes err!(b), 'target_paths'
        c = declare_args(dir, skp, route: 'B', 'process_dir' => File.join(dir, "c#{i}"),
                                   **route_b_args(rows: [[bad, 'sha256', sha('hi')]]))
        assert_includes err!(c), 'bundle_rows'
        [a, b, c].each { |x| refute File.exist?(x['process_dir']) }
      end
    end
  end

  # --- after G1–G5 (orchestrator 2026-10-21) ------------------------------------------------

  # Design §3.3: the declared pipeline names no workdir/download_dir; the
  # attempt supplies them at run time. ThoaBackend requires
  # pipeline.download_dir (execution/thoa_backend.rb:66–67), so a thoa attempt
  # hands gc_tier3_execute a download_dir that is the attempt directory
  # itself, and the job identity stays the declared one. thoa is never
  # contacted: the gc_tier3_execute call is answered by a stub.
  def test_a_thoa_attempt_supplies_download_dir_inside_the_attempt_dir
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      d = ok!(declare_args(dir, skp))['declaration']
      calls = []
      stub = Object.new
      stub.define_singleton_method(:call) do |args|
        calls << JSON.parse(JSON.generate(args))
        [{ type: 'text', text: 'Error: thoa is not contacted in this test' }]
      end
      T3::Tools::GcTier3Execute.stub(:new, ->(*_a, **_k) { stub }) do
        attest_tool.call(attempt_args(dir, backend: 'thoa'))
      rescue StandardError
        nil
      end
      assert_equal 1, calls.length, 'one gc_tier3_execute call'
      c = calls.first
      assert_equal 'thoa', c['backend']
      attempt_dir = File.realpath(File.join(work_root(dir), Dir.children(work_root(dir)).first))
      dd = c.dig('pipeline', 'download_dir')
      refute_nil dd, 'the thoa attempt supplies pipeline.download_dir'
      assert_equal attempt_dir, File.realpath(dd)
      refute declaration_copy(dir).dig('job', 'pipeline').to_h.key?('download_dir'), 'the declared pipeline is unchanged'
      a = ok!(attest_args(dir, skp, own_ref(dir)))['attestation']
      assert_equal d['job_identity'], a['job_identity']
    end
  end

  # (Fable L3) A target_paths entry belongs to a row the comparator compares;
  # one given for another row (a sha1 row under exact_sha256) is refused.
  def test_a_target_path_for_a_row_the_comparator_does_not_compare_is_refused
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      rows = [['a.txt', 'sha1', sha1('A')], ['a.txt', 'sha256', sha('A')]]
      args = declare_args(dir, skp, route: 'B', **route_b_args(rows: rows, target_paths: ['a_sha1.txt', nil]))
      assert_includes err!(args), 'target_paths'
      refute File.exist?(process_dir(dir))
    end
  end

  # (Fable L5) The attempt directory is owner-only.
  def test_the_attempt_directory_is_owner_only
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ok!(declare_args(dir, skp))
      out = ok!(attempt_args(dir))
      assert_equal 0o700, File.stat(out['workdir']).mode & 0o777
    end
  end

  # --- review r3 corrections (orchestrator defaults 2026-10-21) ------------------------------

  def attempt_text(dir, **over)
    attest_tool.call(attempt_args(dir).merge(over)).first[:text]
  rescue StandardError => e
    "Error: raised #{e.class}"
  end

  # (4) The attempt location may not be, or sit inside, the process record.
  def test_a_work_root_at_or_inside_the_process_dir_is_refused
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ok!(declare_args(dir, skp))
      [process_dir(dir), File.join(process_dir(dir), 'work')].each do |root|
        FileUtils.mkdir_p(root)
        text = attempt_text(dir, 'work_root' => root)
        assert text.start_with?('Error:'), text[0, 200]
        assert_includes text, 'work_root'
      end
      assert_empty scores(dir)
    end
  end

  # (5) A failure between making the attempt dir and recording it as started
  # leaves no dir behind (the record is made unwritable, so the started
  # marker cannot be written); the next good attempt is number 1.
  def test_a_failure_before_the_started_marker_leaves_no_attempt_dir
    skip 'running as root: permissions do not stop writes' if Process.uid.zero?

    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ok!(declare_args(dir, skp))
      pd = process_dir(dir)
      files = Dir.glob(File.join(pd, '*'))
      modes = files.to_h { |f| [f, File.stat(f).mode & 0o777] }
      begin
        files.each { |f| File.chmod(0o400, f) }
        File.chmod(0o500, pd)
        assert attempt_text(dir).start_with?('Error:')
      ensure
        File.chmod(0o700, pd)
        modes.each { |f, m| File.chmod(m, f) }
      end
      assert_empty Dir.children(work_root(dir)), 'no attempt dir left behind'
      assert_equal 1, ok!(attempt_args(dir)).dig('attempt', 'attempt')
    end
  end

  # (5) An empty attempt dir with no started marker and no row (left by a
  # crash before the fix) is refused rather than wedging the work_root
  # silently. Review r4 M1: the message is conditional — this process record
  # did not start it, and it is a removable leftover only if no other process
  # record uses this work_root.
  def test_an_empty_attempt_dir_without_a_marker_is_refused_as_a_removable_leftover
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ok!(declare_args(dir, skp))
      FileUtils.mkdir_p(File.join(work_root(dir), 'attempt-1'))
      text = err!(attempt_args(dir))
      assert_match(/leftover/i, text)
      assert_match(/remov/i, text)
      assert_match(/this process record/i, text)
      assert_match(/did not start|not started/i, text)
      assert_match(/only if/i, text)
      assert_match(/other process record/i, text)
      assert_includes text, 'work_root'
      assert_empty scores(dir)
    end
  end

  # Review r4 M1: tier3's SKILL.md states the operating rule.
  def test_skill_md_states_one_work_root_per_process_record
    skill = File.read(File.join(WORKTREE, 'genomicschain_tier3', 'plugin', 'SKILL.md'))
    assert_match(/one `?work_root`? per process record/i, skill)
  end

  # (6) Two declared targets that are one file at compare time (an in-dir
  # symlink) are refused at attempt time, naming targets — the reading picked
  # over counting the file once. Review r4: the message says the attempt number
  # was used and the next call closes the attempt; 04_logs.jsonl has its line.
  def test_two_targets_that_are_one_file_at_compare_time_are_refused
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      cmd = ['ruby', '-e', 'File.write("out.txt", "hi"); File.symlink("out.txt", "link.txt")']
      ok!(declare_args(dir, skp, 'pipeline' => { 'command' => cmd },
                                 'targets' => [{ 'path' => 'out.txt', 'sha256' => sha('hi') },
                                               { 'path' => 'link.txt', 'sha256' => sha('hi') }]))
      text = err!(attempt_args(dir))
      assert_includes text, 'targets'
      assert_match(/\b1\b/, text, 'names the attempt number')
      assert_match(/used/i, text)
      assert_match(/next call|clos/i, text)
      assert_includes jsonl(File.join(process_dir(dir), '04_logs.jsonl')).map { |l| l['attempt'] }, 1
    end
  end

  # Review r4 LOW: a work_root that is the process dir by identity (a symlink
  # alias; on macOS also a firmlink path under /System/Volumes/Data, which
  # File.realpath does not resolve), or has it as an ancestor, is refused.
  def test_a_work_root_that_is_the_process_dir_by_identity_is_refused
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ok!(declare_args(dir, skp))
      pd = process_dir(dir)
      alias_link = File.join(dir, 'alias')
      File.symlink(pd, alias_link)
      roots = [alias_link, File.join(alias_link, 'work')]
      firm = File.join('/System/Volumes/Data', File.realpath(pd))
      if File.directory?(firm) && File.identical?(firm, pd) && File.realpath(firm) != File.realpath(pd)
        roots += [firm, File.join(firm, 'work2')]
      end
      roots.each do |root|
        FileUtils.mkdir_p(root)
        text = attempt_text(dir, 'work_root' => root)
        assert text.start_with?('Error:'), "#{root}: #{text[0, 160]}"
        assert_includes text, 'work_root'
      end
      assert_empty scores(dir)
    end
  end

  # Review r4 LOW: the attempt dir is made, then its real path fixed (and its
  # mode set); if that step raises, the new dir does not stay behind.
  def test_a_failing_realpath_after_making_the_attempt_dir_leaves_no_dir
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ok!(declare_args(dir, skp))
      root = work_root(dir)
      attempt_path = %r{\A(#{Regexp.escape(root)}|#{Regexp.escape(File.realpath(root))})/attempt-\d+/?\z}
      real = File.method(:realpath)
      realdir = File.method(:realdirpath)
      boom = ->(orig) { ->(p, *rest) { p.to_s =~ attempt_path ? raise(Errno::EACCES, 'simulated') : orig.call(p, *rest) } }
      File.stub(:realpath, boom.call(real)) do
        File.stub(:realdirpath, boom.call(realdir)) do
          assert attempt_text(dir).start_with?('Error:')
        end
      end
      assert_empty Dir.children(root), 'no attempt dir left behind'
      assert_equal 1, ok!(attempt_args(dir)).dig('attempt', 'attempt')
    end
  end

  # Same with a chmod that raises: either the attempt is refused and leaves no
  # dir, or it never chmods (and its dir is 0700 from the start).
  def test_a_failing_chmod_after_making_the_attempt_dir_leaves_no_dir
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ok!(declare_args(dir, skp))
      root = work_root(dir)
      attempt_path = %r{(\A|/)attempt-\d+/?\z}
      chmod = File.method(:chmod)
      raising = ->(mode, *paths) { paths.any? { |p| p.to_s =~ attempt_path } ? raise(Errno::EPERM, 'simulated') : chmod.call(mode, *paths) }
      text = File.stub(:chmod, raising) { attempt_text(dir) }
      if text.start_with?('Error:')
        assert_empty Dir.children(root), 'no attempt dir left behind'
      else
        assert_equal 0o700, File.stat(JSON.parse(text)['workdir']).mode & 0o777
      end
    end
  end

  def test_two_targets_that_are_case_aliases_of_one_file_are_refused
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'probe'), 'x')
      skip 'this file system is case-sensitive' unless File.exist?(File.join(dir, 'PROBE'))

      skp, = write_signing_key(dir)
      ok!(declare_args(dir, skp, 'targets' => [{ 'path' => 'out.txt', 'sha256' => sha('hi') },
                                               { 'path' => 'OUT.txt', 'sha256' => sha('hi') }]))
      assert_includes err!(attempt_args(dir)), 'targets'
    end
  end

  # (7) Whatever object holds the commitment key prints neither its bytes nor
  # its hex, through inspect, to_s or pretty_inspect (pp; pre-flight r4). Every live object (not a String, Array, Hash, Module, Proc or
  # Binding) with an instance variable, Struct member or Data member equal to
  # the key is inspected after a salted declare, attempt and attest; GC is held
  # off meanwhile, and at least one holder must be found (not vacuous).
  def test_no_object_holding_the_commitment_key_prints_it
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ckp, key = write_commitment_key(dir)
      # Raw bytes, hex, base64, and the escaped form `inspect` gives a binary
      # string ("\x9F…"), which is how a Struct or an ivar would print it.
      needles = [key.b, key.unpack1('H*'), key.unpack1('H*').upcase, [key].pack('m0'),
                 key.b.inspect[1..-2], key.dup.force_encoding('UTF-8').inspect[1..-2]]
      ::GC.disable
      begin
        ok!(declare_args(dir, skp, form: 'salted', commitment_key_path: ckp))
        ok!(attempt_args(dir))
        ok!(attest_args(dir, skp, own_ref(dir)))
        holders = []
        ObjectSpace.each_object(Object) do |o|
          next if [String, Array, Hash, Module, Proc, Binding].any? { |k| o.is_a?(k) }

          values = begin
            if o.is_a?(Struct) then o.to_a
            elsif defined?(Data) && o.is_a?(Data) then o.to_h.values
            else o.instance_variables.map { |iv| o.instance_variable_get(iv) }
            end
          rescue StandardError
            []
          end
          holders << o if values.any? { |v| v.is_a?(String) && v.b == key.b }
        end
        refute_empty holders, 'the scan found the objects that hold the key (Fable r4 L2: not vacuous)'
        holders.each do |o|
          [o.inspect, o.to_s, o.pretty_inspect].each do |t|
            needles.each { |n| refute t.to_s.b.include?(n.b), "a #{o.class} prints the commitment key" }
          end
        end
      ensure
        ::GC.enable
      end
    end
  end

  # (8) A NUL byte in a build-step command or observe element is refused at
  # declare, naming build_plan.
  def test_a_nul_byte_in_a_command_or_observe_element_is_refused_at_declare
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      [plan(steps: [step(command: ['ruby', '-e', "File.write('tool.txt', '1.0')\u0000"])]),
       plan(steps: [step(pins: [pin(observe: ['ruby', "-e\u0000", 'print 1'])])])].each_with_index do |bad, i|
        args = declare_args(dir, skp, 'process_dir' => File.join(dir, "p#{i}"), 'build_plan' => bad)
        assert_includes err!(args), 'build_plan', "case #{i}"
        refute File.exist?(args['process_dir'])
      end
    end
  end
end
