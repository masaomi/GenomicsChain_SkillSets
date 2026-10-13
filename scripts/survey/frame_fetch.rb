# Build a survey frame from the bioRxiv API — fetch and summarise only, NO draw.
# Same frame construction as sampler.rb (page the window over all categories, keep
# category == genomics, de-dup by DOI keeping the highest version). The seed and the
# draw are registered on chain only after this summary exists, so the frame hash is
# fixed before anyone knows which papers a seed would pick.
#
#   FROM=2025-07-01 TO=2025-09-30 CACHE_DIR=... EXCLUDE_FRAME=<q4 survey_frame_stamp dir> ruby frame_fetch.rb OUT_SUMMARY.json
require 'json'
require 'digest'
require 'fileutils'

FROM = ENV.fetch('FROM'); TO = ENV.fetch('TO'); CACHE = ENV.fetch('CACHE_DIR')
Q4_CACHE = '/Users/masa/forback/github/GenomicsChain_MVP2_2026/log/repro_survey_2026_07/survey_v1_1/pagecache'
out = ARGV[0] or abort 'usage: ruby frame_fetch.rb OUT_SUMMARY.json'
FileUtils.mkdir_p(CACHE)

def fetch_page(cursor)
  cached = File.join(CACHE, "page_#{cursor}.json")
  return JSON.parse(File.read(cached)) if File.exist?(cached)
  url = "https://api.biorxiv.org/details/biorxiv/#{FROM}/#{TO}/#{cursor}"
  40.times do |i|
    raw = `curl -s --max-time 60 "#{url}"`
    begin
      j = JSON.parse(raw)
      if j['messages']&.first
        File.write(cached, JSON.generate(j))
        return j
      end
    rescue JSON::ParserError
    end
    sleep [0.5 * (i + 1), 3.0].min
  end
  nil
end

def genomics_frame(records)
  by_doi = {}
  records.select { |r| r['category'].to_s.strip.downcase == 'genomics' }.each do |r|
    by_doi[r['doi'].to_s] = r if by_doi[r['doi'].to_s].nil? || r['version'].to_i > by_doi[r['doi'].to_s]['version'].to_i
  end
  by_doi.values.sort_by { |r| [r['date'].to_s, r['doi'].to_s] }
end

all = []; cursor = 0; total = nil; started = Time.now
loop do
  j = fetch_page(cursor) or abort "ABORT: page #{cursor} failed after retries (#{cursor}/#{total || '?'}); re-run resumes from cache"
  total ||= j['messages'].first['total'].to_i
  got = j['collection'] || []
  all.concat(got); cursor += got.size
  warn "#{cursor}/#{total} records (#{((Time.now - started) / 60).round(1)} min)" if (cursor / 30) % 50 == 0
  break if got.empty? || cursor >= total
  sleep 0.3
end
abort "ABORT: incomplete (#{cursor}/#{total})" if cursor < total

frame = genomics_frame(all)
q4 = genomics_frame(Dir.glob("#{Q4_CACHE}/page_*.json").flat_map { |f| JSON.parse(File.read(f))['collection'] || [] })
q4_dois = q4.map { |r| r['doi'] }.to_h { |d| [d, true] }
withdrawn = ->(r) { r['type'].to_s == 'withdrawn' || r['title'].to_s.start_with?('WITHDRAWN') }
in_q4 = frame.select { |r| q4_dois[r['doi']] }
wd = frame.select { |r| withdrawn.call(r) }
eligible = frame.reject { |r| q4_dois[r['doi']] || withdrawn.call(r) }

summary = {
  'source' => 'bioRxiv API details/biorxiv', 'category' => 'genomics', 'window' => { 'from' => FROM, 'to' => TO },
  'records_fetched' => all.size, 'api_total' => total, 'fetch_minutes' => ((Time.now - started) / 60).round(1),
  'frame_size_deduped' => frame.size,
  'frame_doi_sha256' => Digest::SHA256.hexdigest(frame.map { |r| r['doi'] }.sort.join(',')),
  'excluded_in_q4_frame' => in_q4.size, 'excluded_withdrawn' => wd.size,
  'eligible' => eligible.size,
  'eligible_doi_sha256' => Digest::SHA256.hexdigest(eligible.map { |r| r['doi'] }.sort.join(',')),
  'q4_frame_size_check' => q4.size,
}
File.write(out, JSON.pretty_generate(summary) + "\n")
puts JSON.generate(summary)
