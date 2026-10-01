# frozen_string_literal: true

# Unit S3, part A of the self-application design: scripts/selfapp/make_variants.rb
# writes each variant as its base plus exactly the spec'd change, and stops with
# nothing written when the spec and the base disagree.
#
#   bundle exec ruby selfapp/test/variants_test.rb
#
# Runs on a small temporary fixture, never on the real subject (INV-S2 concerns
# checkers, not this script, but the subject is not needed to test the copier).

require 'minitest/autorun'
require 'digest'
require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'
require 'fileutils'

class VariantsTest < Minitest::Test
  SCRIPT = File.expand_path('../../scripts/selfapp/make_variants.rb', __dir__)
  NOTICE = '# SYNTHETIC — FICTIONAL STUDY. fixture'

  def setup
    @root = Dir.mktmpdir('variants_test')
    write('base/doc.md', "#{NOTICE}\n## Methods\nref R3 here\n## Results\nref R3 there\nalpha alpha\n")
    write('base/sub/table.tsv', "id\tv\nA\t1\n")
    write('base/.hidden', "dot file\n")
    write('record.json', "{}\n")
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def write(rel, text)
    path = File.join(@root, rel)
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, text)
  end

  def tree(dir)
    Dir.glob('**/*', File::FNM_DOTMATCH, base: dir)
       .select { |r| File.file?(File.join(dir, r)) && !File.symlink?(File.join(dir, r)) }
       .sort_by(&:b)
       .to_h { |r| [r, Digest::SHA256.file(File.join(dir, r)).hexdigest] }
  end

  def tree_sha256(dir)
    Digest::SHA256.hexdigest(tree(dir).map { |r, s| "#{s}  #{r}\n" }.join)
  end

  def spec(variants, base_sha: nil)
    {
      'base' => { 'id' => 'V0', 'path' => 'base', 'tree_sha256' => base_sha || tree_sha256(File.join(@root, 'base')) },
      'output_root' => 'out',
      'variants' => variants
    }
  end

  def good_variant
    { 'id' => 'V1', 'changes' => [{ 'path' => 'sub/table.tsv',
                                     'edits' => [{ 'before' => "A\t1\n", 'after' => "A\t2\n", 'occurrences' => 1 }] }] }
  end

  def run_script(spec_hash)
    spec_path = File.join(@root, 'spec.json')
    File.write(spec_path, JSON.generate(spec_hash))
    _out, err, status = Open3.capture3(RbConfig.ruby, SCRIPT, '--spec', spec_path, '--root', @root)
    [status, err]
  end

  def out
    File.join(@root, 'out')
  end

  def test_wrong_occurrence_count_stops_with_nothing_written
    bad = { 'id' => 'V2', 'changes' => [{ 'path' => 'doc.md',
                                          'edits' => [{ 'before' => 'alpha', 'after' => 'beta', 'occurrences' => 1 }] }] }
    status, err = run_script(spec([good_variant, bad]))
    refute status.success?, 'an anchor found twice where the spec says once must stop the run'
    assert_match(/occurs 2 times, expected 1/, err)
    refute File.exist?(out), 'the valid V1 must not be written either'
  end

  def test_variant_differs_from_base_only_in_the_named_file
    status, err = run_script(spec([good_variant, { 'id' => 'V6', 'changes' => [],
                                                   'execution_record' => { 'path' => 'record.json',
                                                                           'sha256' => Digest::SHA256.hexdigest("{}\n") } }]))
    assert status.success?, err
    base = tree(File.join(@root, 'base'))
    v1 = tree(File.join(out, 'V1'))
    assert_equal base.keys, v1.keys, 'same layout, dot file included'
    assert_equal ['sub/table.tsv'], base.keys.reject { |k| base[k] == v1[k] }
    assert_equal "id\tv\nA\t2\n", File.binread(File.join(out, 'V1/sub/table.tsv'))
    assert_equal tree_sha256(File.join(@root, 'base')), tree_sha256(File.join(out, 'V6')), 'a variant without changes is the base'
  end

  def test_within_limits_the_edit_to_its_section
    v = { 'id' => 'V1', 'changes' => [{ 'path' => 'doc.md', 'edits' => [
      { 'within' => { 'from' => "\n## Methods\n", 'to' => "\n## Results\n" }, 'before' => 'R3', 'after' => 'R', 'occurrences' => 1 }] }] }
    status, err = run_script(spec([v]))
    assert status.success?, err
    assert_equal "#{NOTICE}\n## Methods\nref R here\n## Results\nref R3 there\nalpha alpha\n".b, File.binread(File.join(out, 'V1/doc.md'))
  end

  def test_existing_output_dir_stops
    FileUtils.mkdir_p(File.join(out, 'V1'))
    status, err = run_script(spec([good_variant]))
    refute status.success?
    assert_match(/already exists/, err)
    assert_empty Dir.children(File.join(out, 'V1')), 'the existing directory is left as it was'
  end

  def test_base_tree_hash_mismatch_stops
    status, err = run_script(spec([good_variant], base_sha: '0' * 64))
    refute status.success?
    assert_match(/base tree sha256/, err)
    refute File.exist?(out)
  end

  def test_execution_record_with_another_hash_stops
    v6 = { 'id' => 'V6', 'changes' => [], 'execution_record' => { 'path' => 'record.json', 'sha256' => '0' * 64 } }
    status, err = run_script(spec([good_variant, v6]))
    refute status.success?
    assert_match(/execution record sha256/, err)
    refute File.exist?(out)
  end
end
