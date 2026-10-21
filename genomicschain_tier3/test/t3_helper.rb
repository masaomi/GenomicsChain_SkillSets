# frozen_string_literal: true

# Shared fixtures for the Tier 3 v0.1 executor-side tests (design
# docs/design/tier3_design_v0_1.md §9; names fixed in
# log/tier3_impl_20261020/interface_v0_1.md). Not a test file. The anchor
# side (stub attestor, hand-built params, prov records) comes from the record
# package's helper; tier3 depends on genomicschain_tier3_record.
#
# Run one file: ruby -Ilib -Itest -I../genomicschain_core/lib -I../genomicschain_tier2/lib \
#   -I../genomicschain_prov/lib -I../genomicschain_tier3_record/lib -I"$T/synoptis/lib" -I"$T/mmp/lib" test/<file>.rb
require_relative '../../genomicschain_tier3_record/test/t3_record_helper'

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'genomicschain_tier3'
require_relative '../tools/gc_tier3_execute'

module T3Helpers
  include T3RecordHelpers

  T3 = KairosMcp::SkillSets::GenomicschainTier3
  TIP = 'f' * 64 # executor-only tests: the tool does not read the anchor

  # --- the executor-side tool --------------------------------------------------------

  def attest_tool = T3::Tools::GcTier3Attest.new(nil)
  def tool_text(args, tool: attest_tool) = tool.call(args).first[:text]

  def ok!(args, tool: attest_tool, texts: nil)
    text = tool_text(args, tool: tool)
    texts << text if texts
    flunk "expected success, got: #{text}" if text.start_with?('Error:')
    JSON.parse(text)
  end

  def err!(args, tool: attest_tool, texts: nil)
    text = tool_text(args, tool: tool)
    texts << text if texts
    assert text.start_with?('Error:'), "expected an error, got: #{text[0, 300]}"
    text
  end

  # The gc_submit_client format: base64 of the 32-byte ed25519 seed. [path, key, seed]
  def write_signing_key(dir, name = 'signing.key')
    seed = SecureRandom.random_bytes(32)
    path = File.join(dir, name)
    File.open(path, 'w', 0o600) { |f| f.write(Base64.strict_encode64(seed)) }
    [path, Ed25519::SigningKey.new(seed), seed]
  end

  # A gc-commitment-0.1 key file: 32 raw bytes, owner-only. [path, key]
  def write_commitment_key(dir, key = C.generate_key, name = 'commitment.key')
    path = File.join(dir, name)
    C.write_key_file(path, key)
    [path, key]
  end

  def observe_file(name) = ['ruby', '-e', "print File.read(#{name.inspect})"]

  def pin(name: 'tool', expected: '1.0', origin: 'declared', observe: observe_file('tool.txt'), kind: 'version')
    { 'name' => name, 'kind' => kind, 'expected' => expected, 'observe' => observe, 'origin' => origin }
  end

  def step(name: 'fetch', command: ['ruby', '-e', 'File.write("tool.txt", "1.0")'], pins: [pin])
    { 'name' => name, 'command' => command, 'pins' => pins }
  end

  def plan(steps: [step], env: { 'lock' => 'sha256:envlock' })
    { 'env' => env, 'steps' => steps }
  end

  def write_command(files) = ['ruby', '-e', files.map { |p, body| "File.write(#{p.inspect}, #{body.inspect})" }.join('; ')]

  def input_file(dir)
    path = File.join(dir, 'input', 'reads.txt')
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "@r1\nACGT\n+\nIIII\n") unless File.exist?(path)
    path
  end

  def process_dir(dir) = File.join(dir, 'process')

  def work_root(dir)
    path = File.join(dir, 'work')
    FileUtils.mkdir_p(path)
    path
  end

  def declare_args(dir, signing_key_path, tip_hash = TIP, route: 'A', form: 'plain', commitment_key_path: nil, **over)
    base = {
      'action' => 'declare', 'process_dir' => process_dir(dir), 'signing_key_path' => signing_key_path,
      'chain_tip_hash' => tip_hash, 'subject_ref' => 'repro://656122/C9', 'route' => route,
      'fingerprint_form' => form, 'data_class' => 'non_human', 'build_plan' => plan,
      'data' => { 'accessions' => [] }, 'pipeline' => { 'command' => write_command('out.txt' => 'hi') },
      'inputs' => [input_file(dir)], 'attempts_max' => 3, 'expires_at' => '2026-11-19T00:00:00Z'
    }
    base['commitment_key_path'] = commitment_key_path if commitment_key_path
    if route == 'A'
      base.merge!('route_ref' => 'tier2:demo-adjudication', 'targets' => [{ 'path' => 'out.txt', 'sha256' => sha('hi') }],
                  'source' => 'paper_declared', 'source_citation' => 'doi:10.1038/s41467-018-06108-1',
                  'validated_by' => 'human:executor')
    end
    base.merge(over).compact
  end

  # target_paths, when given, is one entry per bundle row (nil = the row's name).
  def route_b_args(rows:, route_proof_id: 'attest_route_b_fixture', bundle_digest: hex('bundle'), **over)
    { 'route_proof_id' => route_proof_id, 'bundle_digest' => bundle_digest, 'bundle_rows' => rows }.merge(over)
  end

  def attempt_args(dir, backend: 'local')
    { 'action' => 'attempt', 'process_dir' => process_dir(dir), 'work_root' => work_root(dir), 'backend' => backend }
  end

  def attest_args(dir, signing_key_path, ref, tip_hash = TIP)
    { 'action' => 'attest', 'process_dir' => process_dir(dir), 'signing_key_path' => signing_key_path,
      'chain_tip_hash' => tip_hash, 'declaration_ref' => ref }
  end

  def declaration_copy(dir) = JSON.parse(File.read(File.join(process_dir(dir), '01_declaration.json')))

  # A declaration_ref of this process record's own declaration, as the anchor
  # would return it (the executor can check the digest, not the anchor's T_d).
  def own_ref(dir)
    { 'declaration_digest' => h_plain(declaration_copy(dir)['declaration']), 'recorded_at' => '2026-10-20T08:00:00Z' }
  end

  # A build step that fails the first time it runs and succeeds afterwards,
  # counted by a marker outside the attempt dirs.
  def flaky_step(marker)
    script = "m = #{marker.inspect}; if File.exist?(m) then File.write('tool.txt', '1.0') " \
             "else File.write(m, 'x'); exit 1 end"
    step(command: ['ruby', '-e', script])
  end

  def jsonl(path)
    return [] unless File.exist?(path)

    File.readlines(path).map(&:strip).reject(&:empty?).map { |l| JSON.parse(l) }
  end
end
