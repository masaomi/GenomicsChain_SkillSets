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
  # Option 2 (design v0.1.16 §6.3) branches on the convention the bundle
  # declares. ①② are the same, ② also requiring a succinct receipt; ③④ are
  # replaced by three equalities against the bundle's salted fields:
  #
  #   ③ journal's C(input)  = the bundle's hmac_sha256 at input_uri
  #   ④ journal's C(output) = the bundle's hmac_sha256 at output_uri
  #   ⑤ journal's key_id    = the bundle's commitment.key_id
  #
  # (the tag word and the 388-byte length are the binary's precondition for
  # reading the journal at all). No 0.1 reading and no output SHA-256 is
  # done for a 0.2 receipt (S1). These show that the verified journal's
  # values equal the submitter's bundle's values — that they are HMACs under
  # that key holds only if the guest computes them so (not checked).
  #
  # The binary is called with `--journal gc-zk-journal-0.2` for 0.2 only, and
  # with no convention argument for 0.1 (§9 deployment note): an old 0.1.0
  # binary then still serves option 1, and only 0.2 receipts are refused —
  # `journal_convention_not_supported` — when it rejects the argument.
  #
  # Receipt bytes go to the binary on stdin — no temporary file — and nothing
  # here logs them or keeps them: the anchor holds a receipt only for the one
  # verification, as it does the bundle (§6). Results carry codes and digests
  # the bundle already names, never journal values: a 0.2 journal's key_id
  # and commitments are compared here and dropped (§6.3, T3).
  class ZkVerifier
    class Unavailable < StandardError; end
    # The binary would not take the convention argument (an older binary, or
    # one that does not know the convention). Raised for 0.2 only.
    class ConventionUnsupported < StandardError; end

    JOURNAL_V01 = 'gc-zk-journal-0.1'
    JOURNAL_V02 = 'gc-zk-journal-0.2'
    # What the binary's `error` may name for a 0.2 receipt it refused (the
    # interface fixed with the Rust side, design §11 step 4).
    V02_ERRORS = %w[receipt_not_succinct journal_not_convention].freeze
    # The code for a receipt this binary cannot verify. On the anchor it is a
    # refusal; a customer's local tool reports it as "not checked here" with
    # NOT_SUPPORTED_NOTE, because the receipt was not shown wrong.
    CONVENTION_NOT_SUPPORTED = 'journal_convention_not_supported'
    NOT_SUPPORTED_NOTE = "this gc_zk_verify does not verify #{JOURNAL_V02}"

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
    #
    # @param journal [String, nil] passed as `--journal` only when given (0.2)
    # @raise [ConventionUnsupported] when a convention was passed and the
    #   binary exited 2 (usage, or journal_convention_unknown)
    def run(bytes, image_id, journal = nil)
      raise Unavailable, 'gc_zk_verify is not installed' unless self.class.available?(@bin)

      out = nil
      status = nil
      argv = [@bin, image_id.to_s]
      argv += ['--journal', journal.to_s] if journal
      Open3.popen3(*argv) do |stdin, stdout, stderr, wait|
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
      if journal && status.exitstatus == 2
        raise ConventionUnsupported, "gc_zk_verify does not verify #{journal} (an older binary?)"
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

    # True when the binary's lack of support for a convention is the only
    # reason any result is not ok: then the set is "not checked here". Any
    # other failing code (or an undeclared receipt) makes it a failure, and
    # the caller reports every result.
    def self.only_not_supported?(out)
      bad = out['results'].reject { |r| r['code'] == 'ok' }
      !bad.empty? && bad.all? { |r| r['code'] == CONVENTION_NOT_SUPPORTED } && out['undeclared'].to_i.zero?
    end

    # ①–④ (0.1) or ①–⑤ (0.2) for every declared receipt.
    #
    # @param declared [Array<Hash>] np.zk_receipts (the adapter's reading;
    #   declarations with defects never reach here — admission refuses first)
    # @param bytes_by_sha [Hash] receipt sha256 => raw bytes, as submitted
    # @param commitment [Hash, nil] np.commitment, {'state','key_id'} — read for ⑤ only
    # @return [Hash] 'ok' (bool), 'results' [{'stage','receipt_sha256','check',
    #   'code'}], 'undeclared' (count of byte strings nobody declared),
    #   'verifier' {'tool','version','risc0_zkvm','journal_convention'} or nil —
    #   journal_convention is the convention the receipts were verified under (S5)
    def check(declared, bytes_by_sha, commitment: nil)
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
          elsif r['journal_convention'] == JOURNAL_V02
            begin
              out = run(bytes, r['image_id'], JOURNAL_V02)
              tool ||= out.slice('tool', 'version', 'risc0_zkvm').merge('journal_convention' => JOURNAL_V02)
              v02_code(out, r, commitment)
            rescue ConventionUnsupported
              CONVENTION_NOT_SUPPORTED
            end
          elsif r['journal_convention'] == JOURNAL_V01
            out = run(bytes, r['image_id'])
            tool ||= out.slice('tool', 'version', 'risc0_zkvm', 'journal_convention')
            if out['verified'] != true then 'receipt_not_verified'          # ②
            elsif out['journal_ok'] != true then 'journal_not_convention'
            elsif out['journal_input_sha256'] != r['input_sha256'] then 'journal_input_mismatch'    # ③
            elsif out['journal_output_sha256'] != r['output_sha256'] then 'journal_output_mismatch' # ④
            end
          else
            # only a declared 0.1 receipt takes the 0.1 path; admission already
            # refuses anything else, this is for a caller that did not
            # (round-1 implementation review, Sonnet P3)
            'journal_convention_unknown'
          end
        results << res.merge('code' => code || 'ok')
      end
      undeclared = (bytes_by_sha.keys - declared_shas).length
      { 'ok' => results.all? { |x| x['code'] == 'ok' } && undeclared.zero?,
        'results' => results, 'undeclared' => undeclared, 'verifier' => tool }
    end

    private

    # ②–⑤ for a 0.2 receipt, from the binary's answer. nil when all hold.
    # The journal's values are compared and not kept.
    def v02_code(out, r, commitment)
      return out['error'] if V02_ERRORS.include?(out['error'])
      return 'receipt_not_verified' if out['verified'] != true                         # ②
      return 'receipt_not_succinct' if out['receipt_kind'] != 'succinct'               # ② (succinct only)
      return 'journal_not_convention' if out['journal_ok'] != true || out['journal_convention'] != JOURNAL_V02
      return 'journal_input_mismatch' unless same_hex?(out['journal_input_commitment'], r['input_hmac_sha256'])   # ③
      return 'journal_output_mismatch' unless same_hex?(out['journal_output_commitment'], r['output_hmac_sha256']) # ④

      key_id_code(out['journal_key_id'], commitment)                                    # ⑤
    end

    def key_id_code(journal_key_id, commitment)
      case (commitment || {})['state']
      when 'ok' then same_hex?(journal_key_id, commitment['key_id']) ? nil : 'journal_key_id_mismatch'
      when 'conflict' then 'commitment_declared_twice'
      when 'unreadable' then 'commitment_unreadable'
      else 'commitment_missing'
      end
    end

    def same_hex?(a, b)
      a.is_a?(String) && b.is_a?(String) && a =~ /\A[0-9a-f]{64}\z/ && a == b
    end
  end
end
