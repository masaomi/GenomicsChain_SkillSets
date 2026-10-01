#!/usr/bin/env ruby
# frozen_string_literal: true

# Unit S3, part A of docs/design/self_application_design_v0_1.md (§5): write the
# planted-fault variants V1-V8 of the fictional RNA-seq subject from V0 and the
# variant specification selfapp/variants_v1.json.
#
#   ruby scripts/selfapp/make_variants.rb [--spec PATH] [--root DIR]
#
# Paths in the spec (base, output_root, execution records) are relative to
# --root, which defaults to the repository this script lives in.
#
# Each variant is a full copy of the base with exactly the spec's change applied.
# The whole run is planned in memory before the first byte is written, so any
# of these stops it with nothing written:
#   - the base's tree sha256 differs from the spec (the variants would be of
#     some other V0), or the base holds a symlink or special file (a copy would
#     not be full);
#   - an anchor occurs a number of times other than the spec states;
#   - a variant's output directory already exists;
#   - an execution record the spec names is missing or has another sha256.
#
# Standard library only. It reads and copies files; it runs no checker (INV-S2).

require 'digest'
require 'fileutils'
require 'json'
require 'optparse'

module MakeVariants
  class SpecError < StandardError; end

  module_function

  # Every regular file under dir, dot files included, symlinks not followed, as
  # [[relpath, sha256], ...] sorted bytewise by relpath. Reimplements the S-1
  # rule (log/selfapp/s_minus_1/record.json) rather than requiring the DDC code.
  def tree_files(dir)
    Dir.glob('**/*', File::FNM_DOTMATCH, base: dir)
       .select { |rel| path = File.join(dir, rel); File.file?(path) && !File.symlink?(path) }
       .sort_by(&:b)
       .map { |rel| [rel, Digest::SHA256.file(File.join(dir, rel)).hexdigest] }
  end

  def tree_sha256(files)
    Digest::SHA256.hexdigest(files.map { |rel, sha| "#{sha}  #{rel}\n" }.join)
  end

  # Entries a byte-for-byte copy of regular files would silently drop.
  def uncopyable(dir)
    Dir.glob('**/*', File::FNM_DOTMATCH, base: dir).reject do |rel|
      next true if ['.', '..'].include?(File.basename(rel))

      path = File.join(dir, rel)
      !File.symlink?(path) && (File.file?(path) || File.directory?(path))
    end
  end

  def read_utf8(path)
    text = File.binread(path).force_encoding(Encoding::UTF_8)
    raise SpecError, "#{path}: not valid UTF-8" unless text.valid_encoding?

    text
  end

  def occurrences(haystack, needle)
    haystack.scan(needle).size
  end

  # Apply one edit to text; `where` names it in error messages.
  def apply_edit(text, edit, where)
    before = edit.fetch('before')
    after = edit.fetch('after')
    want = Integer(edit.fetch('occurrences'))
    raise SpecError, "#{where}: empty anchor" if before.empty?
    raise SpecError, "#{where}: occurrences must be at least 1" if want < 1
    raise SpecError, "#{where}: before and after are identical" if before == after

    head = +''
    region = text
    tail = +''
    if (scope = edit['within'])
      from = scope.fetch('from')
      to = scope.fetch('to')
      [from, to].each do |a|
        n = occurrences(text, a)
        raise SpecError, "#{where}: scope anchor #{a.inspect} occurs #{n} times, expected 1" unless n == 1
      end
      start = text.index(from) + from.length
      stop = text.index(to)
      raise SpecError, "#{where}: scope end #{to.inspect} precedes scope start #{from.inspect}" if stop < start

      head = text[0...start]
      region = text[start...stop]
      tail = text[stop..]
    end

    n = occurrences(region, before)
    raise SpecError, "#{where}: anchor #{before.inspect} occurs #{n} times, expected #{want}" unless n == want

    head + region.gsub(before) { after } + tail
  end

  # Everything the run will write, computed without writing: [[id, out_dir, {relpath => new text}], ...]
  def plan(spec, root)
    base = spec.fetch('base')
    base_dir = File.join(root, base.fetch('path'))
    raise SpecError, "base #{base_dir} is not a directory" unless File.directory?(base_dir)

    odd = uncopyable(base_dir)
    raise SpecError, "base holds entries that are not regular files or directories: #{odd.join(', ')}" unless odd.empty?

    base_files = tree_files(base_dir)
    got = tree_sha256(base_files)
    raise SpecError, "base tree sha256 is #{got}, spec says #{base.fetch('tree_sha256')}" unless got == base.fetch('tree_sha256')

    known = base_files.map(&:first)
    out_root = File.join(root, spec.fetch('output_root'))
    ids = spec.fetch('variants').map { |v| v.fetch('id') }
    raise SpecError, "variant ids are not unique: #{ids.inspect}" unless ids.uniq.size == ids.size

    spec.fetch('variants').map do |variant|
      id = variant.fetch('id')
      raise SpecError, "bad variant id #{id.inspect}" unless id.match?(/\AV\d+\z/)

      out_dir = File.join(out_root, id)
      raise SpecError, "#{id}: output directory #{out_dir} already exists" if File.exist?(out_dir) || File.symlink?(out_dir)

      if (rec = variant['execution_record'])
        path = File.join(root, rec.fetch('path'))
        raise SpecError, "#{id}: execution record #{path} is missing" unless File.file?(path)

        sha = Digest::SHA256.file(path).hexdigest
        raise SpecError, "#{id}: execution record sha256 is #{sha}, spec says #{rec.fetch('sha256')}" unless sha == rec.fetch('sha256')
      end

      paths = variant.fetch('changes').map { |c| c.fetch('path') }
      raise SpecError, "#{id}: a file is named by more than one change" unless paths.uniq.size == paths.size

      changed = variant.fetch('changes').to_h do |change|
        rel = change.fetch('path')
        raise SpecError, "#{id}: #{rel} is not a file of the base" unless known.include?(rel)

        original = read_utf8(File.join(base_dir, rel))
        edits = change.fetch('edits')
        raise SpecError, "#{id}: #{rel} has no edits" if edits.empty?

        text = edits.each_with_index.reduce(original) do |acc, (edit, i)|
          apply_edit(acc, edit, "#{id} #{rel} edit #{i + 1}")
        end
        raise SpecError, "#{id}: #{rel} is unchanged after its edits" if text == original

        [rel, text]
      end
      [id, out_dir, changed]
    end
  end

  def write(spec, root, planned)
    base_dir = File.join(root, spec.fetch('base').fetch('path'))
    base_files = tree_files(base_dir).map(&:first)
    planned.each do |id, out_dir, changed|
      base_files.each do |rel|
        src = File.join(base_dir, rel)
        dst = File.join(out_dir, rel)
        FileUtils.mkdir_p(File.dirname(dst))
        if changed.key?(rel)
          File.binwrite(dst, changed[rel])
        else
          FileUtils.copy_file(src, dst)
        end
        File.chmod(File.stat(src).mode & 0o7777, dst)
      end
      yield id, out_dir if block_given?
    end
  end

  def run(argv)
    spec_path = nil
    root = File.expand_path('../..', __dir__)
    OptionParser.new do |o|
      o.on('--spec PATH') { |v| spec_path = v }
      o.on('--root DIR') { |v| root = File.expand_path(v) }
    end.parse!(argv)
    spec_path ||= File.join(root, 'selfapp/variants_v1.json')

    spec = JSON.parse(File.read(spec_path))
    planned = plan(spec, root)
    write(spec, root, planned) do |id, out_dir|
      files = tree_files(out_dir)
      puts "#{id}  #{tree_sha256(files)}  #{files.size} files  #{out_dir}"
    end
    0
  rescue SpecError, KeyError, JSON::ParserError, ArgumentError, TypeError => e
    warn "make_variants: #{e.message} -- nothing written"
    1
  end
end

exit(MakeVariants.run(ARGV.dup)) if $PROGRAM_NAME == __FILE__
