# frozen_string_literal: true

# Design v0.1.14 §6.2: the resource reader, its grade (gc-resources-0.1) and
# the nine fields record_version 0.4 signs. Pure: bundles are built in memory
# with the writer and read back through Identity.derive, the function the
# anchor runs.
#
# Run: ruby -Ilib -I../genomicschain_core/lib -I../genomicschain_tier2/lib test/resources_test.rb
require 'minitest/autorun'
require 'json'

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'genomicschain_prov'

class ResourcesTest < Minitest::Test
  W = GenomicsChainProv::Writer
  R = GenomicsChainProv::Resources
  Identity = GenomicsChainProv::Identity

  MACHINE = { 'cpu_model' => 'AMD EPYC 7763', 'logical_cores' => 64, 'memory_total_bytes' => 512 * 1024**3,
              'gpu_probe' => [{ 'tool' => 'nvidia-smi', 'result' => 'ok' }],
              'gpus' => [{ 'vendor' => 'nvidia', 'model' => 'NVIDIA A100-SXM4-80GB' }] * 2,
              'source' => 'probe' }.freeze
  BOTH = { 'requested' => { 'cpus' => 4, 'memory_bytes' => 8 * 1024**3 },
           'observed' => { 'peak_memory_bytes' => 5 * 1024**3, 'realtime_seconds' => 412.5 } }.freeze

  def plan(stages: 2)
    W.normalise_plan(
      'name' => 'resources-demo', 'script' => 'run.sh',
      'runtime' => { 'engine' => 'sh', 'version' => '5.2.21', 'uri' => '/bin/sh' },
      'stages' => (1..stages).map do |i|
        { 'name' => "s#{i}", 'inputs' => ["in#{i}.txt"], 'outputs' => ["out#{i}.txt"],
          'tools' => [{ 'name' => 'tool', 'version' => '1.0.0', 'uri' => "tools/t#{i}.sh" }] }
      end
    )
  end

  # A bundle text with the given resources object in the writer's block.
  def bundle(resources, stages = 2)
    JSON.generate(W.build(plan(stages: stages), object_id: 'urn:uuid:00000000-0000-4000-8000-0000000000aa',
                                                created: '2026-10-17T00:00:00Z', resources: resources))
  end

  def entry(step, part = BOTH, source = 'gc_resources_input')
    { 'step_number' => step, 'source' => source }.merge(part)
  end

  def signed(resources, stages = 2) = Identity.derive(bundle(resources, stages))['signed']
  def grade(resources, stages = 2) = signed(resources, stages)['grade_resources']

  # --- the levels ----------------------------------------------------------

  def test_the_four_levels_rise_as_information_is_added
    assert_equal 'absent', grade(nil)
    assert_equal 'partial', grade('machine' => MACHINE)
    assert_equal 'partial', grade('steps' => [entry(1)]), 'one stage of two'
    only_observed = { 'observed' => BOTH['observed'] }
    only_requested = { 'requested' => BOTH['requested'] }
    assert_equal 'steps', grade('steps' => [entry(1, only_observed), entry(2, only_requested)]),
                 'either kind per stage is enough for steps'
    assert_equal 'steps', grade('steps' => [entry(1), entry(2)]), 'both on every stage, but no machine'
    assert_equal 'full', grade('machine' => MACHINE, 'steps' => [entry(1), entry(2)])
  end

  def test_full_needs_the_gpu_answer_even_when_it_is_none
    no_gpus = MACHINE.reject { |k, _| k == 'gpus' }
    assert_equal 'steps', grade('machine' => no_gpus, 'steps' => [entry(1), entry(2)])
    assert_equal 'full', grade('machine' => no_gpus.merge('gpus' => []), 'steps' => [entry(1), entry(2)])
  end

  # (iv): with no stage, "every stage" would hold without looking.
  def test_a_bundle_with_no_stage_reaches_partial_at_most
    assert_equal 'partial', R.grade(MACHINE, {}, 0)
    assert_equal 'absent', R.grade(nil, {}, 0)
  end

  # (iii): the seven grades and the counts are the predicate's, untouched by
  # what the resources say.
  def test_resources_never_move_the_seven_grades_or_the_counts
    base = signed(nil).slice(*Identity::BASE_SIGNED_FIELDS)
    full = signed('machine' => MACHINE, 'steps' => [entry(1), entry(2)])
    keep = Identity::BASE_SIGNED_FIELDS - %w[subject_ref bundle_digest]
    assert_equal base.slice(*keep), full.slice(*keep)
    assert_equal 'full', full['grade_resources']
  end

  # --- reading -----------------------------------------------------------------

  def test_several_values_for_one_stage_take_the_largest_job_and_sum_the_bytes
    a = entry(1, 'requested' => { 'cpus' => 2, 'memory_bytes' => 100 },
                 'observed' => { 'peak_memory_bytes' => 50, 'realtime_seconds' => 9, 'read_bytes' => 10 })
    b = entry(1, 'requested' => { 'cpus' => 8, 'memory_bytes' => 10 },
                 'observed' => { 'peak_memory_bytes' => 70, 'realtime_seconds' => 3, 'read_bytes' => 5 })
    read = Identity.derive(bundle('steps' => [a, b]))['resources']['steps'][1]
    assert_equal({ 'cpus' => 8, 'memory_bytes' => 100 }, read['requested'])
    assert_equal({ 'peak_memory_bytes' => 70, 'realtime_seconds' => 9, 'read_bytes' => 15 }, read['observed'])
  end

  def test_a_value_that_is_not_a_non_negative_number_is_not_there
    bad = entry(1, 'requested' => { 'cpus' => '4', 'memory_bytes' => -1 },
                   'observed' => { 'peak_memory_bytes' => true, 'realtime_seconds' => nil })
    s = signed('steps' => [bad])
    assert_equal 'absent', s['grade_resources']
    assert_nil s['resources_sources']
  end

  def test_an_entry_with_no_known_source_or_no_step_is_not_read
    s = signed('steps' => [entry(1, BOTH, 'my_script'), entry(99), BOTH.merge('source' => 'plan')])
    assert_equal 'absent', s['grade_resources']
  end

  # Never refused: a 0.3-issuable bundle stays issuable.
  def test_malformed_resources_read_as_absent_and_are_never_refused
    [[], 'x', { 'machine' => [] }, { 'steps' => {} }, { 'steps' => [1, 'x', nil] }].each do |junk|
      s = signed(junk)
      assert_equal 'absent', s['grade_resources'], junk.inspect
      assert_nil s['machine_source']
    end
  end

  def test_two_blocks_stating_different_machines_state_none
    text = JSON.parse(bundle('machine' => MACHINE, 'steps' => [entry(1), entry(2)]))
    other = { 'genomicschain_extension' => { 'resources' => { 'machine' => MACHINE.merge('logical_cores' => 8) } } }
    text['extension_domain'] << other
    s = Identity.derive(JSON.generate(text))
    assert_nil s['signed']['machine_source']
    assert_equal 'steps', s['signed']['grade_resources'], 'adding a block can lower the grade (§6.2 (2), r1)'
    assert_includes s['resources']['notes'].join, 'different machines'
  end

  def test_two_blocks_disagreeing_on_a_stage_field_drop_that_field_only
    text = JSON.parse(bundle('steps' => [entry(1), entry(2)]))
    other = entry(1, 'requested' => { 'cpus' => 16 })
    text['extension_domain'] << { 'genomicschain_extension' => { 'resources' => { 'steps' => [other] } } }
    read = Identity.derive(JSON.generate(text))['resources']['steps'][1]
    refute read['requested'].key?('cpus')
    assert_equal BOTH['requested']['memory_bytes'], read['requested']['memory_bytes']
  end

  def test_a_machine_without_a_source_is_read_as_stated_by_hand
    assert_equal 'plan', signed('machine' => MACHINE.reject { |k, _| k == 'source' })['machine_source']
    assert_equal 'plan', signed('machine' => MACHINE.merge('source' => 'trust me'))['machine_source']
  end

  # --- the GPU fields -------------------------------------------------------------

  def test_looked_for_and_none_is_not_the_same_as_not_looked_for
    none = signed('machine' => MACHINE.merge('gpus' => []))
    assert_equal 0, none['gpus_total']
    assert_equal [], none['gpu_models']
    assert_equal ['nvidia'], none['gpu_vendors_probed']

    unasked = signed('machine' => MACHINE.reject { |k, _| %w[gpus gpu_probe].include?(k) })
    assert_nil unasked['gpus_total']
    assert_nil unasked['gpu_models']
    assert_nil unasked['gpu_vendors_probed']
  end

  def test_the_vendors_probed_come_from_the_probe_name_not_the_bundle
    probes = [{ 'tool' => 'system_profiler', 'result' => 'ok' }, { 'tool' => 'rocm-smi', 'result' => 'not_found' },
              { 'tool' => 'my_probe', 'result' => 'ok', 'vendors' => ['nvidia'] }]
    assert_equal %w[amd apple intel], signed('machine' => MACHINE.merge('gpu_probe' => probes))['gpu_vendors_probed']
  end

  def test_gpus_are_grouped_by_vendor_and_model
    gpus = [{ 'vendor' => 'NVIDIA', 'model' => 'NVIDIA H100 80GB HBM3' }] * 3 +
           [{ 'vendor' => 'nvidia', 'model' => 'NVIDIA A100-SXM4-80GB' }]
    s = signed('machine' => MACHINE.merge('gpus' => gpus))
    assert_equal 4, s['gpus_total']
    assert_equal [{ 'vendor' => 'nvidia', 'model' => 'NVIDIA A100-SXM4-80GB', 'count' => 1 },
                  { 'vendor' => 'nvidia', 'model' => 'NVIDIA H100 80GB HBM3', 'count' => 3 }], s['gpu_models']
  end

  # (vi) and D5 (operator, 2026-10-17): nothing that could name a machine
  # reaches the record. Each is still counted in gpus_total.
  def test_a_model_that_could_identify_a_machine_is_left_out_and_still_counted
    leaking = ['SN-Z9Y8X7W6V5U4', 'gpu17.cluster.uzh.ch', 'node3.local', '10.0.0.17', '00-1A-2B-3C-4D-5E',
               'GPU-6f1c2d3e-4b5a-6789-0abc-def012345678', 'A100 0x1a2b3c4d5e6f7a', 'Tesla V100 <serial>',
               'x' * 129]
    gpus = leaking.map { |m| { 'vendor' => 'nvidia', 'model' => m } } +
           [{ 'vendor' => 'acme', 'model' => 'Turbo 9000' }, { 'vendor' => 'nvidia', 'model' => 'NVIDIA GeForce RTX 4090' }]
    s = signed('machine' => MACHINE.merge('gpus' => gpus))
    assert_equal leaking.length + 2, s['gpus_total']
    assert_equal [{ 'vendor' => 'nvidia', 'model' => 'NVIDIA GeForce RTX 4090', 'count' => 1 }], s['gpu_models']
  end

  def test_ordinary_model_names_pass_the_filter
    ['NVIDIA A100-SXM4-80GB', 'Tesla V100-PCIE-32GB', 'AMD Instinct MI250X', 'Apple M2 Max',
     'Intel Iris Plus Graphics 655', 'Radeon Pro 5500M', 'NVIDIA RTX A6000', 'NVIDIA GH200 480GB',
     'NVIDIA A100-SXM4-40GB MIG 1g.5gb', 'AMD Instinct MI250X/MI250', 'Radeon RX 6800/6800 XT'].each do |m|
      assert R.publishable_model?(m), m
    end
  end

  def test_at_most_sixteen_models_and_sixty_four_of_one
    many = (1..20).map { |i| { 'vendor' => 'nvidia', 'model' => "Model #{i}" } }
    assert_equal 16, signed('machine' => MACHINE.merge('gpus' => many))['gpu_models'].length
    lots = [{ 'vendor' => 'nvidia', 'model' => 'NVIDIA H100' }] * 65
    s = signed('machine' => MACHINE.merge('gpus' => lots))
    assert_equal 65, s['gpus_total']
    assert_equal [], s['gpu_models']
  end

  # --- implementation review r1: conditions the suite did not pin -------------------

  REQ = { 'requested' => BOTH['requested'] }.freeze
  OBS = { 'observed' => BOTH['observed'] }.freeze

  def test_each_half_of_a_pair_is_needed
    only_cpus = { 'requested' => { 'cpus' => 4 } }
    only_peak = { 'observed' => { 'peak_memory_bytes' => 10 } }
    s = signed({ 'steps' => [entry(1, only_cpus), entry(2, only_peak)] })
    assert_equal 'partial', s['grade_resources']
    assert_equal [0, 0], s.values_at('stages_with_requested_resources', 'stages_with_observed_resources')
  end

  def test_full_needs_both_kinds_on_every_stage
    assert_equal 'steps', grade({ 'machine' => MACHINE, 'steps' => [entry(1, OBS), entry(2, OBS)] }),
                 'observed everywhere and a full machine is still steps'
    assert_equal 'steps', grade({ 'machine' => MACHINE, 'steps' => [entry(1), entry(2, OBS)] })
  end

  def test_full_needs_the_machine_cpu_and_memory_not_only_the_gpus
    %w[cpu_model logical_cores memory_total_bytes].each do |k|
      assert_equal 'steps', grade({ 'machine' => MACHINE.reject { |key, _| key == k }, 'steps' => [entry(1), entry(2)] }), k
    end
  end

  def test_a_probe_that_did_not_answer_names_no_vendor
    failed = MACHINE.merge('gpu_probe' => [{ 'tool' => 'nvidia-smi', 'result' => 'failed' }], 'gpus' => [])
    assert_nil signed({ 'machine' => failed })['gpu_vendors_probed']
  end

  def test_vendors_probed_only_beside_a_gpu_list
    no_list = MACHINE.reject { |k, _| k == 'gpus' }
    s = signed({ 'machine' => no_list })
    assert_nil s['gpus_total']
    assert_nil s['gpu_vendors_probed']
  end

  def test_a_gpu_list_with_a_non_object_is_not_read
    s = signed({ 'machine' => MACHINE.merge('gpus' => [1, 'x']) })
    assert_nil s['gpus_total'], 'not "looked, none"'
    assert_equal 'partial', s['grade_resources']
  end

  # (iii) on a bundle already at `immutable`, so a regression that let the
  # resources pull the overall grade down would show.
  def test_resources_never_move_an_immutable_grade
    base = JSON.parse(File.read(File.expand_path('fixtures/record_v0_3/bundle.json', __dir__)))
    before = Identity.derive(JSON.generate(base))['signed']
    assert_equal 'immutable', before['grade_overall']
    [{}, { 'steps' => [entry(1, REQ)] }, { 'machine' => MACHINE, 'steps' => [entry(1)] }].each do |res|
      b = JSON.parse(JSON.generate(base))
      b['extension_domain'].first['genomicschain_extension']['resources'] = res unless res.empty?
      after = Identity.derive(JSON.generate(b))['signed']
      keep = Identity::BASE_SIGNED_FIELDS - %w[subject_ref bundle_digest]
      assert_equal before.slice(*keep), after.slice(*keep), res.keys.inspect
    end
  end

  def test_odd_shapes_around_the_resources_block_are_not_read_and_not_refused
    b = JSON.parse(bundle({ 'steps' => [entry(1), entry(2)] }))
    b['extension_domain'] += [5, { 'genomicschain_extension' => [] }, { 'genomicschain_extension' => { 'resources' => [1] } },
                              { 'genomicschain_extension' => { 'resources' => { 'machine' => 'x', 'steps' => [nil, 1] } } }]
    assert_equal 'steps', Identity.derive(JSON.generate(b))['signed']['grade_resources']
  end

  # §6.2 (2): within one block, more information never lowers the grade —
  # a second job on another CPU drops the CPU name and nothing else.
  def test_a_second_cpu_model_drops_the_name_and_keeps_the_grade
    one = entry(1, 'observed' => BOTH['observed'].merge('cpu_model' => 'Intel Xeon'))
    two = entry(1, 'observed' => BOTH['observed'].merge('cpu_model' => 'AMD EPYC'))
    a = Identity.derive(bundle({ 'steps' => [one] }))
    b = Identity.derive(bundle({ 'steps' => [one, two] }))
    assert_equal a['signed']['grade_resources'], b['signed']['grade_resources']
    assert_equal 'Intel Xeon', a['resources']['steps'][1]['observed']['cpu_model']
    refute b['resources']['steps'][1]['observed'].key?('cpu_model')
    lone = entry(1, 'observed' => { 'cpu_model' => 'Intel Xeon' })
    assert_equal 'absent', grade({ 'steps' => [lone] }), 'a CPU name alone is not a stated value'
  end

  def test_numbers_that_are_equal_agree_across_blocks
    b = JSON.parse(bundle({ 'steps' => [entry(1, 'requested' => { 'cpus' => 4, 'memory_bytes' => 8 })] }))
    b['extension_domain'] << { 'genomicschain_extension' => { 'resources' => {
      'steps' => [entry(1, { 'requested' => { 'cpus' => 4.0 } }, 'plan')] } } }
    d = Identity.derive(JSON.generate(b))
    assert_equal 4, d['resources']['steps'][1]['requested']['cpus']
    assert_equal 1, d['signed']['stages_with_requested_resources']
  end

  def test_a_source_whose_only_value_was_dropped_is_not_listed
    b = JSON.parse(bundle({ 'steps' => [entry(1, REQ, 'plan')] }))
    b['extension_domain'] << { 'genomicschain_extension' => { 'resources' => {
      'steps' => [entry(1, { 'requested' => { 'cpus' => 64 } }, 'nextflow_trace')] } } }
    assert_equal %w[plan], Identity.derive(JSON.generate(b))['signed']['resources_sources']

    only = JSON.parse(bundle({ 'steps' => [entry(1, { 'requested' => { 'cpus' => 4 } }, 'plan')] }))
    only['extension_domain'] << { 'genomicschain_extension' => { 'resources' => {
      'steps' => [entry(1, { 'requested' => { 'cpus' => 8 } }, 'nextflow_trace')] } } }
    s = Identity.derive(JSON.generate(only))['signed']
    assert_nil s['resources_sources'], 'every value of the stage was dropped'
    assert_equal 'absent', s['grade_resources']
  end

  # Operator 2026-10-17 (D5 and the review r1 follow-up): the shapes are found
  # at any delimiter, and paths and long digit runs are dropped too.
  def test_identifier_shapes_are_found_at_any_delimiter
    ['NVIDIA A100 (gpu17.local)', 'gpu17.local/A100', 'A100 node3.uzh)', 'ip-10-0-1-23', 'A100 10_0_0_17',
     '00_1A_2B_3C_4D_5E', '00 1a 2b 3c 4d 5e', 'A00-1A-2B-3C-4D-5E', '/home/jdoe/gpu0', 'Tesla 12345678',
     'GPU deadbeefcafe', 'GPU-abcdefab-abcd-abcd-abcd-abcdefabcdef'].each do |m|
      refute R.publishable_model?(m), m
    end
  end

  # implementation review r1: two shapes cost 9.6 s and 16.7 s on 2 MB.
  def test_the_work_is_linear_in_the_bundle
    many = Array.new(100_000) { |i| entry(1, 'observed' => { 'peak_memory_bytes' => i, 'cpu_model' => "CPU #{i}" }) }
    t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    R.derive(JSON.generate('extension_domain' => [{ 'genomicschain_extension' => { 'resources' => { 'steps' => many } } }]),
             [{ 'id' => 1, 'step_number' => 1 }])
    stages = (1..13_500).map { |i| { 'id' => i, 'step_number' => i } }
    blocks = [{ 'genomicschain_extension' => { 'resources' => { 'steps' => stages.map { |st| entry(st['step_number'], REQ) } } } }] +
             Array.new(21_500) { { 'genomicschain_extension' => { 'resources' => {} } } }
    R.derive(JSON.generate('extension_domain' => blocks), stages)
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - t, :<, 5
  end

  # Acceptance (i) as a test, on the two bundles the repository holds: the 51
  # record_version-0.3 fields as prov 0.3.0 computed them before the change.
  # v0.1.16 S3 (i): the adapter version is the one field that moves (0.4.0 →
  # 0.5.0); the other 50 are what prov 0.3.0 computed.
  def test_the_0_3_fields_are_what_prov_0_3_0_computed
    expected = JSON.parse(File.read(File.expand_path('fixtures/record_v0_3/signed_0_3_fields_by_prov_0_3_0.json', __dir__)))
    expected['bundles'].each do |rel, fields|
      now = Identity.derive(File.read(File.expand_path(rel, __dir__)))['signed']
      assert_equal 51, fields.length
      assert_equal 'prov-adapter-bco-0.4.0', fields['adapter_version']
      assert_equal 'prov-adapter-bco-0.5.0', now['adapter_version'], 'S3 (i)'
      same = fields.keys - ['adapter_version']
      assert_equal fields.slice(*same), now.slice(*same), rel
    end
  end

  # --- implementation review r2 -----------------------------------------------------

  def two_blocks(first, second)
    b = JSON.parse(bundle({ 'steps' => first }))
    b['extension_domain'] << { 'genomicschain_extension' => { 'resources' => second } }
    Identity.derive(JSON.generate(b))
  end

  # Within one block, the sources of a field are those whose value it holds.
  def test_within_one_block_only_the_winning_values_source_is_listed
    plan = entry(1, { 'requested' => { 'cpus' => 4 } }, 'plan')
    file = entry(1, { 'requested' => { 'cpus' => 8 } }, 'gc_resources_input')
    [[plan, file], [file, plan]].each do |order|
      assert_equal %w[gc_resources_input], signed({ 'steps' => order })['resources_sources'], order.map { |e| e['source'] }.inspect
    end
    both = entry(1, { 'requested' => { 'cpus' => 8, 'memory_bytes' => 10 } }, 'plan')
    assert_equal %w[gc_resources_input plan], signed({ 'steps' => [both, file] })['resources_sources'], 'a tie and a kept memory'
  end

  def test_a_sum_is_compared_as_a_number
    halves = [entry(1, { 'observed' => { 'read_bytes' => 1.5 } }), entry(1, { 'observed' => { 'read_bytes' => 2.5 } })]
    d = two_blocks(halves, { 'steps' => [entry(1, { 'observed' => { 'read_bytes' => 4 } })] })
    assert_equal 4, d['resources']['steps'][1]['observed']['read_bytes']
  end

  def test_a_stage_left_with_only_a_cpu_name_after_a_merge_is_not_stated
    a = entry(1, { 'observed' => { 'peak_memory_bytes' => 10, 'cpu_model' => 'Intel Xeon' } })
    d = two_blocks([a], { 'steps' => [entry(1, { 'observed' => { 'peak_memory_bytes' => 20 } })] })
    assert_equal 'absent', d['signed']['grade_resources']
    assert_nil d['signed']['resources_sources']
  end

  def test_whole_floats_agree_and_fractions_do_not
    obs = ->(v) { [entry(1, { 'observed' => { 'realtime_seconds' => v } })] }
    assert_nil two_blocks(obs.call(412.5), { 'steps' => obs.call(412.7) })['resources']['steps'][1]['observed']['realtime_seconds']
    assert_equal 412, two_blocks(obs.call(412), { 'steps' => obs.call(412.0) })['resources']['steps'][1]['observed']['realtime_seconds']
    big = two_blocks(obs.call(2**53), { 'steps' => obs.call(2.0**53) })
    assert_nil big['resources']['steps'][1]['observed']['realtime_seconds'], 'at 2^53 and above, a Float is compared as a Float'
  end

  def test_machine_numbers_compare_by_value
    d = two_blocks([], { 'machine' => MACHINE.merge('logical_cores' => 64.0) })
    b = JSON.parse(bundle({ 'machine' => MACHINE }))
    b['extension_domain'] << { 'genomicschain_extension' => { 'resources' => { 'machine' => MACHINE.merge('logical_cores' => 64.0) } } }
    assert_equal 'probe', Identity.derive(JSON.generate(b))['signed']['machine_source'], 'the two blocks state one machine'
    assert_equal 'probe', d['signed']['machine_source']
  end

  # --- the record ------------------------------------------------------------------

  def test_the_nine_fields_are_signed_and_deterministic
    res = { 'machine' => MACHINE, 'steps' => [entry(1, BOTH, 'nextflow_trace'), entry(2, BOTH, 'plan')] }
    a = signed(res)
    assert_equal Identity::SIGNED_FIELDS['0.4'], a.keys
    assert_equal a, signed(res)
    assert_equal %w[nextflow_trace plan], a['resources_sources']
    assert_equal 'probe', a['machine_source']
    assert_equal [2, 2], a.values_at('stages_with_requested_resources', 'stages_with_observed_resources')
  end
end
