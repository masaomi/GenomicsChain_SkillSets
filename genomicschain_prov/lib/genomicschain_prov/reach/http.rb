# frozen_string_literal: true

require 'uri'
require_relative 'rule'
require_relative 'failure'
require_relative 'gate'

module GenomicsChainProv
  module Reach
    # One query's requests: every URL through Gate.check, then one exchange
    # on the pinned address, following redirects. Redirects and a token
    # realm share one count of MAX_REDIRECTS (design (5)); going past it is
    # no answer (`refused`). One Http per query, so the count and the
    # deadline the resolver and transport were built with are the query's.
    class Http
      REDIRECTS = [301, 302, 303, 307, 308].freeze

      # @param resolver [#addresses] built with the query's deadline
      # @param transport [#exchange] built with the same deadline
      # @param gate [Hash] own_names:, own_addresses:, denylist:
      def initialize(resolver:, transport:, gate: {})
        @resolver = resolver
        @transport = transport
        @gate = gate
        @hops = 0
      end

      # A request that is not a redirect of the last one but still leaves
      # the place the bundle named (a token realm).
      def charge_hop!
        @hops += 1
        raise Failure.new('refused') if @hops > MAX_REDIRECTS
      end

      # @return [Transport::Response] the last response, never a redirect
      #   when follow is true
      def request(url, method:, headers: {}, body_cap: nil)
        first_host = nil
        loop do
          pinned = Gate.check(url, resolver: @resolver, **@gate)
          first_host ||= pinned.host
          # A credential goes only to the host it was issued for.
          sent = pinned.host == first_host ? headers : headers.reject { |k, _| k.casecmp?('authorization') }
          res = @transport.exchange(pinned, method: method, headers: sent, body_cap: body_cap)
          return res unless REDIRECTS.include?(res.status)

          charge_hop!
          url = follow(url, res['location'])
        end
      end

      private

      def follow(base, location)
        raise Failure.new('refused') if location.nil? || location.empty?

        URI.join(base, location).to_s
      rescue URI::Error
        raise Failure.new('refused'), cause: nil
      end
    end
  end
end
