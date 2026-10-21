# frozen_string_literal: true

# Tier 3 v0.1 §9-3 — the executor-side tool gc_tier3_attest and its own
# comparator table. One attempt = build the declared plan once (①), and if it
# built, gc_tier3_execute once with runs = 1 in a fresh output location (②),
# then compare only the declared target paths that were absent before the run
# or changed by it (③, §3.1 F5). n follows E1. thoa is refused for salted and
# option-2 jobs (§4.3). Keys never leave the tool (§4.2). Local backend and
# trivial ruby commands only; nothing touches the network.
require_relative 't3_helper'
require 'genomicschain_tier3_record/record_submit'
require_relative '../tools/gc_tier3_attest'

class AttestToolTest < Minitest::Test
  include T3Helpers

  def setup = reset_nonces

  # --- declare -----------------------------------------------------------------------

  def test_declare_signs_the_declaration_with_the_signing_key
    Dir.mktmpdir do |dir|
      skp, sk, = write_signing_key(dir)
      out = ok!(declare_args(dir, skp))
      assert_equal 'declaration_signed', out['status']
      op = out['operator']
      assert_equal pubkey(sk), op['pubkey']
      assert_equal 'signed', op['mode']
      sig = op['signature']
      assert_equal TIP, sig['chain_tip_hash']
      payload = M.canonical_json('mcp_tool_name' => 'gc_tier3_record_submit', 'params' => out['declaration'],
                                 'nonce' => sig['nonce'], 'chain_tip_hash' => sig['chain_tip_hash'])
      assert sk.verify_key.verify(Base64.urlsafe_decode64(sig['value']), payload)
      args = out.dig('submit', 'arguments')
      assert_equal 'gc_tier3_record_submit', out.dig('submit', 'tool')
      assert_equal 'declaration', args['action']
      assert_equal out['declaration'], args['declaration']
      assert_equal op, args['operator']
    end
  end

  def test_declare_fills_the_route_a_fields
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      d = ok!(declare_args(dir, skp))['declaration']
      assert_equal 'repro://656122/C9', d['subject_ref']
      assert_equal 'gc-job-identity-0.3', d.dig('job_identity', 'rule')
      assert_equal({ 'kind' => 'paper_declared',
                     'items' => [{ 'path' => 'out.txt', 'algorithm' => 'sha256', 'value' => sha('hi') }] }, d['targets'])
      assert_equal({ 'id' => 'exact_sha256', 'version' => '0.2.0' }, d['comparator'])
      assert_equal 'exact', d['tolerance']
      assert_equal 'tier2:demo-adjudication', d['route_ref']
      assert_equal %w[A plain non_human], d.values_at('route', 'fingerprint_form', 'data_class')
      refute d.key?('commitment')
      assert_equal %w[paper_declared doi:10.1038/s41467-018-06108-1 human:executor],
                   d.values_at('source', 'source_citation', 'validated_by')
      assert_equal %w[rebuild rerun reproduce], d['scored_items']
      assert_equal [3, '2026-11-19T00:00:00Z'], d.values_at('attempts_max', 'expires_at')
      assert_equal T3::Tools::GcTier3Attest::TOOL_VERSION, d.dig('checker', 'tool')
      assert_equal 'gc_tier3_attest-0.1.0', T3::Tools::GcTier3Attest::TOOL_VERSION
      assert_match(/\A[0-9a-f]{64}\z/, d.dig('checker', 'tree_digest'))
      (BINDING - %w[subject_ref]).each { |f| assert d.key?(f), "binding field #{f}" }
    end
  end

  def test_declare_requires_attempts_max_and_expiry
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      %w[attempts_max expires_at].each do |field|
        args = declare_args(dir, skp, 'process_dir' => File.join(dir, "process_#{field}")).except(field)
        assert_includes err!(args), field
      end
    end
  end

  def test_route_b_declaration_carries_the_rows_verbatim_and_a_path_per_compared_row
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      rows = [['a.txt', 'sha1', sha1('A')], ['a.txt', 'sha256', sha('A')], ['b.txt', 'sha256', sha('B')]]
      args = declare_args(dir, skp, route: 'B', **route_b_args(rows: rows, target_paths: [nil, nil, 'res/b.txt']))
      d = ok!(args)['declaration']
      t = d['targets']
      assert_equal 'tier2_5_bundle', t['kind']
      assert_equal rows, t['rows']
      assert_equal rows_digest(rows), t['outputs_digest']
      assert_equal hex('bundle'), t['bundle_digest']
      assert_equal([nil, 'a.txt', 'res/b.txt'], t['paths'], 'one path per row, nil for the rows not compared')
      assert_equal GC::ProvProofRef.for('attest_route_b_fixture'), d['route_ref']
      assert_equal({ 'id' => 'exact_sha256', 'version' => '0.2.0' }, d['comparator'])
      %w[source source_citation validated_by].each { |f| refute d.key?(f), "route B carries no #{f}" }
    end
  end

  # --- attempt: ② through gc_tier3_execute, runs = 1, a fresh location ---------------------

  def test_an_attempt_calls_gc_tier3_execute_once_with_runs_1_in_a_fresh_location
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ok!(declare_args(dir, skp))
      real = T3::Tools::GcTier3Execute.new(nil)
      calls = []
      spy = Object.new
      spy.define_singleton_method(:call) do |args|
        calls << args.transform_keys(&:to_s)
        real.call(args)
      end
      out = T3::Tools::GcTier3Execute.stub(:new, ->(*_a, **_k) { spy }) { ok!(attempt_args(dir)) }
      assert_equal 1, calls.length
      c = calls.first
      assert_equal 1, Integer(c.fetch('runs', 1))
      assert_equal out['workdir'], c['workdir'] || Array(c['run_workdirs']).first
      assert_equal 'local', c['backend']
      assert out['workdir'].start_with?(work_root(dir) + File::SEPARATOR)
      assert_equal 'attempted', out['status']
      assert_equal 'built', out.dig('attempt', 'rebuild')
    end
  end

  def test_one_attempt_runs_the_pipeline_exactly_once
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      counter = File.join(dir, 'runs.log')
      cmd = ['ruby', '-e', "File.open(#{counter.inspect}, 'a') { |f| f.puts 'run' }; File.write('out.txt', 'hi')"]
      ok!(declare_args(dir, skp, 'pipeline' => { 'command' => cmd }))
      ok!(attempt_args(dir))
      assert_equal 1, File.readlines(counter).length
      ok!(attempt_args(dir))
      assert_equal 2, File.readlines(counter).length
    end
  end

  # A pipeline that writes out.txt only when it is absent would find attempt
  # 1's file in a reused directory and leave it unchanged (so uncompared).
  def test_each_attempt_gets_a_fresh_output_location
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      cmd = ['ruby', '-e', 'File.write("out.txt", "hi") unless File.exist?("out.txt"); File.write("log.txt", "x")']
      ok!(declare_args(dir, skp, 'pipeline' => { 'command' => cmd }))
      a1 = ok!(attempt_args(dir))
      a2 = ok!(attempt_args(dir))
      refute_equal a1['workdir'], a2['workdir']
      [a1, a2].each do |a|
        assert_equal [1, 1, 'match_exact'], a['attempt'].values_at('m', 'n', 'comparison_verdict')
      end
      assert_equal [1, 2], [a1, a2].map { |a| a.dig('attempt', 'attempt') }
    end
  end

  # --- ③: only declared paths absent before the run or changed by it ----------------------

  def test_a_target_already_present_and_unchanged_by_the_run_is_not_compared
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      build = step(command: write_command('tool.txt' => '1.0', 'out.txt' => 'hi'))
      ok!(declare_args(dir, skp, 'build_plan' => plan(steps: [build]),
                                 'pipeline' => { 'command' => write_command('other.txt' => 'x') }))
      row = ok!(attempt_args(dir))['attempt']
      assert_equal 'completed', row['execution_verdict']
      assert_equal [0, 1, 'mismatch'], row.values_at('m', 'n', 'comparison_verdict')
      assert_empty row['output_fingerprints']
    end
  end

  def test_a_target_changed_by_the_run_is_compared_and_undeclared_files_do_not_count
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      build = step(command: write_command('tool.txt' => '1.0', 'out.txt' => 'stale'))
      ok!(declare_args(dir, skp, 'build_plan' => plan(steps: [build]),
                                 'pipeline' => { 'command' => write_command('out.txt' => 'hi', 'junk.txt' => 'j') }))
      row = ok!(attempt_args(dir))['attempt']
      assert_equal [1, 1, 'match_exact'], row.values_at('m', 'n', 'comparison_verdict')
      assert_equal [{ 'path' => 'out.txt', 'value' => sha('hi') }], row['output_fingerprints']
    end
  end

  def test_a_run_that_does_not_complete_compares_nothing
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ok!(declare_args(dir, skp, 'pipeline' => { 'command' => ['ruby', '-e', 'exit 3'] }))
      row = ok!(attempt_args(dir))['attempt']
      assert_equal 'built', row['rebuild']
      assert_equal 'env_failed', row['execution_verdict']
      assert_equal 'not_attempted', row['comparison_verdict']
      assert_equal [0, 1], row.values_at('m', 'n')
    end
  end

  def test_no_declared_target_reads_no_target_declared
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ok!(declare_args(dir, skp, 'targets' => []))
      row = ok!(attempt_args(dir))['attempt']
      assert_equal [0, 0, 'no_target_declared'], row.values_at('m', 'n', 'comparison_verdict')
    end
  end

  # --- E1: n counts only the rows the declared comparator compares --------------------------

  def test_e1_a_plain_bundle_with_sha1_and_sha256_rows_gives_n_sha256_rows_and_m_equal_n_on_reproduction
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      rows = [['a.txt', 'sha1', sha1('A')], ['a.txt', 'sha256', sha('A')],
              ['b.txt', 'sha1', sha1('B')], ['b.txt', 'sha256', sha('B')]]
      ok!(declare_args(dir, skp, route: 'B', 'pipeline' => { 'command' => write_command('a.txt' => 'A', 'b.txt' => 'B') },
                                             **route_b_args(rows: rows)))
      row = ok!(attempt_args(dir))['attempt']
      assert_equal [2, 2, 'match_exact'], row.values_at('m', 'n', 'comparison_verdict')
    end
  end

  def test_e1_a_partial_reproduction_counts_the_matching_sha256_rows
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      rows = [['a.txt', 'sha1', sha1('A')], ['a.txt', 'sha256', sha('A')],
              ['b.txt', 'sha1', sha1('B')], ['b.txt', 'sha256', sha('B')]]
      ok!(declare_args(dir, skp, route: 'B', 'pipeline' => { 'command' => write_command('a.txt' => 'A', 'b.txt' => 'not B') },
                                             **route_b_args(rows: rows)))
      row = ok!(attempt_args(dir))['attempt']
      assert_equal [1, 2, 'mismatch'], row.values_at('m', 'n', 'comparison_verdict')
    end
  end

  # --- exact_commitment: C(f) under the bundle key --------------------------------------------

  def option2_args(dir, skp, ckp, key, output)
    rows = [['out.txt', 'hmac_sha256', C.commit(key, 'hi')]]
    declare_args(dir, skp, route: 'B', form: 'salted', commitment_key_path: ckp,
                           'pipeline' => { 'command' => write_command('out.txt' => output) }, **route_b_args(rows: rows))
  end

  def test_exact_commitment_matches_c_of_f_under_the_bundle_key
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ckp, key = write_commitment_key(dir)
      d = ok!(option2_args(dir, skp, ckp, key, 'hi'))['declaration']
      assert_equal({ 'id' => 'exact_commitment', 'version' => '0.1.0' }, d['comparator'])
      assert_equal({ 'rule' => 'gc-commitment-0.1', 'key_id' => C.key_id(key) }, d['commitment'])
      row = ok!(attempt_args(dir))['attempt']
      assert_equal [1, 1, 'match_exact'], row.values_at('m', 'n', 'comparison_verdict')
      assert_equal [{ 'path' => 'out.txt', 'value' => C.commit(key, 'hi') }], row['output_fingerprints']
    end
  end

  def test_exact_commitment_reports_a_mismatch_for_other_bytes
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ckp, key = write_commitment_key(dir)
      ok!(option2_args(dir, skp, ckp, key, 'ho'))
      row = ok!(attempt_args(dir))['attempt']
      assert_equal [0, 1, 'mismatch'], row.values_at('m', 'n', 'comparison_verdict')
    end
  end

  # --- the tool's own comparator table (fixed decision 4) -------------------------------------

  def test_the_comparators_live_in_the_tools_own_table_not_in_the_registry
    table = T3::Tools::GcTier3Attest::COMPARATORS
    assert_equal %w[exact_sha256 exact_commitment], table.keys
    assert_equal %w[0.2.0 0.1.0], table.values.map { |c| c::VERSION }
    assert_equal %w[sha256 hmac_sha256], table.values.map { |c| c::ALGORITHM }
    assert_equal %w[exact_sha256 exact_commitment], table.values.map { |c| c::ID }
    assert_equal %w[exact_sha256], T3::Execution::Comparator::REGISTRY.keys
    assert_raises(ArgumentError) { T3::Execution::Comparator.for('exact_commitment') }
  end

  def test_the_two_comparators_compare_a_file
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'f.txt')
      File.write(path, 'hi')
      key = C.generate_key
      sha_c = T3::Tools::GcTier3Attest::COMPARATORS['exact_sha256']
      com_c = T3::Tools::GcTier3Attest::COMPARATORS['exact_commitment']
      assert sha_c.match?(path: path, value: sha('hi'))
      refute sha_c.match?(path: path, value: sha('ho'))
      assert com_c.match?(path: path, value: C.commit(key, 'hi'), key: key)
      refute com_c.match?(path: path, value: C.commit(key, 'ho'), key: key)
      refute com_c.match?(path: path, value: sha('hi'), key: key), 'a plain SHA-256 is not a commitment'
    end
  end

  # --- thoa is refused for salted and option-2 jobs (§4.3) -------------------------------------

  def assert_thoa_refused(dir)
    text = err!(attempt_args(dir, backend: 'thoa'))
    assert_includes text, 'thoa'
    assert_empty Dir.children(work_root(dir)), 'no attempt location was made'
    assert_empty jsonl(File.join(process_dir(dir), '06_scores.jsonl')), 'no attempt row was written'
  end

  def test_thoa_is_refused_for_a_salted_declaration
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ckp, = write_commitment_key(dir)
      ok!(declare_args(dir, skp, form: 'salted', commitment_key_path: ckp))
      assert_thoa_refused(dir)
    end
  end

  # An unsalted declaration over hmac rows: the anchor would refuse it, the
  # executor still must not send its inputs to thoa.
  def test_thoa_is_refused_for_an_option_2_declaration_even_unsalted
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ckp, key = write_commitment_key(dir)
      rows = [['out.txt', 'hmac_sha256', C.commit(key, 'hi')]]
      ok!(declare_args(dir, skp, route: 'B', commitment_key_path: ckp, **route_b_args(rows: rows)))
      assert_thoa_refused(dir)
    end
  end

  # --- target paths stay inside the attempt's output location (§3.1; preflight K3,
  # orchestrator default 2026-10-20: a correction of the class, not a new check) ---------------

  BAD_PATHS = ['/etc/passwd', '~/secret.txt', '../outside.txt', 'res/../../outside.txt', ''].freeze

  def assert_declare_refused(dir, args, argument)
    text = err!(args)
    assert_includes text, argument
    refute File.exist?(args['process_dir']), "nothing is created on refusal (#{argument})"
  end

  def test_declare_refuses_a_route_a_target_path_outside_the_attempt_dir
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      BAD_PATHS.each_with_index do |bad, i|
        args = declare_args(dir, skp, 'process_dir' => File.join(dir, "p#{i}"),
                                      'targets' => [{ 'path' => bad, 'sha256' => sha('hi') }])
        assert_declare_refused(dir, args, 'targets')
      end
    end
  end

  def test_declare_refuses_a_route_b_target_path_outside_the_attempt_dir
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      rows = [['out.txt', 'sha256', sha('hi')]]
      BAD_PATHS.each_with_index do |bad, i|
        args = declare_args(dir, skp, route: 'B', 'process_dir' => File.join(dir, "p#{i}"),
                                      **route_b_args(rows: rows, target_paths: [bad]))
        assert_declare_refused(dir, args, 'target_paths')
      end
    end
  end

  # A row name is a path only when no target_paths entry replaces it.
  def test_declare_refuses_a_route_b_row_name_used_as_a_default_path_outside_the_attempt_dir
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      BAD_PATHS.each_with_index do |bad, i|
        rows = [[bad, 'sha256', sha('hi')]]
        args = declare_args(dir, skp, route: 'B', 'process_dir' => File.join(dir, "p#{i}"), **route_b_args(rows: rows))
        assert_declare_refused(dir, args, 'bundle_rows')
      end
      rows = [['../renamed.txt', 'sha256', sha('hi')]]
      d = ok!(declare_args(dir, skp, route: 'B', 'process_dir' => File.join(dir, 'p_ok'),
                                     **route_b_args(rows: rows, target_paths: ['out.txt'])))
      assert_equal(['out.txt'], d.dig('declaration', 'targets', 'paths'))
    end
  end

  # A symlink the pipeline plants is resolved: only a target whose real path
  # lies inside the attempt dir is compared. Outside ones count as not
  # produced, and neither their bytes' digest nor an absolute path of this
  # machine reaches the attestation.
  def test_a_target_whose_real_path_lies_outside_the_attempt_dir_is_not_compared
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      secret = File.join(dir, 'outside', 'secret.txt')
      FileUtils.mkdir_p(File.dirname(secret))
      File.write(secret, 'hi')
      script = "File.symlink('../../outside/secret.txt', 'out.txt'); File.symlink('../../signing.key', 'key.txt'); " \
               "Dir.mkdir('data'); File.write('data/in.txt', 'in'); File.symlink('data/in.txt', 'link_in.txt'); " \
               "File.write('ok.txt', 'ok')"
      # out.txt would match if read (its declared value is the secret's digest);
      # key.txt points at the executor's signing-key file.
      targets = [['out.txt', sha('hi')], ['key.txt', sha('k')], ['link_in.txt', sha('in')], ['ok.txt', sha('ok')]]
      ok!(declare_args(dir, skp, 'pipeline' => { 'command' => ['ruby', '-e', script] },
                                 'targets' => targets.map { |p, v| { 'path' => p, 'sha256' => v } }))
      row = ok!(attempt_args(dir))['attempt']
      assert_equal 'completed', row['execution_verdict']
      assert_equal [2, 4, 'mismatch'], row.values_at('m', 'n', 'comparison_verdict')
      assert_equal [{ 'path' => 'link_in.txt', 'value' => sha('in') }, { 'path' => 'ok.txt', 'value' => sha('ok') }],
                   row['output_fingerprints'], 'the declared relative paths, inside targets only'
      a = JSON.generate(ok!(attest_args(dir, skp, own_ref(dir)))['attestation'])
      files = Dir.glob(File.join(process_dir(dir), '**', '*')).select { |p| File.file?(p) }.map { |p| File.read(p) }
      key_digest = Digest::SHA256.file(skp).hexdigest
      ([a] + files).each_with_index do |text, i|
        refute_includes text, key_digest, "text #{i}: the key file's digest stays out"
        [secret, File.realpath(secret)].each { |p| refute_includes text, p, "text #{i}: no absolute path of an outside target" }
      end
      # The key path may be the executor's own note in its process record; never in the attestation.
      [dir, File.realpath(dir), skp, File.realpath(skp)].each do |p|
        refute_includes a, p, 'no absolute path of this machine in the attestation'
      end
    end
  end

  # --- attempts_max on the executor's side (operator, 2026-10-20, question 4 「実行者の側で断る」) ---

  # Every file under the dir, by relative path, with its bytes' SHA-256.
  def tree(dir)
    Dir.glob(File.join(dir, '**', '*'), File::FNM_DOTMATCH).reject { |p| File.basename(p).match?(/\A\.\.?\z/) }
       .sort.to_h { |p| [p.delete_prefix(dir), File.file?(p) ? Digest::SHA256.file(p).hexdigest : :dir] }
  end

  def test_the_attempts_max_th_attempt_runs
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ok!(declare_args(dir, skp, 'attempts_max' => 2))
      rows = [ok!(attempt_args(dir)), ok!(attempt_args(dir))].map { |a| a['attempt'] }
      assert_equal [1, 2], rows.map { |r| r['attempt'] }
      assert_equal 2, jsonl(File.join(process_dir(dir), '06_scores.jsonl')).length
    end
  end

  def test_an_attempt_beyond_attempts_max_is_refused_and_changes_nothing
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ok!(declare_args(dir, skp, 'attempts_max' => 2))
      2.times { ok!(attempt_args(dir)) }
      before = [tree(process_dir(dir)), tree(work_root(dir))]
      assert_includes err!(attempt_args(dir)), 'attempts_max'
      assert_equal before, [tree(process_dir(dir)), tree(work_root(dir))], 'no attempt dir, no process-record line'
      assert_equal 2, Dir.children(work_root(dir)).length
    end
  end

  # --- ①: the rule of §3.1 ------------------------------------------------------------------

  def assert_cannot_build(row)
    assert_equal({ 'attempt' => row['attempt'], 'backend_id' => 'local', 'rebuild' => 'cannot_build' }, row)
  end

  def test_a_plan_that_pins_nothing_cannot_build_and_does_not_run
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ok!(declare_args(dir, skp, 'build_plan' => plan(steps: [step(pins: [])])))
      calls = 0
      real = T3::Tools::GcTier3Execute.new(nil)
      spy = Object.new
      spy.define_singleton_method(:call) { |args| calls += 1; real.call(args) }
      row = T3::Tools::GcTier3Execute.stub(:new, ->(*_a, **_k) { spy }) { ok!(attempt_args(dir))['attempt'] }
      assert_cannot_build(row)
      assert_equal 0, calls
    end
  end

  def test_a_failing_build_step_cannot_build
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ok!(declare_args(dir, skp, 'build_plan' => plan(steps: [step(command: ['ruby', '-e', 'exit 1'])])))
      assert_cannot_build(ok!(attempt_args(dir))['attempt'])
    end
  end

  def test_a_pin_not_obtained_as_pinned_cannot_build
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ok!(declare_args(dir, skp, 'build_plan' => plan(steps: [step(pins: [pin(expected: '2.0')])])))
      assert_cannot_build(ok!(attempt_args(dir))['attempt'])
    end
  end

  def test_a_pin_whose_observation_fails_cannot_build
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      bad = pin(observe: ['ruby', '-e', 'exit 2'])
      ok!(declare_args(dir, skp, 'build_plan' => plan(steps: [step(pins: [bad])])))
      assert_cannot_build(ok!(attempt_args(dir))['attempt'])
    end
  end

  def test_failed_build_attempts_appear_in_the_attestation_and_the_process_record
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ok!(declare_args(dir, skp, 'build_plan' => plan(steps: [flaky_step(File.join(dir, 'marker'))])))
      first = ok!(attempt_args(dir))['attempt']
      second = ok!(attempt_args(dir))['attempt']
      assert_equal %w[cannot_build built], [first, second].map { |r| r['rebuild'] }
      a = ok!(attest_args(dir, skp, own_ref(dir)))['attestation']
      assert_equal [first, second], a['attempts']
      assert_equal [first, second], jsonl(File.join(process_dir(dir), '06_scores.jsonl'))
      builds = jsonl(File.join(process_dir(dir), '02_build.jsonl'))
      assert_equal [[1, 'cannot_build'], [2, 'built']], builds.map { |b| b.values_at('attempt', 'rebuild') }
    end
  end

  # --- environment_provenance (§4.1 table) ----------------------------------------------------

  def test_an_inferred_pin_makes_the_environment_operator_authored
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ok!(declare_args(dir, skp, 'build_plan' => plan(steps: [step(pins: [pin, pin(name: 'tool2', origin: 'inferred')])])))
      ok!(attempt_args(dir))
      assert_equal 'authored_by_operator', ok!(attest_args(dir, skp, own_ref(dir)))['attestation']['environment_provenance']
    end
  end

  def test_declared_pins_leave_the_environment_as_derived
    Dir.mktmpdir do |dir|
      skp, = write_signing_key(dir)
      ok!(declare_args(dir, skp))
      ok!(attempt_args(dir))
      assert_equal 'declared_lock', ok!(attest_args(dir, skp, own_ref(dir)))['attestation']['environment_provenance']
    end
  end

  # --- attest -------------------------------------------------------------------------------

  def test_attest_carries_the_binding_fields_and_signs_with_the_same_key
    Dir.mktmpdir do |dir|
      skp, sk, = write_signing_key(dir)
      d = ok!(declare_args(dir, skp))['declaration']
      ok!(attempt_args(dir))
      out = ok!(attest_args(dir, skp, own_ref(dir)))
      a = out['attestation']
      BINDING.each { |f| assert_equal d[f], a[f], f }
      refute a.key?('commitment')
      assert_equal own_ref(dir), a['declaration_ref']
      assert_equal NOT_CHECKED, a['not_checked']
      assert_equal pubkey(sk), out.dig('operator', 'pubkey')
      payload = M.canonical_json('mcp_tool_name' => 'gc_tier3_record_submit', 'params' => a,
                                 'nonce' => out.dig('operator', 'signature', 'nonce'),
                                 'chain_tip_hash' => out.dig('operator', 'signature', 'chain_tip_hash'))
      assert sk.verify_key.verify(Base64.urlsafe_decode64(out.dig('operator', 'signature', 'value')), payload)
      assert_equal 'attestation', out.dig('submit', 'arguments', 'action')
      %w[headline score rebuild rerun reproduce].each { |k| refute a.key?(k) }
    end
  end

  # --- keys never leave the tool (§4.2, fixed decision 5) ----------------------------------------

  def needles(key, seed, signing_key_path)
    [key, key[0, 31], key[0, 31].unpack1('H*'), key.unpack1('H*'), key.unpack1('H*').upcase, Base64.strict_encode64(key), Base64.urlsafe_encode64(key),
     seed, seed.unpack1('H*'), seed.unpack1('H*').upcase, Base64.strict_encode64(seed), Base64.urlsafe_encode64(seed),
     File.binread(signing_key_path)].map(&:b)
  end

  def test_no_key_appears_in_any_response_record_log_error_or_process_file
    with_anchor do |registry, tip|
      Dir.mktmpdir do |dir|
        skp, sk, seed = write_signing_key(dir)
        ckp, key = write_commitment_key(dir)
        texts = []
        stdout, stderr = capture_io do
          d = ok!(declare_args(dir, skp, tip.latest_tip_hash, form: 'salted', commitment_key_path: ckp,
                                    'build_plan' => plan(steps: [flaky_step(File.join(dir, 'marker'))])), texts: texts)
          ref = submit_declaration(registry, tip, sk, d['declaration'], op: d['operator'])[:declaration_ref]
          err!(attempt_args(dir, backend: 'thoa'), texts: texts)
          ok!(attempt_args(dir), texts: texts)
          ok!(attempt_args(dir), texts: texts)
          a = ok!(attest_args(dir, skp, ref, tip.latest_tip_hash), texts: texts)
          rec = submit_attestation(registry, tip, sk, a['attestation'], op: a['operator'])
          texts << evidence_text(registry, rec[:synoptis_proof_id])
          other = a['attestation'].merge('attempts' => a['attestation']['attempts'].first(1))
          dup = assert_raises(T3R::Records::AlreadyAttested) { submit_attestation(registry, tip, sk, other) }
          texts << dup.message
          short = File.join(dir, 'short.key')
          File.binwrite(short, key[0, 31])
          err!(declare_args(dir, skp, form: 'salted', commitment_key_path: short,
                                      'process_dir' => File.join(dir, 'process2')), texts: texts)
        end
        texts << stdout << stderr
        texts.concat(Dir.glob(File.join(dir, 'process{,2}', '**', '*')).select { |p| File.file?(p) }.map { |p| File.binread(p) })
        manifests_of_type(registry, 'tier3_declaration').each { |m| texts << JSON.generate(m) }
        refute_empty texts
        n = needles(key, seed, skp)
        texts.each_with_index do |t, i|
          n.each { |needle| refute t.to_s.b.include?(needle), "text #{i} carries key material" }
        end
      end
    end
  end

  # --- end to end with the anchor ------------------------------------------------------------

  def test_route_a_plain_job_is_declared_attempted_attested_and_recorded
    with_anchor do |registry, tip|
      Dir.mktmpdir do |dir|
        skp, sk, = write_signing_key(dir)
        d = ok!(declare_args(dir, skp, tip.latest_tip_hash))
        rec = submit_declaration(registry, tip, sk, d['declaration'], op: d['operator'])
        assert_equal 'recorded', rec[:status]
        ok!(attempt_args(dir))
        a = ok!(attest_args(dir, skp, rec[:declaration_ref], tip.latest_tip_hash))
        out = submit_attestation(registry, tip, sk, a['attestation'], op: a['operator'])
        assert_equal 'recorded', out[:status]
        [d, a].each { |o| FORBIDDEN.each { |w| refute_includes JSON.generate(o), w } }
      end
    end
  end

  # E1 against a real Tier-2.5 record of the v0.3 fixture bundle: two rows
  # (sha1, sha256) for counts.tsv, n = 1, and the anchor's recount agrees.
  def test_route_b_plain_job_over_the_fixture_bundles_record
    with_anchor do |registry, tip|
      Dir.mktmpdir do |dir|
        prov_id = prov_record(registry, tip)
        skp, sk, = write_signing_key(dir)
        args = declare_args(dir, skp, tip.latest_tip_hash, route: 'B',
                                      'pipeline' => { 'command' => write_command('counts.tsv' => V03_OUTPUT) },
                                      **route_b_args(rows: v03_rows, route_proof_id: prov_id,
                                                     bundle_digest: v03_signed['bundle_digest']))
        d = ok!(args)
        assert_equal prov_id, d.dig('submit', 'arguments', 'route_proof_id')
        assert_equal v03_signed['outputs_digest'], d.dig('declaration', 'targets', 'outputs_digest')
        rec = submit_declaration(registry, tip, sk, d['declaration'], op: d['operator'], route_proof_id: prov_id)
        assert_equal 'recorded', rec[:status]
        row = ok!(attempt_args(dir))['attempt']
        assert_equal [1, 1, 'match_exact'], row.values_at('m', 'n', 'comparison_verdict')
        a = ok!(attest_args(dir, skp, rec[:declaration_ref], tip.latest_tip_hash))
        assert_equal 'recorded', submit_attestation(registry, tip, sk, a['attestation'], op: a['operator'])[:status]
      end
    end
  end
end
