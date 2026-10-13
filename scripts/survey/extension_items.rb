# Build the item list for a prefix extension of survey v1.1 (sampling pre-registration v1.1 §4):
# the same Random.new(202607271) shuffle of the same frame, next contiguous positions.
#
# The frame is rebuilt from the July API page cache exactly as sampler.rb built it, and is
# refused unless its DOI hash and its shuffled order match what the July draw recorded.
# Withdrawn works are skipped (frame-level exclusion, v1.0 §3) and reported, never dropped silently.
#
#   ruby extension_items.rb FROM_POSITION COUNT OUT.json
require 'json'
require 'digest'

MVP2 = '/Users/masa/forback/github/GenomicsChain_MVP2_2026/log/repro_survey_2026_07/survey_v1_1'
SEED = 202607271
FRAME_HASH = '747934549fdc81b6133bc6243e393bb8ddadcff8e07c71b7cde0894cfeb02957'

from, count, out = Integer(ARGV[0]), Integer(ARGV[1]), ARGV[2]
abort 'usage: ruby extension_items.rb FROM_POSITION COUNT OUT.json' unless out

all = Dir.glob("#{MVP2}/pagecache/page_*.json").flat_map { |f| JSON.parse(File.read(f))['collection'] || [] }
by_doi = {}
all.select { |r| r['category'].to_s.strip.downcase == 'genomics' }.each do |r|
  v = r['version'].to_i
  by_doi[r['doi'].to_s] = r if by_doi[r['doi'].to_s].nil? || v > by_doi[r['doi'].to_s]['version'].to_i
end
frame = by_doi.values.sort_by { |r| [r['date'].to_s, r['doi'].to_s] }
hash = Digest::SHA256.hexdigest(frame.map { |r| r['doi'] }.sort.join(','))
abort "frame hash mismatch: #{hash}" unless hash == FRAME_HASH

shuffled = frame.shuffle(random: Random.new(SEED))
recorded = JSON.parse(File.read("#{MVP2}/survey_draw.json"))['shuffled_doi_order']
abort 'shuffled order differs from the July draw' unless shuffled.map { |r| r['doi'] } == recorded

withdrawn = ->(r) { r['type'].to_s == 'withdrawn' || r['title'].to_s.start_with?('WITHDRAWN') }
items = []; skipped = []
pos = from
while items.size < count && pos <= shuffled.size
  r = shuffled[pos - 1]
  if withdrawn.call(r)
    skipped << { 'position' => pos, 'canonical_id' => r['doi'], 'reason' => 'withdrawn' }
  else
    items << { 'canonical_id' => r['doi'].to_s, 'doi' => r['doi'], 'kind' => 'doi',
               'title' => r['title'], 'date' => r['date'], 'version' => r['version'],
               'category' => r['category'], 'jatsxml' => r['jatsxml'],
               'biorxiv_url' => "https://www.biorxiv.org/content/#{r['doi']}v#{r['version']}",
               'institution' => r['author_corresponding_institution'],
               'idx' => pos, 'safe_id' => r['doi'].to_s.tr('/', '_') }
  end
  pos += 1
end

File.write(out, JSON.pretty_generate(items) + "\n")
puts JSON.generate('frame_size' => frame.size, 'frame_hash_ok' => true, 'order_matches_july' => true,
                   'positions' => [from, pos - 1], 'items' => items.size, 'skipped' => skipped)
