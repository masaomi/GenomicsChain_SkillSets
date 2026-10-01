#!/usr/bin/env ruby
# frozen_string_literal: true

# V0 calibration for the self-application demonstration (design
# docs/design/self_application_design_v0_1.md v0.1.5, §4.3 and §10 row S3):
# run the fictional subject's own pipeline at least twice on the same input and
# compare the working directories by sha256. No checker is launched: this script
# loads nothing from genomicschain_*/ and calls no gc_tier* tool (INV-S2).
#
# Per run N:
#   - copy selfapp/synthetic_rnaseq_v1/synthetic_repo to
#     <out>/calibration/run<N>/synthetic_repo (run<N> must not exist);
#   - delete results/ in the copy (the Tier-3 working directory starts without
#     it, design §5 row V4);
#   - inside the copy, run the author's command from the S2 record:
#       docker run --rm --platform linux/amd64 -v "$PWD":/work -w /work \
#         synthetic-rnaseq:1.0 snakemake --cores 1
#     stdout and stderr go to <out>/calibration/run<N>.log (outside the copy).
#
# Two views of each working directory:
#   - Tier-3 view: the rule of the Tier-3 local backend's FileHasher.walk
#     (genomicschain_core/lib/genomicschain_core/manifest.rb:236-257),
#     reimplemented here, not required: Dir.glob(File.join(dir, '**', '*')) WITHOUT
#     File::FNM_DOTMATCH (dot files and everything under dot directories are not
#     visited), regular files only (File.file?), path relative to the directory.
#   - full view: every regular file, dot files included (the S-1 rule).
# Tree hash of a file list (both views and the subject): lines
# "<sha256 hex>  <relative path>\n" sorted bytewise by path, sha256 of the
# concatenation (`find . -type f | LC_ALL=C sort | xargs sha256sum` without "./").
#
# Stops before running anything when the design hash or the local image id
# differs from the expected value.
#
#   ruby scripts/selfapp/calibrate_v0.rb [--runs 2] [--out log/selfapp/s3]

require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'optparse'
require 'pathname'
require 'time'

DESIGN_PATH = 'docs/design/self_application_design_v0_1.md'
DESIGN_SHA256 = '270d4a82dccaba0161ffd7cc983c13a771b8111a8bdcd1779e48d827a4316129'
SUBJECT_DIR = 'selfapp/synthetic_rnaseq_v1'
REPO_SUBDIR = 'synthetic_repo'
IMAGE_TAG = 'synthetic-rnaseq:1.0'
IMAGE_ID = 'sha256:004c13e8611f445b5be24dcac9749edd0a38a0aa136a0642a88c9ee7ee236504'
PLATFORM = 'linux/amd64'
S2_RECORD = 'log/selfapp/s2/s2_record.json'
AUTHOR_COMMAND = 'docker run --rm --platform linux/amd64 -v "$PWD":/work -w /work ' \
                 'synthetic-rnaseq:1.0 snakemake --cores 1'
S1_PATH = 'results/synthetic_supplementary_table_S1.tsv'
S1_DECLARED_SHA256 = '22fe3ff699a91e4ded9a3f58fc0996b95c9bff817c294e0421f2fda68e02508a'

opts = { runs: 2, out: 'log/selfapp/s3' }
OptionParser.new do |o|
  o.on('--runs N', Integer) { |v| opts[:runs] = v }
  o.on('--out DIR') { |v| opts[:out] = v }
end.parse!
abort 'calibrate_v0: --runs must be at least 2' if opts[:runs] < 2

def tree_lines(entries)
  entries.sort_by { |e| e[:relative_path].b }.map { |e| "#{e[:sha256]}  #{e[:relative_path]}\n" }.join
end

def tree_sha256(entries)
  Digest::SHA256.hexdigest(tree_lines(entries))
end

# Full view (S-1 rule): every regular file, dot files included; symlinks listed, not followed.
def full_view(dir)
  files = []
  symlinks = []
  Dir.glob('**/*', File::FNM_DOTMATCH, base: dir).each do |rel|
    next if rel == '.' || rel == '..' || rel.end_with?('/.', '/..')

    full = File.join(dir, rel)
    if File.symlink?(full)
      symlinks << { relative_path: rel, target: File.readlink(full) }
    elsif File.file?(full)
      files << { relative_path: rel, sha256: Digest::SHA256.file(full).hexdigest, size_bytes: File.size(full) }
    end
  end
  [files.sort_by { |e| e[:relative_path].b }, symlinks.sort_by { |e| e[:relative_path].b }]
end

# Tier-3 view: FileHasher.walk reimplemented (no FNM_DOTMATCH, File.file?, sorted).
def tier3_view(dir)
  Dir.glob(File.join(dir, '**', '*')).sort.filter_map do |path|
    next unless File.file?(path)

    {
      relative_path: Pathname.new(path).relative_path_from(Pathname.new(dir)).to_s,
      sha256: Digest::SHA256.file(path).hexdigest,
      size_bytes: File.size(path)
    }
  end
end

def differences(a, b)
  ha = a.to_h { |e| [e[:relative_path], e[:sha256]] }
  hb = b.to_h { |e| [e[:relative_path], e[:sha256]] }
  (ha.keys | hb.keys).sort_by(&:b).filter_map do |path|
    next if ha[path] == hb[path]

    { relative_path: path, run_a_sha256: ha[path], run_b_sha256: hb[path] }
  end
end

def local_image_id
  out, st = Open3.capture2('docker', 'image', 'inspect', IMAGE_TAG, '--format', '{{.Id}}')
  st.success? ? out.strip : nil
end

def utc_now = Time.now.utc

root = Dir.pwd
out_dir = File.expand_path(opts[:out], root)
cal_dir = File.join(out_dir, 'calibration')
record_path = File.join(out_dir, 'calibration_record.json')

design_sha = Digest::SHA256.file(DESIGN_PATH).hexdigest
abort "calibrate_v0: design sha256 #{design_sha} != #{DESIGN_SHA256}; stopping" unless design_sha == DESIGN_SHA256

s2 = JSON.parse(File.read(S2_RECORD))
abort 'calibrate_v0: S2 record image id differs from the constant' unless s2.dig('image', 'id') == IMAGE_ID
abort 'calibrate_v0: S2 record S1 sha256 differs from the constant' unless
  s2.dig('author_run', 'supplementary_table_S1', 'sha256') == S1_DECLARED_SHA256

image_id_before = local_image_id
unless image_id_before == IMAGE_ID
  abort "calibrate_v0: local image #{IMAGE_TAG} id #{image_id_before.inspect} != #{IMAGE_ID}; stopping"
end

abort "calibrate_v0: #{record_path} already exists" if File.exist?(record_path)
(1..opts[:runs]).each do |n|
  d = File.join(cal_dir, "run#{n}")
  abort "calibrate_v0: #{d} already exists; the copy must be fresh" if File.exist?(d)
end

subject_files, subject_links = full_view(SUBJECT_DIR)
repo_src = File.join(SUBJECT_DIR, REPO_SUBDIR)
repo_files, repo_links = full_view(repo_src)
subject_tree_before = tree_sha256(subject_files)
repo_tree_before = tree_sha256(repo_files)

FileUtils.mkdir_p(cal_dir)
runs = []
(1..opts[:runs]).each do |n|
  run_root = File.join(cal_dir, "run#{n}")
  work = File.join(run_root, REPO_SUBDIR)
  log_path = File.join(cal_dir, "run#{n}.log")
  FileUtils.mkdir_p(run_root)
  FileUtils.cp_r(File.join(root, repo_src), work)
  results_was_present = Dir.exist?(File.join(work, 'results'))
  FileUtils.rm_rf(File.join(work, 'results'))

  id_now = local_image_id
  abort "calibrate_v0: image id changed before run #{n}: #{id_now.inspect}" unless id_now == IMAGE_ID

  argv = ['docker', 'run', '--rm', '--platform', PLATFORM, '-v', "#{work}:/work", '-w', '/work',
          IMAGE_TAG, 'snakemake', '--cores', '1']
  warn "calibrate_v0: run #{n} started in #{work}"
  started = utc_now
  pid = Process.spawn(*argv, chdir: work, out: log_path, err: %i[child out])
  _, status = Process.wait2(pid)
  finished = utc_now
  warn "calibrate_v0: run #{n} exit #{status.exitstatus} after #{(finished - started).round(1)} s"

  t3 = tier3_view(work)
  full, links = full_view(work)
  full_manifest_path = File.join(cal_dir, "run#{n}.full_view.sha256")
  File.write(full_manifest_path, tree_lines(full))
  s1_file = File.join(work, S1_PATH)
  s1_sha = File.file?(s1_file) ? Digest::SHA256.file(s1_file).hexdigest : nil

  runs << {
    run: n,
    dir: Pathname.new(work).relative_path_from(Pathname.new(root)).to_s,
    results_dir_deleted_before_run: results_was_present,
    log: Pathname.new(log_path).relative_path_from(Pathname.new(root)).to_s,
    log_sha256: Digest::SHA256.file(log_path).hexdigest,
    command_argv: argv.map { |a| a == "#{work}:/work" ? '"$PWD":/work' : a },
    started: started.iso8601,
    finished: finished.iso8601,
    wall_seconds: (finished - started).round(1),
    exit: status.exitstatus,
    tier3_view: { file_count: t3.size, tree_sha256: tree_sha256(t3), files: t3 },
    full_view: {
      file_count: full.size,
      tree_sha256: tree_sha256(full),
      manifest: Pathname.new(full_manifest_path).relative_path_from(Pathname.new(root)).to_s,
      symlinks: links
    },
    s1: { path: S1_PATH, sha256: s1_sha, matches_declared: s1_sha == S1_DECLARED_SHA256 },
    _full: full,
    _t3: t3
  }
end

subject_tree_after = tree_sha256(full_view(SUBJECT_DIR).first)
repo_tree_after = tree_sha256(full_view(repo_src).first)

base = runs.first
comparison = runs.drop(1).map do |r|
  t3_diff = differences(base[:_t3], r[:_t3])
  full_diff = differences(base[:_full], r[:_full])
  {
    runs: [base[:run], r[:run]],
    tier3_view: { identical: t3_diff.empty?, differences: t3_diff },
    full_view: { identical: full_diff.empty?, difference_count: full_diff.size, differences: full_diff }
  }
end
runs.each { |r| r.delete(:_full); r.delete(:_t3) }

script_path = File.expand_path(__FILE__)
record = {
  record: 'self_application S3 part B — V0 calibration: the subject pipeline run ' \
          "#{opts[:runs]} times on the same input, working directories compared by sha256",
  statement: 'no checker was launched',
  design: { path: DESIGN_PATH, sha256: design_sha, sections: '§4.3, §4.5, §5 (V4 row), §10 S3' },
  subject: {
    dir: SUBJECT_DIR,
    tree_sha256: subject_tree_before,
    file_count: subject_files.size,
    symlinks: subject_links,
    synthetic_repo: {
      dir: repo_src, tree_sha256: repo_tree_before, file_count: repo_files.size, symlinks: repo_links
    },
    unchanged_after_runs: subject_tree_after == subject_tree_before && repo_tree_after == repo_tree_before
  },
  hashing_rules: {
    tree_sha256: 'lines "<sha256 hex>  <relative path>\n" sorted bytewise by path; sha256 of the concatenation',
    full_view: 'every regular file, dot files included (Dir.glob with File::FNM_DOTMATCH); symlinks listed, ' \
               'not followed (S-1 rule)',
    tier3_view: "Tier-3 local backend FileHasher.walk (genomicschain_core/lib/genomicschain_core/manifest.rb:236-257), " \
                "reimplemented, not loaded: Dir.glob(File.join(dir, '**', '*')) without File::FNM_DOTMATCH, " \
                'regular files only (File.file?), path relative to the working directory'
  },
  image: { tag: IMAGE_TAG, id: IMAGE_ID, local_id_before_runs: image_id_before, platform: PLATFORM,
           source: S2_RECORD },
  command: AUTHOR_COMMAND,
  command_run_from: 'inside the fresh copy of synthetic_repo; "$PWD" is that copy',
  preparation: 'fresh copy of synthetic_repo; results/ deleted in the copy before the run ' \
               '(the Tier-3 working directory starts without results/, design §5 row V4)',
  s1_declared: { path: S1_PATH, sha256: S1_DECLARED_SHA256, source: "#{S2_RECORD} author_run (the placed V0 S1)" },
  runs: runs,
  comparison: comparison,
  summary: {
    tier3_view_identical: comparison.all? { |c| c[:tier3_view][:identical] },
    full_view_identical: comparison.all? { |c| c[:full_view][:identical] },
    all_exit_zero: runs.all? { |r| r[:exit].zero? },
    s1_matches_declared_in_every_run: runs.all? { |r| r[:s1][:matches_declared] }
  },
  host: {
    ruby: RUBY_DESCRIPTION,
    docker_server: Open3.capture2('docker', 'version', '--format', '{{.Server.Version}}').first.strip
  },
  script: { path: Pathname.new(script_path).relative_path_from(Pathname.new(root)).to_s,
            sha256: Digest::SHA256.file(script_path).hexdigest },
  written_at: utc_now.iso8601
}

File.write(record_path, "#{JSON.pretty_generate(record)}\n")
warn "calibrate_v0: wrote #{record_path}"
warn "calibrate_v0: summary #{record[:summary].to_json}"
