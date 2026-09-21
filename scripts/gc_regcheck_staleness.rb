#!/usr/bin/env ruby
# frozen_string_literal: true
#
# gc_regcheck_staleness — joins the regulatory watch to the published frame,
# and says which published claims the ground has moved under.
#
# Three artefacts sit in a line and nothing connected them until this script:
#
#   watchlist (24+ sources)  ->  guidance frame (16 points)  ->  check records
#   a digest moved                a point rests on sources       a record cites points
#
# Without the join, freshness rested on one hand-set `as_of` date covering a
# whole page, and nothing said which claims that date actually covered. A page
# that cannot tell a reader the text underneath a claim moved should not be
# published, so this is the piece that makes publishing safe rather than a new
# feature on top of it.
#
# What it does NOT do, deliberately: decide whether a change matters. A moved
# digest means a page was edited — the edit may be a fixed link. Ruling on that
# is a judgement, and the context that produced the finding is the wrong one to
# make it. Same discipline as the scanner it reads from: emit a state and stop.
#
# Usage
#   ruby scripts/gc_regcheck_staleness.rb --guidance PATH [--scan PATH]
#        [--record PATH]... [--watchlist PATH] [--out PATH] [--json]
#
#   --scan may be omitted: the join's own integrity and the coverage counts are
#   computable with no scan at all, and a broken join is worth catching before
#   the next scan rather than after it.
#
# Exit status
#   0  the join is sound (whatever the scan found)
#   1  the join is broken: a watch_id naming no watchlist entry, an unknown
#      watch_status, or a source the frame cites and the join never classified.
#      These fail loudly because each one silently prevents a claim from ever
#      going stale, which is the one failure this script exists to prevent.

require 'set'
require 'json'
require 'time'
require 'optparse'

REPO = File.expand_path('..', __dir__)
$LOAD_PATH.unshift(File.join(REPO, 'genomicschain_regwatch', 'lib'))
require 'genomicschain_regwatch'

RULES_VERSION = '0.1.0'

# How a source's watch_status plus its scan finding become one state.
#
# `unverified` is the load-bearing row. A source that could not be fetched is
# never folded into `current`: a blocked source scored as a pass converts a
# blind spot into a green light, and half this watchlist is permanently blocked.
SOURCE_STATE = {
  # watch_status => state when there is no scan to consult
  'immutable' => 'fixed',
  'navigation_only' => 'not_load_bearing',
  'own' => 'ours',
  'unwatchable' => 'gap',
  'watched' => 'not_scanned'
}.freeze

SCAN_STATE = {
  'changed' => 'moved',
  'unchanged' => 'current',
  'unreachable' => 'unverified',
  'not_checked' => 'unverified',
  'new' => 'unverified'
}.freeze

# Which state wins when a point cites several sources. A point is only as fresh
# as the least fresh thing it rests on.
SEVERITY = {
  'moved' => 4,
  'unverified' => 3,
  'not_scanned' => 3,
  'gap' => 2,
  'current' => 1,
  'fixed' => 0,
  'ours' => 0,
  'not_load_bearing' => 0
}.freeze

POINT_STATE = {
  4 => 'moved',      # someone must read the source before this claim is relied on
  3 => 'unverified', # we tried or should have, and do not know
  2 => 'gap',        # it moves, it matters, and we cannot fetch it
  1 => 'current',
  0 => 'current'     # everything it rests on is fixed, ours, or navigational
}.freeze

options = {
  guidance: nil,
  watchlist: File.join(REPO, 'genomicschain_regwatch', 'knowledge', 'regwatch_watchlist.md'),
  scan: nil,
  records: [],
  out: nil,
  json: false
}

OptionParser.new do |o|
  o.banner = 'Usage: gc_regcheck_staleness.rb --guidance PATH [--scan PATH] [--record PATH]...'
  o.on('--guidance PATH', 'guidance.json — the published frame') { |v| options[:guidance] = v }
  o.on('--watchlist PATH', 'watchlist markdown (defaults to the shipped one)') { |v| options[:watchlist] = v }
  o.on('--scan PATH', 'a gc_regwatch_scan result. Omit for coverage only') { |v| options[:scan] = v }
  o.on('--record PATH', 'a check record to age against the frame (repeatable)') { |v| options[:records] << v }
  o.on('--out PATH', 'write the result JSON here') { |v| options[:out] = v }
  o.on('--json', 'print the result JSON to stdout instead of the summary') { options[:json] = true }
end.parse!

abort('--guidance is required') unless options[:guidance]

guidance = JSON.parse(File.read(options[:guidance]))
watchlist = GenomicsChainRegwatch::Watchlist.load(options[:watchlist])
watch_ids = watchlist.items.map(&:id).to_set

scan = options[:scan] ? JSON.parse(File.read(options[:scan])) : nil
findings = (scan&.dig('findings') || []).to_h { |f| [f['id'], f] }

errors = []

# ---------------------------------------------------------------- sources

sources = guidance.fetch('sources').map do |s|
  status = s['watch_status']
  watch_id = s['watch_id']

  unless SOURCE_STATE.key?(status)
    errors << "source `#{s['id']}`: watch_status #{status.inspect} is not one of " \
              "#{SOURCE_STATE.keys.join(', ')}"
    next { 'id' => s['id'], 'state' => 'unclassified' }
  end

  if status == 'watched'
    if watch_id.nil?
      errors << "source `#{s['id']}`: watch_status is `watched` but no watch_id names a watchlist entry"
    elsif !watch_ids.include?(watch_id)
      errors << "source `#{s['id']}`: watch_id `#{watch_id}` matches no entry in the watchlist — " \
                'this claim could never go stale'
    end
  elsif watch_id
    errors << "source `#{s['id']}`: watch_id `#{watch_id}` is set but watch_status is `#{status}`"
  end

  finding = watch_id && findings[watch_id]
  state =
    if status != 'watched' then SOURCE_STATE[status]
    elsif finding.nil? then SOURCE_STATE['watched'] # watched, but this scan did not examine it
    else SCAN_STATE.fetch(finding['status'], 'unverified')
    end

  {
    'id' => s['id'],
    'kind' => s['kind'],
    'watch_status' => status,
    'watch_id' => watch_id,
    'scan_status' => finding && finding['status'],
    'state' => state,
    'note' => s['watch_note']
  }.compact
end

by_source = sources.to_h { |s| [s['id'], s] }

# ---------------------------------------------------------------- points

points = guidance.fetch('points').map do |p|
  cited = Array(p['sources'])
  unknown = cited.reject { |id| by_source.key?(id) }
  unknown.each { |id| errors << "point `#{p['id']}` cites source `#{id}`, which the sources list does not define" }

  states = (cited - unknown).map { |id| by_source[id]['state'] }
  worst = states.map { |s| SEVERITY.fetch(s, 3) }.max || 3
  state = POINT_STATE.fetch(worst)

  because = (cited - unknown).select { |id| SEVERITY.fetch(by_source[id]['state'], 3) == worst && worst >= 2 }

  { 'id' => p['id'], 'title' => p['title'], 'verdict' => p['verdict'],
    'state' => state, 'because' => because }.reject { |_, v| v == [] }
end

# ---------------------------------------------------------------- records
#
# A check record joins to the frame in one of two ways. Records from
# record_version 0.2.0 carry `frame.points_relied_on`, and age point by point.
# Older records — the 2026-09-13 run is the only one — carry no such
# block, so the coarser `law_version` comparison is the only join available:
# if the law the frame reads has moved since the record was written, the record
# is stale whatever its individual answers said. Reported as `coarse` so that
# nobody mistakes the weaker join for the stronger one.

records = options[:records].map do |path|
  r = JSON.parse(File.read(path))
  frame = r['frame']
  relied = Array(frame && frame['points_relied_on'])
  by_point = points.to_h { |p| [p['id'], p] }

  if relied.empty?
    same_law = r.dig('law_version', 'amended_by') == guidance.dig('law_version', 'amended_by')
    { 'path' => path, 'subject' => r.dig('subject', 'name'), 'checked_on' => r['checked_on'],
      'join' => 'coarse', 'state' => same_law ? 'current' : 'moved',
      'note' => same_law ? 'no frame block: aged only against law_version, which has not moved' \
                         : 'no frame block: the law the frame reads has moved since this record' }
  else
    missing = relied.reject { |id| by_point.key?(id) }
    missing.each { |id| errors << "record #{path} relies on point `#{id}`, which the frame does not define" }
    states = (relied - missing).map { |id| by_point[id]['state'] }
    worst = states.map { |s| SEVERITY.fetch(s == 'current' ? 'current' : s, 3) }.max || 3
    { 'path' => path, 'subject' => r.dig('subject', 'name'), 'checked_on' => r['checked_on'],
      'join' => 'by_point', 'state' => POINT_STATE.fetch(worst),
      'stale_points' => (relied - missing).select { |id| SEVERITY.fetch(by_point[id]['state'], 3) >= 2 } }
  end
end

# ---------------------------------------------------------------- result

def tally(list, key)
  list.each_with_object(Hash.new(0)) { |x, h| h[x[key]] += 1 }.sort.to_h
end

result = {
  'computed_at' => Time.now.utc.iso8601,
  'rules_version' => RULES_VERSION,
  'guidance' => guidance.slice('version', 'as_of', 'next_review_due').merge(
    'path' => options[:guidance]
  ),
  'watchlist' => { 'path' => options[:watchlist], 'items' => watchlist.items.length,
                   'warnings' => watchlist.warnings },
  'scan' => scan ? scan.slice('scanned_at', 'offline', 'counts').merge('path' => options[:scan])
                 : { 'present' => false,
                     'note' => 'no scan supplied: every watched source reads not_scanned, which is ' \
                               'not a pass' },
  'coverage' => { 'sources' => sources.length }.merge(tally(sources, 'watch_status')),
  'source_states' => tally(sources, 'state'),
  'point_states' => tally(points, 'state'),
  'sources' => sources,
  'points' => points,
  'records' => records,
  'join_errors' => errors,
  'limits' => [
    'A point marked `current` means every source it cites was fetched and matched a recorded ' \
    'baseline. It does not mean the claim is right, and nothing here reads the law.',
    'A `gap` is a source that moves, matters, and cannot be fetched. It is reported every time, ' \
    'permanently, and is closed only by a person reading the source and re-dating the frame.',
    'Coverage counts what is watched, not what should be. A source nobody thought to list is ' \
    'invisible to this script exactly as it is to the watchlist.',
    'Records without a `frame` block age only against law_version. That join cannot see a ' \
    'guidance document moving under an individual answer.'
  ]
}

File.write(options[:out], JSON.pretty_generate(result)) if options[:out]

if options[:json]
  puts JSON.pretty_generate(result)
else
  g = result['guidance']
  puts "frame        #{g['version']} as_of #{g['as_of']} (next review due #{g['next_review_due']})"
  puts "watchlist    #{result['watchlist']['items']} items — #{options[:watchlist].sub("#{REPO}/", '')}"
  puts "scan         #{scan ? "#{scan['scanned_at']}#{scan['offline'] ? ' (offline)' : ''}" : 'none supplied'}"
  puts "coverage     #{result['coverage'].map { |k, v| "#{k}=#{v}" }.join('  ')}"
  puts "sources      #{result['source_states'].map { |k, v| "#{k}=#{v}" }.join('  ')}"
  puts "points       #{result['point_states'].map { |k, v| "#{k}=#{v}" }.join('  ')}"
  result['points'].reject { |p| p['state'] == 'current' }.each do |p|
    puts "  #{p['state'].ljust(11)} #{p['id']}  <- #{Array(p['because']).join(', ')}"
  end
  records.each do |r|
    # Every record is named check_record.json; the directory is what tells them
    # apart, so printing the basename alone made two runs indistinguishable.
    label = File.join(File.basename(File.dirname(r['path'])), File.basename(r['path']))
    puts "record       #{r['state'].ljust(11)} (#{r['join']}) #{label}"
  end
  unless errors.empty?
    puts "\njoin errors (#{errors.length}) — each one is a claim that could never go stale:"
    errors.each { |e| puts "  ! #{e}" }
  end
end

exit(errors.empty? ? 0 : 1)
