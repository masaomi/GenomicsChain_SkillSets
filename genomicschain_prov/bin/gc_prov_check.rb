#!/usr/bin/env ruby
# frozen_string_literal: true
#
# gc_prov_check — the customer's look at a provenance bundle before it goes to
# the anchor (design v0.1 §3, §7; v0.1.12 §6.1). No network.
#
# It answers the questions the anchor will answer, with the same code:
#
#   what is this bundle's digest          (the digest subject, §2)
#   what grade, and why                   (§5; per item, with reasons)
#   what the resources grade is           (v0.1.14 §6.2; beside the grade, not in it)
#   what exactly would be signed          (signed_params, §6)
#   will the anchor issue a record        (the ZK declarations; any grade is recorded)
#   do my ZK receipts hold                (①–④ locally, when gc_zk_verify is
#                                          installed and --zk-receipt is given;
#                                          ①–⑤ for gc-zk-journal-0.2, v0.1.16)
#
# What it cannot answer is whether a particular anchor offers option 2
# (gc-zk-journal-0.2, design v0.1.16 S4): that is the anchor's own setting,
# so a 0.2 bundle this tool calls issuable may be refused there with
# `convention_not_offered`.
#
# This runs on the customer's machine, so — unlike the anchor — it may print
# the bundle's own values: item names, locators, the reasons a version string
# graded as it did. That is the point of running it here first.
#
# Lives in bin/, not tools/ (design §7: `Skillset#load!` requires tools/*.rb on
# every node, the anchor included).
#
# Usage
#   ruby genomicschain_prov/bin/gc_prov_check.rb bco.json
#   ruby genomicschain_prov/bin/gc_prov_check.rb bco.json --items
#   ruby genomicschain_prov/bin/gc_prov_check.rb bco.json --zk-receipt receipt.bin --json
#
# Exit status: 0 the anchor would issue a record; 1 it would not (the reason is
# printed); 2 the bundle cannot be read.

require 'json'
require 'optparse'

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'genomicschain_prov'
require 'genomicschain_prov/zk_verifier'

module GcProvCheck
  Identity = GenomicsChainProv::Identity
  Bco = GenomicsChainProv::Adapters::Bco

  module_function

  def options(argv)
    opts = { json: false, items: false, zk: [] }
    parser = OptionParser.new do |o|
      o.banner = 'Usage: gc_prov_check.rb BUNDLE [--json] [--items] [--zk-receipt FILE ...]'
      o.on('--json', 'machine-readable output (signed_params, admission, grades, items)') { opts[:json] = true }
      o.on('--items', 'list every graded item with its reason') { opts[:items] = true }
      o.on('--zk-receipt FILE', 'a receipt file to check locally against the bundle (repeatable)') { |v| opts[:zk] << v }
      o.on('-h', '--help') { puts o; exit 0 }
    end
    parser.parse!(argv)
    opts[:bundle] = argv.shift
    opts
  end

  # @return [Hash] everything this tool knows about the bundle
  def check(text, receipt_paths = [], verifier: GenomicsChainProv::ZkVerifier.new)
    derived = Identity.derive(text)
    admission = Identity.admission(derived)
    { 'bundle_digest' => derived['bundle_digest'],
      'bundle_digest_canonicalization' => Identity::BUNDLE_DIGEST_CANONICALIZATION,
      'record_version' => Identity::RECORD_VERSION,
      'signed_params' => derived['signed'],
      'admission' => admission,
      'zk_local' => zk_local(derived, admission, receipt_paths, verifier),
      'graded' => derived['graded'],
      'platform' => derived['np'].platform,
      'resources' => derived['resources'].slice('machine', 'steps'),
      'notes' => derived['np'].notes + derived['resources']['notes'],
      'versions' => { 'adapter' => Bco::VERSION, 'predicate' => derived['graded']['predicate_version'],
                      'pin_strength' => derived['graded']['pin_strength_version'],
                      'resources_rule' => derived['signed']['resources_rule_version'] } }
  end

  # ①–④ on this machine. Not run — and said so — when the bundle declares
  # nothing, when no receipt file was given, when the declarations are
  # already unusable, or when gc_zk_verify is not installed here.
  def zk_local(derived, admission, paths, verifier)
    declared = Array(derived['np'].zk_receipts)
    return { 'state' => 'none_declared' } if declared.empty?
    return { 'state' => 'not_checked', 'why' => 'declarations unusable' } unless admission['zk_defects'].empty?
    return { 'state' => 'not_checked', 'why' => 'no --zk-receipt given' } if paths.empty?
    unless GenomicsChainProv::ZkVerifier.available?(verifier.bin)
      return { 'state' => 'not_checked', 'why' => "gc_zk_verify not installed (#{verifier.bin})" }
    end

    bytes = paths.to_h { |p| b = File.binread(p); [Digest::SHA256.hexdigest(b), b] }
    out = verifier.check(declared, bytes, commitment: derived['np'].commitment)
    # an older binary: the receipt is not shown wrong, it is not checked here
    # (round-1 implementation review, separation-compat) — but only when that
    # is the sole reason anything is not ok; another receipt's real failure is
    # reported as failed, with every result (pre-flight r2)
    if GenomicsChainProv::ZkVerifier.only_not_supported?(out)
      return { 'state' => 'not_checked', 'why' => GenomicsChainProv::ZkVerifier::NOT_SUPPORTED_NOTE }
    end

    { 'state' => out['ok'] ? 'ok' : 'failed', 'results' => out['results'], 'undeclared' => out['undeclared'],
      'verifier' => out['verifier'] }
  rescue GenomicsChainProv::ZkVerifier::Unavailable => e
    { 'state' => 'not_checked', 'why' => e.message }
  end

  def issuable?(result)
    result['admission']['issuable'] && %w[ok none_declared not_checked].include?(result['zk_local']['state'])
  end

  def report(result, path, items: false)
    g = result['graded']
    c = g['counts']
    adm = result['admission']
    lines = []
    lines << "bundle: #{path}"
    lines << "  digest (#{result['bundle_digest_canonicalization']}): #{result['bundle_digest']}"
    lines << "  grade: #{g['grade_overall']}  (coverage #{g['coverage']} stages with their own environment)"
    lines << "  by category: #{g['grades'].map { |k, v| "#{k}=#{v}" }.join(' ')}"
    lines << "  inputs #{c['inputs_with_checksum']}/#{c['inputs_total']} with a checksum (#{c['inputs_internal']} internal), " \
             "outputs #{c['outputs_with_checksum']}/#{c['outputs_total']}, scripts #{c['scripts_with_checksum']}/#{c['scripts_total']}, " \
             "params #{c['params_count']}/#{c['params_total']}"
    p = result['platform']
    lines << "  platform: #{p ? p.values.compact.join(' ') : 'not recorded (the record will carry null)'}"
    lines.concat(resource_lines(result['signed_params'], c['stages_total']))
    lines.concat(zk_lines(result))
    lines << ''
    if issuable?(result)
      lines << "Tier 2.5: the anchor would issue a record for this bundle, carrying grade #{g['grade_overall']} " \
               '(the grade is recorded, not a condition; whoever reads the record draws its own line).'
      if adm['journal_conventions'].include?(Bco::JOURNAL_V02)
        lines << '  — if that anchor offers gc-zk-journal-0.2 receipts (option 2); one that does not refuses ' \
                 'the bundle with convention_not_offered.'
      end
    else
      lines << 'Tier 2.5: the anchor would NOT issue a record:'
      adm['bundle_refusals'].each { |code| lines << "  bundle refused: #{code}" }
      lines << "  more than #{Identity::MAX_ZK_RECEIPTS} zk receipts declared" if adm['too_many_zk_receipts']
      adm['zk_defects'].each { |d| lines << "  zk receipt for stage #{d['stage'] || '?'}: #{d['defects'].join(', ')}" }
      lines << '  a zk receipt failed the local check (see above)' if result['zk_local']['state'] == 'failed'
    end
    v = result['versions']
    lines << "  (adapter #{v['adapter']}, predicate #{v['predicate']}, pin_strength #{v['pin_strength']}, " \
             "resources rule #{v['resources_rule']}, record_version #{result['record_version']} — " \
             'the anchor refuses a signature made under other versions)'
    result['notes'].each { |n| lines << "  note: #{n}" }
    if items
      lines << ''
      g['items'].each do |i|
        lines << "  #{i['category']}#{i['stage'] ? " (stage #{i['stage']})" : ''}: #{i['name'] || '-'} " \
                 "#{i['grade']} — #{i['reason']}"
      end
    end
    lines.join("\n")
  end

  # What the record will say about resources (v0.1.14 §6.2 (3)). The
  # per-stage values and the machine stay in the bundle; only the GPU vendors
  # and models reach the record, filtered as the anchor filters them.
  def resource_lines(sp, stages_total)
    gpus = if sp['gpus_total'].nil? then 'not looked for'
           else
             named = Array(sp['gpu_models']).map { |g| "#{g['count']} × #{g['vendor']} #{g['model']}" }
             "#{sp['gpus_total']}#{named.empty? ? '' : " (#{named.join(', ')})"}"
           end
    sources = Array(sp['resources_sources'])
    ["  resources: #{sp['grade_resources']} (#{sp['resources_rule_version']}; not part of the grade above) — " \
     "requested on #{sp['stages_with_requested_resources']}/#{stages_total} stages, observed on " \
     "#{sp['stages_with_observed_resources']}/#{stages_total}, from #{sources.empty? ? 'nowhere' : sources.join(', ')}",
     "  machine: #{sp['machine_source'] || 'not recorded'}; GPUs #{gpus}"]
  end

  def zk_lines(result)
    declared = result['signed_params']['zk_receipts']
    return ['  zk receipts: none declared'] if declared.empty?

    zl = result['zk_local']
    lines = ["  zk receipts: #{declared.length} declared; local check: #{zl['state']}#{zl['why'] ? " (#{zl['why']})" : ''}"]
    Array(zl['results']).each do |r|
      lines << "    stage #{r['stage']} receipt #{r['receipt_sha256'].to_s[0, 12]}…: #{r['code']}"
    end
    lines
  end

  def run(argv)
    opts = options(argv)
    abort 'gc_prov_check: give the bundle file' if opts[:bundle].nil?
    result = check(File.read(opts[:bundle]), opts[:zk])
    puts(opts[:json] ? JSON.pretty_generate(result) : report(result, opts[:bundle], items: opts[:items]))
    issuable?(result) ? 0 : 1
  rescue Bco::FormatError => e
    warn "gc_prov_check: #{e.message}"
    2
  rescue Errno::ENOENT => e
    warn "gc_prov_check: #{e.message}"
    2
  end
end

exit GcProvCheck.run(ARGV) if $PROGRAM_NAME == __FILE__
