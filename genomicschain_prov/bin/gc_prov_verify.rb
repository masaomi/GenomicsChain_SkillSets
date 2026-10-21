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
#   ruby genomicschain_prov/bin/gc_prov_verify.rb bco.json --proof-id OBS --prov-proof-id ID   (a reachability
#        observation, v0.1.15 §6.3: read by its own verifier, chosen by the record's type)
#   ruby genomicschain_prov/bin/gc_prov_verify.rb bco.json --proof-id ID --commitment-key run42.key \
#        --open data/S1.kmat=S1_odd.kmat [--open PATH=LOCATOR ...]
#        (option 2, v0.1.16 §7: a key holder checks local files against the
#        bundle's salted fingerprints; PATH is split from LOCATOR at the first
#        "=", so PATH cannot contain one. The key is read only, written nowhere.)
#
# Exit status: 0 consistent; 1 a mismatch, or with --commitment-key a key
# that is not the bundle's or a file that does not match; 2 nothing to
# compare against (the record could not be fetched or read) or the bundle
# is unreadable.

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
require 'genomicschain_prov/reach_verifier'
require 'genomicschain_prov/verdict_spec/prov'
require 'genomicschain_prov/commitment'

module GcProvVerify
  DEFAULT_ANCHOR = 'https://meeting.genomicschain.io'

  module_function

  def options(argv)
    opts = { anchor: DEFAULT_ANCHOR, zk: [], json: false, opens: [] }
    OptionParser.new do |o|
      o.banner = 'Usage: gc_prov_verify.rb BUNDLE (--proof-id ID [--anchor URL] | --envelope FILE) [options]'
      o.on('--proof-id ID', 'the proof to check against') { |v| opts[:proof_id] = v }
      o.on('--anchor URL', "the anchor serving /place/web/prov/proof/ (default #{DEFAULT_ANCHOR})") { |v| opts[:anchor] = v }
      o.on('--envelope FILE', 'a saved route body instead of fetching one') { |v| opts[:envelope] = v }
      o.on('--anchor-pubkey FILE', 'the anchor\'s RSA public key (PEM), obtained out of band') { |v| opts[:anchor_pubkey] = v }
      o.on('--submitter-pubkey KEY', 'the submitter\'s ed25519 key (ed25519:...), obtained out of band') { |v| opts[:submitter] = v }
      o.on('--zk-receipt FILE', 'a ZK receipt to check here (repeatable)') { |v| opts[:zk] << v }
      o.on('--prov-proof-id ID', 'for an observation: the prov record it should be laid over') { |v| opts[:prov_proof_id] = v }
      o.on('--commitment-key FILE', 'the bundle\'s 32-byte gc-commitment-0.1 key, to check files with --open') { |v| opts[:key] = v }
      o.on('--open PATH=LOCATOR', 'a local file and the bundle locator it should be (repeatable; needs --commitment-key)') do |v|
        path, locator = v.split('=', 2)
        abort 'gc_prov_verify: --open takes PATH=LOCATOR' if path.to_s.empty? || locator.to_s.empty?
        opts[:opens] << [path, locator]
      end
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

  # The record type, read from the evidence the anchor signed (not the
  # route's convenience copy); nil when it cannot be read, which the prov
  # verifier then reports as unreadable.
  def record_type(route)
    ev = route && route['evidence']
    parsed = ev.is_a?(String) ? JSON.parse(ev) : nil
    parsed.is_a?(Hash) ? parsed.dig('manifest', 'record_type') : nil
  rescue JSON::ParserError
    nil
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
    notes = [r['version_note'], r['resources_version_note']].compact
    unless notes.empty?
      lines << '' << 'NOT RE-DERIVED (a different version, not a mismatch):'
      notes.each { |n| lines << "  #{n}" }
    end
    unless r['anchor_says'].empty?
      lines << '' << 'THE ANCHOR SAYS (not checked by this tool unless marked confirmed):'
      r['anchor_says'].each { |s| lines << "  - #{s}" }
    end
    unless r['not_checked'].empty?
      lines << '' << 'NOT CHECKED by anyone (the record\'s not_checked):'
      r['not_checked'].each { |s| lines << "  - #{s}" }
    end
    lines.concat(opened_lines(r['opened'])) if r['opened']
    lines << ''
    r['statements'].each { |s| lines << s }
    lines.join("\n")
  end

  # Locators and results only — never a fingerprint or the key.
  def opened_lines(o)
    lines = ['', 'CHECKED WITH THE KEY (gc-commitment-0.1; the key was read here and written nowhere):', "  key: #{o['key']}"]
    { 'match' => 'matches the bundle', 'mismatch' => 'does NOT match the bundle',
      'not_in_bundle' => 'has no hmac_sha256 in the bundle', 'unreadable' => 'local file could not be read' }.each do |k, text|
      o[k].each { |loc| lines << "  [#{k == 'match' ? 'ok' : k.upcase}] #{loc}: #{text}" }
    end
    lines
  end

  # The boolean the verifier sets when it used the key, not the wording of
  # its message (round-1 implementation review, Sonnet P3).
  def opened_ok?(o)
    o.nil? || (o['key_ok'] == true && %w[mismatch not_in_bundle unreadable].all? { |k| o[k].empty? })
  end

  def run(argv)
    opts = options(argv)
    abort 'gc_prov_verify: give the bundle file' if opts[:bundle].nil?
    abort 'gc_prov_verify: give --proof-id or --envelope' if opts[:proof_id].nil? && opts[:envelope].nil?
    abort 'gc_prov_verify: --open needs --commitment-key' if !opts[:opens].empty? && opts[:key].nil?
    GcProvVerifyPaths.add_signature_libs if opts[:anchor_pubkey]

    route, error = opts[:envelope] ? [JSON.parse(File.read(opts[:envelope])), nil] : fetch(opts[:anchor], opts[:proof_id])
    receipts = opts[:zk].to_h { |p| b = File.binread(p); [Digest::SHA256.hexdigest(b), b] }
    common = { bundle_text: File.read(opts[:bundle]), route: route, fetch_error: error, submitter_pubkey: opts[:submitter],
               anchor_pubkey_pem: opts[:anchor_pubkey] && File.read(opts[:anchor_pubkey]) }
    rtype = record_type(route)
    reach = rtype == GenomicsChainProv::ReachVerifier::RECORD_TYPE
    # the key opens a prov record's salted fingerprints; given with any other
    # record it would be silently ignored (round-1 review, Sonnet P2, Fable #5).
    # Any stated record_type other than the prov one (pre-flight r2); a record
    # that states none is left to the prov verifier, which reports it.
    if opts[:key] && !rtype.nil? && rtype != GenomicsChainProv::VerdictSpec::Prov::RECORD_TYPE
      warn "gc_prov_verify: --commitment-key and --open are used only with a #{GenomicsChainProv::VerdictSpec::Prov::RECORD_TYPE} " \
           "record; this record is #{rtype}"
      return 2
    end
    result = if reach
               GenomicsChainProv::ReachVerifier.new(**common, prov_proof_id: opts[:prov_proof_id]).run
             else
               key = opts[:key] && File.binread(opts[:key])
               GenomicsChainProv::Verifier.new(**common, receipts: receipts, commitment_key: key, opens: opts[:opens]).run
             end
    result['proof_id'] ||= opts[:proof_id]
    puts(opts[:json] ? JSON.pretty_generate(result) : report(result))
    code = { 'consistent' => 0, 'mismatch' => 1 }.fetch(result['state'], 2)
    code.zero? && !opened_ok?(result['opened']) ? 1 : code
  rescue Errno::ENOENT => e
    warn "gc_prov_verify: #{e.message}"
    2
  end
end

exit GcProvVerify.run(ARGV) if $PROGRAM_NAME == __FILE__
