# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'digest'

module GenomicsChainRegwatch
  # Fetches one URL and reduces it to a digest that is stable across cosmetic
  # change but moves when the text does.
  #
  # Raw-byte digests are useless on a government HTML page: a session token, a
  # rotating banner or a build timestamp fires every run, and a watcher that
  # cries every run is switched off within a week. So the body is normalised
  # first, and the watchlist can narrow further with `watch: pattern:<regex>`
  # when what matters is one version string rather than a whole page.
  class Fetcher
    Result = Struct.new(:url, :ok, :status, :digest, :excerpt, :bytes, :reason, keyword_init: true)

    DEFAULT_TIMEOUT = 20
    MAX_REDIRECTS = 5
    MAX_BODY = 8 * 1024 * 1024

    # A plain library UA. Several of the sources in this watchlist sit behind
    # a WAF that blocks non-browser agents; the honest response to that is an
    # `unreachable` finding, not a forged user agent. Pretending to be a
    # browser to get past a block someone deliberately installed is not a
    # thing this tool does on the operator's behalf.
    USER_AGENT = "genomicschain_regwatch/#{VERSION} (+regulatory watch; contact repository owner)"

    def initialize(timeout: DEFAULT_TIMEOUT, http: nil)
      @timeout = timeout
      @http = http # injectable for tests
    end

    def fetch(url, watch = 'text')
      return unreachable(url, 'no url in watchlist entry') if url.nil? || url.strip.empty?

      body, status = get(url)
      return unreachable(url, "HTTP #{status}", status) if body.nil?

      normalised = normalise(body, watch, url)
      if normalised.nil?
        return Result.new(url: url, ok: false, status: status, reason: "pattern matched nothing",
                          bytes: body.bytesize)
      end

      Result.new(
        url: url, ok: true, status: status,
        digest: Digest::SHA256.hexdigest(normalised),
        excerpt: normalised[0, 240],
        bytes: body.bytesize
      )
    rescue StandardError => e
      unreachable(url, "#{e.class}: #{e.message}")
    end

    private

    def unreachable(url, reason, status = nil)
      Result.new(url: url, ok: false, status: status, reason: reason)
    end

    def get(url, depth = 0)
      return [nil, 'too many redirects'] if depth > MAX_REDIRECTS

      uri = URI.parse(url)
      return [nil, "unsupported scheme #{uri.scheme}"] unless %w[http https].include?(uri.scheme)

      resp = @http ? @http.call(uri) : perform(uri)

      case resp
      when Net::HTTPSuccess
        [resp.body.to_s.byteslice(0, MAX_BODY), resp.code]
      when Net::HTTPRedirection
        loc = resp['location']
        return [nil, "redirect without location (#{resp.code})"] if loc.nil?
        get(URI.join(url, loc).to_s, depth + 1)
      else
        [nil, resp.code]
      end
    end

    def perform(uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                                          open_timeout: @timeout, read_timeout: @timeout) do |http|
        http.request(Net::HTTP::Get.new(uri, 'User-Agent' => USER_AGENT,
                                             'Accept' => 'text/html,application/xhtml+xml,application/pdf,*/*'))
      end
    end

    # `watch` selects how much of the body is compared:
    #   full            — every byte. Right for a PDF, wrong for a live page.
    #   text            — markup and whitespace removed. The default.
    #   pattern:<regex> — only what the regex matches, joined. Use this to
    #                     watch a version string or an adoption date rather
    #                     than a whole page.
    def normalise(body, watch, url)
      case watch.to_s
      when /\Apattern:(.+)\z/m
        re = Regexp.new(Regexp.last_match(1))
        hits = body.scrub.scan(re).flatten.compact
        return nil if hits.empty?
        hits.map { |h| h.to_s.strip }.join("\n")
      when 'full'
        body
      else
        text_of(body, url)
      end
    end

    def text_of(body, url)
      s = body.scrub
      # A PDF has no markup to strip and its bytes are stable, so leave it.
      return s if url.to_s.downcase.end_with?('.pdf') || s.start_with?('%PDF')

      s = s.gsub(%r{<(script|style|noscript)\b.*?</\1>}mi, ' ')
      s = s.gsub(/<!--.*?-->/m, ' ')
      s = s.gsub(/<[^>]+>/, ' ')
      s.gsub(/\s+/, ' ').strip
    end
  end
end
