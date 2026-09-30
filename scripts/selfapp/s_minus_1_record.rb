#!/usr/bin/env ruby
# frozen_string_literal: true

# S-1 of the self-application design (docs/design/self_application_design_v0_1.md
# §6.1, §10): record the installed checker copies as they are BEFORE anything is
# reinstalled, together with the HEAD commit and the difference between each
# installed copy and the same package at HEAD. Record only: this script reads the
# installed tree and the git object store and writes into --out; it never touches
# .kairos/skillsets.
#
# Hashing rule (stated in the record so a stranger can redo it by hand):
#   - every regular file under the package directory, dot files included,
#     path relative to the package directory;
#   - lines "<sha256 hex>  <relative path>\n", sorted bytewise by path
#     (the output of `find . -type f | LC_ALL=C sort | xargs sha256sum` with the
#     leading "./" removed);
#   - tree hash = sha256 of the concatenated lines.
# The HEAD side reads blobs through `git ls-tree` / `git cat-file`, so
# .gitattributes export rules do not apply. Symlinks are listed, not followed.
#
# Usage: ruby scripts/selfapp/s_minus_1_record.rb [--out log/selfapp/s_minus_1]

require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'optparse'
require 'time'

PACKAGES = %w[genomicschain_core genomicschain_tier1 genomicschain_tier2 genomicschain_tier3].freeze
# Source packages that exist at HEAD but may be absent from the install.
ALSO_CHECK_ABSENT = %w[genomicschain_prov genomicschain_regwatch].freeze
INSTALL_ROOT = '.kairos/skillsets'

def git(*args)
  out, err, st = Open3.capture3('git', *args, binmode: true)
  raise "git #{args.join(' ')} failed: #{err}" unless st.success?

  out
end

def manifest_lines(entries)
  entries.sort_by { |e| e[:path].b }.map { |e| "#{e[:sha256]}  #{e[:path]}\n" }.join
end

def installed_entries(dir)
  files = []
  symlinks = []
  Dir.glob('**/*', File::FNM_DOTMATCH, base: dir).each do |rel|
    next if rel.end_with?('/.', '/..') || rel == '.' || rel == '..'

    full = File.join(dir, rel)
    if File.symlink?(full)
      symlinks << { path: rel, target: File.readlink(full) }
    elsif File.file?(full)
      files << { path: rel, sha256: Digest::SHA256.file(full).hexdigest, size: File.size(full) }
    end
  end
  [files, symlinks]
end

def head_entries(commit, pkg)
  raw = git('ls-tree', '-r', '-z', '--full-tree', commit, '--', pkg)
  raw.split("\0").map do |line|
    meta, path = line.split("\t", 2)
    mode, type, oid = meta.split(' ')
    next unless type == 'blob'

    rel = path.delete_prefix("#{pkg}/")
    if mode == '120000'
      { path: rel, symlink_target: git('cat-file', 'blob', oid).force_encoding('UTF-8') }
    else
      blob = git('cat-file', 'blob', oid)
      { path: rel, sha256: Digest::SHA256.hexdigest(blob), size: blob.bytesize }
    end
  end.compact
end

def version_of(json_text)
  JSON.parse(json_text)['version']
rescue JSON::ParserError, TypeError
  nil
end

opts = { out: 'log/selfapp/s_minus_1' }
OptionParser.new { |o| o.on('--out DIR') { |v| opts[:out] = v } }.parse!

abort 'run from the repository root' unless File.directory?(INSTALL_ROOT) && File.directory?('.git')

head = git('rev-parse', 'HEAD').strip
status = git('status', '--porcelain', '--', *PACKAGES, *ALSO_CHECK_ABSENT)
packages = {}

PACKAGES.each do |pkg|
  inst_dir = File.join(INSTALL_ROOT, pkg)
  inst_files, inst_links = installed_entries(inst_dir)
  head_all = head_entries(head, pkg)
  head_files = head_all.select { |e| e[:sha256] }
  head_links = head_all.select { |e| e[:symlink_target] }

  inst_by = inst_files.to_h { |e| [e[:path], e] }
  head_by = head_files.to_h { |e| [e[:path], e] }
  only_installed = (inst_by.keys - head_by.keys).sort
  only_head = (head_by.keys - inst_by.keys).sort
  both = inst_by.keys & head_by.keys
  differing = both.reject { |p| inst_by[p][:sha256] == head_by[p][:sha256] }.sort

  inst_manifest = manifest_lines(inst_files)
  head_manifest = manifest_lines(head_files)
  inst_json = File.join(inst_dir, 'skillset.json')

  packages[pkg] = {
    installed_version: File.file?(inst_json) ? version_of(File.read(inst_json)) : nil,
    head_version: version_of(git('show', "#{head}:#{pkg}/skillset.json")),
    installed: { file_count: inst_files.size, tree_sha256: Digest::SHA256.hexdigest(inst_manifest),
                 symlinks: inst_links, files: inst_files.sort_by { |e| e[:path].b } },
    head: { file_count: head_files.size, tree_sha256: Digest::SHA256.hexdigest(head_manifest),
            symlinks: head_links, files: head_files.sort_by { |e| e[:path].b } },
    diff: { identical: both.size - differing.size, differing: differing,
            only_installed: only_installed, only_head: only_head }
  }
end

absent = ALSO_CHECK_ABSENT.to_h do |pkg|
  at_head = !git('ls-tree', '--name-only', head, '--', pkg).strip.empty?
  [pkg, { at_head: at_head, installed: File.directory?(File.join(INSTALL_ROOT, pkg)) }]
end

record = {
  record: 'self_application S-1 — installed checker before any reinstall',
  design: { path: 'docs/design/self_application_design_v0_1.md', version: '0.1.5',
            sha256: Digest::SHA256.file('docs/design/self_application_design_v0_1.md').hexdigest },
  recorded_at: Time.now.utc.iso8601,
  head_commit: head,
  source_worktree_status_for_packages: status.empty? ? 'clean' : status,
  install_root: INSTALL_ROOT,
  hashing_rule: 'regular files incl. dot files; lines "<sha256>  <relpath>\\n" sorted bytewise; ' \
                'tree_sha256 = sha256 of the lines; HEAD side from git blobs; symlinks listed, not followed',
  recorder: { script: 'scripts/selfapp/s_minus_1_record.rb', script_sha256: Digest::SHA256.file(__FILE__).hexdigest,
              ruby: RUBY_VERSION, platform: RUBY_PLATFORM },
  scope_note: 'Shows difference between the installed copies and HEAD. It does not show that the installed ' \
              'copies correspond to any published commit, and it does not identify which files a run loads.',
  packages: packages,
  other_packages: absent
}

FileUtils.mkdir_p(opts[:out])
path = File.join(opts[:out], 'record.json')
abort "#{path} exists; S-1 is recorded once — move it aside deliberately" if File.exist?(path)

File.write(path, "#{JSON.pretty_generate(record)}\n")
packages.each do |pkg, r|
  File.write(File.join(opts[:out], "#{pkg}.installed.sha256sum"), manifest_lines(r[:installed][:files]))
  File.write(File.join(opts[:out], "#{pkg}.head.sha256sum"), manifest_lines(r[:head][:files]))
end

puts "head #{head}"
packages.each do |pkg, r|
  d = r[:diff]
  puts format('%-20s installed %-6s (%3d files, tree %s)  head %-6s (%3d files)  same %d / differ %d / only-installed %d / only-head %d',
              pkg, r[:installed_version], r[:installed][:file_count], r[:installed][:tree_sha256][0, 12],
              r[:head_version], r[:head][:file_count], d[:identical], d[:differing].size,
              d[:only_installed].size, d[:only_head].size)
end
absent.each { |pkg, a| puts "#{pkg}: at_head=#{a[:at_head]} installed=#{a[:installed]}" }
puts "record #{path} sha256 #{Digest::SHA256.file(path).hexdigest}"
