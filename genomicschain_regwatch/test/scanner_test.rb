# frozen_string_literal: true

require 'minitest/autorun'
require 'json'
require 'tmpdir'
require 'date'
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'genomicschain_regwatch'

class ScannerTest < Minitest::Test
  MD = <<~M
    ## alpha
    - kind: undated
    - title: Alpha page
    - url: https://example.org/alpha

    ## beta
    - kind: undated
    - title: Beta page
    - url: https://example.org/beta

    ## blocked
    - kind: undated
    - title: A source behind a WAF
    - url: https://example.org/blocked

    ## soon
    - kind: dated
    - due: 2026-09-26
    - title: A deadline
    - url: https://example.org/soon
  M

  # Stands in for Fetcher. Returns whatever the test dictates per URL.
  class StubFetcher
    def initialize(map) = @map = map

    def fetch(url, _watch = 'text')
      r = @map[url]
      return GenomicsChainRegwatch::Fetcher::Result.new(url: url, ok: false, reason: 'HTTP 403') if r.nil?
      GenomicsChainRegwatch::Fetcher::Result.new(url: url, ok: true, status: '200',
                                                 digest: r, excerpt: "excerpt of #{r}")
    end
  end

  def setup
    @wl = GenomicsChainRegwatch::Watchlist.new(MD)
    @today = Date.new(2026, 9, 1)
  end

  def with_baseline
    Dir.mktmpdir do |dir|
      yield File.join(dir, 'state', 'baseline.json')
    end
  end

  def scanner(path, digests)
    GenomicsChainRegwatch::Scanner.new(
      @wl, baseline_path: path, fetcher: StubFetcher.new(digests), today: @today
    )
  end

  def test_first_scan_reports_new_not_unchanged
    with_baseline do |path|
      res = scanner(path, { 'https://example.org/alpha' => 'aaa' }).scan
      alpha = res['findings'].find { |f| f['id'] == 'alpha' }
      assert_equal 'new', alpha['status']
      assert_equal 0, res['counts']['unchanged']
    end
  end

  # The load-bearing behaviour of the whole package.
  def test_unreachable_is_never_folded_into_unchanged
    with_baseline do |path|
      s = scanner(path, { 'https://example.org/blocked' => nil }.compact)
      res = s.scan
      blocked = res['findings'].find { |f| f['id'] == 'blocked' }
      assert_equal 'unreachable', blocked['status']
      assert_equal 'HTTP 403', blocked['reason']
      refute_equal 'unchanged', blocked['status']
    end
  end

  def test_unchanged_then_changed_across_two_scans
    with_baseline do |path|
      digests = { 'https://example.org/alpha' => 'aaa', 'https://example.org/beta' => 'bbb' }
      first = scanner(path, digests).scan
      scanner(path, digests).record(first)

      second = scanner(path, digests).scan
      assert_equal 'unchanged', second['findings'].find { |f| f['id'] == 'alpha' }['status']

      moved = digests.merge('https://example.org/alpha' => 'zzz')
      third = scanner(path, moved).scan
      alpha = third['findings'].find { |f| f['id'] == 'alpha' }
      assert_equal 'changed', alpha['status']
      assert_equal 'aaa', alpha['digest_was']
      assert_equal 'zzz', alpha['digest_now']
      assert_equal 'unchanged', third['findings'].find { |f| f['id'] == 'beta' }['status']
    end
  end

  # Scanning must be repeatable: a check that moves its own reference point on
  # every run is a ratchet, not a check.
  def test_scan_alone_writes_no_baseline
    with_baseline do |path|
      scanner(path, { 'https://example.org/alpha' => 'aaa' }).scan
      refute File.exist?(path)
    end
  end

  def test_record_is_explicit_and_merges_unexamined_entries
    with_baseline do |path|
      digests = { 'https://example.org/alpha' => 'aaa', 'https://example.org/beta' => 'bbb' }
      s = scanner(path, digests)
      s.record(s.scan)
      assert File.exist?(path)

      narrowed = scanner(path, digests.merge('https://example.org/alpha' => 'qqq'))
      out = narrowed.scan(only: %w[alpha])
      assert_equal 1, out['examined']
      narrowed.record(out)

      stored = JSON.parse(File.read(path))['entries']
      assert_equal 'qqq', stored['alpha']['digest']
      assert_equal 'bbb', stored['beta']['digest'], 'a narrowed scan must not forget the rest'
    end
  end

  # An offline pass fetches nothing, so it must not claim anything was compared.
  # Reporting these as `unchanged` would be the same failure as scoring a
  # blocked source as a pass — in the package's own offline path.
  def test_offline_pass_reports_not_checked_never_unchanged
    with_baseline do |path|
      res = scanner(path, {}).scan(offline: true)
      assert res['offline']
      assert_equal 0, res['counts']['unchanged']
      assert_equal res['examined'], res['counts']['not_checked']
      assert(res['findings'].all? { |f| f['status'] == 'not_checked' })
      assert(res['findings'].all? { |f| f['reason'].to_s.include?('offline') })
      refute_empty res['deadlines']
    end
  end

  def test_deadlines_count_down_from_today
    with_baseline do |path|
      res = scanner(path, {}).scan(offline: true, horizon_days: 60)
      d = res['deadlines'].find { |x| x['id'] == 'soon' }
      assert_equal 25, d['days_remaining']
    end
  end

  def test_stale_rules_version_is_flagged
    with_baseline do |path|
      Dir.mkdir(File.dirname(path))
      File.write(path, JSON.generate('rules_version' => 'regwatch-scan-0.0.1', 'entries' => {}))
      res = scanner(path, {}).scan(offline: true)
      assert res['baseline']['stale_rules']
    end
  end

  def test_report_renders_both_languages_without_raising
    with_baseline do |path|
      res = scanner(path, { 'https://example.org/alpha' => 'aaa' }).scan
      %w[en ja].each do |lang|
        html = GenomicsChainRegwatch::Renderer.new(res, lang: lang).render
        assert html.start_with?('<!DOCTYPE html>')
        assert_includes html, "lang=\"#{lang}\""
        assert_includes html, 'alpha'
        # status must never be colour alone: the word has to be present too
        assert_includes html, lang == 'ja' ? '到達不能' : 'unreachable'
      end
    end
  end
end
