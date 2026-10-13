#!/usr/bin/env ruby
# frozen_string_literal: true

# Self-application round 2, unit E-25 (selfapp/round2/expected.json): record
# the frozen V0 and V6 bundles on a disposable local anchor built from the
# archive of C', verify them as a third party would, and compare every
# expected field. Written after round 2's fixing (the fixed set names the
# procedure as log/tier25_gate_withdrawn_20261012/up.sh plus the client and
# verifier at C'); this script is that procedure with the packages, client
# and verifier all taken from the archive of C' instead of the working tree.
#
#   ruby scripts/selfapp/r2_e25.rb --out log/selfapp/r2/e25 [--port 18081]
#
# Leaves the anchor server running and prints its pid: stopping it is left to
# the operator. Nothing here touches this instance's .kairos or the network
# beyond 127.0.0.1.

require 'digest'
require 'fileutils'
require 'json'
require 'net/http'
require 'open3'
require 'optparse'
require 'time'
require 'tmpdir'

opts = { port: 18_081 }
OptionParser.new do |o|
  o.on('--out DIR') { |v| opts[:out] = v }
  o.on('--port N', Integer) { |v| opts[:port] = v }
end.parse!
abort 'usage: r2_e25.rb --out DIR [--port N]' unless opts[:out]
abort "#{opts[:out]} exists" if File.exist?(opts[:out])

REPO = File.realpath(File.join(__dir__, '..', '..'))
C_PRIME = '809151618f2b4e06bdd279be2ee6537c8e8e016c'
C_PRIME_ARCHIVE_SHA256 = 'bc076bfcf2c40720d6800c7de7d9f8cd4c17aa0293c4348dac391a53f91427ed'
EXPECTED = JSON.parse(File.read(File.join(REPO, 'selfapp/round2/expected.json')))
BUNDLES = { 'V0' => 'log/selfapp/ddc_inputs_v1/bco/v0.json', 'V6' => 'log/selfapp/ddc_inputs_v1/bco/v6.json' }.freeze
GEM = Gem::Specification.find_by_name('kairos-chain')
TEMPLATES = File.join(GEM.gem_dir, 'templates', 'skillsets')
URL = "http://127.0.0.1:#{opts[:port]}"
LEVELS = %w[absent local_path floating ranged versioned immutable].freeze # weakest first (Predicate::LEVELS order)

def sh!(env, *cmd)
  o, e, st = Open3.capture3(env, *cmd)
  abort "#{cmd.first(4).join(' ')} failed (#{st.exitstatus}): #{e[0, 600]}" unless st.success?
  o
end

def sh(env, *cmd)
  o, e, st = Open3.capture3(env, *cmd)
  [o, e, st.exitstatus]
end

out = File.expand_path(opts[:out], REPO)
FileUtils.mkdir_p(out)
work = Dir.mktmpdir('kc-r2-e25-')
inst = File.join(work, 'inst')
env = { 'KAIROS_DATA_DIR' => inst }
rec = { 'unit' => 'E-25', 'started_at' => Time.now.utc.iso8601, 'work' => work, 'port' => opts[:port],
        'kairos_chain_gem' => GEM.version.to_s, 'ruby' => RUBY_VERSION }

# 1. the archive of C', unpacked; packages, client and verifier come from here
archive = IO.popen(['git', '-C', REPO, 'archive', C_PRIME], 'rb', &:read)
abort 'archive sha256 differs' unless Digest::SHA256.hexdigest(archive) == C_PRIME_ARCHIVE_SHA256
src = File.join(work, 'src')
FileUtils.mkdir_p(src)
IO.popen(['tar', '-x', '-C', src], 'wb') { |io| io.write(archive) }
rec['source'] = { 'commit' => C_PRIME, 'git_archive_sha256' => C_PRIME_ARCHIVE_SHA256 }

# 2. a fresh anchor instance (up.sh's steps)
sh!(env, 'kairos-chain', 'init', inst)
%w[mmp synoptis hestia].each { |p| sh!(env, 'kairos-chain', 'skillset', 'install', File.join(TEMPLATES, p), '--force') }
%w[genomicschain_core genomicschain_tier2 genomicschain_prov].each do |p|
  sh!(env, 'kairos-chain', 'skillset', 'install', File.join(src, p), '--force')
end
FileUtils.cp(File.join(src, 'genomicschain_core/config/genomicschain_core.anchor.yml.example'),
             File.join(inst, 'skillsets/genomicschain_core/config/genomicschain_core.yml'))
hestia = File.join(inst, 'skillsets/hestia/config/hestia.yml')
text = File.read(hestia)
2.times { text.sub!(/^(\s*)enabled: false$/, '\1enabled: true') }
File.write(hestia, text)
rec['installed'] = JSON.parse(sh!(env, 'ruby', '-rjson', '-e',
                                  'puts JSON.generate(Dir[File.join(ARGV[0], "skillsets/*/skillset.json")].sort.to_h { |f| j = JSON.parse(File.read(f)); [j["name"], j["version"]] })',
                                  inst))

key = File.join(work, 'operator.key')
pub = JSON.parse(sh!(env, 'ruby', File.join(src, 'scripts/gc_submit_client.rb'), '--keygen', '--key', key))['pubkey']
token = JSON.parse(sh!(env, 'ruby', File.join(src, 'scripts/gc_issue_bound_token.rb'), '--user', 'r2e25', '--pubkey', pub,
                       '--expires', '24h'))['raw_token']
rec['submitter_pubkey'] = pub

log = File.open(File.join(work, 'server.log'), 'w')
pid = Process.spawn(env, 'kairos-chain', '--http', '--host', '127.0.0.1', '--port', opts[:port].to_s, out: log, err: log)
Process.detach(pid)
rec['server_pid'] = pid
up = 60.times.any? do
  sleep 1
  Net::HTTP.get_response(URI("#{URL}/health")).code == '200'
rescue StandardError
  false
end
abort "anchor did not come up (pid #{pid}); see #{work}/server.log" unless up
anchor_pem = File.join(inst, 'keys/mmp_keypair.pem.pub')
FileUtils.cp(anchor_pem, File.join(out, 'anchor_pub_local.pem'))

client = lambda do |bundle|
  o, e, code = sh(env, 'ruby', File.join(src, 'scripts/gc_submit_client.rb'), '--tier', 'prov', '--key', key, '--token', token,
                  '--url', "#{URL}/mcp", '--data-dir', inst, '--bundle', bundle)
  { 'http' => o.lines.first&.strip, 'body' => (JSON.parse(o.lines.drop(1).join) rescue o), 'exit' => code, 'stderr' => e[0, 400] }
end
verify = lambda do |bundle, proof_id|
  o, e, code = sh(env, 'ruby', "-I#{src}/genomicschain_prov/lib", "-I#{src}/genomicschain_core/lib",
                  "-I#{src}/genomicschain_tier2/lib", "-I#{TEMPLATES}/synoptis/lib", "-I#{TEMPLATES}/mmp/lib",
                  File.join(src, 'genomicschain_prov/bin/gc_prov_verify.rb'), bundle, '--proof-id', proof_id,
                  '--anchor', URL, '--anchor-pubkey', anchor_pem, '--submitter-pubkey', pub)
  { 'exit' => code, 'text' => o, 'stderr' => e[0, 400] }
end
route = ->(id) { JSON.parse(Net::HTTP.get(URI("#{URL}/place/web/prov/proof/#{id}"))) }
proofs = -> { File.readlines(File.join(inst, 'synoptis_data/proofs.jsonl')).size }

# 3. per variant: submit, resubmit, verify, edit + verify, compare
exp = EXPECTED.dig('expectations', 'E-25', 'expect')
both = exp['both']
rec['variants'] = {}
BUNDLES.each do |v, rel|
  bundle = File.join(REPO, rel)
  first = client.call(bundle)
  n_after_first = proofs.call
  again = client.call(bundle)
  n_after_again = proofs.call
  id = first['body'].is_a?(Hash) ? first['body']['synoptis_proof_id'] : nil
  abort "#{v}: not recorded: #{first.inspect[0, 600]}" unless id
  r = route.call(id)
  File.write(File.join(out, "#{v}_route.json"), JSON.pretty_generate(r) + "\n")
  signed_manifest = JSON.parse(r['evidence'])['manifest']
  ok_verify = verify.call(bundle, id)
  File.write(File.join(out, "#{v}_verify.txt"), ok_verify['text'])
  edited = File.join(work, "#{v}_edited.json")
  b = JSON.parse(File.read(bundle))
  b['object_id'] = "#{b['object_id']}-edited"
  File.write(edited, JSON.generate(b))
  bad_verify = verify.call(edited, id)
  File.write(File.join(out, "#{v}_verify_edited.txt"), bad_verify['text'])

  e = exp[v]
  fields = e['manifest'].to_h do |k, want|
    got = signed_manifest[k]
    [k, { 'expected' => want, 'recorded' => got, 'ok' => got == want }]
  end
  claim = first['body']['claim']
  rb = { 'grade_overall_ge_versioned' => LEVELS.index(signed_manifest['grade_overall']) >= LEVELS.index('versioned'),
         'grade_inputs_immutable' => signed_manifest['grade_inputs'] == 'immutable',
         'outputs_with_checksum_ge_1' => signed_manifest['outputs_with_checksum'].to_i >= 1 }
  rec['variants'][v] = {
    'bundle' => rel, 'bundle_sha256' => Digest::SHA256.file(bundle).hexdigest,
    'submit' => first.except('body').merge('status' => first['body']['status'], 'recovered' => first['body']['recovered'],
                                           'synoptis_proof_id' => id, 'claim' => claim),
    'status_ok' => first['body']['status'] == 'recorded' && first['body']['recovered'] == false,
    'claim_ok' => claim.match?(Regexp.new(e['claim'].delete_prefix('matches '))),
    'manifest_fields' => fields, 'manifest_fields_ok' => fields.values.all? { |f| f['ok'] },
    'not_checked_ok' => signed_manifest['not_checked'] == both['not_checked'],
    'ttl' => r['ttl'], 'ttl_ok' => r['ttl'] == both['ttl'],
    'resubmission' => { 'synoptis_proof_id' => again['body']['synoptis_proof_id'], 'recovered' => again['body']['recovered'],
                        'proofs_after_first' => n_after_first, 'proofs_after_again' => n_after_again },
    'resubmission_ok' => again['body']['synoptis_proof_id'] == id && again['body']['recovered'] == true &&
                         n_after_again == n_after_first,
    'verify' => { 'exit' => ok_verify['exit'], 'result_line' => ok_verify['text'].lines.find { |l| l.include?('result:') }&.strip,
                  'not_ok_lines' => ok_verify['text'].lines.grep(/\[(?!ok\])/).map(&:strip) },
    'verify_ok' => ok_verify['exit'].zero? && ok_verify['text'].include?('result: consistent') &&
                   ok_verify['text'].lines.grep(/\[(?!ok\])/).empty?,
    'verify_after_edit' => { 'exit' => bad_verify['exit'],
                             'result_line' => bad_verify['text'].lines.find { |l| l.include?('result:') }&.strip },
    'verify_after_edit_ok' => bad_verify['exit'] == 1 && bad_verify['text'].include?('result: mismatch'),
    'route_b' => rb.merge('eligible' => rb.values.all?)
  }
end
rec['route_b_ok'] = rec['variants']['V0']['route_b']['eligible'] == true &&
                    rec['variants']['V6']['route_b'].slice('grade_overall_ge_versioned', 'grade_inputs_immutable',
                                                           'outputs_with_checksum_ge_1').values.none?
checks = rec['variants'].values.flat_map { |x| x.select { |k, _| k.end_with?('_ok') }.values } << rec['route_b_ok']
rec['all_expectations_hold'] = checks.all?
rec['finished_at'] = Time.now.utc.iso8601
rec['server_note'] = "anchor server pid #{pid} left running on 127.0.0.1:#{opts[:port]}; stop it with kill #{pid}"
File.write(File.join(out, 'record.json'), JSON.pretty_generate(rec) + "\n")
FileUtils.cp(File.join(work, 'server.log'), File.join(out, 'server.log'))
puts JSON.pretty_generate(rec['variants'].transform_values { |x| x.select { |k, _| k.end_with?('_ok') }.merge('route_b' => x['route_b']['eligible']) })
puts "route_b_ok #{rec['route_b_ok']}  all_expectations_hold #{rec['all_expectations_hold']}"
puts rec['server_note']
