# frozen_string_literal: true

require 'json'

module GenomicsChainProv
  # PlaceExtension — `gc_prov_proof`, the anchor's public read of a Tier-2.5
  # record (design v0.1 §7, §10-14).
  #
  #   GET /place/web/prov/proof/<proof_id>
  #
  # Not an MCP tool: MCP's tools/call checks the Bearer before it reads the
  # body, so no single tool can be opened to the public. Hestia's PlaceRouter
  # serves declared `public_routes` before authentication, GET/HEAD only,
  # under the shared public rate limiter (30 requests/minute per client IP).
  # A third party holding a bundle and a proof_id needs nothing from
  # GenomicsChain but this route to check the record — that is the claim of
  # §0, and a key issued per reader would turn it into "whoever GenomicsChain
  # lets in".
  #
  # Returned: proof_id, version, attester_id, subject_ref, claim, evidence (the
  # canonical JSON string the anchor signed), merkle_root, timestamp, ttl,
  # submitter_pubkey, signature, the parsed manifest, and `revoked` from the
  # registry. NOT returned: actor_user_id (the customer's Bearer user name),
  # actor_role, metadata — outside the signature, not needed to verify, and
  # the first leaks a token name (round 3, three seats).
  #
  # Only prov records and the reachability observations laid over them
  # (v0.1.15 §6.3 (7)): the registry is one proofs file for every tier, and a
  # Tier-2 manifest carries a repository URL in the clear. Any other record
  # answers exactly like an unknown id.
  class PlaceExtension
    PREFIX = '/place/web/prov'
    PROOF_PATH = %r{\A/place/web/prov/proof/([A-Za-z0-9-]{1,64})/?\z}
    RECORD_TYPES = %w[prov_attestation prov_reachability].freeze
    RETURNED = %i[proof_id version attester_id subject_ref claim evidence merkle_root timestamp ttl
                  submitter_pubkey signature].freeze
    JSON_HEADERS = { 'Content-Type' => 'application/json', 'Cache-Control' => 'no-store' }.freeze

    # @param router [Object] the Hestia PlaceRouter (unused: this route needs
    #   no session, no peer and no other extension)
    # @param registry [Object, nil] a Synoptis registry; built from the
    #   instance's data dir when nil (injected in tests)
    def initialize(router = nil, registry: nil)
      @router = router
      @registry = registry
    end

    def public_route_prefixes
      [PREFIX]
    end

    # Authenticated dispatch: this extension serves nothing there.
    def call(_env, peer_id: nil)
      nil
    end

    def public_call(env)
      return nil unless %w[GET HEAD].include?(env['REQUEST_METHOD'])

      m = PROOF_PATH.match(env['PATH_INFO'].to_s)
      return not_found unless m

      body = lookup(m[1])
      body ? [200, JSON_HEADERS.dup, [JSON.generate(body)]] : not_found
    end

    # The JSON body for a proof_id, or nil when the id is unknown or the record
    # is not a provenance record. Public for the tests and for a local
    # verifier that reads its own registry.
    def lookup(proof_id)
      envelope = registry.find_proof(proof_id)
      return nil unless envelope

      manifest = manifest_of(envelope.evidence)
      return nil unless manifest.is_a?(Hash) && RECORD_TYPES.include?(manifest['record_type'])

      h = envelope.to_h
      out = RETURNED.to_h { |k| [k.to_s, h[k]] }
      out['manifest'] = manifest
      out['revoked'] = registry.revoked?(proof_id) ? true : false
      out
    end

    private

    def not_found
      [404, JSON_HEADERS.dup, [JSON.generate('error' => 'not_found')]]
    end

    def manifest_of(evidence)
      parsed = evidence.is_a?(String) ? JSON.parse(evidence) : evidence
      parsed.is_a?(Hash) ? parsed['manifest'] : nil
    rescue JSON::ParserError
      nil
    end

    def registry
      @registry ||= begin
        require 'synoptis/registry/file_registry'
        ::Synoptis::Registry::FileRegistry.new(data_dir: File.join(KairosMcp.data_dir, 'synoptis_data'))
      end
    end
  end
end
