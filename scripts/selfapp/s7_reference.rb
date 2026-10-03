#!/usr/bin/env ruby
# frozen_string_literal: true

# S7 of the self-application design, the reference context's steps for Tier 4
# stage 0 (selfapp/tier4_acceptance_v1.json stage_0.order 3–4; design §7.1).
# This context is not the distiller: it draws the second seed, generates the
# second subject and fixes the reference; the distiller never sees any of it.
#
#   ruby scripts/selfapp/s7_reference.rb seed       # needs log/selfapp/s7/package_digest.json
#   ruby scripts/selfapp/s7_reference.rb generate   # second subject from the first recorded draw
#   ruby scripts/selfapp/s7_reference.rb reference  # original V0 pipeline ×2 on it; fix if identical
#
# seed: SecureRandom, in 1..2**31-1 because the seed also becomes the
# subject's permutation_seed, which R's set.seed takes as a 32-bit integer
# (generator/templates/config.yaml.erb:10). Each draw is appended with its
# time to seed_draws.jsonl before it is used; a second call draws nothing,
# and only the first draw is ever used (seed_rule).
# generate: same generator (tree hash checked against the fixed set), same
# pins and lock as V0, same Ruby, default settings as V0; only the seed changes.
# reference: two fresh copies of the second subject's synthetic_repo without
# results/, with V0's Snakefile and scripts/ (the original pipeline), each
# run with V0's command in image sha256:004c13e8…; sha256 of the two tables
# compared here, not by the checker (reference_rule).

require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'securerandom'
require 'time'
require_relative 'ddc_common'

REPO = File.realpath(File.join(__dir__, '..', '..'))
S7 = File.join(REPO, 'log/selfapp/s7')
DIGEST_RECORD = File.join(S7, 'package_digest.json')
DRAWS = File.join(S7, 'seed_draws.jsonl')
SUBJECT_OUT = File.join(S7, 'subject2')
SUBJECT = File.join(SUBJECT_OUT, 'synthetic_rnaseq_v1')
REF_WORK = File.join(S7, 'reference_work')
REF_RECORD = File.join(S7, 'reference.json')
V0_REPO = File.join(REPO, 'selfapp/synthetic_rnaseq_v1/synthetic_repo')
FIXED = JSON.parse(File.read(File.join(REPO, 'selfapp/fixed_set_v1.json')))
IMAGE_ID = 'sha256:004c13e8611f445b5be24dcac9749edd0a38a0aa136a0642a88c9ee7ee236504'
S1 = 'results/synthetic_supplementary_table_S1.tsv'
SEED_MAX = 2**31 - 1

def now = Time.now.utc.iso8601(3)
def write_json(path, obj) = File.write(path, "#{JSON.pretty_generate(obj)}\n")
def draws = File.exist?(DRAWS) ? File.readlines(DRAWS).map { |l| JSON.parse(l) } : []
def tree(dir) = DdcCommon.tree_sha256(DdcCommon.tree_files(dir))

abort 'no package digest recorded: the seed is drawn only after the Skill is fixed' unless File.exist?(DIGEST_RECORD)

case ARGV.first
when 'seed'
  unless draws.empty?
    puts "already drawn; first draw: #{JSON.generate(draws.first)}"
    exit 0
  end
  seed = SecureRandom.random_number(SEED_MAX) + 1
  File.open(DRAWS, 'a') do |f|
    f.flock(File::LOCK_EX)
    f.write("#{JSON.generate('draw' => 1, 'utc' => now, 'seed' => seed, 'source' => 'SecureRandom.random_number(2**31-1)+1',
                             'package_digest_record_sha256' => Digest::SHA256.file(DIGEST_RECORD).hexdigest)}\n")
  end
  puts File.read(DRAWS)

when 'generate'
  abort "#{SUBJECT_OUT} exists" if File.exist?(SUBJECT_OUT)
  seed = draws.first&.fetch('seed') or abort 'no seed drawn'
  gen = File.join(REPO, 'selfapp/generator')
  abort 'generator differs from the fixed set' unless tree(gen) == FIXED.dig('subject', 'generator', 'tree_sha256')
  cmd = [RbConfig.ruby, File.join(gen, 'bin/generate.rb'), '--seed', seed.to_s,
         '--pins', File.join(REPO, 'selfapp/pins_v0.json'), '--lock', File.join(REPO, 'selfapp/pins_v0.lock'), '--out', SUBJECT_OUT]
  started = now
  o, e, st = Open3.capture3(*cmd)
  abort "generator failed: #{e}" unless st.success?
  manifest = JSON.parse(File.read(File.join(SUBJECT, 'generator_manifest.json')))
  write_json(File.join(S7, 'subject2_record.json'),
             'started_at' => started, 'finished_at' => now, 'seed' => seed, 'ruby' => RUBY_VERSION,
             'command' => cmd.map { |a| a.delete_prefix("#{REPO}/") }, 'stdout' => o,
             'generator_tree_sha256' => manifest.dig('generator', 'tree_sha256'), 'manifest_seed' => manifest['seed'],
             'config' => manifest['config'], 'subject_tree_sha256' => tree(SUBJECT))
  puts o

when 'reference'
  abort "#{REF_RECORD} exists" if File.exist?(REF_RECORD)
  abort "#{REF_WORK} exists" if File.exist?(REF_WORK)
  src = File.join(SUBJECT, 'synthetic_repo')
  code = { 'Snakefile' => 'Snakefile', 'scripts' => 'scripts' }
  same_code = code.keys.to_h do |k|
    a = File.join(src, k)
    b = File.join(V0_REPO, k)
    [k, File.directory?(a) ? tree(a) == tree(b) : Digest::SHA256.file(a) == Digest::SHA256.file(b)]
  end
  runs = (1..2).map do |i|
    dir = File.join(REF_WORK, "run#{i}")
    FileUtils.mkdir_p(REF_WORK)
    FileUtils.cp_r(src, dir)
    FileUtils.rm_rf(File.join(dir, 'results'))
    # The original pipeline is V0's: its Snakefile and scripts replace the subject's.
    code.each_key do |k|
      FileUtils.rm_rf(File.join(dir, k))
      FileUtils.cp_r(File.join(V0_REPO, k), File.join(dir, k))
    end
    argv = ['docker', 'run', '--rm', '--platform', 'linux/amd64', '-v', "#{dir}:/work", '-w', '/work', IMAGE_ID,
            'snakemake', '--cores', '1']
    t0 = now
    o, e, st = Open3.capture3(*argv)
    File.write(File.join(REF_WORK, "run#{i}.log"), "#{o}\n--- stderr\n#{e}")
    table = File.join(dir, S1)
    { 'run' => i, 'started_at' => t0, 'finished_at' => now, 'exit' => st.exitstatus,
      'command' => argv.map { |a| a == "#{dir}:/work" ? '<run dir>:/work' : a },
      'table_sha256' => File.file?(table) ? Digest::SHA256.file(table).hexdigest : nil }
  end
  shas = runs.map { |r| r['table_sha256'] }
  fixed = shas.none?(&:nil?) && shas.uniq.size == 1
  record = { 'what' => 'Tier 4 stage 0 reference: original V0 pipeline on the second subject (tier4_acceptance_v1.json other_data_check.reference)',
             'seed' => draws.first['seed'], 'subject_tree_sha256' => tree(SUBJECT),
             'subject_code_equals_v0' => same_code, 'image' => IMAGE_ID, 'runs' => runs,
             'fixed' => fixed, 'reference_sha256' => (fixed ? shas.first : nil), 'fixed_at' => (fixed ? now : nil),
             'note' => (fixed ? nil : 'tables differ or missing: no reference fixed; the other-data check is not performed') }
  write_json(REF_RECORD, record)
  puts JSON.pretty_generate(record)

else
  abort 'usage: s7_reference.rb seed|generate|reference'
end
