# frozen_string_literal: true

# Adapters::Bco — the BCO half of design v0.1 §4, measured against the one
# real bundle we have (U0: nf-core/demo 1.2.0 under nf-prov 1.7.0, Nextflow
# 26.04.6, 2026-09-20) and against a hand-written BCO that carries everything
# nf-prov leaves out. The numbers asserted on the fixture are the numbers U0
# recorded; if the adapter ever reads the same bytes differently, that is a
# finding to record, not a fixture to update.
require 'minitest/autorun'
require 'json'

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'genomicschain_prov'

class AdapterBcoTest < Minitest::Test
  FIXTURE = File.expand_path('fixtures/nfcore_demo_1_2_0/bco.json', __dir__)
  Bco = GenomicsChainProv::Adapters::Bco

  def fixture
    @fixture ||= File.read(FIXTURE)
  end

  def parsed
    @parsed ||= Bco.parse(fixture)
  end

  # --- the real bundle ------------------------------------------------------------

  def test_format_and_version
    assert_equal 'bco', parsed.format
    assert_equal 'https://w3id.org/ieee/ieee-2791-schema/2791object.json', parsed.format_version
    assert_nil parsed.producer, 'nf-prov names no producer anywhere in its BCO'
    assert_includes parsed.notes, 'bundle names no producer'
  end

  def test_workflow_comes_from_the_scm_extension
    w = parsed.workflow
    assert_equal 'nf-core/demo', w['name']
    assert_equal '1.2.0', w['version']
    assert_equal 'https://github.com/nf-core/demo', w['repository']
    assert_equal '555d145b9e701c012f53996a2f17efb2daff5fe7', w['commit']
    assert_equal 'commit', w['ref_kind']
    assert_equal 'main.nf', w['path']
    assert_equal 'https://github.com/nf-core/demo/tree/555d145b9e701c012f53996a2f17efb2daff5fe7/main.nf', w['script']
  end

  # software_prerequisites holds one line, the engine itself. It is the runtime,
  # not a tool: counting it as software would grade every nf-prov bundle
  # `versioned` on a category the bundle says nothing about.
  def test_runtime_is_nextflow_and_is_not_a_tool
    assert_equal({ 'engine' => 'nextflow', 'version' => '26.04.6',
                   'locator' => 'https://github.com/nextflow-io/nextflow/releases/tag/v26.04.6', 'checksum' => nil },
                 parsed.runtime)
    assert_empty parsed.software
    assert_empty parsed.containers
    assert_includes parsed.notes, 'no tool besides the runtime in software_prerequisites'
    assert_includes parsed.notes, 'no container reference anywhere in the bundle'
  end

  def test_eight_stages_in_step_order
    assert_equal((1..8).to_a, parsed.stages.map { |s| s['id'] })
    first = parsed.stages.first
    last = parsed.stages.last
    assert_equal 'NFCORE_DEMO:DEMO:COWPY', first['description']
    assert_match(/\A[0-9a-f]{32}\z/, first['name'], 'nf-prov puts the task hash in the step name')
    assert_equal [0, 1], [first['inputs'], first['outputs']]
    assert_equal 'NFCORE_DEMO:DEMO:MULTIQC (demo)', last['description']
    assert_equal [10, 3], [last['inputs'], last['outputs']]
    assert(parsed.stages.all? { |s| s['software'].empty? && s['container'].nil? })
  end

  # 8 inputs: 5 supplied over https, 2 collectFile temp files under work/tmp/,
  # the pipeline's own versions.yml under outdir. None of the 8 appears as a
  # step output or a published output in the bundle, so none is internal
  # (review round 1 replaced the path-prefix rule with output evidence): the
  # three run-made files grade as what the bundle shows — local paths without
  # a checksum — until the enricher hashes them.
  def test_inputs_are_internal_only_on_output_evidence
    assert_equal 8, parsed.inputs.length
    assert_equal 0, parsed.inputs.count { |i| i['checksum'] }
    assert_includes parsed.notes, 'no checksum on any input'
    assert_empty parsed.inputs_internal
    assert_equal 8, parsed.inputs_external.length

    locators = parsed.inputs.map { |i| i['locator'] }
    assert_equal 5, locators.count { |l| l.start_with?('https://') }
    assert_equal 2, locators.count { |l| l.start_with?('work/tmp/') }
    assert_equal 1, locators.count { |l| l.start_with?('file:///tmp/gc_u0_demo/results/') }
    assert_equal 'sample1_R1.fastq.gz', parsed.inputs.find { |i| i['locator'].end_with?('sample1_R1.fastq.gz') }['name']
    assert_equal 0, parsed.inputs.count { |i| i['reference_hint'] }, 'demo reads no reference genome'
  end

  def test_sixteen_outputs_without_checksums
    assert_equal 16, parsed.outputs.length
    assert_equal 0, parsed.outputs.count { |o| o['checksum'] }
    assert_includes parsed.notes, 'no checksum on any output'
    assert_equal 'cowpy.txt', parsed.outputs.first['name']
    assert_equal 'file:///tmp/gc_u0_demo/results/cowpy/cowpy.txt', parsed.outputs.first['locator']
    assert_equal 'text/plain', parsed.outputs.first['mediatype']
    assert_equal 2, parsed.outputs.count { |o| o['mediatype'].nil? }, 'the two published directories'
  end

  def test_parameters_are_counted_not_graded
    assert_equal 376, parsed.params_total
    assert_equal 367, parsed.params_count
    assert_equal false, parsed.seed_recorded
  end

  def test_same_bytes_same_structure
    a = Bco.parse(fixture).to_h
    b = Bco.parse(JSON.parse(fixture)).to_h
    assert_equal a, b
    assert_equal a, JSON.parse(JSON.generate(b)), 'string keys and JSON-native values only'
  end

  # --- a bundle carrying what nf-prov omits ----------------------------------------

  # A tool with a version and a digest-pinned image, per-step prerequisites
  # (the same tool in two steps), SHA-1 on an input, SHA-256 in the
  # GenomicsChain extension, a seed, a reference genome named as such, one
  # internal input (made by step 1, read by step 2), one in-place overwrite
  # (step 3 reads and writes the same locator) and one published output that
  # is also a workflow input.
  def enriched_bco
    {
      'spec_version' => 'https://w3id.org/ieee/ieee-2791-schema/2791object.json',
      'provenance_domain' => { 'name' => 'toy', 'version' => '0.1' },
      'description_domain' => {
        'pipeline_steps' => [
          { 'step_number' => 2, 'name' => 'divide', 'description' => 'step 2',
            'prerequisite' => [{ 'name' => 'bc', 'version' => '1.07.1',
                                 'uri' => { 'uri' => 'quay.io/biocontainers/bc:1.07.1--h7b6447c_0' } }],
            'input_list' => [{ 'uri' => 'work/12/34/sum.txt' }],
            'output_list' => [{ 'uri' => 'work/ab/cdef/out.txt' }] },
          { 'step_number' => 3, 'name' => 'polish', 'description' => 'step 3',
            'prerequisite' => [{ 'name' => 'bc', 'version' => '1.07.1',
                                 'uri' => { 'uri' => 'quay.io/biocontainers/bc:1.07.1--h7b6447c_0' } }],
            'input_list' => [{ 'uri' => 'work/ov/inplace.txt' }],
            'output_list' => [{ 'uri' => 'work/ov/inplace.txt' }] },
          { 'step_number' => 1, 'name' => 'add', 'description' => 'step 1',
            'input_list' => [{ 'uri' => 'a.txt' }, { 'uri' => 'b.txt' }],
            'output_list' => [{ 'uri' => 'work/12/34/sum.txt' }] }
        ]
      },
      'execution_domain' => {
        'script' => ['file:///home/x/toy/run.sh'],
        'script_driver' => 'shell',
        'software_prerequisites' => [
          { 'name' => 'shell', 'version' => 'bash 5.2.21', 'uri' => { 'uri' => 'https://www.gnu.org/software/bash/' } },
          { 'name' => 'coreutils', 'version' => '9.4', 'uri' => { 'uri' => "docker://library/debian@sha256:#{'c' * 64}" } },
          { 'name' => 'unpinned-tool', 'uri' => { 'uri' => 'https://example.org/tool' } }
        ]
      },
      'parametric_domain' => [
        { 'param' => 'outdir', 'value' => 'file:///home/x/toy/results', 'step' => '0' },
        { 'param' => 'random_seed', 'value' => '42', 'step' => '0' },
        { 'param' => 'unset', 'value' => 'null', 'step' => '0' }
      ],
      'io_domain' => {
        'input_subdomain' => [
          { 'uri' => { 'uri' => 'https://example.org/data/a.txt', 'sha1_checksum' => 'A' * 40 } },
          { 'uri' => { 'uri' => 'https://example.org/ref/genome.fa.gz' } },
          { 'uri' => { 'uri' => 'file:///home/x/toy/results/previous.txt' } },
          { 'uri' => { 'uri' => 'work/tmp/zz/scratch.txt' } },
          { 'uri' => { 'uri' => 'work/12/34/sum.txt' } },
          { 'uri' => { 'uri' => 'file:///home/x/toy/results/out.txt' } },
          { 'uri' => { 'uri' => 'work/ov/inplace.txt' } }
        ],
        'output_subdomain' => [
          { 'mediatype' => 'text/plain',
            'uri' => { 'filename' => 'work/ab/cdef/out.txt', 'uri' => 'file:///home/x/toy/results/out.txt',
                       'sha1_checksum' => 'B' * 40 } }
        ]
      },
      'extension_domain' => [
        { 'extension_schema' => 'https://w3id.org/biocompute/extension_domain/1.1.0/scm/scm_extension.json',
          'scm_extension' => { 'scm_repository' => 'https://example.org/toy.git', 'scm_type' => 'git',
                               'scm_commit' => 'v0.1', 'scm_path' => 'run.sh' } },
        { 'extension_schema' => 'https://genomicschain.ch/schemas/bco_extension_genomicschain_v0_1.json',
          'genomicschain_extension' => {
            'producer' => { 'name' => 'gc_prov_write', 'version' => '0.1.0' },
            'checksums' => [
              { 'uri' => 'https://example.org/data/a.txt', 'sha256' => 'D' * 64 },
              { 'uri' => 'file:///home/x/toy/results/out.txt', 'sha256' => 'E' * 64 }
            ]
          } }
      ]
    }
  end

  def test_enriched_bco_yields_every_condition
    n = Bco.parse(enriched_bco)
    assert_equal({ 'name' => 'gc_prov_write', 'version' => '0.1.0' }, n.producer)
    assert_equal({ 'engine' => 'shell', 'version' => 'bash 5.2.21', 'locator' => 'https://www.gnu.org/software/bash/',
                   'checksum' => nil }, n.runtime)
    assert_equal %w[coreutils unpinned-tool bc bc], n.software.map { |s| s['name'] }, 'bc is kept once per step'
    assert_equal [nil, nil, 2, 3], n.software.map { |s| s['stage'] }
    assert_nil n.software[1]['version']
    assert_equal ["docker://library/debian@sha256:#{'c' * 64}", 'quay.io/biocontainers/bc:1.07.1--h7b6447c_0',
                  'quay.io/biocontainers/bc:1.07.1--h7b6447c_0'],
                 n.containers.map { |c| c['ref'] }
    assert_equal 'symbolic', n.workflow['ref_kind'], '"v0.1" is not a hash; a tag and a branch look alike here'
    assert_equal [1, 2, 3], n.stages.map { |s| s['id'] }
    assert_equal [1, 2, 3], n.stages.map { |s| s['step_number'] }
    assert_nil n.stages[0]['container']
    assert_equal 'quay.io/biocontainers/bc:1.07.1--h7b6447c_0', n.stages[1]['container']
    refute_includes n.notes, 'bundle names no producer'
  end

  def test_enriched_bco_checksums_internal_and_reference
    n = Bco.parse(enriched_bco)
    a = n.inputs.find { |i| i['name'] == 'a.txt' }
    assert_equal({ 'sha1' => 'a' * 40, 'sha256' => 'd' * 64 }, a['checksum'])
    assert_equal false, a['internal']

    genome = n.inputs.find { |i| i['name'] == 'genome.fa.gz' }
    assert_nil genome['checksum']
    assert_equal true, genome['reference_hint']

    # Internal only when produced by an earlier step than every consumer:
    # sum.txt is step 1's output and step 2's input. out.txt is a published
    # output with no step — publication is not ordering evidence. inplace.txt
    # is read and written by the same step — the bytes read existed before
    # the run wrote them. previous.txt (under outdir) and scratch.txt (under
    # work/) never appear as outputs — a prefix is a producer's choice.
    assert_equal %w[sum.txt], n.inputs_internal.map { |i| i['name'] }
    assert_equal %w[a.txt genome.fa.gz previous.txt scratch.txt out.txt inplace.txt],
                 n.inputs_external.map { |i| i['name'] }

    assert_equal 'out.txt', n.outputs.first['name']
    assert_equal({ 'sha1' => 'b' * 40, 'sha256' => 'e' * 64 }, n.outputs.first['checksum'])

    assert_equal 3, n.params_total
    assert_equal 2, n.params_count
    assert_equal true, n.seed_recorded
    refute_includes n.notes, 'no checksum on any input'
  end

  # Only a full hash is a commit. An abbreviation or a calendar tag that
  # happens to be hex is a name and stays symbolic (review round 1).
  def test_only_a_full_hash_is_a_commit
    { 'a' * 40 => 'commit', 'A' * 64 => 'commit', 'abc1234' => 'symbolic', '20240601' => 'symbolic',
      'v0.1' => 'symbolic', 'main' => 'symbolic' }.each do |ref, kind|
      b = enriched_bco
      b['extension_domain'][0]['scm_extension']['scm_commit'] = ref
      assert_equal kind, Bco.parse(b).workflow['ref_kind'], "ref #{ref.inspect}"
    end
  end

  def test_untagged_unschemed_name_is_not_taken_as_an_image
    refute Bco.oci_ref?('biocontainers/fastqc'), 'indistinguishable from a path'
    assert Bco.oci_ref?('docker://biocontainers/fastqc')
    assert Bco.oci_ref?('quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0')
    assert Bco.oci_ref?('registry.example:5000/img:2.1')
    refute Bco.oci_ref?('https://github.com/nextflow-io/nextflow/releases/tag/v26.04.6')
    refute Bco.oci_ref?('s3://bucket/key:1')
    refute Bco.oci_ref?('./x:1.0'), 'a relative path with a colon is not an image (round 5)'
    refute Bco.oci_ref?('../x:1.0')
  end

  # --- stage identity and the internal-input rule (review round 2) -----------------

  # A stage is its position after sorting on step_number, and every per-stage
  # item carries that position. Step numbers 10 / 30 / 20 are stages 1 / 2 / 3.
  def test_stage_is_position_after_sort
    b = enriched_bco
    b['description_domain']['pipeline_steps'].each { |st| st['step_number'] *= 10 }
    b['description_domain']['pipeline_steps'].rotate!(1)
    n = Bco.parse(b)
    assert_equal [1, 2, 3], n.stages.map { |s| s['id'] }
    assert_equal [10, 20, 30], n.stages.map { |s| s['step_number'] }
    assert_equal %w[add divide polish], n.stages.map { |s| s['name'] }
    assert_equal [2, 3], n.software.select { |x| x['name'] == 'bc' }.map { |x| x['stage'] }
    assert_equal %w[sum.txt], n.inputs_internal.map { |i| i['name'] }, 'ordering follows step_number, not list order'
  end

  # Two steps sharing a number would share a stage and pool their
  # declarations; a step without an integer number has no position.
  def test_duplicate_or_missing_step_number_is_a_format_error
    b = enriched_bco
    b['description_domain']['pipeline_steps'][1]['step_number'] = 2
    err = assert_raises(Bco::FormatError) { Bco.parse(b) }
    assert_match(/1 step_number value\(s\) duplicated/, err.message)
    refute_match(/2/, err.message.sub('1 step_number', ''), 'the duplicated value itself is not in the message')

    b = enriched_bco
    b['description_domain']['pipeline_steps'][0].delete('step_number')
    err = assert_raises(Bco::FormatError) { Bco.parse(b) }
    assert_match(/without an integer step_number/, err.message)

    b = enriched_bco
    b['description_domain']['pipeline_steps'][0]['step_number'] = '20'
    b['description_domain']['pipeline_steps'][1]['step_number'] = '30'
    n = Bco.parse(b)
    assert_equal [1, 2, 3], n.stages.map { |s| s['id'] }, 'a numeric string is an integer'
    assert_equal [1, 20, 30], n.stages.map { |s| s['step_number'] }
  end

  # The same tool declared by two steps is two items with two stages; the
  # same tool declared at the workflow level AND by a step is two items too.
  # Only an entry repeated within one level collapses.
  def test_a_tool_declared_in_two_steps_is_kept_per_step
    b = enriched_bco
    b['execution_domain']['software_prerequisites'] << { 'name' => 'bc', 'version' => '1.07.1',
                                                         'uri' => { 'uri' => 'quay.io/biocontainers/bc:1.07.1--h7b6447c_0' } }
    b['execution_domain']['software_prerequisites'] << { 'name' => 'bc', 'version' => '1.07.1',
                                                         'uri' => { 'uri' => 'quay.io/biocontainers/bc:1.07.1--h7b6447c_0' } }
    n = Bco.parse(b)
    assert_equal [nil, 2, 3], n.software.select { |x| x['name'] == 'bc' }.map { |x| x['stage'] }
    g = GenomicsChainProv::Predicate.grade(n)
    assert_equal 2, g['counts']['stages_with_own_environment'], 'steps 2 and 3 declare bc themselves'
    assert_equal 3, g['counts']['stages_with_environment'], 'step 1 falls back to the workflow level'
    assert_equal '2/3', g['coverage']
  end

  # A `filename` is a caption, not a location: an output whose filename equals
  # an input's uri does not make that input internal.
  def test_filename_label_is_not_production_evidence
    b = enriched_bco
    b['description_domain']['pipeline_steps'][1]['output_list'] = [
      { 'uri' => { 'uri' => 'work/ab/cdef/other.txt', 'filename' => 'work/tmp/zz/scratch.txt' } }
    ]
    b['description_domain']['pipeline_steps'][2]['input_list'] = [{ 'uri' => 'work/tmp/zz/scratch.txt' }]
    n = Bco.parse(b)
    assert_equal false, n.inputs.find { |i| i['name'] == 'scratch.txt' }['internal']
  end

  # An input produced by a LATER step than the one that reads it is not made
  # by this run before it was read; it stays external and graded.
  def test_input_produced_after_it_is_read_stays_external
    b = enriched_bco
    steps = b['description_domain']['pipeline_steps']
    steps.find { |st| st['step_number'] == 1 }['output_list'] = []
    steps.find { |st| st['step_number'] == 3 }['output_list'] << { 'uri' => 'work/12/34/sum.txt' }
    n = Bco.parse(b)
    assert_empty n.inputs_internal
    assert_equal 7, n.inputs_external.length
  end

  # --- review round 3 ---------------------------------------------------------------

  # The extension's checksums join tools and the runtime by locator, the same
  # way inputs and outputs join: the enricher writes the framework jar's sha256
  # keyed by the runtime's uri, and a tool's file hash keyed by its uri.
  def test_extension_checksums_reach_software_and_runtime
    b = enriched_bco
    b['extension_domain'][1]['genomicschain_extension']['checksums'] += [
      { 'uri' => 'https://www.gnu.org/software/bash/', 'sha256' => 'F' * 64 },
      { 'uri' => 'https://example.org/tool', 'sha256' => '9' * 64 }
    ]
    n = Bco.parse(b)
    assert_equal({ 'sha256' => 'f' * 64 }, n.runtime['checksum'])
    assert_equal({ 'sha256' => '9' * 64 }, n.software.find { |x| x['name'] == 'unpinned-tool' }['checksum'])
    g = GenomicsChainProv::Predicate.grade(n)
    assert_equal 'immutable', g['grades']['runtime']
    assert_equal 'immutable', g['items'].find { |i| i['name'] == 'unpinned-tool' }['grade']
  end

  # Two declarations alike but for their checksum are two items; the weaker
  # survives whichever comes first.
  def test_dedup_keeps_entries_that_differ_only_in_checksum
    b = enriched_bco
    b['execution_domain']['software_prerequisites'] << { 'name' => 'coreutils', 'version' => '9.4',
                                                         'uri' => { 'uri' => "docker://library/debian@sha256:#{'c' * 64}",
                                                                    'sha1_checksum' => 'A' * 40 } }
    n = Bco.parse(b)
    assert_equal 2, n.software.count { |x| x['name'] == 'coreutils' }
    assert_equal [nil, { 'sha1' => 'a' * 40 }], n.software.select { |x| x['name'] == 'coreutils' }.map { |x| x['checksum'] }
  end

  # A step that is not an object is refused, not dropped: dropping it would
  # shrink stages_total and could remove the weakest stage from the grade.
  def test_non_object_step_is_a_format_error
    b = enriched_bco
    b['description_domain']['pipeline_steps'] << 'step four'
    err = assert_raises(Bco::FormatError) { Bco.parse(b) }
    assert_match(/1 pipeline step\(s\) are not objects/, err.message)
  end

  # No bundle value reaches an error message: the anchor may log it, and §6
  # promises its logs carry no bundle content.
  def test_error_messages_carry_no_bundle_values
    err = assert_raises(Bco::FormatError) { Bco.parse('{"spec_version": "SECRET-PATH-/data/patient42"') }
    refute_match(/patient42|SECRET/, err.message)
    assert_equal 'bundle is not valid JSON', err.message
    err = assert_raises(Bco::FormatError) { Bco.parse('{"spec_version": "SECRET-PATH-/data/patient42"}') }
    refute_match(/patient42|SECRET/, err.message)
    b = enriched_bco
    b['description_domain']['pipeline_steps'][0]['step_number'] = '/data/patient42'
    err = assert_raises(Bco::FormatError) { Bco.parse(b) }
    refute_match(/patient42/, err.message)
  end

  # --- review round 4 ---------------------------------------------------------------

  # Two software_prerequisites entries naming the engine are two declarations;
  # the weaker decides whatever their order (round 4, customer skeptic).
  def test_duplicate_runtime_entries_take_the_weakest_in_any_order
    weak = { 'name' => 'shell', 'version' => 'latest' }
    strong = { 'name' => 'shell', 'version' => '5.2.21', 'uri' => { 'uri' => "docker://library/bash:5.2@sha256:#{'a' * 64}" } }
    [[weak, strong], [strong, weak]].each do |order|
      b = enriched_bco
      b['execution_domain']['software_prerequisites'] = order
      n = Bco.parse(b)
      assert_equal 'latest', n.runtime['version']
      assert_equal 'floating', GenomicsChainProv::Predicate.grade(n)['grades']['runtime']
      assert_includes n.notes, 'runtime declared more than once; the weakest declaration is taken'
    end
    # two version strings: the predicate's rule decides which is weaker, not the string order
    [[{ 'name' => 'shell', 'version' => '24.04.4' }, { 'name' => 'shell', 'version' => 'latest' }],
     [{ 'name' => 'shell', 'version' => '> 1.0' }, { 'name' => 'shell', 'version' => '1.0' }]].each do |pair|
      [pair, pair.reverse].each do |order|
        b = enriched_bco
        b['execution_domain']['software_prerequisites'] = order
        assert_equal pair[0]['version'] == '24.04.4' ? 'latest' : '> 1.0', Bco.parse(b).runtime['version']
      end
    end
  end

  # The script's checksum comes from the extension keyed by its locator.
  def test_script_checksum_joins_from_the_extension
    b = enriched_bco
    b['extension_domain'].delete_at(0)
    b['extension_domain'][0]['genomicschain_extension']['checksums'] << { 'uri' => 'file:///home/x/toy/run.sh', 'sha256' => 'C' * 64 }
    n = Bco.parse(b)
    assert_nil n.workflow['repository']
    assert_equal({ 'sha256' => 'c' * 64 }, n.workflow['checksum'])
    assert_equal [1, 1], n.workflow.values_at('scripts_total', 'scripts_with_checksum')
    assert_equal 'immutable', GenomicsChainProv::Predicate.grade(n)['grades']['workflow']
  end

  # Round 5 (three seats): with several script entries the workflow is pinned
  # only when every one of them carries a checksum, whatever their order.
  def test_every_script_entry_must_be_checksummed_in_any_order
    a = 'file:///x/helper.sh'
    m = 'file:///x/main.nf'
    [[a, m], [m, a]].each do |order|
      b = enriched_bco
      b['extension_domain'].delete_at(0)
      b['execution_domain']['script'] = order
      b['extension_domain'][0]['genomicschain_extension']['checksums'] << { 'uri' => a, 'sha256' => 'C' * 64 }
      n = Bco.parse(b)
      assert_nil n.workflow['checksum'], "order #{order.inspect}: main.nf has no checksum"
      assert_equal [2, 1], n.workflow.values_at('scripts_total', 'scripts_with_checksum')
      assert_equal 'floating', GenomicsChainProv::Predicate.grade(n)['grades']['workflow']
      b['extension_domain'][0]['genomicschain_extension']['checksums'] << { 'uri' => m, 'sha256' => 'D' * 64 }
      assert_equal 'immutable', GenomicsChainProv::Predicate.grade(Bco.parse(b))['grades']['workflow']
    end
  end

  # A path with a digest suffix is not an image reference (the same shape the
  # runtime rule refuses); a checksum field holds a hex digest or nothing.
  def test_digest_shapes_and_checksum_fields_are_checked
    d = "@sha256:#{'a' * 64}"
    refute Bco.oci_ref?("/opt/tools/awk#{d}")
    assert Bco.oci_ref?("quay.io/x/awk:1#{d}")
    # Round 5 (opus5): unschemed, a name with a slash whose first component is
    # no registry host is a repo-relative path — and the digest route is the
    # one that reaches `immutable`. Write docker:// for a Hub namespace.
    refute Bco.oci_ref?("tools/awk#{d}")
    refute Bco.oci_ref?("biocontainers/fastqc#{d}")
    assert Bco.oci_ref?("docker://tools/awk#{d}")
    assert Bco.oci_ref?("ghcr.io/org/img#{d}")
    assert Bco.oci_ref?("localhost:5000/img#{d}")
    assert Bco.oci_ref?("registry.example.com:5000/a/b:v1#{d}")
    assert Bco.oci_ref?("ubuntu#{d}")
    b = enriched_bco
    b['io_domain']['input_subdomain'][0]['uri']['sha1_checksum'] = '?'
    b['extension_domain'][1]['genomicschain_extension']['checksums'][0]['sha256'] = 'x'
    n = Bco.parse(b)
    assert_nil n.inputs.find { |i| i['name'] == 'a.txt' }['checksum']
    assert_includes n.notes, 'a checksum field that is not a hex digest was ignored'
  end

  # Round 5 (opus5, reproduced): the adapter used to drop an entry it could not
  # read. `inputs_total` is a signed count, so the drop shortened the
  # denominator and a bundle that omitted a field graded ABOVE the same bundle
  # declaring that field honestly.
  def test_an_input_that_names_no_locator_is_kept_and_graded
    b = enriched_bco
    b['io_domain']['input_subdomain'] = [
      { 'uri' => { 'uri' => 'https://example.org/data/a.txt', 'sha1_checksum' => 'A' * 40 } },
      { 'uri' => { 'filename' => 'secret.bam' } }
    ]
    n = Bco.parse(b)
    kept = n.inputs.last
    assert_equal 'secret.bam', kept['name']
    assert_nil kept['locator']
    g = GenomicsChainProv::Predicate.grade(n)
    assert_equal 2, g['counts']['inputs_total']
    assert_equal 1, g['counts']['inputs_with_checksum']
    assert_equal 'absent', g['grades']['inputs'], 'omitting the locator must not outgrade declaring one'
    # the same entry declared with a path grades local_path — weaker than the
    # checksummed input, stronger than saying nothing
    b['io_domain']['input_subdomain'][1]['uri']['uri'] = 'data/secret.bam'
    assert_equal 'local_path', GenomicsChainProv::Predicate.grade(Bco.parse(b))['grades']['inputs']
  end

  def test_an_output_that_names_no_locator_stays_in_the_signed_count
    b = enriched_bco
    before = GenomicsChainProv::Predicate.grade(Bco.parse(b))['counts']['outputs_total']
    b['io_domain']['output_subdomain'] << { 'uri' => { 'filename' => 'unlisted.bam' } }
    assert_equal before + 1, GenomicsChainProv::Predicate.grade(Bco.parse(b))['counts']['outputs_total']
  end

  # A stage whose only prerequisite is unreadable used to fall back to the
  # workflow-level items, which could lift it above a stage that declared a
  # weak tool of its own (round 5, opus5).
  def test_a_prerequisite_that_names_nothing_is_the_stage_own_declaration
    b = enriched_bco
    b['description_domain']['pipeline_steps'].find { |s| s['step_number'] == 1 }['prerequisite'] =
      [{ 'uri' => { 'sha1_checksum' => '' } }]
    st = GenomicsChainProv::Predicate.grade(Bco.parse(b))['stages'].find { |s| s['id'] == 1 }
    assert_equal 'own', st['source'], 'an unreadable entry is a declaration, not a silence'
    assert_equal 'absent', st['grade']
  end

  # Round 5 (opus5): with two SCM extensions the array order chose the signed
  # workflow grade — the same defect script[] and the runtime had already had.
  def test_two_scm_declarations_take_the_weakest_in_any_order
    at = ->(c) { { 'scm_extension' => { 'scm_repository' => 'https://git/x', 'scm_commit' => c, 'scm_path' => 'main.nf' } } }
    [[at['a' * 40], at['main']], [at['main'], at['a' * 40]]].each do |order|
      b = enriched_bco
      b['extension_domain'] = order + [b['extension_domain'][1]]
      n = Bco.parse(b)
      assert_equal 'main', n.workflow['commit'], "order #{order.map { |e| e['scm_extension']['scm_commit'] }.inspect}"
      assert_equal 'symbolic', n.workflow['ref_kind']
      assert_equal 'floating', GenomicsChainProv::Predicate.grade(n)['grades']['workflow']
    end
  end

  def test_format_error_drops_the_parser_cause
    err = assert_raises(Bco::FormatError) { Bco.parse('{"spec_version": "SECRET-patient42"') }
    assert_nil err.cause
    refute_match(/patient42/, err.full_message)
  end

  # --- refusals -------------------------------------------------------------------

  def test_rejects_what_is_not_a_bco
    err = assert_raises(Bco::FormatError) { Bco.parse('{"@context": "https://w3id.org/ro/crate/1.1/context"}') }
    assert_match(/spec_version/, err.message)
    assert_equal GenomicsChainProv::ADAPTER_BCO_VERSION, Bco::VERSION
    assert_raises(Bco::FormatError) { Bco.parse('not json') }
    assert_raises(Bco::FormatError) { Bco.parse('[1,2]') }
    err = assert_raises(Bco::FormatError) { Bco.parse(enriched_bco.reject { |k, _| k == 'io_domain' }) }
    assert_match(/io_domain/, err.message)
  end
end
