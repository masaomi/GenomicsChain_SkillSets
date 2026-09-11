# frozen_string_literal: true

# gc_tier2_scan's two ways in. The `path` mode is what scanner_test.rb covers
# through the library; this suite is about the `files` mode added 2026-09-11 for
# callers that cannot put bytes on this machine's disk, and about the two
# properties it must keep: the same repository gives the same evidence digest
# either way, and nothing of the upload outlives the call.
require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'json'

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'kairos_mcp/version'
require 'kairos_mcp/tools/base_tool'
require 'genomicschain_tier2'
require_relative '../tools/gc_tier2_scan'

class GcTier2ScanToolTest < Minitest::Test
  TOOL = KairosMcp::SkillSets::GenomicschainTier2::Tools::GcTier2Scan

  REPO = {
    'workflow/Snakefile' => %(container: "docker://continuumio/miniconda3:4.12.0"\n),
    'workflow/envs/align.yaml' => "channels:\n  - bioconda\ndependencies:\n  - samtools=1.17\n  - pandas\n",
    'config/config.yaml' => "reference: /data/ref/hg38.fa\n",
    'README.md' => "Data: https://doi.org/10.6084/m9.figshare.1\n",
    'scripts/run.py' => "print('not scanned')\n"
  }.freeze

  def payload(response)
    JSON.parse(response.first[:text])
  end

  def text(response)
    response.first[:text]
  end

  def files
    REPO.map { |path, content| { 'path' => path, 'content' => content } }
  end

  def with_checkout
    Dir.mktmpdir do |dir|
      REPO.each do |rel, content|
        abs = File.join(dir, rel)
        FileUtils.mkdir_p(File.dirname(abs))
        File.write(abs, content)
      end
      yield dir
    end
  end

  def test_files_mode_gives_the_same_evidence_digest_as_a_checkout
    from_files = payload(TOOL.new.call('files' => files, 'include_declarations' => true))
    from_disk = with_checkout { |dir| payload(TOOL.new.call('path' => dir, 'include_declarations' => true)) }

    assert_equal from_disk.dig('target', 'evidence_digest'), from_files.dig('target', 'evidence_digest')
    assert_equal from_disk['counts_by_pin'], from_files['counts_by_pin']
    assert_equal from_disk['declarations'].length, from_files['declarations'].length
  end

  def test_files_mode_reports_the_label_not_the_temporary_directory
    report = payload(TOOL.new.call('files' => files, 'label' => 'pipeline.zip'))
    assert_equal 'pipeline.zip', report.dig('target', 'root')
    assert_equal 'files', report.dig('target', 'source')
    assert_equal REPO.length, report.dig('target', 'files_received')
    refute_match(/gc_tier2_scan/, report.dig('target', 'root'), 'tmpdir leaked into the report')
  end

  def test_files_mode_default_label
    assert_equal 'uploaded files', payload(TOOL.new.call('files' => files)).dig('target', 'root')
  end

  def test_nothing_of_the_upload_outlives_the_call
    before = Dir.glob(File.join(Dir.tmpdir, 'gc_tier2_scan*'))
    TOOL.new.call('files' => files)
    assert_equal before.sort, Dir.glob(File.join(Dir.tmpdir, 'gc_tier2_scan*')).sort
  end

  def test_temporary_directory_is_removed_even_when_the_scanner_fails
    scanner = ::GenomicsChainTier2::Scanner
    scanner.class_eval { alias_method :__scan_orig, :scan; def scan = raise('boom') }
    before = Dir.glob(File.join(Dir.tmpdir, 'gc_tier2_scan*'))
    response = TOOL.new.call('files' => files)
    assert_match(/\AError: gc_tier2_scan failed/, text(response))
    assert_equal before.sort, Dir.glob(File.join(Dir.tmpdir, 'gc_tier2_scan*')).sort
  ensure
    scanner.class_eval { alias_method :scan, :__scan_orig; remove_method :__scan_orig }
  end

  # --- refusals; each one is checked before anything is written ---

  def test_rejects_paths_that_escape_the_temporary_directory
    ['../etc/passwd', '/etc/passwd', 'a/../../b', 'C:\\x.yml', "a\0b.yml"].each do |bad|
      response = TOOL.new.call('files' => [{ 'path' => bad, 'content' => 'x' }])
      assert_match(/\AError: files\[0\]\.path/, text(response), "accepted #{bad.inspect}")
    end
  end

  def test_rejects_both_modes_at_once_and_neither
    assert_match(/either path or files/, text(TOOL.new.call('path' => '/tmp', 'files' => files)))
    assert_match(/one of path or files is required/, text(TOOL.new.call({})))
  end

  def test_rejects_malformed_entries
    assert_match(/non-empty array/, text(TOOL.new.call('files' => [])))
    assert_match(/non-empty array/, text(TOOL.new.call('files' => 'nope')))
    assert_match(/files\[0\] is not an object/, text(TOOL.new.call('files' => ['x'])))
    assert_match(/files\[0\]\.path is empty/, text(TOOL.new.call('files' => [{ 'content' => 'x' }])))
    assert_match(/content is not a string/, text(TOOL.new.call('files' => [{ 'path' => 'a.yml', 'content' => 1 }])))
  end

  def test_rejects_an_oversized_upload
    big = [{ 'path' => 'a.md', 'content' => 'x' * (TOOL::MAX_TOTAL_BYTES + 1) }]
    assert_match(/exceeds the .*-byte limit/, text(TOOL.new.call('files' => big)))
  end

  def test_symbol_keys_are_accepted
    report = payload(TOOL.new.call(files: [{ path: 'env.yaml', content: "dependencies:\n  - bwa=0.7.17\n" }]))
    assert_equal 1, report.dig('target', 'files_parsed')
  end
end
