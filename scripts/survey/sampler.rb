#!/usr/bin/env ruby
# bioRxiv Genomics sampler — calibration draw (collection protocol v0.2.5 §6).
# Pages the bioRxiv API over a bounded window, filters category=="genomics",
# de-dups by DOI (keeps highest version = one work), draws a SEEDED random sample.
# Genomics collection, NO NGS keyword filter (user decision 2026-07-23).
# Network via curl (Bash sandbox has egress). No external gems.
require 'json'
require 'digest'

WINDOW_FROM = ENV.fetch('FROM', '2025-05-01')
WINDOW_TO   = ENV.fetch('TO',   '2025-05-31')
SEED        = Integer(ENV.fetch('SEED', '20260723'))  # fixed at pre-registration
N_SAMPLE    = Integer(ENV.fetch('N', '40'))
CATEGORY    = 'genomics'
# Output paths are parameterised (pre-registration v1.0 §14 permits output/logging
# changes; frame-construction and draw logic are frozen).
LABEL       = ENV.fetch('LABEL', 'calibration_v0.1')
OUT         = ENV.fetch('OUT',    File.join(File.dirname(__FILE__), 'calibration_draw.json'))
PREREG      = ENV.fetch('PREREG', File.join(File.dirname(__FILE__), 'calibration_prereg.json'))
# Page cache makes a multi-year frame fetch resumable; it does not alter which
# records enter the frame.
CACHE_DIR   = ENV['CACHE_DIR']
MAX_ATTEMPTS = Integer(ENV.fetch('MAX_ATTEMPTS', '40'))
RETRY_BASE   = Float(ENV.fetch('RETRY_BASE', '0.5'))
RETRY_CAP    = Float(ENV.fetch('RETRY_CAP', '3.0'))
PAGE_SLEEP   = Float(ENV.fetch('PAGE_SLEEP', '0.3'))

def fetch_page(from, to, cursor)
  if CACHE_DIR
    cached = File.join(CACHE_DIR, "page_#{cursor}.json")
    return JSON.parse(File.read(cached)) if File.exist?(cached)
  end
  url = "https://api.biorxiv.org/details/biorxiv/#{from}/#{to}/#{cursor}"
  # The API intermittently returns an empty body (observed 2026-07-27); treat that
  # as a transient failure and back off, never as "end of collection".
  attempt = 0
  begin
    attempt += 1
    raw = `curl -s --max-time 60 "#{url}"`
    raise "empty response body" if raw.to_s.strip.empty?
    j = JSON.parse(raw)
    raise "no messages block" unless j['messages']&.first
    if CACHE_DIR
      File.write(File.join(CACHE_DIR, "page_#{cursor}.json"), JSON.generate(j))
    end
    j
  rescue => e
    if attempt < MAX_ATTEMPTS
      # The server fast-fails with HTTP 500 in ~0.3s and succeeds in ~5s, so a long
      # backoff buys nothing. Stay strictly sequential (one request in flight) with
      # a short, capped wait.
      backoff = [RETRY_BASE * attempt, RETRY_CAP].min
      warn "page #{cursor} attempt #{attempt} failed (#{e}); retry in #{backoff}s" if attempt % 5 == 0
      sleep backoff
      retry
    end
    warn "page #{cursor} error after #{attempt} attempts: #{e}"
    nil
  end
end

# --- 1. page the full window (all categories), accumulate ---
all = []
total = nil; cursor = 0; pages = 0
loop do
  j = fetch_page(WINDOW_FROM, WINDOW_TO, cursor)
  break unless j && j['messages']&.first
  msg = j['messages'].first
  total ||= msg['total'].to_i
  got = (j['collection'] || [])
  all.concat(got)
  pages += 1
  cursor += got.size
  warn "  … #{cursor}/#{total} records (#{pages} pages)" if pages % 20 == 0
  break if got.empty? || cursor >= total
  sleep PAGE_SLEEP
end
warn "fetched #{all.size} records over #{pages} pages (API total=#{total}) for #{WINDOW_FROM}..#{WINDOW_TO}"
# A truncated fetch would silently yield a wrong frame (and a wrong frame_doi_sha256).
# Fail loudly instead: the pre-registered frame must be complete.
if total.nil? || cursor < total
  abort "ABORT: incomplete frame fetch (#{cursor}/#{total || '?'} records). " \
        "Re-run; cached pages make it resumable. No draw was made."
end

# --- 2. filter genomics ---
genomics = all.select { |r| r['category'].to_s.strip.downcase == CATEGORY }
warn "genomics records (pre-dedup): #{genomics.size}"

# --- 3. de-dup by DOI, keep highest version ---
by_doi = {}
genomics.each do |r|
  doi = r['doi'].to_s
  v = r['version'].to_i
  by_doi[doi] = r if by_doi[doi].nil? || v > by_doi[doi]['version'].to_i
end
frame = by_doi.values.sort_by { |r| [r['date'].to_s, r['doi'].to_s] }
warn "genomics frame (de-duped works): #{frame.size}"

# --- 4. seeded random sample ---
rng = Random.new(SEED)
shuffled = frame.shuffle(random: rng)
sample = shuffled.first([N_SAMPLE, frame.size].min)

# --- 5. emit sample + pre-registration ---
rows = sample.map do |r|
  # Use the DOI as returned by the API. Do NOT reassemble it from a hardcoded
  # prefix: bioRxiv migrated from 10.1101 to 10.64898 (observed 2026-07-27, 186 of
  # 637 works in the 2025-Q4 frame), and reassembly fabricated non-existent
  # 10.1101 ids for those — a wrong canonical id on ~30% of a drawn sample.
  { 'canonical_id' => r['doi'].to_s,
    'doi' => r['doi'], 'kind' => 'doi',
    'title' => r['title'], 'date' => r['date'], 'version' => r['version'],
    'category' => r['category'],
    'jatsxml' => r['jatsxml'],
    'biorxiv_url' => "https://www.biorxiv.org/content/#{r['doi']}v#{r['version']}",
    'institution' => r['author_corresponding_institution'] }
end
File.write(OUT, JSON.pretty_generate({
  'draw' => LABEL,
  'sample' => rows,
  # The full seeded order is emitted so the pre-registered prefix-extension rule
  # (pre-registration v1.0 §5) is executable and checkable later: positions
  # N+1..N+M are already fixed by this draw.
  'shuffled_doi_order' => shuffled.map { |r| r['doi'] }
}) + "\n")

frame_hash = Digest::SHA256.hexdigest(frame.map { |r| r['doi'] }.sort.join(','))
prereg = {
  'draw' => LABEL,
  'purpose' => ENV.fetch('PURPOSE', 'validate harness + measure not-assessable rate before the 1000-paper survey'),
  'source' => 'bioRxiv API details/biorxiv',
  'category' => CATEGORY, 'ngs_keyword_filter' => false,
  'window' => { 'from' => WINDOW_FROM, 'to' => WINDOW_TO },
  'seed' => SEED, 'n_target' => N_SAMPLE,
  'frame_size_deduped' => frame.size,
  'frame_doi_sha256' => frame_hash,
  'draw_method' => 'Random.new(SEED).shuffle.first(N); dedup by DOI keep max version',
  'metric_semantics_version' => '0.2.5',
  'note' => ENV.fetch('NOTE', 'CALIBRATION only. The final ~1000-paper survey pre-registers the full window (e.g. 2022-2025) + its own seed; this bounded window keeps the frame fetch tractable.')
}
File.write(PREREG, JSON.pretty_generate(prereg) + "\n")

puts "== #{LABEL} draw =="
puts "window #{WINDOW_FROM}..#{WINDOW_TO} | genomics frame=#{frame.size} | sampled=#{sample.size} | seed=#{SEED}"
puts "frame_doi_sha256=#{frame_hash[0,16]}…"
puts "wrote #{File.basename(OUT)} + #{File.basename(PREREG)}"
puts
puts "first 5 sampled:"
rows.first(5).each { |r| puts "  #{r['canonical_id']}  #{r['title'][0,70]}" }
