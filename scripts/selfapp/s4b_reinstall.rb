#!/usr/bin/env ruby
# frozen_string_literal: true

# S4b of the self-application design (docs/design/self_application_design_v0_1.md
# §6.1, §10): reinstall the checker A from the archive of commit C and name A by
# its tree hash. Steps, in order, each stopping the script on failure:
#
#   1. `git archive C` and check its sha256 against the fixed set's value;
#   2. unpack it into a temporary directory outside the repository;
#   3. record the installed copies as they are now (same rule as S−1);
#   4. `kairos-chain skillset install <unpacked>/<pkg> --force` for each package,
#      in dependency order, into the instance at --data-dir;
#   5. record the installed copies again and compare each with the archive.
#
# The packages are DdcCommon::PACKAGES, the ones the DDC harness loads. The
# design's wording is "every genomicschain_* package"; genomicschain_regwatch is
# not a checker and the harness does not load it, so it is left out (operator
# decision 2026-10-03).
#
# --force removes the installed directory and copies the new one, keeping only
# the files directly under config/ (kairos-chain skillset_manager.rb#install).
# The install appends one skillset_event block per package to the instance's
# chain. A running MCP server keeps the code it loaded at start; it has to be
# restarted before any S4c launch uses A.
#
# Usage: ruby scripts/selfapp/s4b_reinstall.rb [--round 1|2] [--out DIR]
#   round 1 (default): A from C, record under log/selfapp/s4b
#   round 2: A' from C', record under log/selfapp/r2/s4b

require 'digest'
require 'json'
require 'open3'
require 'optparse'
require 'time'
require 'tmpdir'
require 'fileutils'
require_relative 'ddc_common'

# Round 1 installs A from C (fixed_set_v1.json .commit_c); round 2 installs A'
# from C' (selfapp/round2/fixed_set.json .commit_c_prime, design §14). The
# round-2 entry was added after round 2's fixing; round 1's values are as
# they were.
ROUNDS = {
  1 => { commit: '549accc9b5b6016ccb906b613ea2ea8da73ad4a6', label: 'C', checker: 'A',
         archive_sha256: '2875eec01fd16598aa2f8e0c673860f9ec8194a1e97fa0cf8f6af370a42ab302', out: 'log/selfapp/s4b' },
  2 => { commit: '809151618f2b4e06bdd279be2ee6537c8e8e016c', label: "C'", checker: "A'",
         archive_sha256: 'bc076bfcf2c40720d6800c7de7d9f8cd4c17aa0293c4348dac391a53f91427ed', out: 'log/selfapp/r2/s4b' }
}.freeze
INSTALL_ORDER = %w[genomicschain_core genomicschain_tier1 genomicschain_tier2 genomicschain_tier3 genomicschain_prov].freeze

opts = { round: 1, data_dir: '.kairos' }
OptionParser.new do |o|
  o.on('--round N', Integer) { |v| opts[:round] = v }
  o.on('--out DIR') { |v| opts[:out] = v }
  o.on('--data-dir DIR') { |v| opts[:data_dir] = v }
end.parse!
ROUND = ROUNDS.fetch(opts[:round]) { abort "unknown round #{opts[:round]}" }
C = ROUND[:commit]
C_ARCHIVE_SHA256 = ROUND[:archive_sha256]
opts[:out] ||= ROUND[:out]

abort 'run from the repository root' unless File.directory?('.git')
abort "#{opts[:out]} exists" if File.exist?(opts[:out])
abort 'install order must cover exactly the harness packages' unless INSTALL_ORDER.sort == DdcCommon::PACKAGES.sort

data_dir = File.realpath(opts[:data_dir])
install_root = File.join(data_dir, 'skillsets')

def run(*cmd, env: {})
  out, err, st = Open3.capture3(env, *cmd, binmode: true)
  [out, err, st.exitstatus]
end

def snapshot(dir)
  return nil unless File.directory?(dir)

  files = DdcCommon.tree_files(dir)
  json = File.join(dir, 'skillset.json')
  { version: File.file?(json) ? JSON.parse(File.read(json))['version'] : nil,
    file_count: files.size, tree_sha256: DdcCommon.tree_sha256(files), files: files }
end

def compare(installed, archive)
  both = installed.keys & archive.keys
  { identical: both.count { |p| installed[p] == archive[p] },
    differing: both.reject { |p| installed[p] == archive[p] }.sort,
    only_installed: (installed.keys - archive.keys).sort,
    only_archive: (archive.keys - installed.keys).sort }
end

# 1. the archive of C
archive, err, code = run('git', 'archive', C)
abort "git archive failed: #{err}" unless code.zero?
archive_sha = Digest::SHA256.hexdigest(archive)
abort "archive sha256 #{archive_sha} != fixed set #{C_ARCHIVE_SHA256}" unless archive_sha == C_ARCHIVE_SHA256

design_path = 'docs/design/self_application_design_v0_1.md'
record = {
  record: "self_application S4b — checker #{ROUND[:checker]} reinstalled from the archive of #{ROUND[:label]} (round #{opts[:round]})",
  design: { path: design_path, version: File.read(design_path)[/\*\*状態:\*\* 草稿 v([0-9.]+)/, 1],
            sha256: Digest::SHA256.file(design_path).hexdigest },
  round: opts[:round], commit_c: C, git_archive_sha256: archive_sha, git_archive_bytes: archive.bytesize,
  packages: INSTALL_ORDER,
  packages_note: 'DdcCommon::PACKAGES (what the DDC harness loads). genomicschain_regwatch left out: not a checker, not loaded by the harness; operator decision 2026-10-03.',
  install_root: install_root,
  hashing_rule: DdcCommon.method(:tree_files).source_location.join(':') + ' (the S−1 rule); A tree hash = DdcCommon.tree_sha256(DdcCommon.package_files(install_root))',
  recorder: { script: 'scripts/selfapp/s4b_reinstall.rb', script_sha256: Digest::SHA256.file(__FILE__).hexdigest,
              ddc_common_sha256: Digest::SHA256.file(File.join(__dir__, 'ddc_common.rb')).hexdigest,
              ruby: RUBY_VERSION, platform: RUBY_PLATFORM,
              kairos_chain: run('kairos-chain', '--version', env: { 'KAIROS_DATA_DIR' => data_dir })[0].lines.first&.strip },
  head_commit: run('git', 'rev-parse', 'HEAD')[0].strip,
  started_at: Time.now.utc.iso8601
}

Dir.mktmpdir('selfapp_s4b_') do |tmp|
  # 2. unpack outside the repository
  _, err, code = Open3.capture3('tar', '-x', '-C', tmp, stdin_data: archive, binmode: true).then { |o, e, s| [o, e, s.exitstatus] }
  abort "tar failed: #{err}" unless code.zero?
  record[:unpacked_into] = tmp

  # 3. before
  record[:before] = INSTALL_ORDER.to_h { |p| [p, snapshot(File.join(install_root, p))&.except(:files)] }

  # 4. install
  record[:installs] = INSTALL_ORDER.map do |pkg|
    out, err, code = run('kairos-chain', 'skillset', 'install', File.join(tmp, pkg), '--force',
                         env: { 'KAIROS_DATA_DIR' => data_dir })
    entry = { package: pkg, exit: code, stdout: out.force_encoding('UTF-8'), stderr: err.force_encoding('UTF-8') }
    unless code.zero?
      record[:installs_failed_at] = pkg
      File.write('/tmp/selfapp_s4b_failed_record.json', JSON.pretty_generate(record.merge(failed_entry: entry)))
      abort "install of #{pkg} failed (exit #{code}); partial record in /tmp/selfapp_s4b_failed_record.json"
    end
    entry
  end

  # 5. after, against the archive
  record[:after] = INSTALL_ORDER.to_h do |pkg|
    inst = snapshot(File.join(install_root, pkg))
    arch = snapshot(File.join(tmp, pkg))
    abort "#{pkg} not installed after install" unless inst
    [pkg, { version: inst[:version], file_count: inst[:file_count], tree_sha256: inst[:tree_sha256],
            archive_tree_sha256: arch[:tree_sha256], matches_archive: inst[:tree_sha256] == arch[:tree_sha256],
            diff_against_archive: compare(inst[:files], arch[:files]), files: inst[:files] }]
  end

  a_files = DdcCommon.package_files(install_root)
  c_files = DdcCommon.package_files(tmp)
  record[:a] = { tree_sha256: DdcCommon.tree_sha256(a_files), file_count: a_files.size,
                 archive_tree_sha256: DdcCommon.tree_sha256(c_files), archive_file_count: c_files.size,
                 matches_archive: a_files == c_files }
end

record[:finished_at] = Time.now.utc.iso8601
record[:mcp_server_note] = 'A running genomics-chain MCP server still holds the code it loaded at start. Restart it before any S4c launch.'

FileUtils.mkdir_p(File.dirname(opts[:out]))
Dir.mkdir(opts[:out])
File.write(File.join(opts[:out], 'record.json'), JSON.pretty_generate(record) + "\n")
puts "A tree sha256 #{record[:a][:tree_sha256]} (#{record[:a][:file_count]} files), matches archive: #{record[:a][:matches_archive]}"
record[:after].each { |p, v| puts "  #{p} #{v[:version]} #{v[:file_count]} files #{v[:tree_sha256][0, 12]} matches_archive=#{v[:matches_archive]}" }
puts "record: #{File.join(opts[:out], 'record.json')}"
