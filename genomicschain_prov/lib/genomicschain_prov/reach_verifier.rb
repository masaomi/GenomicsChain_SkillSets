# frozen_string_literal: true

require 'time'
require 'digest'
require_relative 'verifier'
require_relative 'reach/rule'

module GenomicsChainProv
  # ReachVerifier — what a third party holding the bundle and an observation
  # record can say about them (design v0.1.15 §6.3 (6)). Chosen by record_type
  # before anything else is read (implementation queue D1): the prov
  # verifier's re-derivations do not apply to an observation.
  #
  # CONFIRMED here: the bundle's digest and the subject_ref, the manifest body,
  # the submission_key and claim rebuilt from the six signed fields, the
  # submitter's signature, and — given the prov record's proof_id from outside
  # the record — that the observation is laid over that prov record.
  #
  # THE ANCHOR SAYS: the counts, when and by whom they were observed, and
  # whether the signer is the prov record's. These are the anchor's own
  # observation (anchor_observed): an anchor key confirms the anchor said
  # them, never that the places answered so. One line per category and
  # result, with what the result means; no sum across categories, and no sum
  # of digest_match and exists.
  class ReachVerifier < Verifier
    RECORD_TYPE = 'prov_reachability'
    RECORD_VERSIONS = %w[0.1].freeze
    SIGNED_FIELDS = %w[subject_ref prov_proof_ref bundle_digest reachability_rule scope observation_nonce].freeze

    STATEMENT = 'This observation is what the GenomicsChain anchor was told when it asked, at the recorded time, ' \
                'from its own network position. Nothing was fetched, and "answered with the same fingerprint" is ' \
                'the place\'s own answer. An answer from a host that is not a public registry may come from the ' \
                'bundle author\'s own server. It shows neither that the environment can be built nor that the ' \
                'places will still answer later.'

    NOT_CHECKED_TEXT = {
      'reachability_from_other_networks' => 'whether the places answer the same to other networks (this is the ' \
                                            'anchor\'s position only)',
      'content_not_fetched' => 'what the places hold: nothing was fetched, and a digest_match is the place\'s own answer',
      'answerer_independence' => 'who answered: a host that is not a public registry may be the bundle author\'s own',
      'buildability' => 'whether the environment can be built from these places',
      'future_reachability' => 'whether the places will still answer later'
    }.freeze

    BUCKET_TEXT = {
      'digest_match' => 'named by a content fingerprint, and the place answered with the same fingerprint (its ' \
                        'answer; nothing fetched)',
      'exists' => 'the place answered that it exists; named by a tag, version or ref name, not a fingerprint',
      'access_denied' => 'the place answered but would not show it to an anonymous reader (private, or absent — read ' \
                         'as neither)',
      'not_found' => 'the place answered that it does not exist',
      'error' => 'no answer was had (timeout, rate limit, TLS, a failure at the place) — not read as gone',
      'not_attempted' => 'the anchor did not ask (its own budget or breaker) — says nothing about the place',
      'not_checkable' => 'there is no way to ask, or the anchor\'s gate refused the address'
    }.freeze

    CLASS_TEXT = { 'public_registry' => 'from a public registry', 'other_host' => 'from another host' }.freeze

    # @param prov_proof_id [String, nil] the prov record this observation is
    #   said to be laid over, from outside the record
    def initialize(bundle_text:, route: nil, fetch_error: nil, submitter_pubkey: nil, anchor_pubkey_pem: nil,
                   prov_proof_id: nil, now: -> { Time.now.utc })
      super(bundle_text: bundle_text, route: route, fetch_error: fetch_error, submitter_pubkey: submitter_pubkey,
            anchor_pubkey_pem: anchor_pubkey_pem)
      @prov_proof_id = blank(prov_proof_id)
      @now = now
    end

    private

    # The observation's own sentence, then the two every verifier output
    # carries (Identity::STATEMENTS; review r1 G22, operator 2026-10-19).
    def statements = [STATEMENT, *Identity::STATEMENTS]

    def unreadable_reason
      m = @manifest
      prefix = 'this proof cannot be read as a reachability observation'
      return "#{prefix} (record_type is not #{RECORD_TYPE})" unless m['record_type'] == RECORD_TYPE
      return "#{prefix} (unknown record_version #{m['record_version'].inspect})" unless RECORD_VERSIONS.include?(m['record_version'])
      return "#{prefix} (unknown envelope version #{@route['version'].inspect})" unless ENVELOPE_VERSIONS.include?(@route['version'])

      nil
    end

    def bundle_checks
      m = @manifest
      digest = Identity.bundle_digest(@text)
      confirm('bundle_digest', digest == m['bundle_digest'],
              "bundle digest #{digest} #{digest == m['bundle_digest'] ? '=' : '≠'} the record's #{m['bundle_digest']}")
      ref = "prov-reach:sha256:#{digest}"
      confirm('subject_ref', @route['subject_ref'] == ref && m['subject_ref'] == ref,
              "envelope and record subject_ref #{@route['subject_ref'] == ref && m['subject_ref'] == ref ? 'name' : 'do NOT name'} this bundle")
      body = Digest::SHA256.hexdigest(KairosMcp::Manifest.canonical_json(m))
      confirm('manifest_body_sha256', body == @evidence['manifest_body_sha256'],
              'evidence.manifest_body_sha256 matches the manifest it carries')
      pubkey = m.dig('operator', 'pubkey')
      unless identity_outside_signature? || blank(@route['submitter_pubkey']).nil?
        confirm('submitter_pubkey', @route['submitter_pubkey'] == pubkey, 'envelope submitter_pubkey = manifest.operator.pubkey')
      end

      params = SIGNED_FIELDS.to_h { |k| [k, m[k]] }
      key = Digest::SHA256.hexdigest(KairosMcp::Manifest.canonical_json(
                                       'digest_subject_hash' => m['bundle_digest'], 'signed_identity' => params,
                                       'operator_pubkey' => pubkey
                                     ))
      confirm('submission_key', key == m['submission_key'], 'submission_key rebuilt from the signed fields')
      claim = "prov-reach:#{m['reachability_rule']}:#{m['bundle_digest']}:#{m['submission_key']}"
      confirm('claim', claim == @route['claim'], "claim rebuilt: #{claim}")
      submitter_signature(params, pubkey)
      prov_link(m)
    end

    def prov_link(m)
      if @prov_proof_id.nil?
        @out['record_notes'] << 'which prov record this observation is laid over is not checked: give the prov ' \
                                'record\'s proof_id (--prov-proof-id) to compare it with prov_proof_ref'
        return
      end

      ok = Digest::SHA256.hexdigest(@prov_proof_id) == m['prov_proof_ref']
      confirm('prov_proof_ref', ok,
              ok ? "laid over the prov record #{@prov_proof_id} (its SHA-256 is the record's prov_proof_ref)" :
                   "NOT laid over the prov record #{@prov_proof_id}: its SHA-256 is not the record's prov_proof_ref")
    end

    def anchor_lines
      where = envelope_says
      m = @manifest
      says = @out['anchor_says']
      says << "observed by #{m['observer'].inspect} at #{m['observed_at']}#{age(m['observed_at'])} under rule " \
              "#{m['reachability_rule']} (#{where}; the observation itself is the anchor's, anchor_observed)"
      says << "same signer as the prov record: #{m['same_signer'] ? 'yes' : 'no'} (#{where})"
      Array(m['counts']&.keys).each { |cat| says.concat(category_lines(cat, m['counts'][cat])) }
    end

    def age(stamp)
      days = ((@now.call - Time.iso8601(stamp.to_s)) / 86_400).floor
      days.negative? ? ' (after this check\'s clock)' : " (#{days} day#{days == 1 ? '' : 's'} before this check)"
    rescue ArgumentError
      ''
    end

    def category_lines(cat, c)
      return ["#{cat}: counts not readable"] unless c.is_a?(Hash)

      lines = ["#{cat}: #{c['items']} item(s), #{c['distinct']} distinct place(s) asked or judged"]
      Reach::BUCKETS.each do |b|
        v = c[b]
        if v.is_a?(Hash)
          v.each { |cls, n| lines << "  #{cat} #{b} #{CLASS_TEXT.fetch(cls, cls)}: #{n} — #{BUCKET_TEXT[b]}" if n.to_i.positive? }
        elsif v.to_i.positive?
          lines << "  #{cat} #{b}: #{v} — #{BUCKET_TEXT[b]}"
        end
      end
      lines
    end

    def not_checked_lines
      @out['not_checked'] = Array(@manifest['not_checked']).map { |c| NOT_CHECKED_TEXT.fetch(c, c) }
    end
  end
end
