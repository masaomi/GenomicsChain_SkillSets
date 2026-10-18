# frozen_string_literal: true

require 'json'
require 'digest'
require 'base64'
require_relative 'identity'
require_relative 'zk_verifier'

module GenomicsChainProv
  # Verifier — what a third party holding a bundle and a proof can say about
  # them, and what it cannot (design v0.1 §8, v0.1.12 §6.1). The logic behind
  # bin/gc_prov_verify.rb, kept apart from the network so every row of §8's
  # table is testable.
  #
  # The rule (§8, round 2): a line goes under "confirmed" only when this code
  # computed it from bytes it holds. What the anchor's envelope asserts stays
  # under "the anchor says" — until an anchor public key is supplied, at which
  # point the anchor's signature, and the fields inside it, move up. `revoked`
  # never moves: it is outside the signature.
  #
  # Input `route` is the JSON body of GET /place/web/prov/proof/<id> (the
  # envelope fields, plus `manifest` and `revoked`). The manifest is read from
  # `evidence` — the bytes the anchor signed — not from the route's parsed
  # convenience copy.
  class Verifier
    CANONICALIZATIONS = { Identity::BUNDLE_DIGEST_CANONICALIZATION => ->(text) { Identity.bundle_digest(text) } }.freeze
    OUTPUTS_RULES = [Predicate::OUTPUTS_DIGEST_RULE].freeze
    ENVELOPE_VERSIONS = %w[1.0.0 1.1.0].freeze
    VERSIONS_CARRYING_IDENTITY = %w[1.1.0].freeze

    NOT_CHECKED_TEXT = {
      'locator_reachability' => 'whether the locators in the bundle can still be fetched',
      'bundle_truthfulness' => 'whether the bundle describes the run truthfully (the producer and enricher are believed)',
      'bundle_schema_conformance' => 'whether the bundle conforms to the BCO schema',
      'checksum_values_as_written' => 'whether the checksums written in the bundle are correct (they are counted as written)',
      'reference_genome_identification' => 'which reference genome was used (a name guess is not recorded)',
      'seed_identification' => 'which random seed was used (a name guess is not recorded)',
      'platform_as_written' => 'whether the CPU architecture and OS the bundle states are true',
      'zk_guest_program_semantics' => 'what the ZK guest program computes (the image ID names a program, not its meaning)',
      'zk_inputs_are_raw_data' => 'whether the inputs a ZK receipt binds are the raw data',
      'resources_as_written' => 'whether the computing resources the bundle states (the machine, its GPUs, each ' \
                                "stage's requested and observed values) are true"
    }.freeze
    NOT_RECONSTRUCTED = 'whether the outputs are correct, or whether a rebuild gives the same outputs (Tier 3)'

    # @param bundle_text [String]
    # @param route [Hash, nil] the route's JSON body
    # @param fetch_error [Hash, nil] {'status' => Integer or nil, 'reason' => String} when no body came back
    # @param submitter_pubkey [String, nil] the customer's key, from outside the record
    # @param anchor_pubkey_pem [String, nil] the anchor's RSA public key (PEM), from outside the record
    # @param receipts [Hash] sha256 => bytes, receipts this verifier holds
    def initialize(bundle_text:, route: nil, fetch_error: nil, submitter_pubkey: nil, anchor_pubkey_pem: nil,
                   receipts: {}, zk_verifier: nil)
      @text = bundle_text
      @route = route
      @fetch_error = fetch_error
      @submitter_pubkey = blank(submitter_pubkey)
      @anchor_pem = blank(anchor_pubkey_pem)
      @receipts = receipts || {}
      @zk = zk_verifier || ZkVerifier.new
    end

    def run
      @out = { 'state' => nil, 'proof_id' => @route && @route['proof_id'], 'bundle_digest' => nil,
               'confirmed' => [], 'version_note' => nil, 'resources_version_note' => nil, 'anchor_says' => [],
               'record_notes' => [], 'not_checked' => [], 'statements' => Identity::STATEMENTS }
      @out['bundle_digest'] = Identity.bundle_digest(@text)
      return not_comparable(fetch_reason) if @fetch_error || @route.nil?

      evidence = parse_evidence
      return not_comparable(evidence) if evidence.is_a?(String)

      @manifest = evidence['manifest']
      @evidence = evidence
      reason = unreadable_reason
      return not_comparable(reason) if reason

      envelope_notes
      bundle_checks
      anchor_lines
      not_checked_lines
      @out['state'] = @out['confirmed'].all? { |c| c['ok'] } ? 'consistent' : 'mismatch'
      @out
    rescue Adapters::Bco::FormatError => e
      @out.merge('state' => 'bundle_unreadable', 'record_notes' => ["the bundle cannot be read: #{e.message}"])
    end

    private

    # --- the §8 table, rows 6–8: nothing to compare against -------------------

    def fetch_reason
      return 'no proof was given to compare against' if @fetch_error.nil? && @route.nil?

      status = @fetch_error['status']
      case status
      when 404 then 'the anchor does not know this proof_id as a provenance record'
      when 429 then 'the anchor\'s read route refused (429, rate limited) — try again later'
      when nil then "the anchor could not be reached (#{@fetch_error['reason']})"
      else "the anchor's read route refused (HTTP #{status})"
      end
    end

    def not_comparable(reason)
      @out['state'] = 'not_comparable'
      @out['record_notes'] << "#{reason}; only the bundle's own digest is printed"
      @out
    end

    def parse_evidence
      ev = @route['evidence']
      parsed = ev.is_a?(String) ? JSON.parse(ev) : nil
      return 'this proof cannot be read as a provenance record (evidence is not JSON)' unless parsed.is_a?(Hash)
      return 'this proof cannot be read as a provenance record (no manifest)' unless parsed['manifest'].is_a?(Hash)

      parsed
    rescue JSON::ParserError
      'this proof cannot be read as a provenance record (evidence is not JSON)'
    end

    def unreadable_reason
      m = @manifest
      prefix = 'this proof cannot be read as a provenance record'
      return "#{prefix} (record_type is not prov_attestation)" unless m['record_type'] == 'prov_attestation'
      unless CANONICALIZATIONS.key?(m['bundle_digest_canonicalization'])
        return "#{prefix} (unknown digest rule #{m['bundle_digest_canonicalization'].inspect})"
      end
      return "#{prefix} (unknown outputs rule #{m['outputs_digest_rule'].inspect})" unless OUTPUTS_RULES.include?(m['outputs_digest_rule'])
      return "#{prefix} (unknown envelope version #{@route['version'].inspect})" unless ENVELOPE_VERSIONS.include?(@route['version'])

      nil
    end

    # --- §8 table, rows 4–5: the envelope itself ----------------------------

    def envelope_notes
      missing = %w[attester_id subject_ref claim].select { |k| blank(@route[k]).nil? }
      unless missing.empty?
        @out['record_notes'] << "the envelope lacks #{missing.join(', ')} — incomplete as an anchor record; " \
                                'the manifest inside the evidence is still compared'
      end
      return unless identity_outside_signature?

      @out['record_notes'] << "the envelope's submitter_pubkey sits outside the signature (version " \
                              "#{@route['version']}) — ignored; manifest.operator.pubkey is used"
    end

    def identity_outside_signature?
      !VERSIONS_CARRYING_IDENTITY.include?(@route['version']) && !blank(@route['submitter_pubkey']).nil?
    end

    # --- confirmed: computed here from the bytes held -------------------------

    def bundle_checks
      m = @manifest
      digest = CANONICALIZATIONS.fetch(m['bundle_digest_canonicalization']).call(@text)
      confirm('bundle_digest', digest == m['bundle_digest'],
              "bundle digest (#{m['bundle_digest_canonicalization']}) #{digest} " \
              "#{digest == m['bundle_digest'] ? '=' : '≠'} the record's #{m['bundle_digest']}")
      confirm('subject_ref', @route['subject_ref'] == "prov:sha256:#{digest}",
              "envelope subject_ref #{@route['subject_ref'] == "prov:sha256:#{digest}" ? 'names' : 'does NOT name'} this bundle")
      body = Digest::SHA256.hexdigest(KairosMcp::Manifest.canonical_json(m))
      confirm('manifest_body_sha256', body == @evidence['manifest_body_sha256'],
              'evidence.manifest_body_sha256 matches the manifest it carries')
      pubkey = m.dig('operator', 'pubkey')
      unless identity_outside_signature? || blank(@route['submitter_pubkey']).nil?
        confirm('submitter_pubkey', @route['submitter_pubkey'] == pubkey,
                'envelope submitter_pubkey = manifest.operator.pubkey')
      end

      params = Identity.params_from_manifest(m)
      if params.nil?
        @out['version_note'] = "record_version #{m['record_version'].inspect} is not one this tool knows: the set of " \
                               'signed fields is unknown, so the submitter\'s signature, the claim and the ' \
                               'submission_key are not rebuilt. This is a difference of version, not a mismatch.'
        return
      end

      key = Digest::SHA256.hexdigest(KairosMcp::Manifest.canonical_json(
                                       'digest_subject_hash' => m['bundle_digest'], 'signed_identity' => params,
                                       'operator_pubkey' => pubkey
                                     ))
      confirm('submission_key', key == m['submission_key'], 'submission_key rebuilt from the signed fields')
      claim = Identity.claim(params, m['submission_key'])
      confirm('claim', claim == @route['claim'], "claim rebuilt: #{claim}")
      submitter_signature(params, pubkey)
      rederive(params)
      zk_check
    end

    def submitter_signature(params, manifest_pubkey)
      sig = @manifest.dig('operator', 'signature') || {}
      payload = KairosMcp::Manifest.canonical_json(
        'mcp_tool_name' => @manifest['mcp_tool_name'], 'params' => params,
        'nonce' => sig['nonce'], 'chain_tip_hash' => sig['chain_tip_hash']
      )
      key = @submitter_pubkey || manifest_pubkey
      ok = ed25519_valid?(key, sig['value'], payload)
      detail = if @submitter_pubkey
                 "the submitter's ed25519 signature verifies under the key given (#{@submitter_pubkey})"
               else
                 'the submitter\'s ed25519 signature is self-consistent with the key in the manifest — this does ' \
                   'not show who the submitter is (give --submitter-pubkey from outside the record)'
               end
      detail = 'the submitter\'s ed25519 signature does NOT verify' unless ok
      if @submitter_pubkey && @submitter_pubkey != manifest_pubkey
        ok = false
        detail = 'the key given is not the key the record was signed with'
      end
      confirm('submitter_signature', ok, detail)
    end

    def ed25519_valid?(pubkey, sig_b64, payload)
      require 'ed25519'
      vk = Ed25519::VerifyKey.new(decode64(pubkey.to_s.sub(/\Aed25519:/, '')))
      vk.verify(decode64(sig_b64.to_s), payload)
    rescue StandardError
      false
    end

    # §8: re-derive only under the same procedure versions; a version
    # difference is reported under its own heading and is not a mismatch.
    #
    # Two gates, not one (v0.1.14 §6.2 (5)). The seven grades and the counts
    # are re-derived when adapter, predicate and pin_strength match; the nine
    # resource fields when the resource rule and the adapter match. One gate
    # over all four would let a single change of the resource rule stop every
    # 0.4 record's seven grades from re-deriving — and the reason the resource
    # rule is a rule of its own would be gone. A 0.3 record has no resource
    # field, and nothing is said about resources for it.
    def rederive(params)
      res_keys = params.keys & Resources::SIGNED_FIELDS
      derived = nil
      local = Identity.procedure_versions
      if local.any? { |k, v| params[k] != v }
        @out['version_note'] = 'adapter / predicate / pin_strength differ — here ' \
                               "(#{local.values.join(', ')}), in the proof (#{local.keys.map { |k| params[k] }.join(', ')}). " \
                               'The grade was not re-derived. This is a difference of version, not a mismatch.'
      else
        derived = Identity.derive(@text)['signed']
        wrong = (params.keys - res_keys).reject { |k| derived[k] == params[k] }
        confirm('grades_and_counts', wrong.empty?,
                wrong.empty? ? "grade #{params['grade_overall']} and every signed count re-derived from the bundle" :
                               "re-derived from the bundle and different: #{wrong.join(', ')}")
        @out['summary'] = summary(params)
      end
      rederive_resources(params, res_keys, derived) unless res_keys.empty?
    end

    def rederive_resources(params, keys, derived)
      local = Identity.resources_versions
      if local.any? { |k, v| params[k] != v }
        @out['resources_version_note'] = 'resource rule / adapter differ — here ' \
                                         "(#{local.values.join(', ')}), in the proof " \
                                         "(#{local.keys.map { |k| params[k] }.join(', ')}). The resource fields were " \
                                         'not re-derived. This is a difference of version, not a mismatch.'
        return
      end

      derived ||= Identity.derive(@text)['signed']
      wrong = keys.reject { |k| derived[k] == params[k] }
      confirm('resources', wrong.empty?,
              wrong.empty? ? "resources grade #{params['grade_resources']} and every resource field re-derived from the bundle" :
                             "resource fields re-derived from the bundle and different: #{wrong.join(', ')}")
      # Only from fields that re-derived: a mismatching record's values are
      # whatever it holds, and the summary does arithmetic on them
      # (implementation review r1: `gpus_total: "2"` crashed the verifier).
      (@out['summary'] ||= []).concat(resources_summary(params, derived['stages_total'])) if wrong.empty?
    end

    # What the record says about resources, with where it came from beside
    # the grade (queue item: machine_source and resources_sources).
    # The stage count comes from the bundle, not the record: the record's
    # count may be the field that failed the other gate (review r2).
    def resources_summary(p, total)
      sources = Array(p['resources_sources'])
      [
        "resources: #{p['grade_resources']} (#{p['resources_rule_version']}, not part of the overall grade); " \
        "requested on #{p['stages_with_requested_resources']}/#{total} stages, observed on " \
        "#{p['stages_with_observed_resources']}/#{total}; values from #{sources.empty? ? 'nowhere' : sources.join(', ')}",
        "machine as stated (#{p['machine_source'] || 'none'}): #{gpu_line(p)}"
      ]
    end

    def gpu_line(p)
      return 'GPUs not looked for' if p['gpus_total'].nil?

      probed = Array(p['gpu_vendors_probed'])
      looked = probed.empty? ? 'stated, no probe ran' : "probed for #{probed.join(', ')}"
      return "no GPU (#{looked})" if p['gpus_total'].zero?

      models = Array(p['gpu_models'])
      withheld = p['gpus_total'] - models.sum { |g| g['count'] }
      named = models.map { |g| "#{g['count']} × #{g['vendor']} #{g['model']}" }
      line = "#{p['gpus_total']} GPU(s)#{named.empty? ? '' : ": #{named.join(', ')}"} (#{looked})"
      withheld.positive? ? "#{line}; #{withheld} with the model withheld" : line
    end

    def summary(p)
      levels = Predicate::LEVELS
      sw = levels.map { |l| "#{l} #{p["software_#{l}"]}" }.reject { |s| s.end_with?(' 0') }.join(' / ')
      plat = %w[platform_cpu_architecture platform_os_name platform_os_release].map { |k| p[k] }
      [
        "stages #{p['stages_total']}, of which #{p['stages_with_own_environment']} declare their own environment",
        "software #{p['software_total']}#{sw.empty? ? '' : " (#{sw})"}; inputs #{p['inputs_total']}, " \
        "#{p['inputs_with_checksum']} with a checksum; outputs #{p['outputs_total']}, #{p['outputs_with_checksum']} with a checksum",
        "platform as stated in the bundle: #{plat.compact.empty? ? 'not stated' : plat.compact.join(' ')}",
        "zk receipts declared: #{Array(p['zk_receipts']).length}"
      ]
    end

    def zk_check
      declared = Array(Identity.derive(@text)['np'].zk_receipts)
      @zk_confirmed = false
      return if declared.empty? || @receipts.empty?
      return @out['record_notes'] << "zk receipts not checked here: gc_zk_verify is not installed (#{@zk.bin})" unless ZkVerifier.available?(@zk.bin)

      res = @zk.check(declared, @receipts)
      codes = res['results'].map { |r| "stage #{r['stage']}: #{r['code']}" }.join(', ')
      confirm('zk_receipts', res['ok'], "zk receipts verified here and bound to their steps (#{codes})")
      @zk_confirmed = res['ok']
    rescue ZkVerifier::Unavailable => e
      @out['record_notes'] << "zk receipts not checked here: #{e.message}"
    end

    # --- what the anchor says ---------------------------------------------------

    def anchor_lines
      says = @out['anchor_says']
      signed = anchor_signature
      where = signed ? 'confirmed with the anchor key given' : 'anchor-reported'
      says << "witnessed at #{@route['timestamp']} by attester #{@route['attester_id']} (#{where})"
      ttl = @route['ttl']
      says << (expired? ? "freshness: the TTL has passed (timestamp #{@route['timestamp']}, ttl #{ttl} s) — " \
                          'a mark of age, not of an invalid record' :
                          "freshness: within its TTL (#{ttl} s from #{@route['timestamp']})")
      says << "revoked: #{@route['revoked'] ? 'the anchor says it revoked this proof' : 'the anchor says it has not revoked this proof'} " \
              '(always anchor-reported: revocation is outside the signature)'
      tip = @manifest.dig('operator', 'signature', 'chain_tip_hash')
      says << "chain_tip_hash #{tip}: the anchor says it checked the submitter saw a fresh ledger tip; not verified here"
      rule = @manifest['admission_rule']
      says << "admission rule #{rule}: " +
              Identity::ADMISSION_RULES.fetch(rule, 'a rule this verifier does not know (a newer anchor?)')
      zv = @manifest['zk_verification']
      if zv && !@zk_confirmed
        says << "zk receipts: #{zv['receipts_verified']} verified by #{zv['verifier']} (risc0-zkvm #{zv['risc0_zkvm']}) " \
                'and bound to their steps — anchor-reported; give --zk-receipt to check them here'
      end
    end

    # nil when no key was given; true/false otherwise (and recorded as a
    # confirmed line, which a wrong key turns into a mismatch).
    def anchor_signature
      return nil if @anchor_pem.nil?

      require 'synoptis/proof_envelope'
      require 'synoptis/verifier'
      require 'mmp/crypto'
      env = ::Synoptis::ProofEnvelope.from_h(@route.reject { |k, _| %w[manifest revoked].include?(k) })
      errors = ::Synoptis::Verifier.new.verify(env, public_key: @anchor_pem)[:errors]
      ok = !(errors.include?('invalid_signature') || errors.include?('missing_signature'))
      confirm('anchor_signature', ok,
              ok ? 'the anchor\'s signature verifies under the key given: timestamp, ttl, subject_ref, claim and ' \
                   'evidence are as the anchor signed them' :
                   'the anchor\'s signature does NOT verify under the key given — the proof is not this anchor\'s, ' \
                   'the key is another, or the serialisation differs (a non-Ruby implementation)')
      ok
    rescue LoadError
      @out['record_notes'] << 'anchor signature not checked: the synoptis and mmp libraries are not installed here'
      nil
    end

    def expired?
      ttl = @route['ttl']
      return false unless ttl

      require 'time'
      Time.now.utc > Time.parse(@route['timestamp'].to_s) + ttl.to_i
    rescue ArgumentError
      false
    end

    def not_checked_lines
      codes = Array(@manifest['not_checked'])
      @out['not_checked'] = codes.map { |c| NOT_CHECKED_TEXT.fetch(c, c) } + [NOT_RECONSTRUCTED]
    end

    def confirm(check, ok, detail)
      @out['confirmed'] << { 'check' => check, 'ok' => ok ? true : false, 'detail' => detail }
    end

    def decode64(s)
      Base64.urlsafe_decode64(s)
    rescue ArgumentError
      Base64.decode64(s)
    end

    def blank(v)
      v.nil? || v.to_s.strip.empty? ? nil : v.to_s
    end
  end
end
