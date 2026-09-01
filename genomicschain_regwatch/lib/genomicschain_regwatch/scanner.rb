# frozen_string_literal: true

require 'json'
require 'date'
require 'time'
require 'fileutils'

module GenomicsChainRegwatch
  # Compares each watched source against the recorded baseline and counts down
  # the dated triggers.
  #
  # What it deliberately does NOT do: decide whether a change matters. A digest
  # moving tells you a page was edited, not that an obligation changed — the
  # edit may be a broken link fixed. Ruling on that is a judgement, and the
  # context that produced the finding is the wrong one to make it. So the
  # scanner emits a status per item and stops, and the operator's ruling is
  # recorded separately (context_save / chain_record), where it can be
  # attributed to whoever made it.
  class Scanner
    Finding = Struct.new(
      :id, :status, :title, :url, :kind, :due, :days_remaining,
      :was, :now, :reason, :excerpt, :why, :binds,
      keyword_init: true
    ) do
      def to_h
        h = { 'id' => id, 'status' => status, 'title' => title, 'kind' => kind }
        h['url'] = url if url
        h['due'] = due.to_s if due
        h['days_remaining'] = days_remaining if days_remaining
        h['digest_was'] = was if was
        h['digest_now'] = now if now
        h['reason'] = reason if reason
        h['excerpt'] = excerpt if excerpt
        h['binds'] = binds if binds
        h['why'] = why if why
        h
      end
    end

    attr_reader :watchlist, :baseline_path

    def initialize(watchlist, baseline_path:, fetcher: nil, today: Date.today)
      @watchlist = watchlist
      @baseline_path = baseline_path
      @fetcher = fetcher || Fetcher.new
      @today = today
    end

    # `only` limits the scan to a subset of ids — a full sweep of a long
    # watchlist is slow and rate-limit-prone, and most sessions only need to
    # re-check the two or three things that were moving.
    def scan(only: nil, horizon_days: 120, offline: false)
      base = load_baseline
      items = watchlist.items
      items = items.select { |i| only.include?(i.id) } if only && !only.empty?

      findings = items.map { |item| examine(item, base, offline) }

      {
        'scanned_at' => Time.now.utc.iso8601,
        'rules_version' => SCAN_RULES_VERSION,
        'watchlist_items' => watchlist.items.length,
        'examined' => findings.length,
        'offline' => offline,
        'baseline' => baseline_summary(base),
        'counts' => STATUSES.to_h { |s| [s, findings.count { |f| f.status == s }] },
        'deadlines' => deadlines(horizon_days),
        'findings' => findings.map(&:to_h),
        'watchlist_warnings' => watchlist.warnings,
        'limits' => LIMITS
      }
    end

    # Writes the current digests as the new baseline. Separated from `scan` so
    # that scanning has no side effect: a scan you cannot re-run without
    # changing what it compares against is not a check, it is a ratchet.
    def record(scan_result)
      entries = {}
      scan_result['findings'].each do |f|
        next unless f['digest_now']
        entries[f['id']] = {
          'digest' => f['digest_now'], 'url' => f['url'],
          'seen_at' => scan_result['scanned_at']
        }
      end
      # Keep entries for items not examined in this pass, so a narrowed scan
      # does not silently forget the rest of the watchlist.
      previous = load_baseline['entries'] || {}
      merged = previous.merge(entries)

      payload = {
        'rules_version' => SCAN_RULES_VERSION,
        'recorded_at' => Time.now.utc.iso8601,
        'entries' => merged
      }
      FileUtils.mkdir_p(File.dirname(baseline_path))
      File.write(baseline_path, JSON.pretty_generate(payload))
      { 'baseline_path' => baseline_path, 'entries' => merged.length,
        'newly_recorded' => entries.length }
    end

    private

    def examine(item, base, offline)
      known = (base['entries'] || {})[item.id]

      common = {
        id: item.id, title: item.title, url: item.url, kind: item.kind,
        due: item.due, days_remaining: item.days_remaining(@today),
        why: item.why, binds: item.binds
      }

      if offline
        # Not `unchanged`. Nothing was fetched, so nothing was compared, and
        # reporting a comparison that did not happen is the same failure as
        # scoring a blocked source as a pass.
        return Finding.new(**common, status: 'not_checked',
                           was: known && known['digest'],
                           reason: 'offline: not fetched, digest not compared')
      end

      res = @fetcher.fetch(item.url, item.watch)

      unless res.ok
        # The load-bearing line of this file. A blocked or broken source is
        # never folded into "unchanged"; several of the sources on this list
        # are behind a WAF and will sit here permanently, which is exactly the
        # fact the operator needs to keep seeing.
        return Finding.new(**common, status: 'unreachable',
                           was: known && known['digest'],
                           reason: res.reason || "HTTP #{res.status}")
      end

      if known.nil?
        Finding.new(**common, status: 'new', now: res.digest, excerpt: res.excerpt,
                    reason: 'no baseline recorded for this id yet')
      elsif known['digest'] == res.digest
        Finding.new(**common, status: 'unchanged', was: known['digest'], now: res.digest)
      else
        Finding.new(**common, status: 'changed', was: known['digest'], now: res.digest,
                    excerpt: res.excerpt,
                    reason: 'normalised content digest differs from baseline')
      end
    end

    def deadlines(horizon_days)
      watchlist.due_within(horizon_days, @today).map do |i|
        { 'id' => i.id, 'title' => i.title, 'due' => i.due.to_s,
          'days_remaining' => i.days_remaining(@today), 'binds' => i.binds, 'why' => i.why }.compact
      end
    end

    def load_baseline
      return { 'entries' => {} } unless File.file?(baseline_path)
      JSON.parse(File.read(baseline_path))
    rescue JSON::ParserError => e
      { 'entries' => {}, 'parse_error' => e.message }
    end

    def baseline_summary(base)
      {
        'path' => baseline_path,
        'exists' => File.file?(baseline_path),
        'recorded_at' => base['recorded_at'],
        'rules_version' => base['rules_version'],
        'entries' => (base['entries'] || {}).length,
        'stale_rules' => !base['rules_version'].nil? && base['rules_version'] != SCAN_RULES_VERSION
      }
    end

    LIMITS = [
      'A moved digest means the page was edited. It does not mean an obligation changed, and this ' \
        'tool does not rule on which it was.',
      'An unreachable source stays unreachable in every report until someone fetches it by hand. ' \
        'It is never counted as unchanged. Neither is an offline pass, which reports not_checked.',
      'Undated items are the only ones a digest can catch. A dated item whose date slips without ' \
        'the page changing is invisible here — the countdown is only as good as the `due` field.',
      'Normalisation strips markup and whitespace, so a change confined to layout is invisible and ' \
        'a change to boilerplate elsewhere on the page still fires. Narrow with `watch: pattern:` ' \
        'when precision matters.',
      'No archive is kept: the tool stores a digest, not the text it digested. What changed must be ' \
        'read at the source.'
    ].freeze
  end
end
