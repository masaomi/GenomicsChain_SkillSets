# frozen_string_literal: true

require 'set'
require_relative 'rule'

module GenomicsChainProv
  module Reach
    # (5) 予算 inside one observation: at most MAX_DISTINCT locators asked,
    # PER_HOST of them per host by its class, a host left alone after
    # BREAKER_FAILURES timeouts or 5xx answers in a row, and OBSERVATION_SECONDS
    # in all. A locator the budget stops is not_attempted — a statement about
    # the anchor, never about the place.
    #
    # The host charged is the one the bundle wrote (the same host decides the
    # class). A realm or redirect host is not charged on its own: the
    # operator kept budgets to what the frozen design states (2026-10-18),
    # and budgets across observations are not kept at all (named in §10).
    class Budget
      def initialize(clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }, seconds: OBSERVATION_SECONDS)
        @clock = clock
        @deadline = clock.call + seconds
        @asked = 0
        @per_host = Hash.new(0)
        @failures = Hash.new(0)
        @tripped = Set.new
      end

      # Charges one query when it may go ahead.
      # @return [nil, Symbol] nil, or why not (:expired, :distinct, :host, :breaker)
      def admit(host, host_class)
        return :expired if remaining <= 0
        return :breaker if @tripped.include?(host)
        return :distinct if @asked >= MAX_DISTINCT
        return :host if @per_host[host] >= PER_HOST.fetch(host_class)

        @asked += 1
        @per_host[host] += 1
        nil
      end

      # The wall-clock seconds the next query may take.
      def request_seconds
        [REQUEST_SECONDS.to_f, remaining].min
      end

      def remaining
        @deadline - @clock.call
      end

      # @param failed [Boolean] the query ended in a timeout or a 5xx answer
      def record(host, failed:)
        if failed
          @failures[host] += 1
          @tripped << host if @failures[host] >= BREAKER_FAILURES
        else
          @failures[host] = 0
        end
      end
    end

    # (5) Across the anchor: ANCHOR_CONCURRENT_OBSERVATIONS at once, one at a
    # time per key, KEY_DAILY_OBSERVATIONS per key in any 24 hours. A
    # submission over any of these is refused like a malformed one and makes
    # no record.
    #
    # The key is the operator's pubkey; the Bearer is bound to it (SubmitCore
    # refuses a pubkey that does not hash to the Bearer's), so one Bearer is
    # one key.
    #
    # Held in this process's memory (named, 2026-10-18): a restart forgets the
    # day's counts, and an anchor run as several processes allows this much
    # per process.
    class Admission
      class Busy < StandardError
        REASONS = %w[anchor key daily].freeze

        attr_reader :reason

        def initialize(reason)
          @reason = reason
          super("observation refused: #{reason}")
        end
      end

      DAY = 86_400

      def initialize(clock: -> { Time.now.to_f })
        @clock = clock
        @mutex = Mutex.new
        @running = Hash.new(0)
        @started = Hash.new { |h, k| h[k] = [] }
      end

      # Runs the block as one observation for the key.
      # @raise [Busy]
      def hold(key)
        enter(key)
        begin
          yield
        ensure
          leave(key)
        end
      end

      private

      def enter(key)
        @mutex.synchronize do
          now = @clock.call
          @started[key].reject! { |t| t <= now - DAY }
          raise Busy.new('anchor') if @running.values.sum >= ANCHOR_CONCURRENT_OBSERVATIONS
          raise Busy.new('key') if @running[key] >= KEY_CONCURRENT_OBSERVATIONS
          raise Busy.new('daily') if @started[key].length >= KEY_DAILY_OBSERVATIONS

          @running[key] += 1
          @started[key] << now
        end
      end

      def leave(key)
        @mutex.synchronize do
          @running[key] -= 1
          @running.delete(key) if @running[key] <= 0
        end
      end
    end
  end
end
