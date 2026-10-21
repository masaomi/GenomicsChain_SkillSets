# frozen_string_literal: true

require 'ipaddr'
require_relative 'failure'
require_relative 'special_ranges'

module GenomicsChainProv
  module Reach
    # (5) gate(url) — the one check every URL passes before the anchor
    # connects: the locator's own URL, a token realm, every redirect target.
    #
    #   1. https only, no userinfo, port 443 only; a host written as an IP
    #      address in any notation is refused before anything resolves
    #   2. the anchor's own names are refused
    #   3. every A and AAAA answer is taken; none at all is refused
    #   4. each answer, and the IPv4 an IPv6 answer carries, is checked
    #      against SpecialRanges and against the anchor's own addresses and
    #      the operator's denylist; one bad answer refuses the URL
    #
    # Steps 5 and 6 — connect to the address returned here and nowhere else,
    # SNI and certificate checked against the host, no proxy — belong to the
    # transport that uses the Pinned result.
    #
    # Reads nothing but its arguments: the resolver is passed in, so the
    # tests never leave the machine.
    module Gate
      Pinned = Struct.new(:host, :address, :port, :request_target, keyword_init: true)

      # One DNS label (RFC 1123), after lowercasing. Non-ASCII hosts are
      # refused rather than converted: no registry or forge needs one, and an
      # IDNA library is a dependency for no customer.
      LABEL = /\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\z/
      URL = %r{\A([A-Za-z][A-Za-z0-9+.-]*)://([^/?#]*)([/?][^#]*)?(?:#.*)?\z}m

      module_function

      # @param url [String]
      # @param resolver [#addresses] host -> every A and AAAA answer as strings;
      #   [] when the name does not resolve; raises Reach::Failure('timeout')
      # @param own_names [Array<String>] the anchor's own host names
      # @param own_addresses [Array<String>] the anchor's own addresses
      # @param denylist [Array<String>] the operator's further ranges (CIDR)
      # @return [Pinned]
      # @raise [Refused]
      def check(url, resolver:, own_names: [], own_addresses: [], denylist: [])
        host, port, target = parse(url)
        raise Refused.new('own_host') if own_names.any? { |n| normalise_host(n) == host }

        answers = resolver.addresses(host)
        raise Refused.new('unresolvable') if answers.nil? || answers.empty?

        extra = (own_addresses + denylist).map { |a| IPAddr.new(a) }
        ips = answers.map { |a| address(a) }
        ips.each { |ip| raise Refused.new('address') if refused_address?(ip, extra) }
        Pinned.new(host: host, address: ips.first.to_s, port: port, request_target: target)
      end

      # Step 1 alone: what can be refused without resolving anything. A
      # dry run counts these and nothing else (design (3)).
      # @return [Array(String, Integer, String)] host, port, path and query
      # @raise [Refused]
      def parse(url)
        raise Refused.new('form') unless url.is_a?(String) && url.ascii_only? && !url.match?(/[\x00-\x20\x7f]/)

        m = URL.match(url) or raise Refused.new('form')
        raise Refused.new('scheme') unless m[1].casecmp?('https')

        authority = m[2]
        raise Refused.new('userinfo') if authority.include?('@')
        raise Refused.new('ip_literal') if authority.start_with?('[')

        host, port_text = authority.split(':', 2)
        raise Refused.new('port') unless port_text.nil? || port_text == '443'

        host = normalise_host(host)
        raise Refused.new('ip_literal') if ends_in_a_number?(host)

        labels = host.split('.', -1)
        unless labels.length >= 2 && host.length <= 253 && labels.all? { |l| LABEL.match?(l) }
          raise Refused.new('host_form')
        end

        target = m[3].to_s
        target = "/#{target}" unless target.start_with?('/')
        [host, 443, target]
      end

      # Lowercase, one trailing dot removed.
      def normalise_host(host)
        host.to_s.downcase.delete_suffix('.')
      end

      # The URL standard's test for an IPv4 host: the last label is all
      # digits or a 0x number. Catches 10.0.0.1 and also 127.1, 2130706433,
      # 0x7f000001 and 0177.0.0.1, which resolvers read as addresses.
      def ends_in_a_number?(host)
        last = host.split('.').last.to_s
        last.match?(/\A\d+\z/) || last.match?(/\A0x[0-9a-f]*\z/i)
      end

      def address(text)
        IPAddr.new(text.to_s)
      rescue IPAddr::Error
        raise Refused.new('address'), cause: nil
      end

      # IPAddr#include? is false across families, so one list serves both.
      def refused_address?(ip, extra)
        candidates = [ip]
        v4 = embedded_ipv4(ip)
        candidates << v4 if v4
        candidates.any? { |c| SpecialRanges.refused?(c) || extra.any? { |r| r.include?(c) } }
      end

      # The IPv4 in the last 32 bits of an IPv4-compatible ::/96 or a NAT64
      # 64:ff9b::/96 address — the two carriers SpecialRanges lets through.
      # The other two of design (5) step 4 are refused whole by the table
      # (IPv4-mapped ::ffff:0:0/96 False, 6to4 2002::/16 N/A), so what they
      # carry never decides.
      def embedded_ipv4(ip)
        return nil unless ip.ipv6?

        n = ip.to_i
        IPAddr.new(n & 0xffff_ffff, Socket::AF_INET) if (n >> 32).zero? || (n >> 32) == (0x0064_ff9b << 64)
      end
    end
  end
end
