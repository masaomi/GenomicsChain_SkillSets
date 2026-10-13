# Draw for the 2025-Q3 stratum (sampling pre-registration q3 v1.0, 2026-10-13).
#
# Rebuilds the Q3 frame from the cached API pages exactly as frame_fetch.rb did, refuses unless
# the frame and eligible-list hashes equal the registered ones, removes works that also sit in
# the Q4 frame and withdrawn works, orders by [date, doi] as sampler.rb does, shuffles with the
# registered seed, and writes the whole order. Reads take positions 1..N; a read excluded for a
# mid-read model switch is replaced by the next unused position (the replacement rule).
#
#   SEED=202610131 N=372 ruby q3_draw.rb
require 'json'
require 'digest'

ROOT = File.dirname(File.expand_path(__FILE__))
Q3 = File.join(ROOT, 'survey_q3_2025')
Q4_CACHE = ENV.fetch('Q4_CACHE', '/Users/masa/forback/github/GenomicsChain_MVP2_2026/log/repro_survey_2026_07/survey_v1_1/pagecache')
FRAME_HASH = '9db80e765739412e1ec2b3df90d8ce2359bbcdf67a23b65e4aa9c101f0e61f6e'
ELIGIBLE_HASH = 'dfa900a4f1c1744f871a101317ba83ec9d641f909fe638c61e93fd0508083ac6'
SEED = Integer(ENV.fetch('SEED')); N = Integer(ENV.fetch('N'))

def frame_of(pages)
  by_doi = {}
  pages.flat_map { |f| JSON.parse(File.read(f))['collection'] || [] }
       .select { |r| r['category'].to_s.strip.downcase == 'genomics' }.each do |r|
    by_doi[r['doi'].to_s] = r if by_doi[r['doi'].to_s].nil? || r['version'].to_i > by_doi[r['doi'].to_s]['version'].to_i
  end
  by_doi.values.sort_by { |r| [r['date'].to_s, r['doi'].to_s] }
end
hash_of = ->(rs) { Digest::SHA256.hexdigest(rs.map { |r| r['doi'] }.sort.join(',')) }

frame = frame_of(Dir.glob(File.join(Q3, 'pagecache', 'page_*.json')))
abort "frame hash mismatch: #{hash_of.(frame)}" unless hash_of.(frame) == FRAME_HASH
q4 = frame_of(Dir.glob(File.join(Q4_CACHE, 'page_*.json'))).map { |r| r['doi'] }.to_h { |d| [d, true] }
withdrawn = ->(r) { r['type'].to_s == 'withdrawn' || r['title'].to_s.start_with?('WITHDRAWN') }
eligible = frame.reject { |r| q4[r['doi']] || withdrawn.call(r) }
abort "eligible hash mismatch: #{hash_of.(eligible)}" unless hash_of.(eligible) == ELIGIBLE_HASH

order = eligible.shuffle(random: Random.new(SEED)).each_with_index.map do |r, i|
  { 'canonical_id' => r['doi'].to_s, 'doi' => r['doi'], 'kind' => 'doi', 'title' => r['title'], 'date' => r['date'],
    'version' => r['version'], 'category' => r['category'], 'jatsxml' => r['jatsxml'],
    'biorxiv_url' => "https://www.biorxiv.org/content/#{r['doi']}v#{r['version']}",
    'institution' => r['author_corresponding_institution'], 'idx' => i + 1, 'safe_id' => r['doi'].to_s.tr('/', '_') }
end
File.write(File.join(Q3, 'q3_order.json'), JSON.pretty_generate(order) + "\n")
File.write(File.join(Q3, 'q3_items_first.json'), JSON.pretty_generate(order.first(N)) + "\n")
puts JSON.generate('eligible' => eligible.size, 'seed' => SEED, 'n' => N,
                   'order_sha256' => Digest::SHA256.file(File.join(Q3, 'q3_order.json')).hexdigest,
                   'first_n_sha256' => Digest::SHA256.file(File.join(Q3, 'q3_items_first.json')).hexdigest)
