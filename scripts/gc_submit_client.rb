#!/usr/bin/env ruby
# frozen_string_literal: true
#
# gc_submit_client — the operator's half of the submit path.
#
# The anchor's tools (gc_tier1_submit, gc_tier2_submit) verify an ed25519
# signature over {mcp_tool_name, params, nonce, chain_tip_hash}, where params
# are DERIVED from the thing being submitted. Nothing on the server side signs;
# this script is what does, and it is deliberately thin: the params come from
# the same core module the anchor uses (Tier1Submit / Tier2Submit
# .signed_params_for), so what is signed here is what is re-derived there.
#
# Reaches the anchor over HTTP MCP (POST /mcp, Bearer token bound to the
# operator's pubkey_hash). /mcp is not published through Caddy, so this runs
# on the anchor host itself against the container's port, or through an SSH
# tunnel — see log/handoff_meeting_update_tier2_signing_20260909.md.
#
# Usage
#   ruby scripts/gc_submit_client.rb --keygen --key operator.key
#   ruby scripts/gc_submit_client.rb --tier tier2 --adjudication a.json \
#        --repository-url URL --repository-commit SHA \
#        --key operator.key --token kc_xxx --url http://localhost:8080/mcp \
#        --tip <proofs tip hash>|--data-dir /app/.kairos [--dry-run] [--print-only]
#   ruby scripts/gc_submit_client.rb --tier tier1 --report r.json ...
#   ruby scripts/gc_submit_client.rb --tier prov --bundle bco.json \
#        [--zk-receipt receipt.bin ...] --key operator.key --token kc_xxx ...
#
# --tier prov (Tier 2.5, design v0.1 §7): the bundle travels verbatim and the
# params come from GenomicsChainProv::Identity, the function the anchor uses to
# re-derive them; run genomicschain_prov/bin/gc_prov_check.rb first to see
# whether the anchor will issue a record (receipts usable) and which grade the
# record will carry — any grade is recorded since design v0.1.13.
# Each --zk-receipt file goes along as base64 under its own sha256, for every
# receipt the bundle declares; the anchor verifies and discards them.
#
# --dry-run asks the anchor to validate only (no admission, no store). The
# envelope is still signed so the dry run exercises the same bytes.
# --print-only writes the JSON-RPC request to stdout and sends nothing.

require 'json'
require 'digest'
require 'base64'
require 'securerandom'
require 'optparse'
require 'net/http'
require 'uri'

REPO = File.expand_path('..', __dir__)
$LOAD_PATH.unshift(File.join(REPO, 'genomicschain_core', 'lib'))
require 'kairos_mcp/version'
require 'genomicschain_core/manifest'
require 'genomicschain_core/manifest/signer' # TipSource reads its tip-freshness constants
require 'genomicschain_core/tier1_submit'
require 'genomicschain_core/tier2_submit'

module GcSubmitClient
  GC = KairosMcp::SkillSets::GenomicschainCore
  TOOL = { 'tier1' => 'gc_tier1_submit', 'tier2' => 'gc_tier2_submit', 'prov' => 'gc_prov_submit' }.freeze

  module_function

  # --- key handling ---------------------------------------------------------

  def keygen(path)
    require 'ed25519'
    raise "refusing to overwrite #{path}" if File.exist?(path)

    seed = Ed25519::SigningKey.generate.to_bytes
    File.open(path, 'w', 0o600) { |f| f.write(Base64.strict_encode64(seed)) }
    key = load_key(path)
    { 'key' => path, 'pubkey' => pubkey_string(key), 'pubkey_hash' => pubkey_hash(pubkey_string(key)) }
  end

  def load_key(path)
    require 'ed25519'
    raw = File.read(path).strip
    seed = raw.length == 64 && raw =~ /\A[0-9a-f]+\z/i ? [raw].pack('H*') : Base64.decode64(raw)
    raise "key file #{path} does not hold a 32-byte ed25519 seed" unless seed.bytesize == 32

    Ed25519::SigningKey.new(seed)
  end

  def pubkey_string(key)
    'ed25519:' + Base64.urlsafe_encode64(key.verify_key.to_bytes, padding: false)
  end

  # What a pubkey-bound Bearer stores (Authenticator compares against this).
  def pubkey_hash(pubkey_str)
    Digest::SHA256.hexdigest(pubkey_str)
  end

  # --- what gets signed -------------------------------------------------------

  # For prov, `subject` is the bundle's text: the digest the anchor recomputes
  # is of the bytes it receives, so the client derives from the same bytes.
  def signed_params(tier, subject, repository)
    case tier
    when 'tier2' then GC::Tier2Submit.signed_params_for(subject, repository)
    when 'tier1' then GC::Tier1Submit.signed_params_for(subject)
    when 'prov' then load_prov && GenomicsChainProv::Identity.derive(subject)['signed']
    else raise ArgumentError, "unknown tier #{tier.inspect}"
    end
  end

  # genomicschain_prov needs genomicschain_tier2 (the PinStrength rule); both
  # are loaded only for --tier prov, so Tier-1/2 use needs neither.
  def load_prov
    %w[genomicschain_tier2 genomicschain_prov].each do |pkg|
      lib = File.join(REPO, pkg, 'lib')
      $LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
    end
    require 'genomicschain_prov'
    true
  end

  # receipt sha256 => base64, the shape gc_prov_submit's zk_receipt_bytes takes.
  def receipt_bytes(paths)
    Array(paths).to_h do |p|
      bytes = File.binread(p)
      [Digest::SHA256.hexdigest(bytes), Base64.strict_encode64(bytes)]
    end
  end

  # The exact bytes Signer#verify_signed! reconstructs on the anchor.
  def payload(tool, params, nonce, tip)
    KairosMcp::Manifest.canonical_json(
      'mcp_tool_name' => tool, 'params' => params, 'nonce' => nonce, 'chain_tip_hash' => tip
    )
  end

  def operator_envelope(key, tool, params, tip, nonce: SecureRandom.hex(16))
    sig = key.sign(payload(tool, params, nonce, tip))
    {
      'mode' => 'signed',
      'pubkey' => pubkey_string(key),
      'signature' => {
        'algorithm' => 'ed25519',
        'signed_fields' => %w[mcp_tool_name params nonce chain_tip_hash],
        'value' => Base64.urlsafe_encode64(sig, padding: false),
        'nonce' => nonce,
        'chain_tip_hash' => tip
      }
    }
  end

  def tool_arguments(tier, subject, subject_json, params, repository, operator, dry_run, zk_receipt_bytes: nil)
    case tier
    when 'tier2'
      args = { 'adjudication' => subject, 'identity' => params, 'operator' => operator }
      args['repository'] = repository if repository && !repository.empty?
    when 'tier1'
      args = { 'report_json' => subject_json, 'operator' => operator }
    when 'prov'
      args = { 'bundle' => subject_json, 'identity' => params, 'operator' => operator }
      args['zk_receipt_bytes'] = zk_receipt_bytes if zk_receipt_bytes && !zk_receipt_bytes.empty?
    end
    args['dry_run'] = true if dry_run
    args
  end

  def jsonrpc(tool, arguments, id: 1)
    { 'jsonrpc' => '2.0', 'id' => id, 'method' => 'tools/call',
      'params' => { 'name' => tool, 'arguments' => arguments } }
  end

  # --- the anchor's proofs tip ------------------------------------------------

  # Read from a data dir (on the anchor host, or a copy of it). The proofs
  # registry is what TipSource reads; an empty registry yields the genesis tip.
  def tip_from_data_dir(data_dir, synoptis_lib: nil)
    lib = synoptis_lib || File.join(data_dir, 'skillsets', 'synoptis', 'lib')
    unless File.directory?(lib)
      gem_dir = Gem::Specification.find_by_name('kairos-chain').gem_dir
      lib = File.join(gem_dir, 'templates', 'skillsets', 'synoptis', 'lib')
    end
    $LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
    require 'synoptis/registry/file_registry'
    require 'genomicschain_core/tip_source'
    registry = ::Synoptis::Registry::FileRegistry.new(data_dir: File.join(data_dir, 'synoptis_data'))
    GC::TipSource.new(registry: registry).latest_tip_hash
  end

  # --- transport ----------------------------------------------------------------

  def post(url, token, body)
    uri = URI.parse(url)
    req = Net::HTTP::Post.new(uri.request_uri)
    req['Content-Type'] = 'application/json'
    req['Accept'] = 'application/json, text/event-stream'
    req['Authorization'] = "Bearer #{token}"
    req.body = JSON.generate(body)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.read_timeout = 120
    res = http.request(req)
    [res.code.to_i, res.body]
  end

  # The tool answers with text content; unwrap it when it is JSON.
  def unwrap(body)
    outer = JSON.parse(body)
    text = outer.dig('result', 'content', 0, 'text')
    return outer if text.nil?

    JSON.parse(text)
  rescue JSON::ParserError
    text || body
  end
end

if $PROGRAM_NAME == __FILE__
  opts = { tier: 'tier2', url: 'http://localhost:8080/mcp', token: ENV['KAIROS_BEARER'] }
  OptionParser.new do |o|
    o.on('--keygen') { opts[:keygen] = true }
    o.on('--key PATH') { |v| opts[:key] = v }
    o.on('--tier TIER', %w[tier1 tier2 prov]) { |v| opts[:tier] = v }
    o.on('--adjudication FILE') { |v| opts[:subject] = v }
    o.on('--report FILE') { |v| opts[:subject] = v }
    o.on('--bundle FILE') { |v| opts[:subject] = v }
    o.on('--zk-receipt FILE') { |v| (opts[:zk] ||= []) << v }
    o.on('--repository-url URL') { |v| (opts[:repository] ||= {})['url'] = v }
    o.on('--repository-commit SHA') { |v| (opts[:repository] ||= {})['commit'] = v }
    o.on('--url URL') { |v| opts[:url] = v }
    o.on('--token TOKEN') { |v| opts[:token] = v }
    o.on('--tip HASH') { |v| opts[:tip] = v }
    o.on('--data-dir DIR') { |v| opts[:data_dir] = v }
    o.on('--synoptis-lib DIR') { |v| opts[:synoptis_lib] = v }
    o.on('--dry-run') { opts[:dry_run] = true }
    o.on('--print-only') { opts[:print_only] = true }
  end.parse!

  if opts[:keygen]
    abort '--key PATH is required with --keygen' unless opts[:key]
    puts JSON.pretty_generate(GcSubmitClient.keygen(opts[:key]))
    exit 0
  end

  abort '--adjudication FILE (tier2), --report FILE (tier1) or --bundle FILE (prov) is required' unless opts[:subject]
  abort '--key PATH is required (create one with --keygen)' unless opts[:key]

  subject_json = File.read(opts[:subject])
  tier = opts[:tier]
  subject = tier == 'prov' ? subject_json : JSON.parse(subject_json)
  tool = GcSubmitClient::TOOL.fetch(tier)

  tip = opts[:tip] || (opts[:data_dir] && GcSubmitClient.tip_from_data_dir(opts[:data_dir], synoptis_lib: opts[:synoptis_lib]))
  abort '--tip HASH or --data-dir DIR is required (the anchor checks chain_tip_hash freshness)' unless tip

  key = GcSubmitClient.load_key(opts[:key])
  params = GcSubmitClient.signed_params(tier, subject, opts[:repository])
  operator = GcSubmitClient.operator_envelope(key, tool, params, tip)
  arguments = GcSubmitClient.tool_arguments(tier, subject, subject_json, params, opts[:repository], operator, opts[:dry_run],
                                            zk_receipt_bytes: GcSubmitClient.receipt_bytes(opts[:zk]))
  request = GcSubmitClient.jsonrpc(tool, arguments)

  if opts[:print_only]
    puts JSON.pretty_generate(request)
    exit 0
  end

  abort '--token TOKEN (or KAIROS_BEARER) is required to send' unless opts[:token]
  code, body = GcSubmitClient.post(opts[:url], opts[:token], request)
  out = GcSubmitClient.unwrap(body)
  puts "HTTP #{code}"
  puts out.is_a?(String) ? out : JSON.pretty_generate(out)
  exit(code == 200 ? 0 : 1)
end
