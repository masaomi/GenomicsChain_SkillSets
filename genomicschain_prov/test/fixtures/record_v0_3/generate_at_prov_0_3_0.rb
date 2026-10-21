# frozen_string_literal: true

# Writes the record_version 0.3 fixture that design v0.1.14 (6)(ii) asks for:
# a record made by prov 0.3.0, BEFORE the v0.1.14 change, so the new verifier
# can be shown to read an old record as consistent. The existing tests make
# their records on the spot with whatever code is loaded, so until this
# fixture existed no test held a record the old code had made.
#
# Run once, at prov 0.3.0 (worktree base ffdc34d). It refuses to run under
# any other version: re-run after the change, it would overwrite the old
# record with a new one and the test would prove nothing.
#
#   T=<kairos-chain 3.87.1>/templates/skillsets
#   ruby -I../../lib -I../../../genomicschain_core/lib -I../../../genomicschain_tier2/lib \
#        -I"$T/synoptis/lib" -I"$T/mmp/lib" generate_at_prov_0_3_0.rb
require 'json'
require 'tmpdir'
require 'digest'
require 'base64'
require 'fileutils'
require 'securerandom'
require 'ed25519'
require 'kairos_mcp/version'
require 'synoptis/proof_envelope'
require 'synoptis/verifier'
require 'synoptis/attestation_engine'
require 'synoptis/registry/file_registry'
require 'mmp/crypto'

$LOAD_PATH.unshift(File.expand_path('../../../lib', __dir__))
require 'genomicschain_core'
require 'genomicschain_prov'
require 'genomicschain_prov/writer/environment'
require 'genomicschain_prov/prov_submit'
require 'genomicschain_prov/place_extension'

unless GenomicsChainProv::VERSION == '0.3.0' && GenomicsChainProv::Identity::RECORD_VERSION == '0.3'
  abort "refusing: this writes the prov 0.3.0 fixture, and the loaded code is prov #{GenomicsChainProv::VERSION}"
end

OUT = __dir__
GCORE = KairosMcp::SkillSets::GenomicschainCore
W = GenomicsChainProv::Writer

Dir.mktmpdir('record_v0_3') do |dir|
  run = File.join(dir, 'run')
  FileUtils.mkdir_p(File.join(run, 'tools'))
  File.write(File.join(run, 'reads.fastq'), "@r1\nACGT\n+\nIIII\n")
  File.write(File.join(run, 'counts.tsv'), "gene\tcount\nG1\t1\n")
  File.write(File.join(run, 'tools', 'count.sh'), "#!/bin/sh\n")
  File.write(File.join(run, 'run.sh'), "#!/bin/sh\n")
  plan = W.normalise_plan(
    'name' => 'record-v0-3-fixture', 'script' => 'run.sh',
    'runtime' => { 'engine' => 'sh', 'version' => '5.2.21', 'uri' => '/bin/sh', 'path' => '/bin/sh' },
    'platform' => { 'cpu_architecture' => 'x86_64', 'os_name' => 'Linux', 'os_release' => '6.8.0' },
    'params' => [{ 'param' => 'min_count', 'value' => '1' }],
    'stages' => [{ 'name' => 'count', 'inputs' => ['reads.fastq'], 'outputs' => ['counts.tsv'],
                   'tools' => [{ 'name' => 'count.sh', 'version' => '0.1.0', 'uri' => 'tools/count.sh' }] }]
  )
  r = W::Environment.resolve!(plan, base_dir: run, docker: false)
  text = JSON.pretty_generate(W.build(plan, checksums: r['checksums'], platform: plan['platform'],
                                          object_id: 'urn:uuid:00000000-0000-4000-8000-000000000003',
                                          created: '2026-10-17T00:00:00Z'))

  registry = ::Synoptis::Registry::FileRegistry.new(data_dir: File.join(dir, 'proofs'))
  tip = GCORE::TipSource.new(registry: registry)
  KairosMcp::Manifest::Signer.bootstrap_seen_list!(tip_source: tip)
  sk = Ed25519::SigningKey.generate
  pubkey = 'ed25519:' + Base64.urlsafe_encode64(sk.verify_key.to_bytes, padding: false)
  params = GenomicsChainProv::ProvSubmit.signed_params_for(text)
  nonce = SecureRandom.hex(16)
  payload = KairosMcp::Manifest.canonical_json('mcp_tool_name' => 'gc_prov_submit', 'params' => params,
                                               'nonce' => nonce, 'chain_tip_hash' => tip.latest_tip_hash)
  op = { 'mode' => 'signed', 'pubkey' => pubkey,
         'signature' => { 'algorithm' => 'ed25519', 'signed_fields' => %w[mcp_tool_name params nonce chain_tip_hash],
                          'value' => Base64.urlsafe_encode64(sk.sign(payload), padding: false),
                          'nonce' => nonce, 'chain_tip_hash' => tip.latest_tip_hash } }
  anchor = MMP::Crypto.new(auto_generate: true)
  engine = ::Synoptis::AttestationEngine.new(registry: registry,
                                             config: { 'require_signature' => true, 'default_ttl' => 86_400 })
  attestor = GCORE::Attestation::SynoptisAttestor.new(engine: engine, attester_id: 'mmp:fixture-anchor', crypto: anchor,
                                                    submitter_pubkey: pubkey, registry: registry)
  out = GenomicsChainProv::ProvSubmit.submit(
    bundle: text, identity: params, operator: op, bearer_pubkey_hash: Digest::SHA256.hexdigest(pubkey),
    tip_source: tip, attestor: attestor, registry: registry
  )
  abort "not recorded: #{out.inspect}" unless out[:status] == 'recorded'

  route = GenomicsChainProv::PlaceExtension.new(nil, registry: registry).lookup(out[:synoptis_proof_id])
  File.write(File.join(OUT, 'bundle.json'), text)
  File.write(File.join(OUT, 'route.json'), "#{JSON.pretty_generate(route)}\n")
  File.write(File.join(OUT, 'anchor_pubkey.pem'), anchor.export_public_key)
  File.write(File.join(OUT, 'submitter_pubkey.txt'), "#{pubkey}\n")
  File.write(File.join(OUT, 'made_with.json'), "#{JSON.pretty_generate(
    'prov' => GenomicsChainProv::VERSION, 'record_version' => GenomicsChainProv::Identity::RECORD_VERSION,
    'adapter' => GenomicsChainProv::Adapters::Bco::VERSION,
    'predicate' => GenomicsChainProv::Predicate::PREDICATE_VERSION,
    'pin_strength' => GenomicsChainProv::Predicate::PIN_STRENGTH_VERSION,
    'writer' => W::VERSION, 'kairos_mcp' => KairosMcp::VERSION, 'ruby' => RUBY_VERSION,
    'worktree_base' => 'ffdc34d', 'grade_overall' => params['grade_overall']
  )}\n")
  puts "recorded #{out[:synoptis_proof_id]} grade #{params['grade_overall']}"
end
