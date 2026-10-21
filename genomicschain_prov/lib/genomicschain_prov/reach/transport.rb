# frozen_string_literal: true

require 'socket'
require 'openssl'
require 'zlib'
require_relative 'rule'
require_relative 'failure'

module GenomicsChainProv
  module Reach
    # (5) steps 5 and 6: one HTTP/1.1 exchange over TLS with the address the
    # gate pinned, under the query's single deadline — the one the name
    # lookup already ran under, through to the last byte read.
    #
    # Not Net::HTTP: it reads headers with no size limit and bounds each read,
    # not the exchange (design review r2, D2). Here the head is capped at
    # HEADER_BYTES and MAX_HEADERS lines, a body is read only when asked for
    # and counted after decompression, and every read and every wait is
    # against the deadline.
    #
    # Connects to Pinned#address and nothing else — no second lookup, no
    # proxy from any environment variable. The host goes out only as SNI and
    # in the Host header, and the certificate is verified against it.
    #
    # A response that is not well-formed HTTP/1.1 reads as `refused`: no
    # answer was had.
    class Transport
      Response = Struct.new(:status, :headers, :body, keyword_init: true) do
        # The first value of a header, by lowercase name.
        def [](name) = headers.fetch(name, []).first
      end

      MAX_HEADERS = 100
      MAX_LINE = 4096
      READ = 16 * 1024
      USER_AGENT = 'genomicschain-reach/0.1 (+https://genomicschain.ch)'

      def initialize(deadline:, cert_store: nil, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
        @deadline = deadline
        @clock = clock
        @cert_store = cert_store || OpenSSL::X509::Store.new.tap(&:set_default_paths)
      end

      # @param pinned [Gate::Pinned]
      # @param method [String] HEAD or GET
      # @param headers [Hash{String=>String}]
      # @param body_cap [Integer, nil] read the body, decoded, up to this many
      #   bytes (Failure 'too_large' beyond); nil closes after the head
      # @return [Response]
      def exchange(pinned, method:, headers: {}, body_cap: nil)
        io = connect(pinned)
        begin
          write_all(io, request(pinned, method, headers))
          reader = Reader.new(self, io)
          status, fields = read_head(reader)
          body = (read_body(reader, fields, body_cap) if body_cap && method != 'HEAD' && ![204, 304].include?(status))
          Response.new(status: status, headers: fields, body: body)
        ensure
          io.close
        end
      end

      # Seconds left, or Failure('timeout').
      def remaining
        r = @deadline - @clock.call
        raise Failure.new('timeout') if r <= 0

        r
      end

      def wait(io, direction)
        ready = direction == :read ? IO.select([io], nil, nil, remaining) : IO.select(nil, [io], nil, remaining)
        raise Failure.new('timeout') unless ready
      end

      private

      def connect(pinned)
        tcp = Socket.tcp(pinned.address, pinned.port, connect_timeout: remaining)
        ctx = OpenSSL::SSL::SSLContext.new
        ctx.set_params(verify_mode: OpenSSL::SSL::VERIFY_PEER, verify_hostname: true, cert_store: @cert_store)
        ssl = OpenSSL::SSL::SSLSocket.new(tcp, ctx)
        ssl.hostname = pinned.host
        ssl.sync_close = true
        loop do
          case ssl.connect_nonblock(exception: false)
          when :wait_readable then wait(tcp, :read)
          when :wait_writable then wait(tcp, :write)
          else break
          end
        end
        ssl.post_connection_check(pinned.host)
        ssl
      rescue StandardError
        tcp&.close
        raise
      end

      def request(pinned, method, headers)
        lines = ["#{method} #{pinned.request_target} HTTP/1.1", "Host: #{pinned.host}", "User-Agent: #{USER_AGENT}",
                 'Accept-Encoding: identity', 'Connection: close']
        headers.each do |k, v|
          raise ArgumentError, 'header with a line break' if "#{k}#{v}".match?(/[\r\n]/)

          lines << "#{k}: #{v}"
        end
        "#{lines.join("\r\n")}\r\n\r\n"
      end

      def write_all(io, data)
        data = data.b
        until data.empty?
          n = io.write_nonblock(data, exception: false)
          case n
          when :wait_writable then wait(io, :write)
          when :wait_readable then wait(io, :read)
          else data = data.byteslice(n..)
          end
        end
      end

      def read_head(reader)
        head = reader.read_until("\r\n\r\n", HEADER_BYTES)
        lines = head.split("\r\n")
        m = %r{\AHTTP/1\.[01] ([2-5]\d\d)(?: [\x20-\x7e\t]*)?\z}.match(lines.shift.to_s) or raise Failure.new('refused')
        raise Failure.new('refused') if lines.length > MAX_HEADERS

        fields = {}
        lines.each do |line|
          f = /\A([!#$%&'*+.^_`|~0-9A-Za-z-]+):[ \t]*([\x20-\x7e\t]*?)[ \t]*\z/.match(line) or raise Failure.new('refused')
          (fields[f[1].downcase] ||= []) << f[2]
        end
        [m[1].to_i, fields]
      end

      def read_body(reader, fields, cap)
        sink = Sink.new(fields['content-encoding'], cap)
        te = fields['transfer-encoding']
        cl = fields['content-length']
        if te
          raise Failure.new('refused') unless te.map(&:downcase) == ['chunked']

          read_chunked(reader, sink)
        elsif cl
          raise Failure.new('refused') unless cl.uniq.length == 1 && cl.first.match?(/\A\d{1,15}\z/)

          n = cl.first.to_i
          raise Failure.new('too_large') if n > cap

          reader.read_exact(n) { |piece| sink << piece }
        else
          reader.read_to_eof { |piece| sink << piece }
        end
        sink.finish
      end

      def read_chunked(reader, sink)
        loop do
          size = reader.read_until("\r\n", MAX_LINE)
          m = /\A(\h{1,8})(?:;[\x20-\x7e\t]*)?\z/.match(size) or raise Failure.new('refused')
          n = m[1].to_i(16)
          break if n.zero?

          reader.read_exact(n) { |piece| sink << piece }
          raise Failure.new('refused') unless reader.read_exact(2) == "\r\n"
        end
        # Trailer lines, then the empty line that ends the message.
        MAX_HEADERS.times { return if reader.read_until("\r\n", MAX_LINE).empty? }
        raise Failure.new('refused')
      end

      # Counts the body after decoding (design (5)); gzip and deflate are
      # decoded as they arrive, in pieces, so a small bomb cannot expand past
      # the cap in one step. Compressed bytes that decode to little are bound
      # by the deadline, not counted.
      #
      # Zlib keeps whatever follows the end of the compressed stream, neither
      # decoded nor counted, and returns it whole at finish; so a body that
      # goes on after its stream has ended is refused as soon as it does
      # (one gzip member only).
      class Sink
        def initialize(encodings, cap)
          enc = Array(encodings).flat_map { |e| e.split(',') }.map { |e| e.strip.downcase }.reject { |e| e == 'identity' }
          raise Failure.new('refused') if enc.length > 1 || (enc.first && !%w[gzip x-gzip deflate].include?(enc.first))

          @inflate = Zlib::Inflate.new(Zlib::MAX_WBITS + 32) if enc.first
          @fed = 0
          @cap = cap
          @out = +''.b
        end

        def <<(piece)
          if @inflate
            @fed += piece.bytesize
            @inflate.inflate(piece) { |c| add(c) }
            raise Failure.new('refused') if @inflate.finished? && @inflate.total_in < @fed
          else
            add(piece)
          end
          self
        end

        def finish
          @inflate&.finish&.then { |c| add(c) }
          @out
        ensure
          @inflate&.close
        end

        private

        def add(chunk)
          @out << chunk
          raise Failure.new('too_large') if @out.bytesize > @cap
        end
      end

      # Buffered reads off the TLS socket, every wait against the deadline.
      class Reader
        def initialize(transport, io)
          @t = transport
          @io = io
          @buf = +''.b
        end

        # The bytes before `delim`, consuming it; at most `max` bytes before it.
        def read_until(delim, max)
          loop do
            i = @buf.index(delim)
            if i
              raise Failure.new('refused') if i > max

              out = @buf.byteslice(0, i)
              @buf = @buf.byteslice((i + delim.bytesize)..)
              return out
            end
            raise Failure.new('refused') if @buf.bytesize > max + delim.bytesize
            raise Failure.new('refused') unless fill
          end
        end

        # Exactly n bytes; yielded in pieces when a block is given.
        def read_exact(n)
          collected = block_given? ? nil : +''.b
          while n.positive?
            raise Failure.new('refused') if @buf.empty? && !fill

            piece = @buf.byteslice(0, n)
            @buf = @buf.byteslice(piece.bytesize..)
            n -= piece.bytesize
            block_given? ? yield(piece) : collected << piece
          end
          collected
        end

        def read_to_eof
          loop do
            yield @buf unless @buf.empty?
            @buf = +''.b
            break unless fill
          end
        end

        private

        # The deadline is checked before every read, not only before a wait:
        # a peer that keeps the socket readable never makes the reader wait.
        # @return [Boolean] false at end of stream
        def fill
          loop do
            @t.remaining
            chunk = @io.read_nonblock(READ, exception: false)
            case chunk
            when :wait_readable then @t.wait(@io, :read)
            when :wait_writable then @t.wait(@io, :write)
            when nil then return false
            else
              @buf << chunk
              return true
            end
          end
        end
      end
    end
  end
end
