# Distinctness over every valid rater-3 read of the survey, and the DOI list that is recorded on chain.
#
# Valid reads = rater3/by_paper (original 200) + extension/by_paper (rest of Q4) + survey_q3_2025/by_paper.
# Checks unique canonical ids, unique fetched-JATS SHA-256 and unique normalised titles, and writes the
# sorted DOI list.
#
#   ruby final_distinctness.rb [OUT.txt]
require 'json'
require 'digest'

ROOT = File.dirname(File.expand_path(__FILE__))
TREES = { 'q4_original' => 'survey_v1_1/rater3/by_paper', 'q4_extension' => 'survey_v1_1/extension/by_paper',
          'q3' => 'survey_q3_2025/by_paper' }
ITEM_FILES = %w[survey_v1_1/rater3_batch1_items.json survey_v1_1/rater3_batch2_items.json
                survey_v1_1/extension_items_trial100.json survey_v1_1/extension_items_night1a.json
                survey_v1_1/extension_items_night1b.json survey_q3_2025/q3_order.json]

titles = ITEM_FILES.flat_map { |f| JSON.parse(File.read(File.join(ROOT, f))) }
                   .to_h { |x| [x['canonical_id'], x['title'].to_s.downcase.gsub(/<[^>]+>/, '').gsub(/[^a-z0-9]/, '')] }
reads = TREES.flat_map do |k, t|
  Dir.glob(File.join(ROOT, t, '*', '*__rater3.json')).map do |f|
    r = JSON.parse(File.read(f))
    fm = File.join(File.dirname(f), 'fetch_manifest.json')
    jats = File.exist?(fm) && (JSON.parse(File.read(fm))['sources'] || []).find { |x| x['kind'] == 'jats' && x['http_ok'] && !x['sha256'].to_s.empty? }
    { 'stratum' => k, 'id' => r.dig('canonical_id', 'value'), 'jats' => jats && jats['sha256'] }
  end
end
dups = ->(a) { a.compact.group_by(&:itself).select { |_, v| v.size > 1 }.keys }
ids = reads.map { |x| x['id'] }
list = ids.sort.join("\n") + "\n"
out = ARGV[0] || File.join(ROOT, 'survey_q3_2025', 'valid_reads_doi_list_1000.txt')
File.write(out, list)
puts JSON.pretty_generate(
  'valid_reads' => reads.size, 'by_stratum' => reads.map { |x| x['stratum'] }.tally,
  'unique_canonical_ids' => ids.uniq.size, 'duplicate_ids' => dups.(ids),
  'fetched_jats_sha256_present' => reads.count { |x| x['jats'] }, 'unique_jats_sha256' => reads.map { |x| x['jats'] }.compact.uniq.size,
  'duplicate_jats' => dups.(reads.map { |x| x['jats'] }).size,
  'titles_found' => ids.count { |i| titles[i] }, 'unique_titles' => ids.map { |i| titles[i] }.compact.uniq.size,
  'doi_list' => out, 'doi_list_sha256' => Digest::SHA256.hexdigest(list))
