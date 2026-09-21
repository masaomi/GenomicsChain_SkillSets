# frozen_string_literal: true

# Predicate — six hand-made normalised provenances, one per level, the rules
# review rounds 1 and 2 changed (per-stage environment with fallback-only
# inheritance, two routes per tool, the version rule in words, locators never
# immutable on their own, zero stages absent, seed beside the grades), and the
# real U0 bundle whose grades are pinned here as numbers. Design v0.1 §5, §9 U2.
require 'minitest/autorun'
require 'json'

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'genomicschain_prov'

class PredicateTest < Minitest::Test
  NP = GenomicsChainProv::NormalizedProvenance
  P = GenomicsChainProv::Predicate
  FIXTURE = File.expand_path('fixtures/nfcore_demo_1_2_0/bco.json', __dir__)

  DIGEST_IMAGE = "quay.io/x/bc:1.07.1@sha256:#{'b' * 64}"

  # Everything pinned as hard as a bundle can pin it, declared for the whole
  # workflow (stage nil). Each case below loosens exactly one thing.
  def np(**over)
    base = {
      format: 'bco', format_version: 'x', producer: nil,
      workflow: { 'name' => 'toy', 'version' => '1', 'repository' => 'https://example.org/toy.git',
                  'commit' => 'a' * 40, 'ref_kind' => 'commit', 'path' => 'run.sh', 'script' => nil },
      runtime: { 'engine' => 'shell', 'version' => '5.2', 'locator' => 'https://gnu.org/bash', 'checksum' => { 'sha256' => 'f' * 64 } },
      software: [{ 'name' => 'bc', 'version' => '1.07.1', 'locator' => DIGEST_IMAGE, 'checksum' => { 'sha256' => 'e' * 64 },
                   'stage' => nil }],
      containers: [{ 'ref' => DIGEST_IMAGE, 'name' => 'bc', 'stage' => nil }],
      stages: [{ 'id' => 1, 'name' => 'add', 'description' => nil, 'inputs' => 2, 'outputs' => 1,
                 'software' => [], 'container' => nil }],
      inputs: [{ 'name' => 'a.txt', 'locator' => 'https://example.org/a.txt', 'checksum' => { 'sha256' => 'c' * 64 },
                 'internal' => false, 'reference_hint' => false }],
      outputs: [{ 'name' => 'out.txt', 'locator' => 'file:///r/out.txt', 'checksum' => { 'sha256' => 'd' * 64 },
                  'mediatype' => 'text/plain' }],
      params_total: 3, params_count: 3, seed_recorded: true, notes: []
    }
    NP.new(**base.merge(over))
  end

  def stage(id)
    { 'id' => id, 'name' => "s#{id}", 'description' => nil, 'inputs' => 0, 'outputs' => 0, 'software' => [], 'container' => nil }
  end

  # --- six levels -----------------------------------------------------------------

  def test_immutable_when_every_category_names_bytes
    g = P.grade(np)
    assert_equal 'immutable', g['grade_overall']
    assert_equal %w[immutable immutable immutable immutable immutable immutable], g['grades'].values_at(*P::REPORTED)
    assert_equal 1, g['counts']['stages_with_environment']
  end

  def test_versioned_when_the_runtime_is_a_release_not_bytes
    g = P.grade(np(runtime: { 'engine' => 'nextflow', 'version' => '26.04.6', 'locator' => nil, 'checksum' => nil }))
    assert_equal 'versioned', g['grade_overall']
    assert_equal 'versioned', g['grades']['runtime']
    assert_match(/release name/, g['items'].find { |i| i['category'] == 'runtime' }['reason'])
  end

  def test_versioned_when_the_only_container_is_tag_pinned
    tagged = 'quay.io/x/bc:1.07.1'
    g = P.grade(np(software: [], containers: [{ 'ref' => tagged, 'name' => 'bc', 'stage' => nil }]))
    assert_equal 'versioned', g['grade_overall']
    assert_equal 'versioned', g['grades']['container']
    assert_equal 'versioned', g['grades']['environment']
  end

  def test_ranged_when_a_tool_admits_more_than_one_release
    g = P.grade(np(software: [{ 'name' => 'python', 'version' => '>=3.10,<3.12', 'locator' => nil, 'checksum' => nil, 'stage' => nil }],
                   containers: []))
    assert_equal 'ranged', g['grade_overall']
    assert_equal 'ranged', g['grades']['software']
    assert_equal 'absent', g['grades']['container']
    assert_equal 'ranged', g['grades']['environment'], 'no container, so the package list is the only route'
  end

  def test_floating_when_the_only_route_is_a_latest_container
    g = P.grade(np(software: [], containers: [{ 'ref' => 'docker://x/bc:latest', 'name' => 'bc', 'stage' => nil }]))
    assert_equal 'floating', g['grade_overall']
    assert_equal 'floating', g['grades']['container']
    assert_equal 'floating', g['grades']['environment']
  end

  def test_local_path_when_an_input_is_a_path_with_no_way_to_obtain_it
    g = P.grade(np(inputs: [{ 'name' => 'x.fa', 'locator' => '/data/x.fa', 'checksum' => nil,
                              'internal' => false, 'reference_hint' => true }]))
    assert_equal 'local_path', g['grade_overall']
    assert_equal 'local_path', g['grades']['inputs']
  end

  def test_absent_when_no_runtime_is_named
    g = P.grade(np(runtime: nil))
    assert_equal 'absent', g['grade_overall']
    assert_equal 'absent', g['grades']['runtime']
  end

  # --- rules with consequences ------------------------------------------------------

  # The environment has two routes, a container image or a package list, and
  # one suffices (decided 2026-09-20, design §10-8). So a run without
  # containers is graded by what it says about its packages; a run that says
  # nothing on either route is `absent` — declaring nothing never outgrades
  # declaring a floating URL.
  def test_environment_is_the_stronger_of_its_two_routes
    checksummed = [{ 'name' => 'bc', 'version' => '1.07.1', 'locator' => 'https://example.org/bc-1.07.1.tar.gz',
                     'checksum' => { 'sha256' => 'e' * 64 }, 'stage' => nil }]
    no_container = P.grade(np(software: checksummed, containers: []))
    assert_equal 'absent', no_container['grades']['container']
    assert_equal 'immutable', no_container['grades']['software']
    assert_equal 'immutable', no_container['grades']['environment']
    assert_equal 'immutable', no_container['grade_overall']
    assert_equal 0, no_container['counts']['containers_total']

    latest_but_pinned_packages = P.grade(np(software: checksummed,
                                            containers: [{ 'ref' => 'docker://x/bc:latest', 'name' => 'bc', 'stage' => nil }]))
    assert_equal 'floating', latest_but_pinned_packages['grades']['container']
    assert_equal 'immutable', latest_but_pinned_packages['grades']['environment']

    neither = P.grade(np(software: [], containers: []))
    assert_equal 'absent', neither['grades']['environment']
    assert_equal 'absent', neither['grade_overall']
  end

  # Review round 1 (three seats): one digest-pinned image must not make the
  # whole environment immutable while other stages name nothing. Environment
  # is graded per stage — own items plus inherited workflow-level items — and
  # the category takes the weakest stage; the claim carries the coverage.
  def test_environment_is_graded_per_stage_and_takes_the_weakest_stage
    two_stages = [stage(1), stage(2)]
    pinned_on_one = P.grade(np(stages: two_stages, software: [],
                               containers: [{ 'ref' => DIGEST_IMAGE, 'name' => 'bc', 'stage' => 1 }]))
    assert_equal 'immutable', pinned_on_one['grades']['container'], 'the category still reports its items'
    assert_equal 'absent', pinned_on_one['grades']['environment'], 'stage 2 names nothing'
    assert_equal 'absent', pinned_on_one['grade_overall']
    assert_equal 1, pinned_on_one['counts']['stages_with_environment']
    assert_equal 2, pinned_on_one['counts']['stages_total']
    assert_equal [%w[1 immutable], %w[2 absent]], pinned_on_one['stages'].map { |s| [s['id'].to_s, s['grade']] }

    each_stage_pinned = P.grade(np(stages: two_stages, software: [{ 'name' => 'bc', 'version' => '1.07.1', 'locator' => nil, 'checksum' => nil, 'stage' => 2 }],
                                   containers: [{ 'ref' => DIGEST_IMAGE, 'name' => 'bc', 'stage' => 1 }]))
    assert_equal 'versioned', each_stage_pinned['grades']['environment'], 'stage 1 immutable, stage 2 versioned → weakest'
    assert_equal 2, each_stage_pinned['counts']['stages_with_environment']
    assert_equal 2, each_stage_pinned['counts']['stages_with_own_environment']
  end

  # A BCO's software_prerequisites apply to every step: workflow-level items
  # cover every stage, and the coverage count says so.
  def test_workflow_level_declarations_cover_every_stage
    g = P.grade(np(stages: [stage(1), stage(2), stage(3)]))
    assert_equal 'immutable', g['grades']['environment']
    assert_equal 3, g['counts']['stages_with_environment']
    assert_equal 0, g['counts']['stages_with_own_environment']
    assert_equal 3, g['counts']['stages_total']
  end

  # A tool naming both a version and an image is two routes, not one: the
  # version grades the package route, the image grades the container route.
  # Naming the `:latest` image that actually ran must not lower the grade
  # below not naming it (review round 1, customer skeptic).
  def test_a_version_and_an_image_are_two_routes
    latest = 'quay.io/biocontainers/fastqc:latest'
    g = P.grade(np(software: [{ 'name' => 'fastqc', 'version' => '0.12.1', 'locator' => latest, 'checksum' => nil, 'stage' => nil }],
                   containers: [{ 'ref' => latest, 'name' => 'fastqc', 'stage' => nil }]))
    assert_equal 'versioned', g['grades']['software']
    assert_equal 'floating', g['grades']['container']
    assert_equal 'versioned', g['grades']['environment']
    without_image = P.grade(np(software: [{ 'name' => 'fastqc', 'version' => '0.12.1', 'locator' => nil, 'checksum' => nil, 'stage' => nil }],
                               containers: []))
    assert_equal g['grades']['environment'], without_image['grades']['environment'], 'disclosing the image changes nothing'
  end

  # A BCO version is free text. Only a release-shaped string names a release —
  # by the rule in words (predicate.rb, design §5): a leading tool-name token
  # is dropped, the first token after it is read, an epoch is dropped; a
  # constraint or wildcard is ranged, a literal x token is ranged, a
  # NOT_A_RELEASE token anywhere is floating. The customer-skeptic seat of
  # review round 2 measured the first regex misgrading `GATK 4.5.0.0` and
  # `bash 5.2.21` as floating and admitting `0-unknown` and `1.x.2`.
  def test_version_strings_grade_by_shape
    expect = { '0.12.1' => 'versioned', '1.4-r122' => 'versioned', '2024.06' => 'versioned', 'v1.2.0' => 'versioned',
               'V1.2.0' => 'versioned', '5.2.21' => 'versioned', 'GATK 4.5.0.0' => 'versioned',
               'bash 5.2.21' => 'versioned', '5.2.21 (x86_64)' => 'versioned', '1:2.3.4' => 'versioned',
               '2.3~rc1' => 'versioned', '0.12.1--hdfd78af_0' => 'versioned', '2.0-alpha' => 'versioned',
               'latest' => 'floating', 'unknown' => 'floating', 'HEAD' => 'floating', 'master' => 'floating',
               '0-unknown' => 'floating', '1.0-SNAPSHOT' => 'floating', '2.0.dev3' => 'floating', 'r122' => 'floating',
               '' => 'floating',
               '>=1.0' => 'ranged', '1.*' => 'ranged', '*' => 'ranged', '1.x' => 'ranged', '1.x.2' => 'ranged',
               '~1.2' => 'ranged', '^1.2' => 'ranged', '3.10,<3.12' => 'ranged', 'GATK >=4' => 'ranged',
               # review round 3: a tool name carrying a digit, a comma in a dropped word, the veto anywhere
               'python3 3.11.4' => 'versioned', 'openjdk11 11.0.22' => 'versioned', 'gcc-13 13.2.0' => 'versioned',
               'GNU bash, version 5.2.21' => 'versioned', 'GATK ~1.2' => 'ranged', 'main.py 1.2' => 'versioned',
               '1.0 latest' => 'floating', 'latest 1.0' => 'floating', '5.2.21(1)-release' => 'floating',
               '1.0 0-unknown' => 'floating', '4.5.0.0 2.0.dev3' => 'floating', 'GATK >' => 'ranged', '~' => 'ranged',
               # review round 4: a range mark as its own word, a tool name with a digit and a veto piece,
               # a veto word glued to a digit, Unicode whitespace, a trailing comma
               '> 1.0' => 'ranged', '>= 1.0' => 'ranged', '1.0 *' => 'ranged', 'GATK > 4' => 'ranged', '1.0 >=2' => 'ranged',
               'python3-dev 3.11.4' => 'versioned', '1.0latest' => 'floating', '1.0.0latest' => 'floating',
               "GATK\u00a04.5.0.0" => 'versioned', "1.0\u30004.0" => 'versioned',
               '4.5.0.0,' => 'versioned', 'GATK 4.5.0.0, HTSJDK 3.0.5' => 'versioned', '1.0,2.0' => 'ranged',
               # review round 5: v-led veto, a mark glued to a tool name
               'v1.0-SNAPSHOT' => 'floating', 'v2.0.dev3' => 'floating', 'V1.0-nightly' => 'floating',
               'GATK> 4' => 'ranged', 'GATK>= 4' => 'ranged', '>=GATK 4' => 'ranged', '4 <=x' => 'ranged' }
    expect.each do |version, level|
      assert_equal level, P.version_grade('tool', version).first, "version #{version.inspect}"
    end
    assert_equal 'floating', P.runtime_grade('engine' => 'nextflow', 'version' => 'latest', 'locator' => nil, 'checksum' => nil).first
  end

  # The reference genome is found by file name — a guess. It is reported
  # beside the grade; as an input it is still graded as one, so the signed
  # grade never depends on the guess being right.
  def test_reference_genome_is_reported_beside_the_grade_not_inside_it
    inputs = [
      { 'name' => 'a.txt', 'locator' => 'https://example.org/a.txt', 'checksum' => { 'sha256' => 'c' * 64 },
        'internal' => false, 'reference_hint' => false },
      { 'name' => 'genome.fa', 'locator' => 'https://example.org/genome.fa', 'checksum' => nil,
        'internal' => false, 'reference_hint' => true }
    ]
    g = P.grade(np(inputs: inputs))
    assert_equal({ 'grade' => 'floating', 'detection' => 'heuristic', 'count' => 1 }, g['reference'])
    assert_equal 'floating', g['grades']['inputs']
    assert_equal 2, g['counts']['inputs_total']
    assert_equal 1, g['counts']['inputs_with_checksum']
    assert_nil P.grade(np)['reference']['grade']
  end

  def test_internal_inputs_are_counted_but_not_graded
    inputs = np.inputs + [{ 'name' => 'sum.txt', 'locator' => 'work/12/34/sum.txt', 'checksum' => nil,
                            'internal' => true, 'reference_hint' => false }]
    g = P.grade(np(inputs: inputs))
    assert_equal 'immutable', g['grades']['inputs']
    assert_equal 1, g['counts']['inputs_total']
    assert_equal 1, g['counts']['inputs_internal']
  end

  # A symbolic ref is floating in the signed grade whatever its shape; the
  # tag-likeness is a heuristic and is reported beside it (review round 1).
  def test_symbolic_refs_are_floating_and_tag_likeness_stays_beside_the_grade
    tag = P.grade(np(workflow: { 'name' => 'toy', 'version' => '1', 'repository' => 'r', 'commit' => 'v1.2.0',
                                 'ref_kind' => 'symbolic', 'path' => nil, 'script' => nil }))
    assert_equal 'floating', tag['grades']['workflow']
    assert_equal({ 'kind' => 'symbolic', 'tag_like' => true, 'detection' => 'heuristic' }, tag['workflow_ref'])
    branch = P.grade(np(workflow: { 'name' => 'toy', 'version' => '1', 'repository' => 'r', 'commit' => 'main',
                                    'ref_kind' => 'symbolic', 'path' => nil, 'script' => nil }))
    assert_equal 'floating', branch['grades']['workflow']
    assert_equal false, branch['workflow_ref']['tag_like']
    assert_equal({ 'kind' => 'commit', 'tag_like' => nil, 'detection' => 'heuristic' }, P.grade(np)['workflow_ref'])
    assert_equal 'floating', P.workflow_grade('repository' => 'r', 'commit' => nil, 'ref_kind' => nil).first
    assert_equal 'absent', P.workflow_grade('repository' => nil, 'commit' => nil, 'ref_kind' => nil, 'script' => nil).first
  end

  def test_outputs_digest_binds_the_checksum_column_in_any_order
    a = [{ 'name' => 'x', 'checksum' => { 'sha256' => '1' * 64 } }, { 'name' => 'y', 'checksum' => { 'sha1' => '2' * 40 } }]
    assert_equal P.outputs_digest(a), P.outputs_digest(a.reverse)
    assert_match(/\A[0-9a-f]{64}\z/, P.outputs_digest(a))
    changed = [{ 'name' => 'x', 'checksum' => { 'sha256' => '3' * 64 } }, a[1]]
    refute_equal P.outputs_digest(a), P.outputs_digest(changed)
    assert_nil P.outputs_digest([{ 'name' => 'x', 'checksum' => nil }])
    assert_nil P.outputs_digest([])
  end

  def test_same_input_same_grade_and_json_native
    a = P.grade(np)
    b = P.grade(np)
    assert_equal a, b
    assert_equal a, JSON.parse(JSON.generate(a))
    assert_equal P::PREDICATE_VERSION, a['predicate_version']
    assert_equal GenomicsChainTier2::PinStrength::RULE_VERSION, a['pin_strength_version'], 'the rule, not the package'
    assert_match(/\Apin-strength-\d+\.\d+\.\d+\z/, a['pin_strength_version'])
    refute_equal GenomicsChainTier2::VERSION, a['pin_strength_version']
    assert_equal 'gc-outputs-rows-0.1', a['outputs_digest_rule']
  end

  # --- rules review round 2 changed -------------------------------------------------

  # Inheritance is a fallback, not an addition: a stage that declares its own
  # `:latest` image is graded on that, even when the workflow level names a
  # checksummed package; only a stage that declares nothing takes the
  # workflow-level items. The coverage in the claim counts own declarations.
  def test_inherited_items_are_fallback_only
    g = P.grade(np(stages: [stage(1), stage(2)],
                   software: [{ 'name' => 'bc', 'version' => '1.07.1', 'locator' => nil,
                                'checksum' => { 'sha256' => 'e' * 64 }, 'stage' => nil }],
                   containers: [{ 'ref' => 'docker://x/bc:latest', 'name' => 'bc', 'stage' => 1 }]))
    assert_equal [%w[1 floating own], %w[2 immutable inherited]],
                 g['stages'].map { |s| [s['id'].to_s, s['grade'], s['source']] }
    assert_equal 'floating', g['grades']['environment']
    assert_equal 2, g['counts']['stages_with_environment']
    assert_equal 1, g['counts']['stages_with_own_environment']
    assert_equal '1/2', g['coverage']
    assert_equal '0/3', P.grade(np(stages: [stage(1), stage(2), stage(3)]))['coverage'], 'workflow-level only'
  end

  # A bundle with no steps has no stage to grade: environment is absent and
  # the counts read 0/0, never an implicit stage graded immutable.
  def test_zero_stages_grade_environment_absent
    g = P.grade(np(stages: []))
    assert_equal 'absent', g['grades']['environment']
    assert_equal 'absent', g['grade_overall']
    assert_equal 'immutable', g['grades']['software'], 'the items are still reported by category'
    assert_empty g['stages']
    assert_equal [0, 0, 0], g['counts'].values_at('stages_total', 'stages_with_environment', 'stages_with_own_environment')
    assert_equal '0/0', g['coverage']
  end

  # A hash-like substring in a locator is a producer-chosen string, not a
  # checksum field: it never raises an input to immutable, and
  # inputs_with_checksum stays 0. Only a checksum field does that.
  def test_a_hash_in_a_locator_is_not_a_checksum
    path = { 'name' => 'x.fa', 'locator' => "/data/x.fa#sha256:#{'a' * 64}", 'checksum' => nil,
             'internal' => false, 'reference_hint' => false }
    url = path.merge('locator' => "https://example.org/x.fa?sha256=#{'a' * 64}")
    doi = path.merge('locator' => "https://doi.org/10.5281/zenodo.1234#md5=#{'a' * 32}")
    assert_equal 'immutable', P::PS.data_locator(path['locator']).first, 'tier2 reads it as a hash; prov must not'
    assert_equal 'local_path', P.input_grade(path).first
    assert_equal 'floating', P.input_grade(url).first
    assert_equal 'versioned', P.input_grade(doi).first
    g = P.grade(np(inputs: [path]))
    assert_equal 'local_path', g['grades']['inputs']
    assert_equal 0, g['counts']['inputs_with_checksum']
    assert_equal 'immutable', P.input_grade(path.merge('checksum' => { 'sha256' => 'a' * 64 })).first
  end

  # Review round 3 (customer skeptic, reproduced): a `10.1234/` directory
  # inside a path lifted an input two levels. A DOI is a DOI only when the
  # whole locator is one.
  def test_a_doi_shaped_substring_is_not_a_doi
    grade = ->(l) { P.input_grade('name' => 'x', 'locator' => l, 'checksum' => nil, 'internal' => false, 'reference_hint' => false).first }
    assert_equal 'local_path', grade.call('/data/x.fa')
    assert_equal 'local_path', grade.call('/data/10.1234/x.fa')
    assert_equal 'local_path', grade.call('work/10.1000/tmp.txt')
    assert_equal 'local_path', grade.call('/data/x.fa?ref=10.1234/abc')
    assert_equal 'floating', grade.call('https://example.org/x.fa')
    assert_equal 'floating', grade.call('https://example.org/10.1234/x.fa')
    assert_equal 'versioned', grade.call('10.5281/zenodo.1234')
    assert_equal 'versioned', grade.call('doi:10.5281/zenodo.1234')
    assert_equal 'versioned', grade.call('https://doi.org/10.5281/zenodo.1234')
    assert_equal 'versioned', grade.call('https://dx.doi.org/10.5281/zenodo.1234')
    assert_equal 'absent', grade.call('')
  end

  # Review round 3 (customer skeptic, reproduced on the fixture): `@sha256:`
  # appended to the runtime's release URL graded it immutable. The runtime is
  # digest-pinned only when its locator IS an OCI image reference.
  def test_runtime_is_immutable_only_via_checksum_or_an_oci_digest
    rt = ->(l, c = nil) { P.runtime_grade('engine' => 'nextflow', 'version' => '26.04.6', 'locator' => l, 'checksum' => c).first }
    assert_equal 'versioned', rt.call('https://github.com/nextflow-io/nextflow/releases/tag/v26.04.6')
    assert_equal 'versioned', rt.call("https://github.com/nextflow-io/nextflow/releases/tag/v26.04.6@sha256:#{'a' * 64}")
    assert_equal 'versioned', rt.call("/opt/nextflow.jar@sha256:#{'a' * 64}")
    assert_equal 'versioned', rt.call("nextflow@sha256:#{'a' * 64} extra")
    assert_equal 'immutable', rt.call("docker://nextflow/nextflow:26.04.6@sha256:#{'a' * 64}")
    assert_equal 'immutable', rt.call("quay.io/nextflow/nextflow:26.04.6@sha256:#{'a' * 64}")
    assert_equal 'immutable', rt.call("registry.example:5000/nf@sha256:#{'a' * 64}")
    assert_equal 'immutable', rt.call('https://github.com/nextflow-io/nextflow/releases/tag/v26.04.6', { 'sha256' => 'a' * 64 })
    # Round 5 (opus5): round 3 closed the absolute path, but a repo-relative
    # one with a digest suffix still read as an image and graded the strongest
    # level the design has. Unschemed, a slashed name must carry a registry
    # host; otherwise say docker://.
    assert_equal 'versioned', rt.call("tools/nextflow@sha256:#{'a' * 64}")
    assert_equal 'versioned', rt.call("nextflow/nextflow@sha256:#{'a' * 64}")
    assert_equal 'immutable', rt.call("docker://nextflow/nextflow@sha256:#{'a' * 64}")
    assert_equal 'immutable', rt.call("nextflow@sha256:#{'a' * 64}")
  end

  # An entry the adapter could not read is kept and graded weakest, so that
  # omitting a field never outgrades declaring one (round 5, opus5).
  def test_a_software_entry_that_names_nothing_grades_absent
    assert_equal 'absent',
                 P.software_grade('name' => nil, 'locator' => nil, 'version' => nil, 'checksum' => nil).first
    assert_equal 'floating', P.software_grade('name' => 'bc', 'locator' => nil, 'version' => nil, 'checksum' => nil).first
  end

  # Round 6 (opus5): the checksum and version branches ran before the
  # names-nothing branch, so a digest with nothing to fetch — and a version
  # naming no tool — bought a grade above an honest weak declaration.
  def test_a_checksum_or_a_version_alone_does_not_outrank_naming_nothing
    assert_equal 'absent', P.input_grade('locator' => nil, 'checksum' => { 'sha1' => 'a' * 40 }).first
    assert_equal 'absent', P.input_grade('locator' => '  ', 'checksum' => { 'sha256' => 'a' * 64 }).first
    assert_equal 'immutable', P.input_grade('locator' => 'x.fa', 'checksum' => { 'sha1' => 'a' * 40 }).first
    assert_equal 'absent',
                 P.software_grade('name' => nil, 'locator' => nil, 'version' => nil, 'checksum' => { 'sha1' => 'a' * 40 }).first
    assert_equal 'absent',
                 P.software_grade('name' => nil, 'locator' => nil, 'version' => '1.0', 'checksum' => nil).first
  end

  # Round 6 (codex, reproduced): the wildcard was tested only on the candidate
  # being accepted, so the order of two candidates chose the signed grade.
  def test_a_wildcard_in_any_candidate_is_ranged_whatever_its_position
    assert_equal 'ranged', P.version_grade('tool', '1.x 1.0').first
    assert_equal 'ranged', P.version_grade('tool', '1.0 1.x').first
    assert_equal 'versioned', P.version_grade('tool', 'GATK 4.5.0.0').first
  end

  # Round 6 (codex, reproduced): PinStrength reads a digest SUBSTRING as a pin,
  # so a scheme plus a digest-shaped tail reached immutable on a reference that
  # is not an image digest reference.
  def test_a_digest_shaped_tail_is_not_an_image_digest
    d = "@sha256:#{'a' * 64}"
    assert_equal 'floating', P.container_grade("docker://tool:latest#" + d).first
    assert_equal 'immutable', P.container_grade("docker://tool#{d}").first
    assert_equal 'immutable', P.container_grade("ghcr.io/o/i:1.0#{d}").first
    assert_equal 'versioned', P.container_grade('quay.io/biocontainers/bc:1.07.1').first
  end

  # §4 promises the two script counters; until round 6 they never reached the
  # record.
  def test_the_script_counters_are_in_the_counts
    c = P.grade(np)['counts']
    assert c.key?('scripts_total') && c.key?('scripts_with_checksum'),
           'the transparency number behind the all-or-nothing script rule must reach the record'
  end

  # The seed is found by parameter NAME — a guess — so it is reported beside
  # the grades and is not among the signed counts.
  def test_seed_is_reported_beside_the_grades
    assert_equal({ 'recorded' => true, 'detection' => 'heuristic' }, P.grade(np)['seed'])
    assert_equal({ 'recorded' => false, 'detection' => 'heuristic' }, P.grade(np(seed_recorded: false))['seed'])
    refute P.grade(np)['counts'].key?('seed_recorded')
  end

  # Round 4 (opus5): a bundle without SCM — gc_prov_write from shell/R, a local
  # Nextflow launch — could never rise above floating on the workflow. A
  # checksum on the script, joined from the extension, names its bytes.
  def test_workflow_reaches_immutable_through_a_script_checksum
    no_scm = { 'name' => 'toy', 'version' => nil, 'repository' => nil, 'commit' => nil, 'ref_kind' => nil, 'path' => nil,
               'script' => 'file:///home/x/toy/run.sh', 'checksum' => nil }
    assert_equal 'floating', P.workflow_grade(no_scm).first
    assert_equal 'immutable', P.workflow_grade(no_scm.merge('checksum' => { 'sha256' => 'a' * 64 })).first
    assert_equal 'absent', P.workflow_grade(no_scm.merge('script' => nil)).first
  end

  def test_outputs_digest_tolerates_a_nil_name
    rows = [{ 'name' => nil, 'checksum' => { 'sha256' => '1' * 64 } }, { 'name' => 'y', 'checksum' => { 'sha1' => '2' * 40 } }]
    assert_match(/\A[0-9a-f]{64}\z/, P.outputs_digest(rows))
    assert_equal P.outputs_digest(rows), P.outputs_digest(rows.reverse)
    assert_equal P.outputs_digest(rows), P.outputs_digest([rows[0].merge('name' => ''), rows[1]]), 'nil sorts as ""'
  end

  # --- the real bundle, pinned ----------------------------------------------------

  def test_fixture_grades_are_pinned
    g = P.grade(GenomicsChainProv::Adapters::Bco.parse(File.read(FIXTURE)))
    assert_equal 'absent', g['grade_overall']
    assert_equal({ 'software' => 'absent', 'container' => 'absent', 'environment' => 'absent', 'inputs' => 'local_path',
                   'workflow' => 'immutable', 'runtime' => 'versioned' }, g['grades'])
    c = g['counts']
    assert_equal 8, c['stages_total']
    assert_equal 0, c['stages_with_environment'], 'nf-prov names no tool and no image for any step'
    assert_equal 0, c['software_total']
    assert_equal 0, c['containers_total']
    assert_equal 8, c['inputs_total'], 'nothing in the bundle shows the run producing any of its 8 inputs'
    assert_equal 0, c['inputs_internal']
    assert_equal 0, c['inputs_with_checksum']
    assert_equal 16, c['outputs_total']
    assert_equal 0, c['outputs_with_checksum']
    assert_nil c['outputs_digest']
    assert_equal 376, c['params_total']
    assert_equal 367, c['params_count']
    assert_equal({ 'recorded' => false, 'detection' => 'heuristic' }, g['seed'])
    assert_equal '0/8', g['coverage']
    assert_equal({ 'grade' => nil, 'detection' => 'heuristic', 'count' => 0 }, g['reference'])
    assert_equal({ 'kind' => 'commit', 'tag_like' => nil, 'detection' => 'heuristic' }, g['workflow_ref'])
    inputs = g['items'].select { |i| i['category'] == 'inputs' }
    assert_equal({ 'local_path' => 3, 'floating' => 5 }, inputs.map { |i| i['grade'] }.tally)
    assert_equal 8, g['stages'].length
    assert(g['stages'].all? { |s| s['source'] == 'none' })
  end
end
