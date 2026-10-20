# frozen_string_literal: true

require 'digest'
require 'base64'
require 'json'
require 'openssl'

# T3 (design v0.1.16 §10): after a local admission, search every place the
# anchor wrote or answered for what option 2 must keep out of it.
# The admissions run the real MCP tool, config loader and gc_zk_verify, with
# the attestor STUBBED (prov_option2_test's StubAttestor, no signing key):
# what a signing attestor would add is not covered by T3.
#
#   everywhere (record, logs, replies, temp files, the receipt, the bundle):
#     the plain SHA-256 and SHA-1 of every bundle file, the output bytes
#     (raw and word-expanded — risc0 serde writes one byte per u32 word),
#     and the key — the last two in every encoding of `encodings`
#   in the record, logs, replies and temp files (not the bundle, which
#   carries them by design):
#     the key_id and the journal's two commitments
#
# `outputs_digest` is a SHA-256 over rows, not a file digest, and is not a
# probe. Each probe is searched in several spellings (hex either case,
# base64 strict and url-safe, raw bytes), because a leak need not keep the
# form it started in. Byte strings — the output and the key — are also
# searched as a Ruby `inspect` would print them (an exception message), as a
# byte array, and JSON-escaped where they are valid UTF-8 (a reply is JSON
# text): the fixture output is binary, so a leak of it into JSON would not
# be its raw bytes (round-1 implementation review, confidentiality F2).
# test_r1_f4_t3_positive_control_planted_leaks_are_found_in_every_place
# plants each of these, made independently, and asserts it is found.
module ConfidentialityScan
  module_function

  def spellings(raw)
    hex = raw.unpack1('H*')
    [raw, hex, hex.upcase, Base64.strict_encode64(raw), Base64.urlsafe_encode64(raw, padding: false)].map(&:b).uniq
  end

  # spellings, plus how a byte string looks once a program has printed it.
  # Quoted forms are searched without their quotes, so a leak inside a
  # longer string is found too.
  def encodings(raw)
    raw = raw.b
    forms = spellings(raw) + [raw.inspect[1..-2], raw.bytes.inspect, JSON.generate(raw.bytes)]
    utf8 = raw.dup.force_encoding('UTF-8')
    forms += [JSON.generate(utf8)[1..-2], utf8.inspect[1..-2]] if utf8.valid_encoding?
    forms.map(&:b).uniq
  end

  def word_expanded(bytes)
    bytes.bytes.pack('V*')
  end

  # @param files [Hash] name => bytes, every file the bundle fingerprints
  # @param output [String] the covered step's output bytes
  # @param key [String, nil] the 32-byte key (option 2)
  # @param salted [Hash] name => 64-hex values: key_id and the journal's commitments
  # @return [Hash] {'everywhere' => {label => [spellings]}, 'outside_bundle' => {...}}
  def probes(files:, output:, key: nil, salted: {})
    everywhere = {}
    files.each do |name, bytes|
      everywhere["sha256(#{name})"] = spellings(Digest::SHA256.digest(bytes))
      everywhere["sha1(#{name})"] = spellings(Digest::SHA1.digest(bytes))
    end
    everywhere['output bytes'] = encodings(output)
    everywhere['output bytes, word-expanded'] = encodings(word_expanded(output))
    everywhere['key'] = encodings(key) if key
    outside = salted.transform_values { |hex| spellings([hex].pack('H*')) }
    { 'everywhere' => everywhere, 'outside_bundle' => outside }
  end

  # @param places [Hash] name => bytes; names starting with "bundle" or
  #   "receipt" are the customer's own artefacts: only the 'everywhere'
  #   probes apply to them (the journal carries the key_id and commitments)
  # @return [Array<String>] "label in place" for every hit; [] when clean
  def scan(probes, places)
    hits = []
    places.each do |where, hay|
      hay = hay.to_s.b
      sets = probes['everywhere'].dup
      sets.merge!(probes['outside_bundle']) unless where.start_with?('bundle', 'receipt')
      sets.each do |label, forms|
        hits << "#{label} in #{where}" if forms.any? { |f| !f.empty? && hay.include?(f) }
      end
    end
    hits
  end

  # Every regular file under the given directories, as "dir-label:relative path" => bytes.
  def files_under(dirs)
    dirs.each_with_object({}) do |(label, dir), acc|
      Dir.glob(File.join(dir, '**', '*'), File::FNM_DOTMATCH).each do |f|
        acc["#{label}:#{f.delete_prefix(dir)}"] = File.binread(f) if File.file?(f)
      end
    end
  end
end
