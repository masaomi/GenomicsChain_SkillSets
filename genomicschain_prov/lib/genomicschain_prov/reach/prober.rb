# frozen_string_literal: true

require 'json'
require 'uri'
require_relative 'rule'
require_relative 'failure'
require_relative 'reference'
require_relative 'resolver'
require_relative 'transport'
require_relative 'http'

module GenomicsChainProv
  module Reach
    # (4) The questions, one per kind of place, as Observation asks them
    # (target, then ask). Nothing is fetched beyond what the answer needs:
    # a manifest's head, a git ref advertisement, a URL's head, a conda
    # release's status.
    class Prober
      MANIFEST_TYPES = %w[
        application/vnd.oci.image.index.v1+json application/vnd.oci.image.manifest.v1+json
        application/vnd.docker.distribution.manifest.list.v2+json application/vnd.docker.distribution.manifest.v2+json
      ].freeze
      ADVERTISEMENT_TYPE = 'application/x-git-upload-pack-advertisement'
      TOKEN = /\A[\x21-\x7e]{1,16384}\z/

      # @param gate [Hash] own_names:, own_addresses:, denylist: for Gate.check
      # @param http_for [#call] deadline -> Http (the tests pass their own)
      def initialize(gate: {}, cert_store: nil, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) },
                     http_for: nil)
        @clock = clock
        @http_for = http_for || lambda do |deadline|
          Http.new(resolver: Resolver.new(deadline: deadline, clock: clock),
                   transport: Transport.new(deadline: deadline, cert_store: cert_store, clock: clock), gate: gate)
        end
      end

      def target(category, locator)
        Reference.host(Reference.read(category, locator))
      end

      # @return [String] a bucket; raises Failure / Refused for the rest
      def ask(category, locator, _host, seconds:)
        ref = Reference.read(category, locator)
        http = @http_for.call(@clock.call + seconds)
        case ref
        when Reference::Oci then oci(http, ref)
        when Reference::Git then git_refs(http, ref.url) ? 'exists' : 'not_attempted'
        when Reference::Commit then commit(http, ref)
        when Reference::Https then https(http, ref.url)
        when Reference::Conda then conda(http, ref)
        end
      end

      # --- OCI: the manifest's head, anonymously ---------------------------------

      def oci(http, ref)
        url = "https://#{ref.registry}/v2/#{ref.name}/manifests/#{ref.digest || ref.tag}"
        accept = { 'Accept' => MANIFEST_TYPES.join(', ') }
        res = http.request(url, method: 'HEAD', headers: accept)
        if res.status == 401 && (challenge = bearer(res['www-authenticate']))
          token = anonymous_token(http, challenge, ref)
          res = http.request(url, method: 'HEAD', headers: accept.merge('Authorization' => "Bearer #{token}"))
        end
        raise Failure.new("http_#{res.status}") unless res.status == 200
        # A registry answers with a manifest type; anything else is not a
        # registry's answer.
        raise Failure.new('refused') unless MANIFEST_TYPES.include?(media_type(res['content-type']))
        return 'exists' unless ref.digest

        answered = res['docker-content-digest']
        return 'exists' if answered.nil?
        return 'digest_match' if answered == ref.digest

        raise Failure.new('refused')
      end

      # Bearer realm="…",service="…",scope="…" → {'realm', 'service', 'scope'}
      def bearer(header)
        return nil unless header.to_s =~ /\ABearer\s+(.*)\z/i

        params = Regexp.last_match(1).scan(/([A-Za-z]+)="([^"]*)"/).to_h { |k, v| [k.downcase, v] }
        params['realm'] ? params : nil
      end

      # The token request is a hop of its own: through the gate, counted with
      # the redirects (design (5)). A realm that refuses an anonymous token
      # (401, 403) says the image cannot be read anonymously; any other status
      # of the realm is no answer about the image, never its 404 (review r1).
      # A realm 5xx keeps its code, so a token service that is down still
      # counts toward the breaker (review r2 N2).
      def anonymous_token(http, challenge, ref)
        http.charge_hop!
        query = URI.encode_www_form({ 'service' => challenge['service'],
                                      'scope' => challenge['scope'] || "repository:#{ref.name}:pull" }.compact)
        realm = challenge['realm']
        res = http.request("#{realm}#{realm.include?('?') ? '&' : '?'}#{query}", method: 'GET', body_cap: JSON_BYTES)
        unless res.status == 200
          keep = [401, 403].include?(res.status) || (500..599).cover?(res.status)
          raise Failure.new(keep ? "http_#{res.status}" : 'refused')
        end

        body = JSON.parse(res.body.force_encoding(Encoding::UTF_8))
        token = body.is_a?(Hash) ? (body['token'] || body['access_token']) : nil
        raise Failure.new('refused') unless token.is_a?(String) && TOKEN.match?(token)

        token
      rescue JSON::ParserError, EncodingError
        raise Failure.new('refused'), cause: nil
      end

      # --- git: the smart-HTTP ref advertisement, no subprocess -----------------

      # @return [Hash{String=>String}, nil] refname -> object id (peeled tags
      #   as "name^{}"); nil when the advertisement is larger than the anchor
      #   reads (design (4): not_attempted, a limit of the anchor's)
      def git_refs(http, repo_url)
        res = http.request("#{repo_url}/info/refs?service=git-upload-pack", method: 'GET',
                                                                            body_cap: ADVERTISEMENT_BYTES)
        raise Failure.new("http_#{res.status}") unless res.status == 200
        raise Failure.new('refused') unless media_type(res['content-type']) == ADVERTISEMENT_TYPE

        Advertisement.parse(res.body)
      rescue Failure => e
        return nil if e.code == 'too_large'

        raise
      end

      # A full object id at a ref tip (or a peeled tag) is a digest match; a
      # full id elsewhere cannot be seen without fetching objects. A ref name
      # is looked for as itself, under refs/heads/ and under refs/tags/.
      def commit(http, ref)
        refs = git_refs(http, ref.url) or return 'not_attempted'
        if Reference::HEX_OBJECT_ID.match?(ref.commit)
          return refs.value?(ref.commit) ? 'digest_match' : 'not_checkable'
        end

        names = [ref.commit, "refs/heads/#{ref.commit}", "refs/tags/#{ref.commit}"]
        names.any? { |n| refs.key?(n) } ? 'exists' : 'not_found'
      end

      # --- https: the head of the URL --------------------------------------------

      # HEAD; when a server will not answer HEAD, a GET for one byte whose
      # body is never read (a server may ignore Range and send everything).
      def https(http, url)
        res = http.request(url, method: 'HEAD')
        res = http.request(url, method: 'GET', headers: { 'Range' => 'bytes=0-0' }) if [405, 501].include?(res.status)
        return 'exists' if res.status.between?(200, 299)

        raise Failure.new("http_#{res.status}")
      end

      # --- conda: the release's status in the anaconda.org API --------------------

      def conda(http, ref)
        res = http.request("https://api.anaconda.org/release/#{ref.channel}/#{ref.name}/#{ref.version}", method: 'HEAD')
        return 'exists' if res.status == 200

        raise Failure.new("http_#{res.status}")
      end

      def media_type(value)
        value.to_s.split(';').first.to_s.strip.downcase
      end

      # The pkt-line ref advertisement of git's smart HTTP protocol, version 0,
      # read strictly: any line that is not what the protocol allows ends the
      # read as `refused`.
      module Advertisement
        BANNER = "# service=git-upload-pack\n"
        REF = %r{\A(\h{40}|\h{64}) ([^\x00\n ]+)(?:\x00[^\n]*)?\n?\z}

        module_function

        def parse(body)
          lines = pkt_lines(body.b)
          raise Failure.new('refused') unless lines.shift == BANNER && lines.shift == :flush
          raise Failure.new('refused') unless lines.pop == :flush

          lines.each_with_object({}) do |line, refs|
            m = REF.match(line) or raise Failure.new('refused')
            next if m[2] == 'capabilities^{}'

            refs[m[2]] = m[1].downcase
          end
        end

        def pkt_lines(data)
          out = []
          i = 0
          while i < data.bytesize
            len = data.byteslice(i, 4)
            raise Failure.new('refused') unless len&.match?(/\A\h{4}\z/)

            n = len.to_i(16)
            if n.zero?
              out << :flush
              i += 4
              next
            end
            raise Failure.new('refused') if n < 5 || i + n > data.bytesize

            out << data.byteslice(i + 4, n - 4)
            i += n
          end
          out
        end
      end
    end
  end
end
