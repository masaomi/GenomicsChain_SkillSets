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

  # A tool with a version and a digest-pinned image, a per-step prerequisite,
  # SHA-1 on an input, SHA-256 in the GenomicsChain extension, a seed, a
  # reference genome named as such, and both kinds of internal input.
  def enriched_bco
    {
      'spec_version' => 'https://w3id.org/ieee/ieee-2791-schema/2791object.json',
      'provenance_domain' => { 'name' => 'toy', 'version' => '0.1' },
      'description_domain' => {
        'pipeline_steps' => [
          { 'step_number' => 2, 'name' => 'divide', 'description' => 'step 2',
            'prerequisite' => [{ 'name' => 'bc', 'version' => '1.07.1',
                                 'uri' => { 'uri' => 'quay.io/biocontainers/bc:1.07.1--h7b6447c_0' } }],
            'input_list' => [{ 'uri' => 'work/ab/cdef/sum.txt' }],
            'output_list' => [{ 'uri' => 'work/ab/cdef/out.txt' }] },
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
          { 'uri' => { 'uri' => 'file:///home/x/toy/results/out.txt' } }
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
    assert_equal %w[coreutils unpinned-tool bc], n.software.map { |s| s['name'] }
    assert_equal [nil, nil, 2], n.software.map { |s| s['stage'] }
    assert_nil n.software[1]['version']
    assert_equal ["docker://library/debian@sha256:#{'c' * 64}", 'quay.io/biocontainers/bc:1.07.1--h7b6447c_0'],
                 n.containers.map { |c| c['ref'] }
    assert_equal 'symbolic', n.workflow['ref_kind'], '"v0.1" is not a hash; a tag and a branch look alike here'
    assert_equal [1, 2], n.stages.map { |s| s['id'] }
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

    # Internal only on output evidence: sum.txt is step 1's output_list entry,
    # out.txt is a published output. previous.txt (under outdir) and
    # scratch.txt (under work/) are NOT — a prefix is a producer's choice.
    assert_equal %w[sum.txt out.txt], n.inputs_internal.map { |i| i['name'] }
    assert_equal %w[a.txt genome.fa.gz previous.txt scratch.txt], n.inputs_external.map { |i| i['name'] }

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
  end

  # --- refusals -------------------------------------------------------------------

  def test_rejects_what_is_not_a_bco
    err = assert_raises(Bco::FormatError) { Bco.parse('{"@context": "https://w3id.org/ro/crate/1.1/context"}') }
    assert_match(/spec_version/, err.message)
    assert_raises(Bco::FormatError) { Bco.parse('not json') }
    assert_raises(Bco::FormatError) { Bco.parse('[1,2]') }
    err = assert_raises(Bco::FormatError) { Bco.parse(enriched_bco.reject { |k, _| k == 'io_domain' }) }
    assert_match(/io_domain/, err.message)
  end
end
