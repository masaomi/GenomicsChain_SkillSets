# frozen_string_literal: true

require 'resolv'
require_relative 'failure'

module GenomicsChainProv
  module Reach
    # (5) step 3: every A and AAAA answer for a host, inside the query's
    # deadline. The name is asked as absolute (a trailing dot), so the
    # resolver's search domains never turn "registry" into an internal name,
    # and /etc/hosts is not read (Resolv::DNS asks the nameservers only).
    #
    # Resolv::DNS answers [] both when a name does not exist and when its
    # nameserver does not answer in time; both read as a name that does not
    # resolve (not_checkable), never as gone. The deployment condition — a
    # resolver that keeps no query log — is the operator's (design (5)).
    class Resolver
      # @param config [Hash, nil] as Resolv::DNS takes it; nil reads the
      #   system's (/etc/resolv.conf)
      def initialize(deadline:, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }, config: nil)
        @deadline = deadline
        @clock = clock
        @config = config || Resolv::DNS::Config.default_config_hash
        @nameservers = [Array(@config[:nameserver_port] || @config[:nameserver]).length, 1].max
      end

      # @return [Array<String>] A answers first, then AAAA
      def addresses(host)
        name = Resolv::DNS::Name.create("#{host}.")
        Resolv::DNS.open(@config) do |dns|
          ask(dns, name, Resolv::DNS::Resource::IN::A, 2) + ask(dns, name, Resolv::DNS::Resource::IN::AAAA, 1)
        end
      end

      private

      # Resolv waits out the timeout once for each nameserver in turn, so the
      # share of the deadline is split across them (review r1).
      def ask(dns, name, type, parts)
        dns.timeouts = remaining / parts / @nameservers
        dns.getresources(name, type).map { |r| r.address.to_s }
      end

      def remaining
        r = @deadline - @clock.call
        raise Failure.new('timeout') if r <= 0

        r
      end
    end
  end
end
