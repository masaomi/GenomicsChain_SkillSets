# frozen_string_literal: true
# TipSource freshness OR semantics (P1 C3).
require 'minitest/autorun'
require 'kairos_mcp/version'
require 'kairos_mcp/skillset'
require_relative '../lib/genomicschain_core'

GCore = KairosMcp::SkillSets::GenomicschainCore

class TipSourceTest < Minitest::Test
  class FakeRegistry
    def initialize(records)
      @records = records
    end

    def read(kind)
      raise "unexpected #{kind}" unless kind == :proofs

      @records
    end
  end

  def make_record(i, stored_at:)
    { 'n' => i, '_stored_at' => stored_at.utc.iso8601 }
  end

  def test_fresh_within_block_window
    now = Time.utc(2026, 7, 29, 12, 0, 0)
    records = (1..5).map { |i| make_record(i, stored_at: now - 10) }
    tip = GCore::TipSource.new(registry: FakeRegistry.new(records))
    h = tip.entry_hash(records[-2])
    assert tip.tip_fresh?(h, now: now)
  end

  def test_fresh_via_time_window_beyond_block_count
    now = Time.utc(2026, 7, 29, 12, 0, 0)
    max = GCore::TipSource::CHAIN_TIP_MAX_BLOCKS
    # max+21 records, all within 1 hour; target is the oldest (outside block window)
    records = (0..(max + 20)).map do |i|
      make_record(i, stored_at: now - 3600 + i)
    end
    tip = GCore::TipSource.new(registry: FakeRegistry.new(records))
    h = tip.entry_hash(records.first)
    recent = records.last(max)
    refute recent.any? { |r| tip.entry_hash(r) == h }
    assert tip.tip_fresh?(h, now: now), 'time-window OR branch must accept tip older than block window'
  end

  def test_block_window_exact_max_not_max_plus_one
    now = Time.utc(2026, 7, 29, 12, 0, 0)
    max = GCore::TipSource::CHAIN_TIP_MAX_BLOCKS
    # Exactly max+1 records, all older than time window. Oldest must be rejected
    # (was wrongly accepted when slice used last(MAX+1)).
    records = (0..max).map do |i|
      make_record(i, stored_at: now - (7 * 3600) - (max - i))
    end
    tip = GCore::TipSource.new(registry: FakeRegistry.new(records))
    oldest = tip.entry_hash(records.first)
    newest = tip.entry_hash(records.last)
    assert tip.tip_fresh?(newest, now: now), 'newest of max+1 stale records is still in block window'
    refute tip.tip_fresh?(oldest, now: now), 'entry at index 0 of max+1 must not pass block-only branch'
  end

  def test_stale_outside_block_and_time_windows
    now = Time.utc(2026, 7, 29, 12, 0, 0)
    max = GCore::TipSource::CHAIN_TIP_MAX_BLOCKS
    records = (0..(max + 5)).map do |i|
      make_record(i, stored_at: now - (7 * 3600) - (max + 5 - i))
    end
    tip = GCore::TipSource.new(registry: FakeRegistry.new(records))
    h = tip.entry_hash(records.first)
    refute tip.tip_fresh?(h, now: now)
  end

  def test_genesis_on_empty
    tip = GCore::TipSource.new(registry: FakeRegistry.new([]))
    assert tip.tip_fresh?(GCore::TipSource::GENESIS_TIP)
  end
end
