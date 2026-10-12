# frozen_string_literal: true

require 'json'
require 'digest'
require 'open3'

module GenomicsChainProv
  # ZkVerifier — the Ruby side of `gc_zk_verify` (design v0.1.12 §6.1, §7).
  #
  # RISC Zero receipts can only be verified by RISC Zero's Rust code, so the
  # one non-Ruby piece of this package is a small, lock-pinned binary
  # (genomicschain_prov/zk_verifier/). This file runs it and applies the four
  # checks that turn "some computation was correct" into "this step of this
  # bundle was":
  #
  #   ① sha256(bytes)                   = the receipt sha256 the bundle declares
  #   ② Receipt::verify(image_id)       passes                       (the binary)
  #   ③ journal's input digest          = the bundle's SHA-256 of the step's input
  #   ④ sha256(journal's output bytes)  = the bundle's SHA-256 of the step's output
  #
  # Receipt bytes go to the binary on stdin — no temporary file — and nothing
  # here logs them or keeps them: the anchor holds a receipt only for the one
  # verification, as it does the bundle (§6). Results carry codes and digests
  # the bundle already names, never journal values.
  class ZkVerifier
    class Unavailable < StandardError; end

    DEFAULT_BIN = File.expand_path('../../zk_verifier/target/release/gc_zk_verify', __dir__)
    TIMEOUT_SECONDS = 30
    MAX_RECEIPT_BYTES = 512 * 1024

    def self.binary
      env = ENV.fetch('GC_ZK_VERIFY_BIN', nil)
      env.nil? || env.strip.empty? ? DEFAULT_BIN : env
    end

    def self.available?(bin = binary)
      File.file?(bin) && File.executable?(bin)
    end

    def initialize(bin: self.class.binary, timeout: TIMEOUT_SECONDS)
      @bin = bin
      @timeout = timeout
    end

    attr_reader :bin

    # One receipt through the binary. Returns its JSON answer as a Hash.
    # @raise [Unavailable] no binary, a timeout, a crash, or output that is not
    #   the one JSON object the binary always prints
    def run(bytes, image_id)
      raise Unavailable, 'gc_zk_verify is not installed' unless self.class.available?(@bin)

      out = nil
      status = nil
      Open3.popen3(@bin, image_id.to_s) do |stdin, stdout, stderr, wait|
        stdin.binmode
        writer = Thread.new do
          stdin.write(bytes)
        rescue Errno::EPIPE
          nil
        ensure
          stdin.close unless stdin.closed?
        end
        reader = Thread.new { stdout.read }
        drain = Thread.new { stderr.read }
        unless wait.join(@timeout)
          Process.kill('KILL', wait.pid) rescue nil # rubocop:disable Style/RescueModifier
          wait.join
          raise Unavailable, 'gc_zk_verify timed out'
        end
        writer.join
        drain.join
        out = reader.value
        status = wait.value
      end
      raise Unavailable, "gc_zk_verify exited #{status.exitstatus}" unless status.success?

      parsed = JSON.parse(out.to_s.lines.last.to_s)
      raise Unavailable, 'gc_zk_verify printed no result' unless parsed.is_a?(Hash) && parsed.key?('verified')

      parsed
    rescue JSON::ParserError
      raise Unavailable, 'gc_zk_verify printed no result'
    rescue SystemCallError
      raise Unavailable, 'gc_zk_verify could not be started'
    end

    # ①–④ for every declared receipt.
    #
    # @param declared [Array<Hash>] np.zk_receipts (the adapter's reading;
    #   declarations with defects never reach here — admission refuses first)
    # @param bytes_by_sha [Hash] receipt sha256 => raw bytes, as submitted
    # @return [Hash] 'ok' (bool), 'results' [{'stage','receipt_sha256','check',
    #   'code'}], 'undeclared' (count of byte strings nobody declared),
    #   'verifier' {'tool','version','risc0_zkvm','journal_convention'} or nil
    def check(declared, bytes_by_sha)
      bytes_by_sha = (bytes_by_sha || {}).transform_keys { |k| k.to_s.downcase }
      declared_shas = declared.map { |r| r['receipt_sha256'] }
      results = []
      tool = nil
      declared.each do |r|
        res = { 'stage' => r['stage'], 'receipt_sha256' => r['receipt_sha256'] }
        bytes = bytes_by_sha[r['receipt_sha256']]
        code =
          if bytes.nil?
            'receipt_bytes_missing'
          elsif bytes.bytesize > MAX_RECEIPT_BYTES
            'receipt_too_large'
          elsif Digest::SHA256.hexdigest(bytes) != r['receipt_sha256']
            'receipt_sha256_mismatch'                                      # ①
          else
            out = run(bytes, r['image_id'])
            tool ||= out.slice('tool', 'version', 'risc0_zkvm', 'journal_convention')
            if out['verified'] != true then 'receipt_not_verified'          # ②
            elsif out['journal_ok'] != true then 'journal_not_convention'
            elsif out['journal_input_sha256'] != r['input_sha256'] then 'journal_input_mismatch'    # ③
            elsif out['journal_output_sha256'] != r['output_sha256'] then 'journal_output_mismatch' # ④
            end
          end
        results << res.merge('code' => code || 'ok')
      end
      undeclared = (bytes_by_sha.keys - declared_shas).length
      { 'ok' => results.all? { |x| x['code'] == 'ok' } && undeclared.zero?,
        'results' => results, 'undeclared' => undeclared, 'verifier' => tool }
    end
  end
end
