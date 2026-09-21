# frozen_string_literal: true

require 'minitest/autorun'
require 'json'
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'genomicschain_regwatch'

# Covers the 2026-09-14 defect: a scan crashed while serialising its own
# result whenever a watched page contained a non-ASCII byte.
#
# Net::HTTP returns ASCII-8BIT. The normalised body therefore carried UTF-8
# bytes under a binary encoding, and JSON.generate refuses that string. Only
# `changed` and `new` findings carry an excerpt, so the crash hit precisely the
# runs that had something to report.
class FetcherTest < Minitest::Test
  # A response body exactly as Net::HTTP hands one over: binary, with UTF-8
  # bytes inside. The apostrophe is the real one from the Commission page.
  def binary_page(text)
    resp = Net::HTTPOK.new('1.1', '200', 'OK')
    resp.instance_variable_set(:@body, text.dup.force_encoding(Encoding::BINARY))
    resp.instance_variable_set(:@read, true)
    resp
  end

  def fetch(text, watch: 'text', url: 'https://example.org/p')
    f = GenomicsChainRegwatch::Fetcher.new(http: ->(_uri) { binary_page(text) })
    f.fetch(url, watch)
  end

  def test_excerpt_of_a_non_ascii_page_survives_json
    res = fetch("<h1>Shaping Europe’s digital future</h1><p>café</p>")

    assert res.ok
    assert_equal Encoding::UTF_8, res.excerpt.encoding
    assert res.excerpt.valid_encoding?
    assert_includes res.excerpt, "Europe’s"

    # The whole point: the finding has to reach JSON. Before the fix this raised.
    round_tripped = JSON.parse(JSON.generate({ 'excerpt' => res.excerpt }))
    assert_equal res.excerpt, round_tripped['excerpt']
  end

  # The digest must be taken over the bytes as normalised. Re-encoding them to
  # fix the excerpt would move every digest at once and report the entire
  # watchlist as `changed` on the next run.
  def test_digest_is_unchanged_by_the_excerpt_fix
    text = "<h1>Shaping Europe’s digital future</h1>"
    normalised = 'Shaping Europe’s digital future'.dup.force_encoding(Encoding::BINARY)

    assert_equal Digest::SHA256.hexdigest(normalised), fetch(text).digest
  end

  # A PDF read with `watch: full` is mostly not valid UTF-8. It must degrade to
  # a readable fragment, not to an exception.
  def test_pdf_bytes_do_not_raise
    res = fetch("%PDF-1.7\n\x00\xC3\x28\xFF\xFEstream Annex 22\n".b, watch: 'full',
                url: 'https://example.org/a.pdf')

    assert res.ok
    assert res.excerpt.valid_encoding?
    assert_includes res.excerpt, 'Annex 22'
    JSON.generate({ 'excerpt' => res.excerpt }) # must not raise
  end

  def test_excerpt_is_capped_at_240_characters
    assert_equal 240, fetch("<p>#{'é' * 900}</p>").excerpt.length
  end

  # --- the 2026-09-14 green-light defect -------------------------------------
  #
  # EUR-Lex answers an automated request with HTTP 202 and a script-only
  # interstitial. Both halves of that had to be caught: 202 is a 2xx, so it
  # passed the success check, and `text` strips the script, so the digest became
  # the SHA-256 of the empty string. Recorded once, that source would have read
  # `unchanged` forever — the exact blind-spot-as-green-light this package was
  # built to prevent.

  EMPTY_SHA256 = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'

  def coded_page(code, text)
    resp = Net::HTTPResponse::CODE_TO_OBJ.fetch(code).new('1.1', code, 'x')
    resp.instance_variable_set(:@body, text.dup.force_encoding(Encoding::BINARY))
    resp.instance_variable_set(:@read, true)
    resp
  end

  def fetch_coded(code, text, watch: 'text')
    GenomicsChainRegwatch::Fetcher
      .new(http: ->(_uri) { coded_page(code, text) })
      .fetch('https://example.org/p', watch)
  end

  def test_202_is_not_a_document
    res = fetch_coded('202', '<html><script>challenge()</script></html>')

    refute res.ok, 'a 202 interstitial must not be digested as the document'
    assert_includes res.reason, 'not 200'
    assert_nil res.digest
  end

  def test_body_that_normalises_to_nothing_is_unreachable_not_empty
    res = fetch_coded('200', '<html><script>var a=1;</script><style>b{}</style></html>')

    refute res.ok
    assert_includes res.reason, 'normalised to nothing'
    refute_equal EMPTY_SHA256, res.digest
    assert_nil res.digest
  end

  # The guard must not fire on a page that is merely short.
  def test_a_short_but_real_page_still_passes
    res = fetch_coded('200', '<html><body>Adopted.</body></html>')

    assert res.ok
    assert_equal 'Adopted.', res.excerpt
  end
end
