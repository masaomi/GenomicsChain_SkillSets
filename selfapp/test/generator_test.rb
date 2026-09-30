# frozen_string_literal: true

# Unit S1 of the self-application design: the generator is deterministic, the
# subject is labelled fictional throughout, and the answer key stays outside it.
#
#   ruby -Iselfapp/generator/lib selfapp/test/generator_test.rb

require 'minitest/autorun'
require 'json'
require 'tmpdir'
require 'zlib'
require_relative '../generator/lib/synthetic_rnaseq'

class GeneratorTest < Minitest::Test
  PINS = JSON.parse(File.read(File.expand_path('fixtures/pins_fixture.json', __dir__)))
  LOCK = File.binread(File.expand_path('fixtures/rnaseq_fixture.lock', __dir__))
  SMALL = 1500

  HUMAN_FACING = %w[
    synthetic_manuscript.md
    synthetic_repo/README.md
    synthetic_repo/Snakefile
    synthetic_repo/config/config.yaml
    synthetic_repo/config/samples.tsv
    synthetic_repo/envs/rnaseq.yml
    synthetic_repo/Dockerfile
    synthetic_repo/scripts/tximport.R
    synthetic_repo/scripts/deseq2.R
  ].freeze

  def generate(dir, seed: 20_260_929, pins: PINS)
    SyntheticRnaseq::Generator.new(seed: seed, pins: pins, lock: LOCK, out: dir, reads_per_sample: SMALL).run
  end

  def subject(dir) = File.join(dir, SyntheticRnaseq::SUBJECT_DIR)

  def with_subject(seed: 20_260_929)
    Dir.mktmpdir('selfapp') do |dir|
      manifest = generate(dir, seed: seed)
      yield dir, manifest
    end
  end

  def test_same_seed_same_bytes
    Dir.mktmpdir('a') do |a|
      Dir.mktmpdir('b') do |b|
        ma = generate(a)
        mb = generate(b)
        assert_equal ma[:subject_tree_sha256], mb[:subject_tree_sha256]
        assert_equal ma[:files], mb[:files]
        assert_equal ma[:truth][:sha256], mb[:truth][:sha256]
        assert_equal File.binread(File.join(subject(a), 'generator_manifest.json')),
                     File.binread(File.join(subject(b), 'generator_manifest.json'))
      end
    end
  end

  def test_another_seed_gives_other_reads
    Dir.mktmpdir('a') do |a|
      Dir.mktmpdir('b') do |b|
        refute_equal generate(a)[:subject_tree_sha256], generate(b, seed: 20_260_930)[:subject_tree_sha256]
      end
    end
  end

  def test_every_human_facing_file_opens_with_the_notice
    with_subject do |dir, _|
      HUMAN_FACING.each do |rel|
        first = File.foreach(File.join(subject(dir), rel)).first
        assert_includes first, SyntheticRnaseq::NOTICE, rel
      end
      assert_includes File.read(File.join(subject(dir), 'synthetic_repo/Dockerfile')), 'LABEL org.genomicschain.synthetic='
    end
  end

  def test_answer_key_is_outside_the_subject
    with_subject do |dir, manifest|
      truth = File.join(dir, SyntheticRnaseq::TRUTH_FILE)
      assert File.file?(truth)
      refute manifest[:files].any? { |f| f[:path].include?('truth') }
      key = JSON.parse(File.read(truth))
      de = key['de_genes']
      assert_equal 20, de.length
      assert_equal 10, de.count { |g| g['log2fc'].positive? }
      assert(de.all? { |g| g['log2fc'].abs.between?(1.0, 3.0) })
      # No log2fc of the key appears in any text file of the subject.
      texts = HUMAN_FACING.map { |rel| File.read(File.join(subject(dir), rel)) }.join
      de.each { |g| refute_includes texts, format('%.3f', g['log2fc']) }
    end
  end

  def test_identifiers_are_fictional_and_no_doi_shape_appears
    with_subject do |dir, _|
      s = subject(dir)
      ref = File.join(s, 'synthetic_repo/data/synthetic_reference')
      headers = File.foreach(File.join(ref, 'synthetic_SynthRef_r3.transcripts.fa')).grep(/\A>/)
      assert(headers.all? { |h| h.match?(/\A>SYNT\d{4}\.1 gene=SYN\d{4}\n\z/) })
      assert_includes 300..400, headers.length
      genes = File.foreach(File.join(ref, 'synthetic_SynthRef_r3.tx2gene.tsv')).drop(1).map { |l| l.split("\t")[1].strip }
      assert_equal 200, genes.uniq.length

      Dir.glob('**/*', base: s).each do |rel|
        path = File.join(s, rel)
        next unless File.file?(path) && !rel.end_with?('.gz', '.fa')

        refute_match(%r{\b10\.\d{4,9}/\S+}, File.read(path), "DOI-shaped string in #{rel}")
      end
    end
  end

  def test_reads_are_gzip_with_a_zero_mtime_and_synth_names
    with_subject do |dir, _|
      truth = JSON.parse(File.read(File.join(dir, SyntheticRnaseq::TRUTH_FILE)))
      truth['samples'].each do |smp|
        path = File.join(subject(dir), "synthetic_repo/data/synthetic_reads/synthetic_#{smp['sample']}.fastq.gz")
        header = File.binread(path, 10).bytes
        assert_equal [0, 0, 0, 0], header[4, 4], 'gzip mtime must be 0'
        lines = Zlib::GzipReader.open(path, &:readlines)
        assert_equal smp['realised_reads'] * 4, lines.length
        names = lines.each_slice(4).map(&:first)
        assert(names.all? { |n| n.match?(/\A@SYNTH_S0[1-6]_\d{6}\n\z/) })
        assert(lines.each_slice(4).all? { |(_, seq, _, qual)| seq.length == 101 && qual.length == 101 })
      end
    end
  end

  # §4.3 V0 conditions that Tier 2 would otherwise score as floating.
  def test_v0_declares_nothing_tier2_scores_floating
    with_subject do |dir, _|
      repo = File.join(subject(dir), 'synthetic_repo')
      deps = File.read(File.join(repo, 'envs/rnaseq.yml')).lines.grep(/\A\s+- /).drop(3)
      refute_empty deps
      assert(deps.all? { |d| d.strip.delete_prefix('- ').count('=') == 2 }, deps.inspect)
      containers = File.read(File.join(repo, 'Snakefile')).lines.grep(/\A\s*container:/)
      assert_equal 6, containers.length
      assert(containers.all? { |c| c.match?(/@sha256:[0-9a-f]{64}"\s*\z/) })
      assert_match(/^FROM \S+@sha256:[0-9a-f]{64}$/, File.read(File.join(repo, 'Dockerfile')))
      refute_match(%r{https?://}, File.read(File.join(repo, 'config/config.yaml')))
      lock = File.binread(File.join(repo, 'envs/rnaseq.lock'))
      assert_equal LOCK, lock, 'the Dockerfile installs from envs/rnaseq.lock'
      assert(lock.lines.grep(%r{\Ahttps?://}).all? { |l| l.include?('#') })
    end
  end

  def test_a_missing_rule_container_stops_generation
    pins = PINS.merge('rule_containers' => PINS['rule_containers'].except('trim'))
    Dir.mktmpdir('x') { |dir| assert_raises(KeyError) { generate(dir, pins: pins) } }
  end

  # A fresh Linux container runs with LANG=C, where Ruby reads files as US-ASCII.
  def test_generates_under_a_c_locale
    old = Encoding.default_external
    Encoding.default_external = Encoding::US_ASCII
    with_subject { |dir, _| assert File.file?(File.join(subject(dir), 'synthetic_repo/README.md')) }
  ensure
    Encoding.default_external = old
  end

  def test_refuses_to_overwrite_a_subject
    Dir.mktmpdir('x') do |dir|
      generate(dir)
      assert_raises(RuntimeError) { generate(dir) }
    end
  end
end
