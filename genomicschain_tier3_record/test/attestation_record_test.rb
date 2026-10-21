# frozen_string_literal: true

# Tier 3 v0.1 §9-2 — the attestation record (tier3_attestation 0.1). The
# anchor re-reads the declaration, requires the same signing key and the §4.1
# binding list field by field, keeps env_digest and backend_id outside the
# equality, takes one attestation per declaration_ref by its own check (not
# SubmitCore's idempotency, 36:63–71; an identical resend recovers, orchestrator
# amendment 2026-10-20) and requires 1 ≤ attempts ≤ attempts_max (§3.4).
# Params are hand-built (t3_record_helper).
require_relative 't3_record_helper'
require 'genomicschain_tier3_record/record_submit'

class AttestationRecordTest < Minitest::Test
  include T3RecordHelpers

  def setup = reset_nonces

  def attestations(registry) = manifests_of_type(registry, 'tier3_attestation')

  # --- recorded ---------------------------------------------------------------------

  def test_an_attestation_under_the_declarations_key_is_recorded_verbatim
    with_anchor do |registry, tip|
      sk = new_key
      d, ref, = declared(registry, tip, sk)
      a = attestation_for(d, ref, attempts: [cannot_build_row(1), built_row(2)])
      out = submit_attestation(registry, tip, sk, a)
      assert_equal 'recorded', out[:status]
      m = manifest_of(registry, out[:synoptis_proof_id])
      assert_equal %w[tier3_attestation 0.1 gc_tier3_record_submit],
                   m.values_at('record_type', 'record_version', 'mcp_tool_name')
      a.each { |k, v| assert_equal v, m[k], "field #{k} is recorded as signed" }
      assert_match ISO, m['recorded_at']
      assert_equal "tier3-attestation:0.1:#{ref['declaration_digest']}:#{out[:submission_key]}", out[:claim]
      FORBIDDEN.each { |w| refute_includes out[:claim], w }
      assert_equal Digest::SHA256.hexdigest(out[:submission_key]), out[:idempotency_key]
      assert_equal PROOF_TTL, registry.find_proof(out[:synoptis_proof_id]).ttl
    end
  end

  # §4.1 札の言い方: what the anchor re-derived is procedure_checked, T_a is
  # anchor_observed, the comparator is the executor's word.
  def test_backing_labels
    with_anchor do |registry, tip|
      sk = new_key
      d, ref, = declared(registry, tip, sk)
      out = submit_attestation(registry, tip, sk, attestation_for(d, ref))
      b = manifest_of(registry, out[:synoptis_proof_id])['backing']
      assert_equal 'gc-backing-0.1', b['vocabulary']
      assert_equal 'anchor_observed', b['recorded_at']
      assert_equal 'procedure_checked', b['signing_key']
      assert_equal 'procedure_checked', b['binding']
      assert_equal 'customer_signed', b['attestation']
      refute_equal 'procedure_checked', b['comparator']
    end
  end

  def test_not_checked_is_the_fixed_list
    with_anchor do |registry, tip|
      sk = new_key
      d, ref, = declared(registry, tip, sk)
      out = submit_attestation(registry, tip, sk, attestation_for(d, ref))
      assert_equal NOT_CHECKED, manifest_of(registry, out[:synoptis_proof_id])['not_checked']
    end
    with_anchor do |registry, tip|
      sk = new_key
      d, ref, = declared(registry, tip, sk)
      short = attestation_for(d, ref, 'not_checked' => NOT_CHECKED - ['route_a_targets_complete'])
      assert_raises(T3R::Records::FormRejected) { submit_attestation(registry, tip, sk, short) }
      assert_empty attestations(registry)
    end
  end

  # §3.2: 代表値は置かない.
  def test_no_headline_score_field
    with_anchor do |registry, tip|
      sk = new_key
      d, ref, = declared(registry, tip, sk)
      out = submit_attestation(registry, tip, sk, attestation_for(d, ref))
      m = manifest_of(registry, out[:synoptis_proof_id])
      %w[headline score rebuild rerun reproduce best_attempt m n].each { |k| refute m.key?(k), "no top-level #{k}" }
      reset_nonces
      d2, ref2, = declared(registry, tip, sk, declaration('subject_ref' => 'repro://656122/C10'))
      with_headline = attestation_for(d2, ref2, 'headline' => { 'reproduce' => 'match_exact' })
      assert_raises(T3R::Records::FormRejected) { submit_attestation(registry, tip, sk, with_headline) }
      assert_equal 1, attestations(registry).length
    end
  end

  # --- §4.1: the same signing key -------------------------------------------------------

  def test_an_attestation_under_another_signing_key_is_refused
    with_anchor do |registry, tip|
      d, ref, = declared(registry, tip, new_key)
      assert_raises(T3R::Records::SignerMismatch) { submit_attestation(registry, tip, new_key, attestation_for(d, ref)) }
      assert_empty attestations(registry)
    end
  end

  # --- §4.1: the binding list, one field at a time ---------------------------------------

  OTHER_KEY = GenomicsChainProv::Commitment.generate_key

  BINDING_MUTATIONS = {
    'subject_ref' => ->(_t, a) { a.merge('subject_ref' => 'repro://656122/C10') },
    'job_identity' => ->(t, a) { a.merge('job_identity' => a['job_identity'].merge('digest' => t.hex('other job'))) },
    'job_identity_rule' => ->(_t, a) { a.merge('job_identity' => a['job_identity'].merge('rule' => 'gc-job-identity-0.1')) },
    'inputs_commitment' => ->(t, a) { a.merge('inputs_commitment' => t.hex('other inputs')) },
    'targets' => lambda { |t, a|
      items = a['targets']['items'].map { |i| i.merge('value' => t.hex('other target')) }
      a.merge('targets' => a['targets'].merge('items' => items))
    },
    'targets_kind' => ->(t, a) { a.merge('targets' => t.route_b_targets) },
    'comparator' => ->(_t, a) { a.merge('comparator' => { 'id' => 'exact_commitment', 'version' => '0.1.0' }) },
    'comparator_version' => ->(_t, a) { a.merge('comparator' => { 'id' => 'exact_sha256', 'version' => '0.1.0' }) },
    'build_plan_digest' => ->(t, a) { a.merge('build_plan_digest' => t.hex('other plan')) },
    'route_ref' => ->(_t, a) { a.merge('route_ref' => 'tier2:another-adjudication') },
    'fingerprint_form' => ->(_t, a) { a.merge('fingerprint_form' => 'plain').except('commitment') },
    'data_class' => ->(_t, a) { a.merge('data_class' => 'human') },
    'commitment' => ->(_t, a) { a.merge('commitment' => GenomicsChainProv::Commitment.declaration(OTHER_KEY)) }
  }.freeze

  BINDING_MUTATIONS.each do |name, mutate|
    field = name.sub(/_(rule|kind|version)\z/, '')
    define_method("test_binding_#{name}_must_equal_the_declaration") do
      with_anchor do |registry, tip|
        sk = new_key
        d, ref, = declared(registry, tip, sk, declaration(form: 'salted', key: C.generate_key))
        a = mutate.call(self, attestation_for(d, ref))
        e = assert_raises(T3R::Records::BindingMismatch) { submit_attestation(registry, tip, sk, a) }
        assert_includes e.message, field
        assert_empty attestations(registry)
      end
    end
  end

  # v0.1 has one tolerance, so another value may already fail on form.
  def test_binding_tolerance_must_equal_the_declaration
    with_anchor do |registry, tip|
      sk = new_key
      d, ref, = declared(registry, tip, sk)
      a = attestation_for(d, ref).merge('tolerance' => 'within_1_percent')
      assert_raises(T3R::Records::BindingMismatch, T3R::Records::FormRejected) { submit_attestation(registry, tip, sk, a) }
      assert_empty attestations(registry)
    end
  end

  # Design §4.4 「欄の形」 (pre-flight r2, orchestrator default 2026-10-21): the
  # attestation's copy of the targets is held to the same path form, so a bad
  # path is a form refusal, not a binding comparison.
  def test_an_attestation_target_path_outside_the_output_location_is_refused_on_form
    with_anchor do |registry, tip|
      sk = new_key
      d, ref, = declared(registry, tip, sk)
      ['', '/etc/passwd', '~/secret.txt', '../outside.txt', 'res/../../outside.txt'].each do |bad|
        reset_nonces
        a = attestation_for(d, ref, 'targets' => route_a_targets(path: bad))
        assert_raises(T3R::Records::FormRejected) { submit_attestation(registry, tip, sk, a) }
      end
      assert_empty attestations(registry)
    end
  end

  # Review r2 G5 (2), (3): attempts[].output_fingerprints[].path has the target
  # path form, control characters included.
  def test_an_output_fingerprint_path_outside_the_output_location_is_refused_on_form
    with_anchor do |registry, tip|
      sk = new_key
      d, ref, = declared(registry, tip, sk)
      ['', '/etc/passwd', '~/secret.txt', '../outside.txt', 'res/../../outside.txt',
       "out\u0000.txt", "out\n.txt", "out\u001b.txt", "out\u0085.txt", "out\u009b.txt"].each do |bad|
        reset_nonces
        row = built_row(1).merge('output_fingerprints' => [{ 'path' => bad, 'value' => hex('out') }])
        assert_raises(T3R::Records::FormRejected) { submit_attestation(registry, tip, sk, attestation_for(d, ref, attempts: [row])) }
      end
      assert_empty attestations(registry)
    end
  end

  def test_an_attestation_target_path_with_a_control_character_is_refused_on_form
    with_anchor do |registry, tip|
      sk = new_key
      d, ref, = declared(registry, tip, sk)
      ["out\u0000.txt", "out\n.txt", "out\u007f.txt", "out\u0085.txt", "out\u009b.txt"].each do |bad|
        reset_nonces
        a = attestation_for(d, ref, 'targets' => route_a_targets(path: bad))
        assert_raises(T3R::Records::FormRejected) { submit_attestation(registry, tip, sk, a) }
      end
      assert_empty attestations(registry)
    end
  end

  # Review r2 G5 (1): whole-value patterns for digests and times.
  def test_a_digest_or_a_time_with_a_trailing_line_is_refused_on_form
    with_anchor do |registry, tip|
      sk = new_key
      d, ref, = declared(registry, tip, sk)
      tail = "\n/home/alice/x"
      [attestation_for(d, ref, 'process_record_digest' => hex('process') + tail),
       attestation_for(d, ref, 'result_commitment' => hex('result') + tail),
       attestation_for(d, ref, attempts: [built_row(1, env_digest: hex('env') + tail)]),
       attestation_for(d, ref, attempts: [built_row(1).merge('output_fingerprints' => [{ 'path' => 'out.txt', 'value' => hex('o') + tail }])]),
       attestation_for(d, ref.merge('declaration_digest' => ref['declaration_digest'] + tail)),
       attestation_for(d, ref.merge('recorded_at' => "#{ref['recorded_at']}\n…"))].each_with_index do |a, i|
        reset_nonces
        assert_raises(T3R::Records::FormRejected, "case #{i}") { submit_attestation(registry, tip, sk, a) }
      end
      assert_empty attestations(registry)
    end
  end

  def test_every_binding_field_is_required_in_the_attestation
    with_anchor do |registry, tip|
      sk = new_key
      d, ref, = declared(registry, tip, sk)
      BINDING.each do |field|
        reset_nonces
        e = assert_raises(T3R::Records::FormRejected) do
          submit_attestation(registry, tip, sk, attestation_for(d, ref).except(field))
        end
        assert_includes e.message, field
      end
      assert_empty attestations(registry)
    end
  end

  # §3.1: env_digest and backend_id are ① outputs, decided after building.
  def test_env_digest_and_backend_id_are_outside_the_equality
    with_anchor do |registry, tip|
      sk = new_key
      d, ref, = declared(registry, tip, sk)
      rows = [built_row(1, backend: 'local', env_digest: hex('env a')), built_row(2, backend: 'thoa', env_digest: hex('env b'))]
      out = submit_attestation(registry, tip, sk, attestation_for(d, ref, attempts: rows))
      assert_equal 'recorded', out[:status]
      assert_equal %w[local thoa], manifest_of(registry, out[:synoptis_proof_id])['attempts'].map { |r| r['backend_id'] }
    end
  end

  # --- the house gates before any other work (orchestrator default 2026-10-20;
  # manifest.rb dos_gate! / restricted_subset!, the verdict_spec/tier3.rb:151–158 pattern) ----

  DEEP = 20.times.reduce('x') { |acc, _| { 'n' => acc } }

  def test_the_dos_gate_refuses_an_oversized_or_over_deep_attestation
    with_anchor do |registry, tip|
      sk = new_key
      d, ref, = declared(registry, tip, sk)
      [attestation_for(d, ref, 'environment_provenance' => 'x' * 70_000),
       attestation_for(d, ref, 'environment_provenance' => DEEP)].each do |a|
        reset_nonces
        assert_raises(KairosMcp::Manifest::DoSGateTripped) { submit_attestation(registry, tip, sk, a) }
      end
      assert_empty attestations(registry)
    end
  end

  def test_the_restricted_subset_refuses_an_attestation_value_outside_it
    with_anchor do |registry, tip|
      sk = new_key
      d, ref, = declared(registry, tip, sk)
      [attestation_for(d, ref, 'environment_provenance' => "declared_lock\u2028"),
       attestation_for(d, ref, attempts: [built_row(1).merge('backend_id' => "local\u2029")]),
       attestation_for(d, ref, 'donnée' => 'x')].each do |a|
        reset_nonces
        assert_raises(KairosMcp::Manifest::RestrictedSubsetViolation) { submit_attestation(registry, tip, sk, a) }
      end
      assert_empty attestations(registry)
    end
  end

  # The per-declaration_ref serialisation key is derived only from params the
  # gates accepted (orchestrator default 2026-10-20). No lock table is named in
  # the interface, so this checks what is observable: an oversized or
  # over-deep declaration_ref is refused by dos_gate! and records nothing, and
  # the declaration can still be attested afterwards.
  def test_an_oversized_or_over_deep_declaration_ref_trips_the_dos_gate_and_records_nothing
    with_anchor do |registry, tip|
      sk = new_key
      d, ref, = declared(registry, tip, sk)
      [ref.merge('declaration_digest' => 'x' * 70_000), ref.merge('recorded_at' => DEEP), DEEP].each do |bad|
        reset_nonces
        assert_raises(KairosMcp::Manifest::DoSGateTripped) { submit_attestation(registry, tip, sk, attestation_for(d, bad)) }
      end
      assert_empty attestations(registry)
      reset_nonces
      assert_equal 'recorded', submit_attestation(registry, tip, sk, attestation_for(d, ref))[:status]
    end
  end

  # --- only the anchor's own records count (implementation review r1 H2, fix group F2) ----
  #
  # A record the anchor's tool wrote carries mcp_tool_name gc_tier3_record_submit,
  # and its Synoptis envelope names the operator as submitter (SynoptisAttestor.build
  # (operator_pubkey:) → envelope.submitter_pubkey). Anything else in the registry
  # with a Tier 3 record_type neither blocks nor stands in for a declaration.
  # (The lock table's emptiness after a call is not observable through the
  # interface, so it is not tested here.) foreign_writers is in t3_record_helper.

  # Review r2 C2 (fix group G2): a resend recovers the anchor-written record,
  # never a foreign copy that carries the same submission_key.
  def test_a_resend_recovers_the_anchor_written_attestation_not_a_planted_copy
    with_anchor do |registry, tip|
      sk = new_key
      d, ref, = declared(registry, tip, sk)
      a = attestation_for(d, ref)
      op = envelope(sk, a, tip)
      first = submit_attestation(registry, tip, sk, a, op: op)
      real = manifest_of(registry, first[:synoptis_proof_id])
      foreign_writers(sk).each { |w| plant_copy(registry, real, w, 'recorded_at' => '2001-01-01T00:00:00Z') }
      again = submit_attestation(registry, tip, sk, a, op: op)
      assert_equal ['recorded', true, first[:synoptis_proof_id]], again.values_at(:status, :recovered, :synoptis_proof_id)
    end
  end

  # Foreign copies planted under an attestation's submission_key before its
  # first submit do not block it (pre-flight r3 §2.2 (b); orchestrator
  # 2026-10-21): the real attestation is recorded (recovered false) with its
  # own proof, nothing in the response comes from a planted copy, and an
  # identical resend then recovers the real one. The registry is copied after
  # the declaration so the submission_key can be learnt on one copy and
  # planted on the other.
  def test_planted_copies_under_its_submission_key_do_not_stop_the_real_attestation
    with_anchor do |registry, tip|
      sk = new_key
      d, ref, = declared(registry, tip, sk)
      Dir.mktmpdir('t3_anchor_copy') do |copy_dir|
        FileUtils.cp_r(File.join(registry.instance_variable_get(:@data_dir), '.'), copy_dir)
        a = attestation_for(d, ref)
        learnt = manifest_of(registry, submit_attestation(registry, tip, sk, a)[:synoptis_proof_id])
        copy = ::Synoptis::Registry::FileRegistry.new(data_dir: copy_dir)
        copy_tip = GC::TipSource.new(registry: copy)
        reset_nonces
        planted = foreign_writers(sk).map { |w| plant_copy(copy, learnt, w, 'recorded_at' => '2001-01-01T00:00:00Z') }
        op = envelope(sk, a, copy_tip)
        out = submit_attestation(copy, copy_tip, sk, a, op: op)
        assert_equal ['recorded', false], out.values_at(:status, :recovered)
        refute_includes planted, out[:synoptis_proof_id]
        m = manifest_of(copy, out[:synoptis_proof_id])
        assert_equal TOOL, m['mcp_tool_name']
        refute_equal '2001-01-01T00:00:00Z', m['recorded_at']
        planted.each { |p| refute_includes out.inspect, p }
        again = submit_attestation(copy, copy_tip, sk, a, op: op)
        assert_equal [true, out[:synoptis_proof_id]], again.values_at(:recovered, :synoptis_proof_id)
      end
    end
  end

  # Review r3 D2 (operator 2026-10-21, question 8; design §3.4): a proof planted
  # BEFORE the first submit with the attestation's real subject_ref and claim
  # makes Synoptis answer the store with 'existing'. No success with that proof:
  # a recording failure naming no proof_id, and no attestation recorded. The
  # claim is learnt on a copy of the registry taken after the declaration.
  def test_a_proof_planted_with_the_real_claim_before_the_first_submit_is_not_reported_as_success
    with_anchor do |registry, tip|
      sk = new_key
      d, ref, = declared(registry, tip, sk)
      Dir.mktmpdir('t3_anchor_copy') do |copy_dir|
        FileUtils.cp_r(File.join(registry.instance_variable_get(:@data_dir), '.'), copy_dir)
        a = attestation_for(d, ref)
        out = submit_attestation(registry, tip, sk, a)
        learnt = manifest_of(registry, out[:synoptis_proof_id])
        copy = ::Synoptis::Registry::FileRegistry.new(data_dir: copy_dir)
        copy_tip = GC::TipSource.new(registry: copy)
        planted = plant(copy, learnt, submitter_pubkey: nil, claim: out[:claim], subject_ref: d['subject_ref'])
        reset_nonces
        result = begin
          submit_attestation(copy, copy_tip, sk, a)
        rescue GC::SubmitCore::SubmitError => e
          e
        end
        if result.is_a?(Exception)
          refute_includes result.message, planted
        else
          assert_match(/fail/, result[:status].to_s, 'a recording failure, not a success')
          refute_includes result.inspect, planted
        end
        assert_equal 1, manifests_of_type(copy, 'tier3_attestation').length, 'nothing new recorded'
      end
    end
  end

  # Review r3 (correction): a stored record with a Tier 3 record_type, the
  # tool's name and a submitter, but an `operator` that is not an object, stops
  # no later Tier 3 submission — first submissions and recoveries alike.
  def test_a_stored_tier3_record_with_a_malformed_operator_stops_nothing
    with_anchor do |registry, tip|
      sk = new_key
      %w[tier3_declaration tier3_attestation].product(['x', ['x']]).each_with_index do |(type, operator), i|
        plant(registry, { 'record_type' => type, 'record_version' => '0.1', 'mcp_tool_name' => TOOL,
                          'subject_ref' => 'repro://656122/C9', 'operator' => operator,
                          'declaration_digest' => hex("malformed #{i}"), 'recorded_at' => '2026-10-20T00:00:00Z',
                          'declaration_ref' => { 'declaration_digest' => hex("malformed #{i}"),
                                                 'recorded_at' => '2026-10-20T00:00:00Z' },
                          'submission_key' => hex("malformed key #{i}") }, submitter_pubkey: pubkey(sk))
      end
      d = declaration
      dop = envelope(sk, d, tip)
      first = submit_declaration(registry, tip, sk, d, op: dop)
      assert_equal ['recorded', false], first.values_at(:status, :recovered)
      assert_equal true, submit_declaration(registry, tip, sk, d, op: dop)[:recovered]
      a = attestation_for(d, first[:declaration_ref])
      aop = envelope(sk, a, tip)
      out = submit_attestation(registry, tip, sk, a, op: aop)
      assert_equal ['recorded', false], out.values_at(:status, :recovered)
      assert_equal true, submit_attestation(registry, tip, sk, a, op: aop)[:recovered]
    end
  end

  def test_a_planted_attestation_from_another_writer_does_not_block_the_real_one
    with_anchor do |registry, tip|
      sk = new_key
      d, ref, = declared(registry, tip, sk)
      foreign_writers(sk).each do |tool, submitter|
        planted = attestation_for(d, ref, attempts: [cannot_build_row(1)]).merge(
          'record_type' => 'tier3_attestation', 'record_version' => '0.1', 'mcp_tool_name' => tool,
          'recorded_at' => '2026-10-20T09:00:00Z', 'submission_key' => hex("planted #{tool} #{submitter}"),
          'operator' => { 'mode' => 'signed', 'pubkey' => pubkey(sk) }
        )
        plant(registry, planted, submitter_pubkey: submitter)
      end
      out = submit_attestation(registry, tip, sk, attestation_for(d, ref))
      assert_equal ['recorded', false], out.values_at(:status, :recovered)
    end
  end

  def test_a_planted_declaration_from_another_writer_stands_in_for_nothing
    with_anchor do |registry, tip|
      sk = new_key
      foreign_writers(sk).each_with_index do |(tool, submitter), i|
        reset_nonces
        decl = declaration('data_class' => 'human', 'subject_ref' => "repro://planted/#{i}")
        planted = decl.merge('record_type' => 'tier3_declaration', 'record_version' => '0.1', 'mcp_tool_name' => tool,
                             'declaration_digest' => h_plain(decl), 'recorded_at' => '2001-01-01T00:00:00Z',
                             'submission_key' => hex("planted declaration #{i}"),
                             'operator' => { 'mode' => 'signed', 'pubkey' => pubkey(sk) })
        plant(registry, planted, submitter_pubkey: submitter)
        ref = { 'declaration_digest' => planted['declaration_digest'], 'recorded_at' => planted['recorded_at'] }
        assert_raises(T3R::Records::DeclarationNotFound, "writer #{i}") do
          submit_attestation(registry, tip, sk, attestation_for(decl, ref))
        end
      end
      assert_empty attestations(registry)
    end
  end

  # Two attestations of one declaration, different submission_keys, sent at
  # once: one is recorded, the other refused (F2, the one-attestation rule
  # under concurrency). Three rounds, one declaration each.
  def test_two_racing_attestations_of_one_declaration_record_one
    with_anchor do |registry, tip|
      sk = new_key
      3.times do |round|
        d, ref, = declared(registry, tip, sk, declaration('subject_ref' => "repro://race/#{round}"))
        pair = [attestation_for(d, ref), attestation_for(d, ref, attempts: [cannot_build_row(1)])]
        ops = pair.map { |a| envelope(sk, a, tip) }
        start = Queue.new
        threads = pair.zip(ops).map do |a, op|
          Thread.new do
            Thread.current.report_on_exception = false
            start.pop
            begin
              submit_attestation(registry, tip, sk, a, op: op)
            rescue T3R::Records::AlreadyAttested => e
              e
            end
          end
        end
        2.times { start << :go }
        results = threads.map(&:value)
        assert_equal 1, results.count { |r| r.is_a?(Hash) && r[:status] == 'recorded' }, "round #{round}: #{results.inspect}"
        assert_equal 1, results.count { |r| r.is_a?(T3R::Records::AlreadyAttested) }, "round #{round}"
        assert_equal 1, attestations(registry).count { |m| m['declaration_ref'] == ref }
      end
    end
  end

  # --- declaration_ref resolves --------------------------------------------------------

  def test_an_attestation_pointing_at_no_declaration_is_refused
    with_anchor do |registry, tip|
      sk = new_key
      d, ref, = declared(registry, tip, sk)
      [ref.merge('declaration_digest' => hex('nothing')), ref.merge('recorded_at' => '2001-01-01T00:00:00Z')].each do |bad|
        reset_nonces
        assert_raises(T3R::Records::DeclarationNotFound) { submit_attestation(registry, tip, sk, attestation_for(d, bad)) }
      end
      assert_empty attestations(registry)
    end
  end

  # --- §3.4: one attestation per declaration_ref, by the tool's own check ----------------

  def test_a_second_attestation_with_other_attempts_is_refused
    with_anchor do |registry, tip|
      sk = new_key
      d, ref, = declared(registry, tip, sk)
      assert_equal 'recorded', submit_attestation(registry, tip, sk, attestation_for(d, ref))[:status]
      other = attestation_for(d, ref, attempts: [built_row(1), built_row(2, m: 0)])
      assert_raises(T3R::Records::AlreadyAttested) { submit_attestation(registry, tip, sk, other) }
      assert_equal 1, attestations(registry).length
    end
  end

  # The refusal names no proof_id (precedent prov_manifest!).
  def test_the_refusal_of_a_second_attestation_names_no_proof_id
    with_anchor do |registry, tip|
      sk = new_key
      d, ref, = declared(registry, tip, sk)
      submit_attestation(registry, tip, sk, attestation_for(d, ref))
      e = assert_raises(T3R::Records::AlreadyAttested) do
        submit_attestation(registry, tip, sk, attestation_for(d, ref, attempts: [cannot_build_row(1)]))
      end
      registry.read(:proofs).each { |r| refute_includes e.message, (r[:proof_id] || r['proof_id']).to_s }
    end
  end

  # Orchestrator amendment 2026-10-20: an identical resend (same
  # submission_key) makes no second attestation, so it goes on to SubmitCore's
  # recovery_branch (36:63–71) and gets the existing proof back — the one way
  # a crashed executor learns its proof_id, since refusals never carry one.
  def test_an_identical_resend_recovers_the_existing_proof
    with_anchor do |registry, tip|
      sk = new_key
      d, ref, = declared(registry, tip, sk)
      a = attestation_for(d, ref)
      op = envelope(sk, a, tip)
      first = submit_attestation(registry, tip, sk, a, op: op)
      assert_equal 'recorded', first[:status]
      again = submit_attestation(registry, tip, sk, a, op: op)
      assert_equal ['recorded', true, first[:synoptis_proof_id]], again.values_at(:status, :recovered, :synoptis_proof_id)
      fresh_nonce = submit_attestation(registry, tip, sk, a, op: envelope(sk, a, tip))
      assert_equal [true, first[:synoptis_proof_id]], fresh_nonce.values_at(:recovered, :synoptis_proof_id)
      assert_equal first[:submission_key], fresh_nonce[:submission_key]
      assert_equal 1, attestations(registry).length
    end
  end

  def test_one_attestation_per_declaration_does_not_block_another_declaration
    with_anchor do |registry, tip|
      sk = new_key
      d1, ref1, = declared(registry, tip, sk)
      d2, ref2, = declared(registry, tip, sk, declaration('subject_ref' => 'repro://656122/C10'))
      assert_equal 'recorded', submit_attestation(registry, tip, sk, attestation_for(d1, ref1))[:status]
      assert_equal 'recorded', submit_attestation(registry, tip, sk, attestation_for(d2, ref2))[:status]
      assert_equal 2, attestations(registry).length
    end
  end

  # --- §3.4: 1 ≤ attempts ≤ attempts_max ------------------------------------------------

  def test_an_empty_attempts_list_is_refused
    with_anchor do |registry, tip|
      sk = new_key
      d, ref, = declared(registry, tip, sk)
      assert_raises(T3R::Records::AttemptsOutOfRange) { submit_attestation(registry, tip, sk, attestation_for(d, ref, attempts: [])) }
      assert_empty attestations(registry)
    end
  end

  def test_more_attempts_than_attempts_max_is_refused
    with_anchor do |registry, tip|
      sk = new_key
      d, ref, = declared(registry, tip, sk, declaration('attempts_max' => 2))
      rows = [built_row(1), built_row(2), built_row(3)]
      assert_raises(T3R::Records::AttemptsOutOfRange) { submit_attestation(registry, tip, sk, attestation_for(d, ref, attempts: rows)) }
      assert_empty attestations(registry)
    end
  end

  def test_exactly_attempts_max_rows_are_accepted
    with_anchor do |registry, tip|
      sk = new_key
      d, ref, = declared(registry, tip, sk, declaration('attempts_max' => 2))
      out = submit_attestation(registry, tip, sk, attestation_for(d, ref, attempts: [cannot_build_row(1), built_row(2)]))
      assert_equal 'recorded', out[:status]
    end
  end

  # --- §4.1: a row with ① = 作れない has no ② ③ -----------------------------------------

  def test_a_cannot_build_row_with_rerun_or_reproduce_fields_is_refused
    with_anchor do |registry, tip|
      sk = new_key
      d, ref, = declared(registry, tip, sk)
      [{ 'execution_verdict' => 'completed' }, { 'comparison_verdict' => 'mismatch' }, { 'm' => 0, 'n' => 1 },
       { 'output_fingerprints' => [] }].each do |extra|
        reset_nonces
        row = cannot_build_row(1).merge(extra)
        assert_raises(T3R::Records::FormRejected) { submit_attestation(registry, tip, sk, attestation_for(d, ref, attempts: [row])) }
      end
      assert_empty attestations(registry)
    end
  end

  def test_a_lone_cannot_build_row_is_an_attestation
    with_anchor do |registry, tip|
      sk = new_key
      d, ref, = declared(registry, tip, sk)
      out = submit_attestation(registry, tip, sk, attestation_for(d, ref, attempts: [cannot_build_row(1)]))
      assert_equal [cannot_build_row(1)], manifest_of(registry, out[:synoptis_proof_id])['attempts']
    end
  end
end
