# frozen_string_literal: true

require 'timeout'
require 'socket'
require 'openssl'
require 'resolv'

module GenomicsChainProv
  module Reach
    # (5) 漏らさない: what leaves the query layer is one of a few fixed codes.
    # A library's message can carry a host name or a URL, so it is dropped,
    # and so is the cause chain (`raise ..., cause: nil`), leaving a logger
    # that prints causes nothing to print.
    class Failure < StandardError
      CODES = %w[timeout tls dns refused too_large].freeze

      attr_reader :code

      def initialize(code)
        raise ArgumentError, 'unknown failure code' unless CODES.include?(code) || code.to_s.match?(/\Ahttp_\d{3}\z/)

        @code = code
        super(code)
      end
    end

    # The gate's refusal (design (5)). Its reason never reaches the record or
    # the customer: every refusal reads as not_checkable, the same as a name
    # that does not resolve, so the anchor's own DNS cannot be probed from
    # outside through the difference (design (4)).
    class Refused < StandardError
      REASONS = %w[form scheme userinfo port ip_literal host_form own_host unresolvable address].freeze

      attr_reader :reason

      def initialize(reason)
        raise ArgumentError, 'unknown refusal reason' unless REASONS.include?(reason)

        @reason = reason
        super(reason)
      end
    end

    module_function

    # Runs the block at the query layer's boundary. A Failure or a Refused
    # leaves as a fresh one with no cause; anything else leaves as a Failure
    # with a fixed code. A fault in this code reads as `refused` too, and so
    # as `error`: one bad locator must not end the observation, and no
    # message may leave.
    def guard
      yield
    rescue Refused => e
      raise Refused.new(e.reason), cause: nil
    rescue Failure => e
      raise Failure.new(e.code), cause: nil
    rescue StandardError => e
      raise Failure.new(code_for(e)), cause: nil
    end

    def code_for(error)
      case error
      when Resolv::ResolvTimeout then 'timeout'
      when Resolv::ResolvError, SocketError then 'dns'
      when Timeout::Error, Errno::ETIMEDOUT, IO::TimeoutError then 'timeout'
      when OpenSSL::SSL::SSLError, OpenSSL::X509::StoreError, OpenSSL::X509::CertificateError then 'tls'
      else 'refused'
      end
    end

    # (4) The answer a failure stands for. A name that does not resolve is
    # not_checkable (as a refusal is, above); every other failure is "no
    # answer was had", which never reads as gone.
    def bucket_for(failure)
      code = failure.code
      return 'not_checkable' if code == 'dns'
      return 'access_denied' if %w[http_401 http_403].include?(code)
      return 'not_found' if code == 'http_404'

      'error'
    end

    # (5) The breaker counts timeouts and 5xx answers, nothing else.
    def breaker_failure?(failure)
      failure.code == 'timeout' || failure.code.match?(/\Ahttp_5\d\d\z/)
    end
  end
end
