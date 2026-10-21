# frozen_string_literal: true

# v0.1.15 R2, the transport (design §6.3 (5); review r2 D2): one exchange
# against a real TLS socket on 127.0.0.1, served by a thread that misbehaves
# on purpose. The gate is not involved — it would refuse 127.0.0.1 — so the
# tests hand the transport a Pinned address directly, as the gate would.
#
# Run: ruby -Ilib -Itest test/reach_transport_test.rb
require 'minitest/autorun'
require 'socket'
require 'openssl'
require 'zlib'
require 'stringio'
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'genomicschain_prov'
require 'genomicschain_prov/reach'

class ReachTransportTest < Minitest::Test
  R = GenomicsChainProv::Reach
  T = R::Transport
  HOST = 'registry.test'

  def self.certificate
    @certificate ||= begin
      key = OpenSSL::PKey::EC.generate('prime256v1')
      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = 1
      cert.subject = cert.issuer = OpenSSL::X509::Name.parse("/CN=#{HOST}")
      cert.public_key = key
      cert.not_before = Time.now - 60
      cert.not_after = Time.now + 3600
      ef = OpenSSL::X509::ExtensionFactory.new(cert, cert)
      cert.add_extension(ef.create_extension('subjectAltName', "DNS:#{HOST}"))
      cert.add_extension(ef.create_extension('basicConstraints', 'CA:TRUE', true))
      cert.sign(key, OpenSSL::Digest.new('SHA256'))
      [cert, key]
    end
  end

  def store
    OpenSSL::X509::Store.new.tap { |s| s.add_cert(self.class.certificate.first) }
  end

  # Serves one connection: reads the request head, hands it and the socket
  # to the block. Errors on the server side (the client hung up) are ignored.
  def serve(&handler)
    cert, key = self.class.certificate
    tcp = TCPServer.new('127.0.0.1', 0)
    ctx = OpenSSL::SSL::SSLContext.new
    ctx.cert = cert
    ctx.key = key
    @sni = nil
    ctx.servername_cb = lambda do |(_sock, name)|
      @sni = name
      nil
    end
    server = OpenSSL::SSL::SSLServer.new(tcp, ctx)
    @request = nil
    thread = Thread.new do
      conn = server.accept
      head = +''
      head << conn.readpartial(4096) until head.include?("\r\n\r\n")
      @request = head
      handler.call(conn)
    rescue StandardError
      nil
    ensure
      conn&.close rescue nil
    end
    yield_port = tcp.addr[1]
    [yield_port, thread, server]
  end

  def exchange(port, seconds: 5, host: HOST, method: 'GET', body_cap: nil, headers: {})
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
    pinned = R::Gate::Pinned.new(host: host, address: '127.0.0.1', port: port, request_target: '/v2/x?y=1')
    T.new(deadline: deadline, cert_store: store).exchange(pinned, method: method, headers: headers, body_cap: body_cap)
  end

  def with_server(handler)
    port, thread, server = serve(&handler)
    yield port
  ensure
    thread&.join(5)
    server&.close rescue nil
  end

  def failure(code)
    e = assert_raises(R::Failure) { R.guard { yield } }
    assert_equal code, e.code
  end

  def elapsed
    t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
  ensure
    @elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t
  end

  def test_a_head_is_read_and_the_request_is_what_it_should_be
    with_server(lambda do |c|
      c.write("HTTP/1.1 200 OK\r\nContent-Type: application/vnd.oci.image.index.v1+json\r\n" \
              "Docker-Content-Digest: sha256:#{'a' * 64}\r\nContent-Length: 0\r\n\r\n")
    end) do |port|
      res = exchange(port, method: 'HEAD', headers: { 'Accept' => 'x' }, body_cap: 10)
      assert_equal 200, res.status
      assert_equal "sha256:#{'a' * 64}", res['docker-content-digest']
      assert_nil res.body
    end
    assert_equal HOST, @sni
    assert_match(%r{\AHEAD /v2/x\?y=1 HTTP/1\.1\r\nHost: registry\.test\r\n}, @request)
    assert_includes @request, "Accept-Encoding: identity\r\n"
    assert_includes @request, "Accept: x\r\n"
  end

  def test_a_chunked_body_is_joined
    with_server(lambda do |c|
      c.write("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n6;ext=1\r\n world\r\n0\r\nX-T: 1\r\n\r\n")
    end) do |port|
      assert_equal 'hello world', exchange(port, body_cap: 100).body
    end
  end

  def test_a_gzip_body_is_decoded_and_counted_decoded
    zipped = StringIO.new.tap { |io| Zlib::GzipWriter.wrap(io) { |gz| gz.write('x' * 1000) } }.string
    with_server(lambda do |c|
      c.write("HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\nContent-Length: #{zipped.bytesize}\r\n\r\n")
      c.write(zipped)
    end) do |port|
      assert_equal 'x' * 1000, exchange(port, body_cap: 1000).body
    end
  end

  def test_a_gzip_bomb_stops_at_the_cap
    zipped = StringIO.new.tap { |io| Zlib::GzipWriter.wrap(io) { |gz| 20.times { gz.write("\0" * (1 << 20)) } } }.string
    assert_operator zipped.bytesize, :<, 100_000
    with_server(lambda do |c|
      c.write("HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\nContent-Length: #{zipped.bytesize}\r\n\r\n")
      c.write(zipped)
    end) do |port|
      failure('too_large') { exchange(port, body_cap: R::ADVERTISEMENT_BYTES) }
    end
  end

  # The bomb is decoded in pieces: what is held when the cap trips is the cap
  # plus one piece, not the whole expansion.
  def test_a_bomb_is_never_held_whole
    zipped = StringIO.new.tap { |io| Zlib::GzipWriter.wrap(io) { |gz| 20.times { gz.write("\0" * (1 << 20)) } } }.string
    sink = T::Sink.new(['gzip'], 1 << 20)
    failure('too_large') { sink << zipped }
    assert_operator sink.instance_variable_get(:@out).bytesize, :<, 2 << 20
  end

  # A head over the anchor's caps is a malformed answer (refused, read as
  # error); too_large is kept for a body over its cap, the anchor's own limit.
  def test_an_endless_header_stops_at_sixty_four_kibibytes
    with_server(lambda do |c|
      c.write("HTTP/1.1 200 OK\r\n")
      200.times { c.write("X-Pad: #{'a' * 1000}\r\n") }
    end) do |port|
      failure('refused') { exchange(port) }
    end
  end

  def test_more_than_a_hundred_header_lines_is_refused
    with_server(->(c) { c.write("HTTP/1.1 200 OK\r\n#{"X: 1\r\n" * 101}\r\n") }) do |port|
      failure('refused') { exchange(port) }
    end
  end

  def test_a_drip_feed_is_cut_at_the_deadline
    with_server(lambda do |c|
      c.write('HTTP/1.1 200 OK')
      20.times do
        sleep 0.2
        c.write('a')
      end
    end) do |port|
      elapsed { failure('timeout') { exchange(port, seconds: 1) } }
      assert_operator @elapsed, :<, 2.0
    end
  end

  # Review r1 (P0): zlib keeps what follows the end of a gzip stream without
  # decoding or counting it, so a tiny member followed by endless bytes once
  # grew past any cap. It is refused as soon as it arrives.
  def test_bytes_after_the_gzip_stream_are_refused
    zipped = StringIO.new.tap { |io| Zlib::GzipWriter.wrap(io) { |gz| gz.write('{}') } }.string
    sink = T::Sink.new(['gzip'], 1 << 20)
    failure('refused') { sink << (zipped + ('x' * 100)) }
    sink = T::Sink.new(['gzip'], 1 << 20)
    sink << zipped
    failure('refused') { sink << 'x' }
    with_server(lambda do |c|
      c.write("HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\nTransfer-Encoding: chunked\r\n\r\n")
      c.write("#{zipped.bytesize.to_s(16)}\r\n#{zipped}\r\n")
      loop { c.write("4000\r\n#{'y' * 0x4000}\r\n") }
    end) do |port|
      elapsed { failure('refused') { exchange(port, body_cap: R::JSON_BYTES) } }
      assert_operator @elapsed, :<, 2.0
    end
  end

  # Review r1 (HIGH): the deadline once applied only when a read had to wait;
  # a peer that keeps the socket readable with bytes that decode to nothing
  # (empty stored deflate blocks) ran on past it.
  def test_a_peer_that_keeps_sending_is_cut_at_the_deadline
    empty_blocks = "\x00\x00\x00\xff\xff".b * 50_000
    with_server(lambda do |c|
      c.write("HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\n\r\n")
      c.write("\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\xff".b)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 8
      c.write(empty_blocks) while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
    end) do |port|
      elapsed { failure('timeout') { exchange(port, seconds: 1, body_cap: R::JSON_BYTES) } }
      assert_operator @elapsed, :<, 2.0
    end
  end

  def test_a_server_that_ignores_range_is_not_read
    with_server(lambda do |c|
      c.write("HTTP/1.1 200 OK\r\nContent-Length: #{50 << 20}\r\n\r\n")
      50.times { c.write('z' * (1 << 20)) }
    end) do |port|
      res = elapsed { exchange(port, headers: { 'Range' => 'bytes=0-0' }) }
      assert_equal 200, res.status
      assert_nil res.body
      assert_operator @elapsed, :<, 2.0
    end
  end

  def test_a_declared_length_over_the_cap_is_refused_unread
    with_server(->(c) { c.write("HTTP/1.1 200 OK\r\nContent-Length: #{9 << 20}\r\n\r\n") }) do |port|
      failure('too_large') { exchange(port, body_cap: R::ADVERTISEMENT_BYTES) }
    end
  end

  def test_an_oversized_chunked_advertisement_is_too_large
    with_server(lambda do |c|
      c.write("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n")
      9.times { c.write("100000\r\n#{'0' * (1 << 20)}\r\n") }
      c.write("0\r\n\r\n")
    end) do |port|
      failure('too_large') { exchange(port, body_cap: R::ADVERTISEMENT_BYTES) }
    end
  end

  def test_a_certificate_for_another_host_is_a_tls_failure
    with_server(->(c) { c.write("HTTP/1.1 200 OK\r\n\r\n") }) do |port|
      failure('tls') { exchange(port, host: 'other.test') }
    end
  end

  def test_a_certificate_no_one_vouches_for_is_a_tls_failure
    with_server(->(c) { c.write("HTTP/1.1 200 OK\r\n\r\n") }) do |port|
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
      pinned = R::Gate::Pinned.new(host: HOST, address: '127.0.0.1', port: port, request_target: '/')
      failure('tls') { T.new(deadline: deadline, cert_store: OpenSSL::X509::Store.new).exchange(pinned, method: 'GET') }
    end
  end

  def test_framing_and_encodings_it_does_not_read_are_refused
    { "Content-Encoding: br\r\nContent-Length: 1\r\n\r\nx" => 'refused',
      "Content-Length: 1\r\nContent-Length: 2\r\n\r\nxx" => 'refused',
      "Transfer-Encoding: gzip, chunked\r\n\r\n0\r\n\r\n" => 'refused',
      "Transfer-Encoding: chunked\r\n\r\nzz\r\n" => 'refused' }.each do |rest, code|
      with_server(->(c) { c.write("HTTP/1.1 200 OK\r\n#{rest}") }) do |port|
        failure(code) { exchange(port, body_cap: 100) }
      end
    end
  end

  def test_a_header_value_cannot_carry_a_line_break
    pinned = R::Gate::Pinned.new(host: HOST, address: '127.0.0.1', port: 1, request_target: '/')
    t = T.new(deadline: Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5, cert_store: store)
    assert_raises(ArgumentError) { t.send(:request, pinned, 'GET', { 'Authorization' => "Bearer x\r\nX-Evil: 1" }) }
  end

  def test_a_response_that_is_not_http_reads_as_refused
    with_server(->(c) { c.write("SSH-2.0-OpenSSH\r\n\r\n") }) do |port|
      failure('refused') { exchange(port) }
    end
    with_server(->(c) { c.write("HTTP/1.1 100 Continue\r\n\r\n") }) do |port|
      failure('refused') { exchange(port) }
    end
    with_server(->(c) { c.write("HTTP/1.1 200 OK\r\nBad header\r\n\r\n") }) do |port|
      failure('refused') { exchange(port) }
    end
  end

  def test_no_proxy_is_read_from_the_environment
    saved = %w[https_proxy HTTPS_PROXY all_proxy].to_h { |k| [k, ENV.fetch(k, nil)] }
    saved.each_key { |k| ENV[k] = 'http://127.0.0.1:9' }
    with_server(->(c) { c.write("HTTP/1.1 204 No Content\r\n\r\n") }) do |port|
      assert_equal 204, exchange(port).status
    end
  ensure
    saved&.each { |k, v| v ? ENV[k] = v : ENV.delete(k) }
  end
end
