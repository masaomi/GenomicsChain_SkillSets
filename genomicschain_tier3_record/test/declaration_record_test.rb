# frozen_string_literal: true

# Tier 3 v0.1 §9-1 — the declaration record (tier3_declaration 0.1) through
# the anchor-side library on a disposable anchor. The params are built by hand
# (t3_record_helper), so these tests judge the anchor alone: §4.1 binding fields,
# §3.3 route_ref resolution, the outputs_digest recount, the option-2 salt
# rule, §2.5 human data, §3.2 sources, proof_ttl and the claim (05 C1, C10).
require_relative 't3_record_helper'
require 'genomicschain_tier3_record/record_submit'

class DeclarationRecordTest < Minitest::Test
  include T3RecordHelpers

  def setup = reset_nonces

  def refused(klass, &blk)
    assert_raises(klass, &blk)
  end

  # --- recorded ---------------------------------------------------------------------

  def test_a_route_a_declaration_is_recorded_with_its_params_verbatim
    with_anchor do |registry, tip|
      d = declaration
      out = submit_declaration(registry, tip, new_key, d)
      assert_equal 'recorded', out[:status]
      m = manifest_of(registry, out[:synoptis_proof_id])
      assert_equal %w[tier3_declaration 0.1 gc_tier3_record_submit],
                   m.values_at('record_type', 'record_version', 'mcp_tool_name')
      d.each { |k, v| assert_equal v, m[k], "field #{k} is recorded as signed" }
      assert_equal M.canonical_json_sha256(d), m['declaration_digest']
      assert_match ISO, m['recorded_at']
      assert_equal({ 'declaration_digest' => m['declaration_digest'], 'recorded_at' => m['recorded_at'] },
                   out[:declaration_ref])
    end
  end

  # 05 C10 (10:140–142 shape), 05 C1 and §3.4: claim, lifetime, idempotency key.
  def test_claim_proof_ttl_and_idempotency_key
    with_anchor do |registry, tip|
      d = declaration
      out = submit_declaration(registry, tip, new_key, d)
      assert_equal "tier3-declaration:0.1:#{M.canonical_json_sha256(d)}:#{out[:submission_key]}", out[:claim]
      FORBIDDEN.each { |w| refute_includes out[:claim], w }
      envelope = registry.find_proof(out[:synoptis_proof_id])
      assert_equal PROOF_TTL, envelope.ttl
      refute envelope.expired?
      assert_equal Digest::SHA256.hexdigest(out[:submission_key]), out[:idempotency_key]
    end
  end

  def test_a_resend_recovers_the_same_record_and_declaration_ref
    with_anchor do |registry, tip|
      sk = new_key
      d = declaration
      op = envelope(sk, d, tip)
      first = submit_declaration(registry, tip, sk, d, op: op)
      again = submit_declaration(registry, tip, sk, d, op: op)
      assert_equal [false, true], [first[:recovered], again[:recovered]]
      assert_equal first[:synoptis_proof_id], again[:synoptis_proof_id]
      assert_equal first[:declaration_ref], again[:declaration_ref]
      assert_equal 1, manifests_of_type(registry, 'tier3_declaration').length
    end
  end

  # Review r2 C2 (fix group G2): a foreign copy that carries the real record's
  # submission_key (and a back-dated T_d) is never what a resend returns.
  def test_a_resend_recovers_the_anchor_written_declaration_not_a_planted_copy
    with_anchor do |registry, tip|
      sk = new_key
      d = declaration
      op = envelope(sk, d, tip)
      first = submit_declaration(registry, tip, sk, d, op: op)
      real = manifest_of(registry, first[:synoptis_proof_id])
      foreign_writers(sk).each { |w| plant_copy(registry, real, w, 'recorded_at' => '2001-01-01T00:00:00Z') }
      again = submit_declaration(registry, tip, sk, d, op: op)
      assert_equal ['recorded', true, first[:synoptis_proof_id]], again.values_at(:status, :recovered, :synoptis_proof_id)
      assert_equal first[:declaration_ref], again[:declaration_ref]
    end
  end

  # Foreign copies planted under a submission_key before its first submit do
  # not block it (pre-flight r3 §2.2 (b); orchestrator 2026-10-21): SubmitCore
  # sees only anchor-written Tier 3 records, so the real declaration is
  # recorded (recovered false) with its own proof and T_d, nothing in the
  # response comes from a planted copy, and an identical resend then recovers
  # the real one. The submission_key is learnt on one anchor and planted on a
  # fresh one (it depends on the params and the pubkey only).
  def test_planted_copies_under_its_submission_key_do_not_stop_the_real_declaration
    sk = new_key
    d = declaration
    learnt = nil
    with_anchor { |registry, tip| learnt = manifest_of(registry, submit_declaration(registry, tip, sk, d)[:synoptis_proof_id]) }
    with_anchor do |registry, tip|
      planted = foreign_writers(sk).map { |w| plant_copy(registry, learnt, w, 'recorded_at' => '2001-01-01T00:00:00Z') }
      op = envelope(sk, d, tip)
      out = submit_declaration(registry, tip, sk, d, op: op)
      assert_equal ['recorded', false], out.values_at(:status, :recovered)
      refute_includes planted, out[:synoptis_proof_id]
      m = manifest_of(registry, out[:synoptis_proof_id])
      assert_equal TOOL, m['mcp_tool_name']
      assert_equal({ 'declaration_digest' => m['declaration_digest'], 'recorded_at' => m['recorded_at'] }, out[:declaration_ref])
      refute_equal '2001-01-01T00:00:00Z', out[:declaration_ref]['recorded_at']
      planted.each { |p| refute_includes out.inspect, p }
      again = submit_declaration(registry, tip, sk, d, op: op)
      assert_equal [true, out[:synoptis_proof_id], out[:declaration_ref]],
                   again.values_at(:recovered, :synoptis_proof_id, :declaration_ref)
    end
  end

  # Review r3 D2 (operator 2026-10-21, question 8 「偽の成功を返さず、根は別に」; design
  # §3.4): a proof planted BEFORE the first submit, under the anchor's attester
  # with the victim's real subject_ref and claim (learnt on another anchor:
  # both depend on the params and the key only), makes Synoptis answer the
  # store with 'existing'. The submission must not report success with that
  # proof: a recording failure naming no proof_id, nothing new recorded, and no
  # declaration_ref taken from a record that is not anchor-written.
  def test_a_proof_planted_with_the_real_claim_before_the_first_submit_is_not_reported_as_success
    sk = new_key
    d = declaration
    learnt = nil
    with_anchor do |registry, tip|
      out = submit_declaration(registry, tip, sk, d)
      learnt = [manifest_of(registry, out[:synoptis_proof_id]), out[:claim]]
    end
    with_anchor do |registry, tip|
      manifest, claim = learnt
      planted = plant(registry, manifest.merge('recorded_at' => '2001-01-01T00:00:00Z'), submitter_pubkey: nil,
                                claim: claim, subject_ref: d['subject_ref'])
      result = begin
        submit_declaration(registry, tip, sk, d)
      rescue GC::SubmitCore::SubmitError => e
        e
      end
      if result.is_a?(Exception)
        refute_includes result.message, planted
      else
        assert_match(/fail/, result[:status].to_s, 'a recording failure, not a success')
        refute_includes result.inspect, planted
        assert_nil result[:declaration_ref], 'no declaration_ref from a record that is not anchor-written'
      end
      assert_equal 1, manifests_of_type(registry, 'tier3_declaration').length, 'nothing new recorded'
    end
  end

  # §3.3, §8: route A's route_ref is carried and signed, never resolved.
  def test_route_a_route_ref_is_carried_without_resolution
    with_anchor do |registry, tip|
      d = declaration(route_ref: 'tier1:whatever-the-executor-names')
      out = submit_declaration(registry, tip, new_key, d)
      m = manifest_of(registry, out[:synoptis_proof_id])
      assert_equal 'tier1:whatever-the-executor-names', m['route_ref']
      assert_equal 'not_checked', m.dig('backing', 'route_ref')
      refute m['backing'].key?('outputs_digest')
      assert_equal 'gc-backing-0.1', m.dig('backing', 'vocabulary')
      assert_equal 'anchor_observed', m.dig('backing', 'recorded_at')
      assert_equal 'customer_signed', m.dig('backing', 'declaration')
    end
  end

  # --- required fields (§4.1: every binding field is required) -------------------------

  def test_every_binding_field_is_required
    with_anchor do |registry, tip|
      BINDING.each do |field|
        reset_nonces
        e = refused(T3R::Records::FormRejected) { submit_declaration(registry, tip, new_key, declaration.except(field)) }
        assert_includes e.message, field
      end
      assert_empty manifests_of_type(registry, 'tier3_declaration')
    end
  end

  # Brief, readings: no defaults for expiry and attempts_max.
  def test_expiry_and_attempts_max_are_required
    with_anchor do |registry, tip|
      %w[expires_at attempts_max].each do |field|
        e = refused(T3R::Records::FormRejected) { submit_declaration(registry, tip, new_key, declaration.except(field)) }
        assert_includes e.message, field
      end
      refused(T3R::Records::FormRejected) { submit_declaration(registry, tip, new_key, declaration('attempts_max' => 0)) }
      assert_empty manifests_of_type(registry, 'tier3_declaration')
    end
  end

  def test_commitment_is_required_when_salted
    with_anchor do |registry, tip|
      d = declaration(form: 'salted', key: C.generate_key).except('commitment')
      e = refused(T3R::Records::FormRejected) { submit_declaration(registry, tip, new_key, d) }
      assert_includes e.message, 'commitment'
    end
  end

  def test_commitment_is_refused_when_plain
    with_anchor do |registry, tip|
      d = declaration.merge('commitment' => C.declaration(C.generate_key))
      e = refused(T3R::Records::FormRejected) { submit_declaration(registry, tip, new_key, d) }
      assert_includes e.message, 'commitment'
      assert_empty manifests_of_type(registry, 'tier3_declaration')
    end
  end

  def test_a_salted_declaration_with_its_commitment_is_recorded
    with_anchor do |registry, tip|
      key = C.generate_key
      out = submit_declaration(registry, tip, new_key, declaration(form: 'salted', key: key))
      m = manifest_of(registry, out[:synoptis_proof_id])
      assert_equal({ 'rule' => 'gc-commitment-0.1', 'key_id' => C.key_id(key) }, m['commitment'])
      assert_equal 'salted', m['fingerprint_form']
    end
  end

  # --- the house gates before any other work (orchestrator default 2026-10-20;
  # manifest.rb dos_gate! / restricted_subset!, the verdict_spec/tier3.rb:151–158 pattern) ----

  DEEP = 20.times.reduce('x') { |acc, _| { 'n' => acc } }

  def test_the_dos_gate_refuses_an_oversized_or_over_deep_declaration
    with_anchor do |registry, tip|
      [declaration('validated_by' => 'x' * 70_000), declaration('validated_by' => DEEP)].each do |d|
        reset_nonces
        assert_raises(KairosMcp::Manifest::DoSGateTripped) { submit_declaration(registry, tip, new_key, d) }
      end
      assert_empty registry.read(:proofs)
    end
  end

  def test_the_restricted_subset_refuses_a_declaration_value_outside_it
    with_anchor do |registry, tip|
      [declaration('validated_by' => "human:executor\u2028x"), declaration('validated_by' => "x\u2029"),
       declaration('donnée' => 'x')].each do |d|
        reset_nonces
        assert_raises(KairosMcp::Manifest::RestrictedSubsetViolation) { submit_declaration(registry, tip, new_key, d) }
      end
      assert_empty registry.read(:proofs)
    end
  end

  # --- target paths have a form (design §4.4 「欄の形」; pre-flight r2, orchestrator
  # default 2026-10-21): relative, non-empty, no leading ~, no .. segment ------------------

  BAD_PATHS = ['', '/etc/passwd', '~/secret.txt', '../outside.txt', 'res/../../outside.txt'].freeze

  def test_a_route_a_target_path_outside_the_output_location_is_refused_on_form
    with_anchor do |registry, tip|
      BAD_PATHS.each do |bad|
        reset_nonces
        d = declaration(targets: route_a_targets(path: bad))
        refused(T3R::Records::FormRejected) { submit_declaration(registry, tip, new_key, d) }
      end
      assert_empty manifests_of_type(registry, 'tier3_declaration')
    end
  end

  def test_a_route_b_path_entry_outside_the_output_location_is_refused_on_form
    with_anchor do |registry, tip|
      prov_id = prov_record(registry, tip)
      BAD_PATHS.each do |bad|
        reset_nonces
        d = declaration(route: 'B', route_ref: GC::ProvProofRef.for(prov_id),
                        targets: route_b_targets(paths: default_paths(v03_rows).map { |p| p && bad }))
        refused(T3R::Records::FormRejected) { submit_declaration(registry, tip, new_key, d, route_proof_id: prov_id) }
      end
      assert_empty manifests_of_type(registry, 'tier3_declaration')
    end
  end

  # Review r2 G5 (3): NUL and other control characters in a target path.
  CONTROL_PATHS = ["out\u0000.txt", "out\n.txt", "out\u001b.txt", "out\u007f.txt", "out\u0085.txt", "out\u009b.txt"].freeze # C0, DEL, C1 (review r3)

  def test_a_target_path_with_a_control_character_is_refused_on_form
    with_anchor do |registry, tip|
      prov_id = prov_record(registry, tip)
      CONTROL_PATHS.each do |bad|
        reset_nonces
        refused(T3R::Records::FormRejected) do
          submit_declaration(registry, tip, new_key, declaration(targets: route_a_targets(path: bad)))
        end
        reset_nonces
        d = declaration(route: 'B', route_ref: GC::ProvProofRef.for(prov_id),
                        targets: route_b_targets(paths: default_paths(v03_rows).map { |p| p && bad }))
        refused(T3R::Records::FormRejected) { submit_declaration(registry, tip, new_key, d, route_proof_id: prov_id) }
      end
      assert_empty manifests_of_type(registry, 'tier3_declaration')
    end
  end

  # Review r2 G5 (1): the schema patterns are whole-value (Ruby ^/$ are line
  # anchors, so "<hex>\n/home/alice/x" used to pass).
  def test_a_digest_or_a_time_with_a_trailing_line_is_refused_on_form
    with_anchor do |registry, tip|
      tail = "\n/home/alice/x"
      [declaration('inputs_commitment' => hex('inputs') + tail),
       declaration('build_plan_digest' => hex('plan') + tail),
       declaration('job_identity' => { 'rule' => 'gc-job-identity-0.3', 'digest' => hex('job') + tail }),
       declaration(targets: route_a_targets(value: sha('hi') + tail)),
       declaration('expires_at' => "2026-11-19T00:00:00Z#{tail}")].each_with_index do |d, i|
        reset_nonces
        refused(T3R::Records::FormRejected) { submit_declaration(registry, tip, new_key, d) }
        assert_empty manifests_of_type(registry, 'tier3_declaration'), "case #{i}"
      end
    end
  end

  # --- §3.2 sources, §2.5 human data -----------------------------------------------------

  def test_llm_extracted_and_operator_supplied_sources_are_refused
    with_anchor do |registry, tip|
      %w[llm_extracted operator_supplied].each do |source|
        reset_nonces
        refused(T3R::Records::SourceRefused) { submit_declaration(registry, tip, new_key, declaration('source' => source)) }
      end
      assert_empty manifests_of_type(registry, 'tier3_declaration')
    end
  end

  def test_human_data_is_refused_while_the_anchor_setting_is_off
    with_anchor do |registry, tip|
      [{}, { 'genomicschain' => { 'tier3' => { 'human_data_records' => false } } }].each do |config|
        reset_nonces
        refused(T3R::Records::HumanDataRefused) do
          submit_declaration(registry, tip, new_key, declaration('data_class' => 'human'), config: config)
        end
      end
      assert_empty manifests_of_type(registry, 'tier3_declaration')
    end
  end

  def test_human_data_is_accepted_once_the_anchor_enables_it
    with_anchor do |registry, tip|
      on = { 'genomicschain' => { 'tier3' => { 'human_data_records' => true } } }
      out = submit_declaration(registry, tip, new_key, declaration('data_class' => 'human'), config: on)
      assert_equal 'recorded', out[:status]
    end
  end

  # --- §3.3 route B: route_ref resolution -------------------------------------------------

  def route_b(prov_id, **kw) = declaration(route: 'B', route_ref: GC::ProvProofRef.for(prov_id), **kw)

  def test_route_b_resolves_against_the_prov_record_and_recounts_its_outputs_digest
    with_anchor do |registry, tip|
      prov_id = prov_record(registry, tip)
      d = route_b(prov_id)
      out = submit_declaration(registry, tip, new_key, d, route_proof_id: prov_id)
      assert_equal 'recorded', out[:status]
      m = manifest_of(registry, out[:synoptis_proof_id])
      assert_equal v03_signed['outputs_digest'], m.dig('targets', 'outputs_digest')
      assert_equal v03_rows, m.dig('targets', 'rows')
      assert_equal GC::ProvProofRef.for(prov_id), m['route_ref']
      assert_equal 'procedure_checked', m.dig('backing', 'route_ref')
      assert_equal 'procedure_checked', m.dig('backing', 'outputs_digest')
    end
  end

  def test_route_b_without_its_proof_id_is_refused
    with_anchor do |registry, tip|
      prov_id = prov_record(registry, tip)
      refused(T3R::Records::RouteRefUnresolved) { submit_declaration(registry, tip, new_key, route_b(prov_id)) }
      assert_empty manifests_of_type(registry, 'tier3_declaration')
    end
  end

  def test_route_b_route_ref_must_be_the_sha256_of_the_proof_id
    with_anchor do |registry, tip|
      prov_id = prov_record(registry, tip)
      d = declaration(route: 'B', route_ref: GC::ProvProofRef.for('some-other-proof'))
      e = refused(T3R::Records::RouteRefUnresolved) { submit_declaration(registry, tip, new_key, d, route_proof_id: prov_id) }
      refute_includes e.message, prov_id
    end
  end

  def test_route_b_unknown_proof_is_refused_without_naming_it
    with_anchor do |registry, tip|
      nowhere = 'attest_no_such_proof_0001'
      e = refused(T3R::Records::RouteRefUnresolved) do
        submit_declaration(registry, tip, new_key, route_b(nowhere), route_proof_id: nowhere)
      end
      refute_includes e.message, nowhere
      assert_empty manifests_of_type(registry, 'tier3_declaration')
    end
  end

  def test_route_b_revoked_record_is_refused_without_naming_it
    with_anchor do |registry, tip|
      prov_id = prov_record(registry, tip)
      registry.store_revocation(proof_id: prov_id, reason: 'test', revoker_id: 'ed25519:stub')
      e = refused(T3R::Records::RouteRefUnresolved) do
        submit_declaration(registry, tip, new_key, route_b(prov_id), route_proof_id: prov_id)
      end
      refute_includes e.message, prov_id
    end
  end

  # A record carrying the same bundle_digest, but not a provenance record.
  def test_route_b_record_of_another_type_is_refused_without_naming_it
    with_anchor do |registry, tip|
      other = plant_as_prov_writer(registry, v03_signed.merge('record_type' => 'prov_reachability', 'record_version' => '0.1'))
      e = refused(T3R::Records::RouteRefUnresolved) do
        submit_declaration(registry, tip, new_key, route_b(other), route_proof_id: other)
      end
      refute_includes e.message, other
    end
  end

  # Rows intact, so only the bundle named differs from the record's.
  def test_route_b_record_of_another_bundle_is_refused_without_naming_it
    with_anchor do |registry, tip|
      prov_id = prov_record(registry, tip)
      d = route_b(prov_id, targets: route_b_targets(bundle_digest: hex('another bundle')))
      e = refused(T3R::Records::RouteRefUnresolved) do
        submit_declaration(registry, tip, new_key, d, route_proof_id: prov_id)
      end
      refute_includes e.message, prov_id
    end
  end

  def test_the_route_proof_id_is_never_recorded
    with_anchor do |registry, tip|
      prov_id = prov_record(registry, tip)
      out = submit_declaration(registry, tip, new_key, route_b(prov_id), route_proof_id: prov_id)
      refute_includes evidence_text(registry, out[:synoptis_proof_id]), prov_id
    end
  end

  # --- the outputs_digest recount (operator, question 7 (1)) -----------------------------

  def test_a_dropped_row_is_refused
    with_anchor do |registry, tip|
      prov_id = prov_record(registry, tip)
      rows = v03_rows.reject { |_, algo, _| algo == 'sha1' }
      d = route_b(prov_id, targets: route_b_targets(rows: rows))
      e = refused(T3R::Records::OutputsDigestMismatch) do
        submit_declaration(registry, tip, new_key, d, route_proof_id: prov_id)
      end
      refute_includes e.message, prov_id
      assert_empty manifests_of_type(registry, 'tier3_declaration')
    end
  end

  def test_an_altered_row_is_refused
    with_anchor do |registry, tip|
      prov_id = prov_record(registry, tip)
      rows = v03_rows.map { |n, a, v| a == 'sha256' ? [n, a, sha('something else')] : [n, a, v] }
      d = route_b(prov_id, targets: route_b_targets(rows: rows))
      refused(T3R::Records::OutputsDigestMismatch) { submit_declaration(registry, tip, new_key, d, route_proof_id: prov_id) }
      assert_empty manifests_of_type(registry, 'tier3_declaration')
    end
  end

  def test_a_declared_outputs_digest_other_than_the_recount_is_refused
    with_anchor do |registry, tip|
      prov_id = prov_record(registry, tip)
      d = route_b(prov_id, targets: route_b_targets(outputs_digest: hex('not the recount')))
      refused(T3R::Records::OutputsDigestMismatch) { submit_declaration(registry, tip, new_key, d, route_proof_id: prov_id) }
    end
  end

  # --- option 2 must be salted (operator, question 3) -------------------------------------

  def option2(registry, key)
    rows = [['out.txt', 'hmac_sha256', C.commit(key, 'hi')]]
    m = option2_manifest(rows)
    prov_id = plant_as_prov_writer(registry, m)
    targets = route_b_targets(rows: rows, bundle_digest: m['bundle_digest'])
    [prov_id, targets]
  end

  # --- the Tier-2.5 record must be gc_prov_submit's (pre-flight r2 §2.1, orchestrator default
  # 2026-10-21; the F2 writer rule applied to the record route B resolves) ---------------------

  # The pre-flight's case: an option-2-shaped record (hmac rows, outputs_digest
  # their recount) with NO 0.2 receipt, written by another writer, and a plain
  # declaration over it. Without the writer rule it would pass as "not option 2".
  def test_a_prov_record_from_another_writer_does_not_resolve_route_ref
    with_anchor do |registry, tip|
      key = C.generate_key
      rows = [['out.txt', 'hmac_sha256', C.commit(key, 'hi')]]
      shaped = option2_manifest(rows).merge('zk_receipts' => [])
      writer = new_key
      [[shaped.merge('operator' => { 'mode' => 'signed', 'pubkey' => pubkey(writer) }), nil],
       [shaped.merge('operator' => { 'mode' => 'signed', 'pubkey' => pubkey(writer) }), pubkey(new_key)],
       [shaped.merge('mcp_tool_name' => 'gc_something_else', 'operator' => { 'mode' => 'signed', 'pubkey' => pubkey(writer) }),
        pubkey(writer)]].each_with_index do |(manifest, submitter), i|
        reset_nonces
        prov_id = plant(registry, manifest, submitter_pubkey: submitter)
        d = route_b(prov_id, targets: route_b_targets(rows: rows, bundle_digest: shaped['bundle_digest']),
                             comparator: { 'id' => 'exact_commitment', 'version' => '0.1.0' })
        e = refused(T3R::Records::RouteRefUnresolved) { submit_declaration(registry, tip, new_key, d, route_proof_id: prov_id) }
        refute_includes e.message, prov_id, "writer #{i}"
      end
      assert_empty manifests_of_type(registry, 'tier3_declaration')
    end
  end

  # The same shape written as gc_prov_submit writes is resolved (so the refusal
  # above is the writer rule, not the shape). Salted, so nothing here depends
  # on whether a plain declaration over hmac rows is acceptable.
  def test_the_same_record_shape_from_gc_prov_submit_resolves
    with_anchor do |registry, tip|
      key = C.generate_key
      rows = [['out.txt', 'hmac_sha256', C.commit(key, 'hi')]]
      shaped = option2_manifest(rows).merge('zk_receipts' => [])
      prov_id = plant_as_prov_writer(registry, shaped)
      d = route_b(prov_id, targets: route_b_targets(rows: rows, bundle_digest: shaped['bundle_digest']), form: 'salted',
                           key: key, comparator: { 'id' => 'exact_commitment', 'version' => '0.1.0' })
      assert_equal 'recorded', submit_declaration(registry, tip, new_key, d, route_proof_id: prov_id)[:status]
    end
  end

  def test_an_unsalted_declaration_over_an_option_2_record_is_refused
    with_anchor do |registry, tip|
      key = C.generate_key
      prov_id, targets = option2(registry, key)
      d = route_b(prov_id, targets: targets, comparator: { 'id' => 'exact_commitment', 'version' => '0.1.0' })
      e = refused(T3R::Records::SaltRequired) { submit_declaration(registry, tip, new_key, d, route_proof_id: prov_id) }
      refute_includes e.message, prov_id
      assert_empty manifests_of_type(registry, 'tier3_declaration')
    end
  end

  def test_a_salted_declaration_over_an_option_2_record_is_recorded
    with_anchor do |registry, tip|
      key = C.generate_key
      prov_id, targets = option2(registry, key)
      d = route_b(prov_id, targets: targets, form: 'salted', key: key,
                           comparator: { 'id' => 'exact_commitment', 'version' => '0.1.0' })
      out = submit_declaration(registry, tip, new_key, d, route_proof_id: prov_id)
      assert_equal 'recorded', out[:status]
      m = manifest_of(registry, out[:synoptis_proof_id])
      assert_equal targets['rows'], m.dig('targets', 'rows'), 'option-2 rows stay as the bundle has them'
    end
  end

  # The check reads the record's journal_convention, not the rows' algorithm.
  def test_an_unsalted_declaration_over_a_record_without_option_2_is_recorded
    with_anchor do |registry, tip|
      prov_id = prov_record(registry, tip)
      assert_empty manifest_of(registry, prov_id)['zk_receipts']
      out = submit_declaration(registry, tip, new_key, route_b(prov_id), route_proof_id: prov_id)
      assert_equal 'recorded', out[:status]
    end
  end
end
