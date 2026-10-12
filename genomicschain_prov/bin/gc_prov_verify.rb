#!/usr/bin/env ruby
# frozen_string_literal: true
#
# gc_prov_verify — check a provenance bundle against its Tier-2.5 record
# (design v0.1 §8, v0.1.12 §6.1). For a third party: an auditor, a reviewer,
# GenomicsChain itself. Needs the bundle (from the customer) and a proof_id;
# reads the record from the anchor's public route — no account, no token.
#
# It prints what it CONFIRMED from bytes it holds, what the ANCHOR SAYS (and
# this tool did not check), and what NOBODY checked (the record's own
# not_checked list), then the two statements every verifier output carries.
# Give --anchor-pubkey to check the anchor's signature and move what it
# covers up into "confirmed"; give --submitter-pubkey to check who signed;
# give --zk-receipt to check ZK receipts here instead of taking the anchor's
# word for them.
#
# Lives in bin/, not tools/ (design §7).
#
# Usage
#   ruby genomicschain_prov/bin/gc_prov_verify.rb bco.json --proof-id ID \
#        [--anchor https://meeting.genomicschain.io] [--anchor-pubkey anchor.pem] \
#        [--submitter-pubkey ed25519:...] [--zk-receipt receipt.bin ...] [--json]
#   ruby genomicschain_prov/bin/gc_prov_verify.rb bco.json --envelope proof.json   (offline: a saved route body)
#
# Exit status: 0 consistent; 1 a mismatch; 2 nothing to compare against
# (the record could not be fetched or read) or the bundle is unreadable.

require 'json'
require 'optparse'
require 'net/http'
require 'uri'
require 'digest'

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

# synoptis and mmp check the anchor's signature. Installed, they sit beside
# this package under .kairos/skillsets/; otherwise the kairos-chain gem ships
# them as templates. Only needed with --anchor-pubkey.
module GcProvVerifyPaths
  module_function

  def add_signature_libs
    roots = [File.expand_path('../..', File.expand_path('..', __dir__))]
    roots << File.join(ENV['KAIROS_DATA_DIR'], 'skillsets') if ENV['KAIROS_DATA_DIR']
    begin
      roots << File.join(Gem::Specification.find_by_name('kairos-chain').gem_dir, 'templates', 'skillsets')
    rescue Gem::MissingSpecError
      nil
    end
    %w[synoptis mmp].each do |pkg|
      lib = roots.map { |r| File.join(r, pkg, 'lib') }.find { |p| File.directory?(p) }
      $LOAD_PATH.unshift(lib) if lib && !$LOAD_PATH.include?(lib)
    end
  end
end

require 'genomicschain_prov'
require 'genomicschain_prov/verifier'

module GcProvVerify
  DEFAULT_ANCHOR = 'https://meeting.genomicschain.io'

  module_function

  def options(argv)
    opts = { anchor: DEFAULT_ANCHOR, zk: [], json: false }
    OptionParser.new do |o|
      o.banner = 'Usage: gc_prov_verify.rb BUNDLE (--proof-id ID [--anchor URL] | --envelope FILE) [options]'
      o.on('--proof-id ID', 'the proof to check against') { |v| opts[:proof_id] = v }
      o.on('--anchor URL', "the anchor serving /place/web/prov/proof/ (default #{DEFAULT_ANCHOR})") { |v| opts[:anchor] = v }
      o.on('--envelope FILE', 'a saved route body instead of fetching one') { |v| opts[:envelope] = v }
      o.on('--anchor-pubkey FILE', 'the anchor\'s RSA public key (PEM), obtained out of band') { |v| opts[:anchor_pubkey] = v }
      o.on('--submitter-pubkey KEY', 'the submitter\'s ed25519 key (ed25519:...), obtained out of band') { |v| opts[:submitter] = v }
      o.on('--zk-receipt FILE', 'a ZK receipt to check here (repeatable)') { |v| opts[:zk] << v }
      o.on('--json', 'machine-readable output') { opts[:json] = true }
      o.on('-h', '--help') { |_| puts o; exit 0 }
    end.parse!(argv)
    opts[:bundle] = argv.shift
    opts
  end

  # [route Hash or nil, fetch_error Hash or nil]
  def fetch(anchor, proof_id)
    uri = URI.join(anchor.end_with?('/') ? anchor : "#{anchor}/", "place/web/prov/proof/#{URI.encode_www_form_component(proof_id)}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.open_timeout = 15
    http.read_timeout = 30
    res = http.request(Net::HTTP::Get.new(uri.request_uri, 'Accept' => 'application/json'))
    return [JSON.parse(res.body), nil] if res.code.to_i == 200

    [nil, { 'status' => res.code.to_i, 'reason' => res.message }]
  rescue JSON::ParserError
    [nil, { 'status' => 200, 'reason' => 'the body was not JSON' }]
  rescue StandardError => e
    [nil, { 'status' => nil, 'reason' => e.class.name }]
  end

  def report(r)
    lines = []
    lines << "bundle digest: #{r['bundle_digest']}"
    lines << "proof: #{r['proof_id'] || '-'}   result: #{r['state']}"
    r['record_notes'].each { |n| lines << "  note: #{n}" }
    unless r['confirmed'].empty?
      lines << '' << 'CONFIRMED here, from the bundle and the record:'
      r['confirmed'].each { |c| lines << "  [#{c['ok'] ? 'ok' : 'MISMATCH'}] #{c['detail']}" }
      Array(r['summary']).each { |s| lines << "    #{s}" }
    end
    if r['version_note']
      lines << '' << 'NOT RE-DERIVED (a different version, not a mismatch):'
      lines << "  #{r['version_note']}"
    end
    unless r['anchor_says'].empty?
      lines << '' << 'THE ANCHOR SAYS (not checked by this tool unless marked confirmed):'
      r['anchor_says'].each { |s| lines << "  - #{s}" }
    end
    unless r['not_checked'].empty?
      lines << '' << 'NOT CHECKED by anyone (the record\'s not_checked):'
      r['not_checked'].each { |s| lines << "  - #{s}" }
    end
    lines << ''
    r['statements'].each { |s| lines << s }
    lines.join("\n")
  end

  def run(argv)
    opts = options(argv)
    abort 'gc_prov_verify: give the bundle file' if opts[:bundle].nil?
    abort 'gc_prov_verify: give --proof-id or --envelope' if opts[:proof_id].nil? && opts[:envelope].nil?
    GcProvVerifyPaths.add_signature_libs if opts[:anchor_pubkey]

    route, error = opts[:envelope] ? [JSON.parse(File.read(opts[:envelope])), nil] : fetch(opts[:anchor], opts[:proof_id])
    receipts = opts[:zk].to_h { |p| b = File.binread(p); [Digest::SHA256.hexdigest(b), b] }
    result = GenomicsChainProv::Verifier.new(
      bundle_text: File.read(opts[:bundle]), route: route, fetch_error: error,
      submitter_pubkey: opts[:submitter], anchor_pubkey_pem: opts[:anchor_pubkey] && File.read(opts[:anchor_pubkey]),
      receipts: receipts
    ).run
    result['proof_id'] ||= opts[:proof_id]
    puts(opts[:json] ? JSON.pretty_generate(result) : report(result))
    { 'consistent' => 0, 'mismatch' => 1 }.fetch(result['state'], 2)
  rescue Errno::ENOENT => e
    warn "gc_prov_verify: #{e.message}"
    2
  end
end

exit GcProvVerify.run(ARGV) if $PROGRAM_NAME == __FILE__
