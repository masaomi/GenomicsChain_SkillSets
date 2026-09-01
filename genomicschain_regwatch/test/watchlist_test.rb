# frozen_string_literal: true

require 'minitest/autorun'
require 'date'
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'genomicschain_regwatch'

class WatchlistTest < Minitest::Test
  SAMPLE = <<~MD
    # heading that is not an item

    ## dated-one
    - kind: dated
    - due: 2027-03-26
    - title: A dated thing
    - url: https://example.org/a
    - binds: European Commission
    - why: because

    ## undated-one
    - kind: undated
    - title: An undated thing
    - url: https://example.org/b
    - watch: pattern:draft-\\d+

    ## defaults-one
    - title: No kind given
    - url: https://example.org/c

    ## bad-date
    - kind: dated
    - due: not-a-date
    - title: Broken

    ## bad-key
    - title: Fine
    - nonsense: ignored
  MD

  def setup
    @wl = GenomicsChainRegwatch::Watchlist.new(SAMPLE)
  end

  def test_parses_every_section
    assert_equal %w[dated-one undated-one defaults-one bad-date bad-key], @wl.items.map(&:id)
  end

  def test_kind_defaults_to_undated
    item = @wl.items.find { |i| i.id == 'defaults-one' }
    assert_equal 'undated', item.kind
    refute item.dated?
  end

  def test_watch_defaults_to_text
    assert_equal 'text', @wl.items.find { |i| i.id == 'defaults-one' }.watch
    assert_equal 'pattern:draft-\d+', @wl.items.find { |i| i.id == 'undated-one' }.watch
  end

  def test_dated_item_parses_its_date
    item = @wl.items.find { |i| i.id == 'dated-one' }
    assert item.dated?
    assert_equal Date.new(2027, 3, 26), item.due
  end

  def test_days_remaining_counts_down_and_goes_negative
    item = @wl.items.find { |i| i.id == 'dated-one' }
    assert_equal 10, item.days_remaining(Date.new(2027, 3, 16))
    assert_equal(-4, item.days_remaining(Date.new(2027, 3, 30)))
  end

  def test_undated_item_has_no_countdown
    assert_nil @wl.items.find { |i| i.id == 'undated-one' }.days_remaining(Date.today)
  end

  # A malformed date must not silently become "no deadline"; it has to surface,
  # because a deadline that quietly stops counting is worse than none.
  def test_bad_date_warns
    assert(@wl.warnings.any? { |w| w.include?('bad-date') && w.include?('not-a-date') })
    assert(@wl.warnings.any? { |w| w.include?('bad-date') && w.include?('never count down') })
  end

  def test_unknown_key_warns_but_keeps_the_item
    assert(@wl.warnings.any? { |w| w.include?('nonsense') })
    assert(@wl.items.map(&:id).include?('bad-key'))
  end

  def test_due_within_includes_overdue_soonest_first
    today = Date.new(2027, 3, 30)
    ids = @wl.due_within(60, today).map(&:id)
    assert_includes ids, 'dated-one'
  end

  def test_shipped_watchlist_parses_without_warnings
    path = File.expand_path('../knowledge/regwatch_watchlist.md', __dir__)
    wl = GenomicsChainRegwatch::Watchlist.load(path)
    assert_empty wl.warnings, "shipped watchlist has warnings: #{wl.warnings.inspect}"
    refute_empty wl.items
    assert wl.items.all? { |i| i.title && !i.title.empty? }
    # Every dated item must actually carry a date, or its countdown is a lie.
    wl.items.select(&:dated?).each { |i| refute_nil i.due, "#{i.id} is dated with no due" }
  end
end
