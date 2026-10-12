# frozen_string_literal: true

# Writer — design v0.1 §9 U1b. Two faces of `gc_prov_write`, tested the way
# each is used.
#
# The producer is measured on the computation the principle demo runs — three
# numbers, two steps, (223 + 553) / 2 = 388 — actually executed in a temporary
# directory, so the checksums in the bundle are checksums of files that exist
# and the bundle describes a run that happened. The load-bearing assertion is
# the pair: with checksums collected the bundle grades `immutable`; with
# `--no-checksums` the same computation, the same plan, the same stages grade
# down. The grade rises exactly as far as what was gathered, and no further.
#
# The enricher is measured on the one real bundle we have (U0: nf-core/demo
# 1.2.0 under nf-prov 1.7.0) together with the run artifacts captured beside
# it. The numbers asserted on the fixture are what the fixture actually
# carries; if the readers ever see those bytes differently, that is a finding
# to record, not a fixture to update.
require 'minitest/autorun'
require 'json'
require 'open3'
require 'tmpdir'
require 'fileutils'
require 'rbconfig'

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'genomicschain_prov'
require 'genomicschain_prov/writer/environment'
require 'genomicschain_prov/writer/nextflow_run'

class ProvWriteTest < Minitest::Test
  W = GenomicsChainProv::Writer
  Env = GenomicsChainProv::Writer::Environment
  NF = GenomicsChainProv::Writer::NextflowRun
  Bco = GenomicsChainProv::Adapters::Bco
  Predicate = GenomicsChainProv::Predicate
  FIXTURES = File.expand_path('fixtures/nfcore_demo_1_2_0', __dir__)

  # --- the producer: the demo's two-step computation, actually run ------------

  # (a + b) / c with a = 223, b = 553, c = 2. Each step is its own little
  # script so the stages have tools with locators on this filesystem, which is
  # what a shell computation looks like when somebody describes it honestly.
  def with_demo_computation
    Dir.mktmpdir('gc_prov_write') do |dir|
      FileUtils.mkdir_p(File.join(dir, 'tools'))
      File.write(File.join(dir, 'a.txt'), "223\n")
      File.write(File.join(dir, 'b.txt'), "553\n")
      File.write(File.join(dir, 'c.txt'), "2\n")
      File.write(File.join(dir, 'tools', 'add.sh'),
                 "#!/bin/sh\necho $(( $(cat \"$1\") + $(cat \"$2\") )) > \"$3\"\n")
      File.write(File.join(dir, 'tools', 'div.sh'),
                 "#!/bin/sh\necho $(( $(cat \"$1\") / $(cat \"$2\") )) > \"$3\"\n")
      File.write(File.join(dir, 'run.sh'),
                 "#!/bin/sh\nset -eu\nsh tools/add.sh a.txt b.txt sum.txt\nsh tools/div.sh sum.txt c.txt out.txt\n")
      _out, err, status = Open3.capture3('/bin/sh', 'run.sh', chdir: dir)
      assert status.success?, "the demo computation did not run: #{err}"
      assert_equal '388', File.read(File.join(dir, 'out.txt')).strip
      yield dir
    end
  end

  # The runtime version is written as the plan declares it, not sniffed from
  # this machine: a plan is the customer saying what ran, and `--version`
  # collection is the separate, opt-in path tested below.
  def demo_plan
    {
      'name' => 'two-step-arithmetic',
      'version' => '0.1.0',
      'description' => '(a + b) / c — the computation the service (2.5) principle demo runs',
      'script' => 'run.sh',
      'runtime' => { 'engine' => 'sh', 'version' => '5.2.21', 'uri' => '/bin/sh', 'path' => '/bin/sh' },
      'params' => [{ 'param' => 'divisor', 'value' => '2', 'step' => 2 }],
      'stages' => [
        { 'name' => 'add', 'description' => 'sum = a + b',
          'inputs' => %w[a.txt b.txt], 'outputs' => %w[sum.txt],
          'tools' => [{ 'name' => 'add.sh', 'version' => '1.0.0', 'uri' => 'tools/add.sh' }] },
        { 'name' => 'divide', 'description' => 'out = sum / c',
          'inputs' => %w[sum.txt c.txt], 'outputs' => %w[out.txt],
          'tools' => [{ 'name' => 'div.sh', 'version' => '1.0.0', 'uri' => 'tools/div.sh' }] }
      ]
    }
  end

  def write_demo(dir, checksums: true)
    plan = W.normalise_plan(demo_plan)
    resolved = Env.resolve!(plan, base_dir: dir, checksums: checksums, docker: false)
    bco = W.build(plan, checksums: resolved['checksums'],
                        object_id: 'urn:uuid:00000000-0000-4000-8000-000000000000',
                        created: '2026-09-21T00:00:00Z')
    [bco, resolved['notes']]
  end

  def test_the_bundle_it_writes_is_a_bco_the_adapter_reads
    with_demo_computation do |dir|
      bco, = write_demo(dir)
      np = Bco.parse(bco)

      assert_equal 'bco', np.format
      assert_equal W::SPEC_VERSION, np.format_version
      assert_equal({ 'name' => 'gc_prov_write', 'version' => W::VERSION }, np.producer
        .transform_keys(&:to_s))
      assert_equal 'two-step-arithmetic', np.workflow['name']
      assert_equal 'sh', np.runtime['engine']
      assert_equal 2, np.stages.length
      assert_equal [1, 2], np.stages.map { |s| s['id'] }
      assert_equal %w[add divide], np.stages.map { |s| s['name'] }
    end
  end

  # The bundle is the same file JSON round-trips: the digest subject is bytes,
  # and a writer whose output does not survive a parse cannot be the subject
  # of anything (§4 — digest before normalisation).
  def test_the_bundle_round_trips_through_json
    with_demo_computation do |dir|
      bco, = write_demo(dir)
      assert_equal bco, JSON.parse(JSON.generate(bco))
      assert_equal bco['etag'], W.etag(bco)
    end
  end

  def test_with_every_checksum_collected_the_bundle_grades_immutable
    with_demo_computation do |dir|
      bco, notes = write_demo(dir)
      graded = Predicate.grade(Bco.parse(bco))

      assert_equal 'immutable', graded['grade_overall']
      assert_equal 'immutable', graded['grades']['workflow'], 'the script carries a checksum'
      assert_equal 'immutable', graded['grades']['runtime'], 'the engine carries a checksum'
      assert_equal 'immutable', graded['grades']['inputs']
      assert_equal 'immutable', graded['grades']['environment']
      assert_equal '2/2', graded['coverage'], 'both stages declare tools of their own'
      assert_empty notes.grep(/no checksum for/), "nothing should have been left unhashed: #{notes}"
    end
  end

  # Design §9's completion mark for U1b, stated there as "omitting the
  # checksums grades floating". Measured, it is `local_path`: the workflow
  # does fall to `floating` (a script location with no commit and no
  # checksum), but the inputs fall further, to `local_path`, because a bare
  # relative path is what the plan names them by and §5 puts a path BELOW a
  # URL. The overall grade is the weakest category, so `local_path` is the
  # honest answer and the design line was one level optimistic. What §9 was
  # after holds exactly: every category that reached `immutable` through a
  # checksum drops when the checksums are not collected.
  def test_without_checksums_every_category_that_a_checksum_lifted_falls
    with_demo_computation do |dir|
      with, = write_demo(dir)
      without, notes = write_demo(dir, checksums: false)
      lifted = Predicate.grade(Bco.parse(with))
      bare = Predicate.grade(Bco.parse(without))

      assert_equal 'local_path', bare['grade_overall']
      assert_equal 'floating', bare['grades']['workflow']
      assert_equal 'versioned', bare['grades']['runtime'], 'a declared version and nothing more'
      assert_equal 'versioned', bare['grades']['environment'], 'the tools still name their versions'
      assert_equal 'local_path', bare['grades']['inputs'], 'a relative path, with nothing that names its bytes'

      %w[workflow runtime environment inputs].each do |category|
        assert_equal 'immutable', lifted['grades'][category]
        refute_equal 'immutable', bare['grades'][category], "#{category} must not stay immutable"
      end
      assert_equal 0, bare['counts']['inputs_with_checksum']
      assert_equal 3, lifted['counts']['inputs_with_checksum']
      assert_includes notes.join("\n"), '--no-checksums'
    end
  end

  # §13.4-3: an input is internal only when the bundle shows this run producing
  # it before reading it. `sum.txt` is written by stage 1 and read by stage 2,
  # so it leaves the signed denominator; a.txt, b.txt and c.txt stay in it.
  def test_the_intermediate_file_is_internal_and_leaves_the_denominator
    with_demo_computation do |dir|
      bco, = write_demo(dir)
      np = Bco.parse(bco)
      counts = Predicate.grade(np)['counts']

      assert_equal %w[a.txt b.txt c.txt], np.inputs_external.map { |i| i['name'] }.sort
      assert_equal %w[sum.txt], np.inputs_internal.map { |i| i['name'] }
      assert_equal 3, counts['inputs_total']
      assert_equal 1, counts['inputs_internal']
      assert_equal 2, counts['outputs_total']
      assert_equal 2, counts['outputs_with_checksum']
    end
  end

  # Per-stage tools go in the stage and nowhere else (§13.4-1): a copy at the
  # workflow level would become a fallback covering every stage, and the
  # coverage the claim carries would stop distinguishing the two.
  def test_per_stage_tools_never_reach_the_workflow_level
    with_demo_computation do |dir|
      bco, = write_demo(dir)
      top = bco['execution_domain']['software_prerequisites']

      assert_equal 1, top.length
      assert_equal 'sh', top.first['name']
      assert_equal %w[add.sh div.sh],
                   bco['description_domain']['pipeline_steps'].flat_map { |s| s['prerequisite'].map { |p| p['name'] } }
      assert_equal 2, Predicate.grade(Bco.parse(bco))['counts']['stages_with_own_environment']
    end
  end

  def test_the_extension_block_keys_every_checksum_by_its_own_locator
    with_demo_computation do |dir|
      bco, = write_demo(dir)
      ext = bco['extension_domain'].first['genomicschain_extension']

      assert_equal W::EXTENSION_SCHEMA, bco['extension_domain'].first['extension_schema']
      assert_equal 'gc_prov_write', ext['producer']['name']
      keyed = ext['checksums'].to_h { |c| [c['uri'], c['sha256']] }
      assert_equal %w[/bin/sh a.txt b.txt c.txt out.txt run.sh sum.txt tools/add.sh tools/div.sh],
                   keyed.keys.sort
      keyed.each_value { |sha| assert_match(/\A[0-9a-f]{64}\z/, sha) }
      assert_equal Digest::SHA256.hexdigest(File.read(File.join(dir, 'run.sh'))), keyed['run.sh']
    end
  end

  def test_a_plan_that_names_nothing_is_refused_rather_than_guessed_at
    assert_raises(W::PlanError) { W.normalise_plan({}) }
    assert_raises(W::PlanError) { W.normalise_plan('name' => 'x') }
    assert_raises(W::PlanError) { W.normalise_plan('name' => 'x', 'stages' => []) }
    assert_raises(W::PlanError) do
      W.normalise_plan('name' => 'x', 'stages' => [{ 'tools' => [{ 'version' => '1.0' }] }])
    end
    assert_raises(W::PlanError) do
      W.normalise_plan('name' => 'x', 'stages' => [{ 'step_number' => 1 }, { 'step_number' => 1 }])
    end
  end

  # A plan is a data file and a version_command in it is a command line, so
  # nothing runs until the caller says so.
  def test_version_commands_do_not_run_unless_asked
    Dir.mktmpdir('gc_prov_write') do |dir|
      plan = W.normalise_plan('name' => 'x', 'stages' => [
                                { 'tools' => [{ 'name' => 't', 'version_command' => 'echo 9.9.9' }] }
                              ])
      notes = Env.resolve!(plan, base_dir: dir, checksums: false, docker: false)['notes']
      assert_nil plan['stages'][0]['tools'][0]['version']
      assert_includes notes.join("\n"), '--run-version-commands'

      Env.resolve!(plan, base_dir: dir, checksums: false, docker: false, run_version_commands: true)
      assert_equal '9.9.9', plan['stages'][0]['tools'][0]['version']
    end
  end

  def test_a_version_banner_is_read_from_either_stream
    Dir.mktmpdir('gc_prov_write') do |dir|
      banner = Env.version_banner("#{RbConfig.ruby} --version", dir)
      assert_match(/\Aruby \d/, banner.to_s)
      assert_nil Env.version_banner('exit 3', dir)
    end
  end

  def test_an_unpinnable_image_is_written_as_declared_and_said_so
    Dir.mktmpdir('gc_prov_write') do |dir|
      plan = W.normalise_plan('name' => 'x', 'stages' => [
                                { 'tools' => [{ 'name' => 't', 'image' => 'biocontainers/seqtk:1.4' }] }
                              ])
      notes = Env.resolve!(plan, base_dir: dir, checksums: false, docker: false)['notes']
      assert_equal 'biocontainers/seqtk:1.4', plan['stages'][0]['tools'][0]['uri']
      assert_includes notes.join("\n"), 'no digest for image biocontainers/seqtk:1.4'
    end
  end

  # An unschemed, non-registry-shaped name plus a digest is indistinguishable
  # from a repo-relative path, and §5 refuses to read it as an image. The
  # writer does not prepend a scheme the customer did not write; it says why
  # the grade will not rise.
  def test_a_digest_on_a_name_that_is_not_registry_shaped_is_flagged
    Dir.mktmpdir('gc_prov_write') do |dir|
      ref = "biocontainers/seqtk:1.4@sha256:#{'a' * 64}"
      plan = W.normalise_plan('name' => 'x', 'stages' => [
                                { 'tools' => [{ 'name' => 't', 'image' => ref }] }
                              ])
      notes = Env.resolve!(plan, base_dir: dir, checksums: false, docker: false)['notes']
      assert_equal ref, plan['stages'][0]['tools'][0]['uri']
      assert_includes notes.join("\n"), 'write docker://'
      assert_equal 'floating', Predicate.container_grade(ref).first
    end
  end

  # --- the enricher's readers, on the real run artifacts ----------------------

  def test_it_reads_the_image_out_of_a_real_command_run
    text = File.read(File.join(FIXTURES, 'command_run_fastqc.sh'))
    assert_equal 'quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0', NF.image_from_command_run(text)
  end

  def test_it_refuses_a_docker_line_it_cannot_read_rather_than_naming_the_wrong_image
    assert_nil NF.image_from_command_run("docker run --some-unknown-flag /tmp/value image:1\n"),
               'an unknown value-taking flag must not let its value pass as the image'
    assert_nil NF.image_from_command_run("nxf_launch() { /bin/bash .command.sh; }\n")
    assert_nil NF.image_from_command_run("docker run -v 'unbalanced\n")
  end

  def test_it_reads_the_four_image_digests_the_run_pulled
    digests = NF.digests_from(File.read(File.join(FIXTURES, 'container_digests.txt')))

    assert_equal 4, digests.length
    assert_equal 'sha256:e194048df39c3145d9b4e0a14f4da20b59d59250465b6f2a9cb698445fd45900',
                 digests['quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0']
    assert_equal 'sha256:1ebc0043e8cafa61203bf42d29fd05bd14e7b4298e5e8cf986504c15f5aa4160',
                 digests['community.wave.seqera.io/library/cowpy:1.1.5--3db457ae1977a273']
  end

  # `docker images --digests` prints REPOSITORY and TAG as separate columns;
  # a file somebody kept by hand usually writes them joined. Both read.
  def test_it_reads_the_column_form_of_docker_images_digests_too
    text = "REPOSITORY\tTAG\tDIGEST\tIMAGE ID\tSIZE\n" \
           "quay.io/biocontainers/seqtk 1.4--he4a0461_1 sha256:#{'b' * 64} abc123 15.2MB\n"
    assert_equal({ 'quay.io/biocontainers/seqtk:1.4--he4a0461_1' => "sha256:#{'b' * 64}" },
                 NF.digests_from(text))
  end

  # Read line by line rather than through YAML: Psych turns an unquoted `1.10`
  # into the Float 1.1, and a version string losing a digit would be signed.
  def test_it_reads_tool_versions_without_letting_yaml_round_a_version
    tools = NF.tools_from_versions_yml(File.read(File.join(FIXTURES, 'nf_core_demo_software_mqc_versions.yml')))

    assert_equal [{ 'name' => 'cowpy', 'version' => '1.1.5' }], tools['COWPY']
    assert_equal [{ 'name' => 'seqtk', 'version' => '1.4-r122' }], tools['SEQTK_TRIM']
    assert_equal({ 'name' => 'Nextflow', 'version' => '26.04.6' }, tools['Workflow'].last)
    assert_nil tools['MULTIQC'], 'the fixture names no tool for MULTIQC — and the enricher must not invent one'
    assert_equal [{ 'name' => 'x', 'version' => '1.10' }], NF.tools_from_versions_yml("P:\n  x: 1.10\n")['P']
  end

  def test_it_names_the_process_a_task_belongs_to
    assert_equal 'FASTQC', NF.process_name('NFCORE_DEMO:DEMO:FASTQC (SAMPLE1_PE)')
    assert_equal 'COWPY', NF.process_name('NFCORE_DEMO:DEMO:COWPY')
  end

  def test_the_default_trace_has_no_container_column
    assert_empty NF.containers_from_trace(File.read(File.join(FIXTURES, 'execution_trace.txt'))),
                 'the default 14 columns carry no container (design §13.3)'
    text = "task_id\thash\tname\tcontainer\n1\t7a/51f65b\tFASTQC\tquay.io/biocontainers/fastqc:0.12.1\n"
    assert_equal({ '7a/51f65b' => 'quay.io/biocontainers/fastqc:0.12.1' }, NF.containers_from_trace(text))
  end

  def test_it_finds_the_work_directory_of_a_step
    bco = JSON.parse(File.read(File.join(FIXTURES, 'bco.json')))
    steps = bco['description_domain']['pipeline_steps']

    assert_equal 'work/7a/51f65ba6cac4d8e3dd04ef13e17f52', NF.work_dir_of(steps[1])
    assert_equal 'work/2d/111dbf8dfacc35bd593af90f0c82da', NF.work_dir_of(steps[0])
    assert_equal 'work/aa/bbccdd',
                 NF.work_dir_of('name' => 'x', 'output_list' => [{ 'uri' => 'work/aa/bbccdd/out.txt' }])
  end

  # --- the enricher, end to end on the real bundle ----------------------------

  # The launch directory as it would be found after a run, with the pieces the
  # fixture kept: the bundle, the versions file, and the one `.command.run`
  # that was captured. The work tree itself is gone, which is the ordinary
  # state of a run somebody comes back to later — so the enricher fills in
  # what survives and says what did not.
  def with_fixture_launch_dir
    Dir.mktmpdir('gc_prov_nf') do |dir|
      FileUtils.mkdir_p(File.join(dir, 'results', 'pipeline_info'))
      FileUtils.mkdir_p(File.join(dir, 'work', '7a', '51f65ba6cac4d8e3dd04ef13e17f52'))
      FileUtils.cp(File.join(FIXTURES, 'nf_core_demo_software_mqc_versions.yml'),
                   File.join(dir, 'results', 'pipeline_info'))
      FileUtils.cp(File.join(FIXTURES, 'command_run_fastqc.sh'),
                   File.join(dir, 'work', '7a', '51f65ba6cac4d8e3dd04ef13e17f52', '.command.run'))
      File.write(File.join(dir, 'nextflow-26.04.6-one.jar'), 'not really a jar, but bytes this machine can name')
      yield dir
    end
  end

  def enriched_fixture(dir, **overrides)
    bco = JSON.parse(File.read(File.join(FIXTURES, 'bco.json')))
    NF.read(dir, bco: bco, docker: false,
                 digest_map: NF.digests_from(File.read(File.join(FIXTURES, 'container_digests.txt'))),
                 jar_path: File.join(dir, 'nextflow-26.04.6-one.jar'), **overrides)
  end

  def test_the_unenriched_fixture_grades_absent
    graded = Predicate.grade(Bco.parse(File.read(File.join(FIXTURES, 'bco.json'))))

    assert_equal 'absent', graded['grade_overall']
    assert_equal '0/8', graded['coverage']
    assert_equal 'versioned', graded['grades']['runtime']
  end

  def test_the_enricher_writes_the_tool_and_the_digest_pinned_image_into_the_stage
    with_fixture_launch_dir do |dir|
      out = enriched_fixture(dir)
      step = out['bco']['description_domain']['pipeline_steps'].find { |s| s['step_number'] == 2 }

      assert_equal [{ 'name' => 'fastqc', 'version' => '0.12.1',
                      'uri' => { 'uri' => 'quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0@sha256:' \
                                          'e194048df39c3145d9b4e0a14f4da20b59d59250465b6f2a9cb698445fd45900' } }],
                   step['prerequisite']
      assert_equal 1, out['bco']['execution_domain']['software_prerequisites'].length,
                   'the workflow level stays the one runtime line nf-prov wrote'
    end
  end

  def test_the_enricher_lifts_the_runtime_with_the_framework_jar
    with_fixture_launch_dir do |dir|
      out = enriched_fixture(dir)
      np = Bco.parse(out['bco'])
      graded = Predicate.grade(np)

      assert_equal 'https://github.com/nextflow-io/nextflow/releases/tag/v26.04.6', np.runtime['locator']
      assert_equal Digest::SHA256.hexdigest(File.read(File.join(dir, 'nextflow-26.04.6-one.jar'))),
                   np.runtime['checksum']['sha256']
      assert_equal 'immutable', graded['grades']['runtime']
    end
  end

  # What the fixture can and cannot reach, stated as numbers. Seven of eight
  # stages get a tool from versions.yml; one stage (MULTIQC) gets nothing,
  # because the fixture's versions.yml names no tool for it and its work
  # directory is gone. The environment is the WEAKEST stage, so the bundle
  # stays `absent` overall — the enricher raised everything it could reach and
  # the one gap still decides the headline. That is the rule working, not a
  # defect in it.
  def test_the_enriched_fixture_shows_exactly_what_survived_and_what_did_not
    with_fixture_launch_dir do |dir|
      out = enriched_fixture(dir)
      graded = Predicate.grade(Bco.parse(out['bco']))

      assert_equal '7/8', graded['coverage']
      assert_equal 'immutable', graded['grades']['container'], 'the one task whose .command.run survived'
      assert_equal 'immutable', graded['stages'].find { |s| s['id'] == 2 }['grade']
      assert_equal 'versioned', graded['stages'].find { |s| s['id'] == 1 }['grade'], 'a version, no image'
      assert_equal 'absent', graded['stages'].find { |s| s['id'] == 8 }['grade'], 'MULTIQC: nothing survived'
      assert_equal 'absent', graded['grades']['environment']
      assert_equal 'absent', graded['grade_overall']
      assert_includes out['notes'].join("\n"), 'versions.yml names no tool for MULTIQC'
    end
  end

  def test_the_enricher_replaces_its_own_block_instead_of_stacking_them
    with_fixture_launch_dir do |dir|
      once = enriched_fixture(dir)['bco']
      twice = NF.read(dir, bco: once, docker: false, jar_path: File.join(dir, 'nextflow-26.04.6-one.jar'),
                           digest_map: NF.digests_from(File.read(File.join(FIXTURES, 'container_digests.txt'))))['bco']
      mine = twice['extension_domain'].count { |e| e.dig('genomicschain_extension', 'producer', 'name') == 'gc_prov_write' }

      assert_equal 1, mine
      assert_equal 1, twice['extension_domain'].count { |e| e.key?('scm_extension') },
                   'nf-prov\'s own SCM block is left alone'
      assert_equal Predicate.grade(Bco.parse(once))['grade_overall'],
                   Predicate.grade(Bco.parse(twice))['grade_overall']
      assert_equal once['description_domain']['pipeline_steps'].map { |s| s['prerequisite'] },
                   twice['description_domain']['pipeline_steps'].map { |s| s['prerequisite'] }
    end
  end

  # The other direction, on a bundle whose run directory is intact: a bundle
  # that grades `absent` before, and `immutable` after, with nothing changed
  # but what was read back out of the directory it ran in.
  def test_a_complete_run_directory_lifts_a_bundle_from_absent_to_immutable
    Dir.mktmpdir('gc_prov_nf_full') do |dir|
      FileUtils.mkdir_p(File.join(dir, 'work', 'aa', 'bbccddeeff00112233445566778899'))
      FileUtils.mkdir_p(File.join(dir, 'results', 'pipeline_info'))
      File.write(File.join(dir, 'in.txt'), "223\n")
      File.write(File.join(dir, 'nextflow-26.04.6-one.jar'), 'engine bytes')
      File.write(File.join(dir, 'results', 'pipeline_info', 'demo_versions.yml'), "TRIM:\n  seqtk: 1.4-r122\n")
      File.write(File.join(dir, 'work', 'aa', 'bbccddeeff00112233445566778899', '.command.run'),
                 "nxf_launch() {\n    docker run -i -v /a:/a -u 0:0 --name box " \
                 "quay.io/biocontainers/seqtk:1.4--he4a0461_1 /bin/bash -c \"run\"\n}\n")
      bare = thin_nextflow_bundle
      digests = { 'quay.io/biocontainers/seqtk:1.4--he4a0461_1' => "sha256:#{'c' * 64}" }

      assert_equal 'absent', Predicate.grade(Bco.parse(bare))['grade_overall']

      out = NF.read(dir, bco: bare, docker: false, digest_map: digests,
                         jar_path: File.join(dir, 'nextflow-26.04.6-one.jar'))
      graded = Predicate.grade(Bco.parse(out['bco']))

      assert_equal 'immutable', graded['grade_overall']
      assert_equal '1/1', graded['coverage']
      assert_equal 1, graded['counts']['inputs_with_checksum']
      %w[workflow runtime inputs environment container].each do |category|
        assert_equal 'immutable', graded['grades'][category], category
      end
    end
  end

  # A field the standard defines as an array, written as something else, is a
  # bundle the adapter rejects (§5, round 7). An enricher that replaced it
  # would turn that bundle into one that parses — laundering the defect the
  # boundary rule exists to surface. It is left alone and said out loud.
  def test_a_malformed_field_is_left_alone_rather_than_laundered
    bare = thin_nextflow_bundle
    bare['description_domain']['pipeline_steps'][0]['prerequisite'] = { 'name' => 'x' }
    out, refused = NF.enrich(bare, tools_by_step: { 1 => [{ 'name' => 'seqtk', 'version' => '1.4' }] })

    assert_equal({ 'name' => 'x' }, out['description_domain']['pipeline_steps'][0]['prerequisite'])
    assert_includes refused.join("\n"), 'prerequisite is not an array'
    assert_raises(Bco::FormatError) { Bco.parse(out) }

    bad = thin_nextflow_bundle.merge('extension_domain' => { 'genomicschain_extension' => {} })
    _, refused_ext = NF.enrich(bad, checksums: { 'in.txt' => { 'sha256' => 'a' * 64 } })
    assert_includes refused_ext.join("\n"), 'extension_domain is not an array'
  end

  # --- v0.1.12 §6.1: platform and ZK receipts ---------------------------------

  CLI = File.expand_path('../bin/gc_prov_write.rb', __dir__)
  ZK = File.expand_path('fixtures/zk_sizefactor_s1', __dir__)

  def cli(*args)
    out, err, status = Open3.capture3(RbConfig.ruby, CLI, *args)
    assert status.success?, "gc_prov_write failed: #{err}"
    [JSON.parse(out), err]
  end

  def extension(bco)
    bco['extension_domain'].find { |e| e.key?('genomicschain_extension') }['genomicschain_extension']
  end

  def test_the_platform_names_the_machine_and_never_the_host
    p = Env.platform(uname: { sysname: 'Linux', nodename: 'lab-host-07', release: '6.8.0-1012-aws',
                              version: '#1 SMP', machine: 'x86_64' })
    assert_equal({ 'cpu_architecture' => 'x86_64', 'os_name' => 'Linux', 'os_release' => '6.8.0-1012-aws' }, p)
    refute_includes p.values, 'lab-host-07'
    assert_equal %w[cpu_architecture os_name os_release], Env.platform.keys, 'this machine answers all three'
  end

  # --plan records this machine by default (the writer usually runs where the
  # stages ran); a plan's own statement wins; --no-platform leaves it out.
  def test_a_plan_records_the_platform_unless_told_otherwise
    with_demo_computation do |dir|
      plan_path = File.join(dir, 'plan.json')
      File.write(plan_path, JSON.generate(demo_plan))
      bco, = cli('--plan', plan_path, '--no-docker', '--no-grade')
      assert_equal Env.platform, extension(bco)['platform']
      assert_equal Env.platform, Bco.parse(bco).platform

      bco, = cli('--plan', plan_path, '--no-docker', '--no-grade', '--no-platform')
      refute extension(bco).key?('platform')

      stated = { 'cpu_architecture' => 'x86_64', 'os_name' => 'Linux', 'os_release' => '5.15.0' }
      File.write(plan_path, JSON.generate(demo_plan.merge('platform' => stated)))
      bco, = cli('--plan', plan_path, '--no-docker', '--no-grade')
      assert_equal stated, extension(bco)['platform']
    end
  end

  # The enricher may run on a head node while the tasks ran elsewhere, so it
  # writes a platform only when asked (§6.1 (2): never invent a value).
  def test_the_enricher_records_a_platform_only_when_asked
    with_fixture_launch_dir do |dir|
      File.write(File.join(dir, 'bco.json'), File.read(File.join(FIXTURES, 'bco.json')))
      digests = File.join(FIXTURES, 'container_digests.txt')
      jar = File.join(dir, 'nextflow-26.04.6-one.jar')
      bco, err = cli('--from-nextflow-run', dir, '--no-docker', '--container-digests', digests, '--nextflow-jar', jar)
      refute extension(bco).key?('platform')
      assert_includes err, 'no platform recorded: pass --platform-of-this-machine'

      bco, = cli('--from-nextflow-run', dir, '--no-docker', '--container-digests', digests, '--nextflow-jar', jar,
                 '--platform-of-this-machine')
      assert_equal Env.platform, extension(bco)['platform']
    end
  end

  # A receipt named in the plan becomes a declaration carrying the SHA-256 of
  # the receipt file as found here; the adapter reads it back with no defect
  # because the step, its input and its output all carry checksums.
  def test_a_receipt_in_the_plan_is_declared_with_the_digest_of_its_file
    with_demo_computation do |dir|
      FileUtils.cp(File.join(ZK, 'receipt.succinct.bin'), File.join(dir, 'receipt.bin'))
      image_id = File.read(File.join(ZK, 'image_id.txt')).strip
      raw = demo_plan.merge('zk_receipts' => [{ 'receipt' => 'receipt.bin', 'image_id' => image_id.upcase,
                                                'zkvm_version' => '3.0.6', 'step_number' => 2,
                                                'input' => 'sum.txt', 'output' => 'out.txt' }])
      plan = W.normalise_plan(raw)
      resolved = Env.resolve!(plan, base_dir: dir, docker: false)
      zk = Env.zk_declarations(plan['zk_receipts'], base_dir: dir)
      bco = W.build(plan, checksums: resolved['checksums'], zk_receipts: zk['zk_receipts'])

      decl = extension(bco)['zk_receipts'].first
      assert_equal Digest::SHA256.file(File.join(dir, 'receipt.bin')).hexdigest, decl['sha256']
      assert_equal image_id, decl['image_id'], 'the image ID is written lower-case'
      assert_equal({ 'name' => 'risc0-zkvm', 'version' => '3.0.6' }, decl['zkvm'])
      assert_equal 'gc-zk-journal-0.1', decl['journal']
      read = Bco.parse(bco).zk_receipts.first
      assert_empty read['defects']
      assert_equal 2, read['stage']

      FileUtils.rm(File.join(dir, 'receipt.bin'))
      gone = Env.zk_declarations(plan['zk_receipts'], base_dir: dir)
      assert_empty gone['zk_receipts'], 'no file, no digest, no declaration'
      assert_includes gone['notes'].join, 'is not a readable file'
    end
  end

  def test_a_receipt_entry_missing_a_field_is_refused_in_the_plan
    err = assert_raises(W::PlanError) do
      W.normalise_plan(demo_plan.merge('zk_receipts' => [{ 'receipt' => 'r.bin', 'image_id' => 'a' * 64,
                                                           'step_number' => 1, 'input' => 'a.txt' }]))
    end
    assert_match(/zkvm_version, output/, err.message)
    assert_raises(W::PlanError) do
      W.normalise_plan(demo_plan.merge('zk_receipts' => [{ 'receipt' => 'r.bin', 'image_id' => 'not-hex',
                                                           'zkvm_version' => '3.0.6', 'step_number' => 1,
                                                           'input' => 'a.txt', 'output' => 'b.txt' }]))
    end
  end

  # Shaped like what nf-prov 1.7.0 actually emits (design §13.1): an SCM
  # extension, one runtime line, URIs, and no checksum, tool or container
  # anywhere.
  def thin_nextflow_bundle
    {
      'object_id' => 'urn:uuid:11111111-1111-4111-8111-111111111111',
      'spec_version' => W::SPEC_VERSION,
      'etag' => 'x',
      'provenance_domain' => { 'name' => 'demo', 'version' => '1.0.0' },
      'extension_domain' => [{
        'extension_schema' => 'https://w3id.org/biocompute/extension_domain/1.1.0/scm/scm_extension.json',
        'scm_extension' => { 'scm_repository' => 'https://example.org/demo', 'scm_type' => 'git',
                             'scm_commit' => '0' * 40, 'scm_path' => 'main.nf' }
      }],
      'description_domain' => {
        'keywords' => [],
        'pipeline_steps' => [{
          'step_number' => 1, 'name' => 'aabbccddeeff00112233445566778899',
          'description' => 'DEMO:TRIM (S1)',
          'input_list' => [{ 'uri' => 'in.txt' }],
          'output_list' => [{ 'uri' => 'work/aa/bbccddeeff00112233445566778899/out.txt' }]
        }]
      },
      'execution_domain' => {
        'script' => ['https://example.org/demo/main.nf'],
        'script_driver' => 'nextflow',
        'software_prerequisites' => [{
          'name' => 'Nextflow', 'version' => '26.04.6',
          'uri' => { 'uri' => 'https://github.com/nextflow-io/nextflow/releases/tag/v26.04.6' }
        }],
        'external_data_endpoints' => [], 'environment_variables' => {}
      },
      'parametric_domain' => [],
      'io_domain' => {
        'input_subdomain' => [{ 'uri' => { 'uri' => 'in.txt' } }],
        'output_subdomain' => []
      },
      'error_domain' => {}
    }
  end
end
