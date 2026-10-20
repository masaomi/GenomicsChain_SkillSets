# frozen_string_literal: true

# gc-commitment-0.1 (design v0.1.16 §5, §11 step 1). Known-answer values were
# computed with the OpenSSL command line, not with this module:
#
#   K=000102…1f
#   printf 'abc' | openssl dgst -sha256 -mac HMAC -macopt hexkey:$K
#   (printf 'gc-commitment-0.1/key-id'; echo $K | xxd -r -p) | openssl dgst -sha256
#
# Run: ruby -Ilib -Itest test/commitment_test.rb
require 'minitest/autorun'
require 'tmpdir'

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'genomicschain_prov/commitment'

class CommitmentTest < Minitest::Test
  C = GenomicsChainProv::Commitment
  KEY = (0..31).to_a.pack('C*')

  def test_known_answers_for_a_fixed_key
    assert_equal 'f0133729c4163dede81e21cd47839256da58171238c8a0d874397c73b14e1e47', C.commit(KEY, 'abc')
    assert_equal 'd38b42096d80f45f826b44a9d5607de72496a415d3f4a1a8c88e3bb9da8dc1cb', C.commit(KEY, '')
    assert_equal '242b5dcc2b29972cc074f57e57bd539b62ff79ebdd3c32a94887bf135ff8801c', C.key_id(KEY)
    assert_equal({ 'rule' => 'gc-commitment-0.1', 'key_id' => C.key_id(KEY) }, C.declaration(KEY))
  end

  def test_a_file_commits_to_the_same_value_as_its_bytes
    Dir.mktmpdir do |d|
      path = File.join(d, 'f')
      File.binwrite(path, 'abc')
      assert_equal C.commit(KEY, 'abc'), C.commit_file(KEY, path)
      assert_nil C.commit_file(KEY, File.join(d, 'missing'))
    end
  end

  # §5: HMAC pads a short key with zeros, so the 31-byte prefix of a key
  # padded to 32 with a zero byte is the same key to HMAC. The length check
  # is what stops it.
  def test_a_key_that_is_not_32_bytes_is_refused_everywhere
    short = KEY[0, 31]
    long = KEY + "\x00".b
    [short, long, '', nil, KEY.unpack1('H*')].each do |bad|
      assert_raises(C::KeyError) { C.commit(bad, 'abc') }
      assert_raises(C::KeyError) { C.key_id(bad) }
    end
    err = assert_raises(C::KeyError) { C.commit(short, 'abc') }
    refute_includes err.message, short.unpack1('H*'), 'the message never carries the key'
  end

  def test_key_files_are_raw_32_bytes_owner_only_and_never_overwritten
    Dir.mktmpdir do |d|
      path = File.join(d, 'bundle.key')
      key = C.generate_key
      assert_equal 32, key.bytesize
      refute_equal key, C.generate_key, 'a fresh key each time'
      C.write_key_file(path, key)
      assert_equal 0o600, File.stat(path).mode & 0o777
      assert_equal key, C.read_key_file(path)
      assert_raises(C::KeyError) { C.write_key_file(path, C.generate_key) }
      assert_equal key, C.read_key_file(path), 'the existing key is untouched'

      hex = File.join(d, 'hex.key')
      File.write(hex, "#{key.unpack1('H*')}\n")
      assert_raises(C::KeyError) { C.read_key_file(hex) }
      nl = File.join(d, 'nl.key')
      File.binwrite(nl, key + "\n")
      assert_raises(C::KeyError) { C.read_key_file(nl) }
      assert_raises(C::KeyError) { C.read_key_file(File.join(d, 'none.key')) }
    end
  end
end
