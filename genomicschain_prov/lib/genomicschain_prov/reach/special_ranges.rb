# frozen_string_literal: true

require 'ipaddr'

module GenomicsChainProv
  module Reach
    # (5) gate step 4: the address ranges the anchor never connects to.
    #
    # Taken on 2026-10-18 from the IANA Special-Purpose Address Registries:
    #   https://www.iana.org/assignments/iana-ipv4-special-registry/iana-ipv4-special-registry-1.csv
    #     sha256 cbc4b7653c8bc640ba1e8e5d4ebbf11e7c7a1d867e7f1593aad001d3f8632aac
    #   https://www.iana.org/assignments/iana-ipv6-special-registry/iana-ipv6-special-registry-1.csv
    #     sha256 bf56772aef97fbf9b4a27c98b8511f2bb1ba96da4b9ccc12ab203a2496faba66
    # Every block whose "Globally Reachable" is not True — False, N/A, or
    # empty (the two deprecated rows) — with footnote marks removed. The CSVs
    # are kept in test/fixtures/iana and a test derives this list from them.
    #
    # Where a True block sits inside a refused one (192.0.0.9/32 inside
    # 192.0.0.0/24, 2001:1::1/128 inside 2001::/23), the address is refused:
    # erring towards refusal costs a few anycast services no registry uses.
    #
    # Language helpers are not used (IPAddr#private? passes 0.0.0.0,
    # 100.64/10 and NAT64; design review r1, Ruby 3.4.10).
    module SpecialRanges
      SOURCE_DATE = '2026-10-18'

      IPV4 = %w[
        0.0.0.0/8 0.0.0.0/32 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.0.0.0/24
        192.0.0.0/29 192.0.0.8/32 192.0.0.170/32 192.0.0.171/32 192.0.2.0/24 192.88.99.0/24 192.88.99.2/32
        192.168.0.0/16 198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 240.0.0.0/4 255.255.255.255/32
      ].freeze

      IPV6 = %w[
        ::1/128 ::/128 ::ffff:0:0/96 64:ff9b:1::/48 100::/64 100:0:0:1::/64 2001::/23 2001::/32 2001:2::/48
        2001:10::/28 2001:db8::/32 2002::/16 3fff::/20 5f00::/16 fc00::/7 fe80::/10
      ].freeze

      # Not in the special-purpose registries: the multicast ranges as a
      # whole (IANA multicast address registries).
      MULTICAST = %w[224.0.0.0/4 ff00::/8].freeze

      # Refused whatever IPv4 they may carry: where Teredo and the local-use
      # NAT64 prefix put an embedded address is not fixed (design (5) step 4).
      # Both are in IPV6 already; named here so a later table cannot drop them.
      NO_EXTRACTION = %w[2001::/32 64:ff9b:1::/48].freeze

      RANGES = (IPV4 + IPV6 + MULTICAST + NO_EXTRACTION).map { |c| IPAddr.new(c) }.freeze

      module_function

      # @param ip [IPAddr] (IPAddr#include? is false across families)
      def refused?(ip)
        RANGES.any? { |r| r.include?(ip) }
      end
    end
  end
end
