# Outside checks for one survey read run, and the replacement-rule bookkeeping.
#
# Checks every report the run should have written (schema, assessor fields, b1 hash, rubric, fetch
# manifest), counts the model of every API response in the subagent transcripts, and scans tool calls
# for access to other reports. With --quarantine, reads that received any response from a model other
# than the registered one are moved to the quarantine directory and logged in its README.json.
# Prints a JSON summary, including how many valid reads the tree holds and the next unused positions.
#
#   ruby check_run.rb --transcripts DIR --items q3_order.json --positions 187-378 \
#        --tree survey_q3_2025/by_paper --date 2026-10-14 --label q3b \
#        [--quarantine survey_q3_2025/model_fallback_quarantine] [--target 372]
require 'json'
require 'digest'
require 'fileutils'
require 'optparse'
require 'json_schemer'

SCHEMA = '/Users/masa/forback/github/GenomicsChain_MVP2_2026/log/reproducibility_framework/report_schema_v0_2_5.json'
RUBRIC = '4024d4d8817abb0feb76ca9e91effcb11fcea53b1caae2a2ee4efc985e4ca3b1'
MODEL = 'claude-opus-5-5'
ASSESSOR = 'claude (stage1 subagent, rater3) + masaomi'

o = { target: 372 }
OptionParser.new do |p|
  p.on('--transcripts DIR') { |v| o[:tx] = v }
  p.on('--items FILE') { |v| o[:items] = v }
  p.on('--positions SPEC', 'e.g. 187-372,373-378') { |v| o[:pos] = v }
  p.on('--tree DIR') { |v| o[:tree] = v }
  p.on('--date DATE') { |v| o[:date] = v }
  p.on('--label LABEL') { |v| o[:label] = v }
  p.on('--quarantine DIR') { |v| o[:q] = v }
  p.on('--target N', Integer) { |v| o[:target] = v }
end.parse!
%i[tx items pos tree date label].each { |k| abort "missing --#{k}" unless o[k] }

positions = o[:pos].split(',').flat_map { |r| a, b = r.split('-').map(&:to_i); (a..(b || a)).to_a }
order = JSON.parse(File.read(o[:items]))
by_idx = order.to_h { |x| [x['idx'], x] }
schema = JSONSchemer.schema(JSON.parse(File.read(SCHEMA)))

# --- transcripts: model per response, isolation --------------------------------------
agents = {}
Dir.glob(File.join(o[:tx], 'agent-*.jsonl')).each do |f|
  desc = JSON.parse(File.read(f.sub(/\.jsonl\z/, '.meta.json')))['description'].to_s
  pos = desc[/pos-(\d+)/, 1]&.to_i or next
  own = by_idx[pos] && by_idx[pos]['safe_id']
  a = agents[pos] = { 'models' => Hash.new(0), 'refusals' => 0, 'isolation_hits' => [] }
  seen = {}
  File.foreach(f) do |line|
    m = JSON.parse(line) rescue next
    if m['type'] == 'assistant'
      a['refusals'] += 1 if m.dig('message', 'stop_reason') == 'refusal'
      id = m.dig('message', 'id')
      unless id && seen[id]
        seen[id] = true if id
        a['models'][m.dig('message', 'model')] += 1
      end
    end
    content = m.dig('message', 'content')
    next unless content.is_a?(Array)
    content.each do |c|
      next unless c.is_a?(Hash) && c['type'] == 'tool_use'
      s = JSON.generate(c['input'])
      other_tree = s.scan(%r{#{Regexp.escape(File.expand_path(o[:tree]))}/([0-9A-Za-z_.\-]+)}).flatten
                    .map { |x| x.sub(/\.+\z/, '') }.reject { |x| x == own }
      if s =~ %r{survey_v1_1/|repro_survey_2026_07/collection|model_fallback_quarantine} || !other_tree.empty? ||
         (c['name'] == 'Bash' && c.dig('input', 'command').to_s =~ /(^|[;&|\s])(grep\s+-\w*[rR]|rg\s|find\s+\/(Users|$))/)
        a['isolation_hits'] << s[0, 160]
      end
    end
  end
end

# --- reports --------------------------------------------------------------------------
bad = Hash.new { |h, k| h[k] = [] }
fallback = []
positions.each do |pos|
  it = by_idx[pos] or (bad[:unknown_position] << pos; next)
  s = it['safe_id']; dir = File.join(o[:tree], s); f = File.join(dir, "#{s}__stage1__v0.2.5__rater3.json")
  ag = agents[pos]
  bad[:no_transcript] << pos unless ag
  bad[:isolation] << pos if ag && !ag['isolation_hits'].empty?
  if ag && ag['models'].keys.any? { |m| m != MODEL }
    fallback << { 'position' => pos, 'safe_id' => s, 'title' => it['title'].to_s[0, 110],
                  'other_model_responses' => ag['models'].reject { |m, _| m == MODEL }, 'refusals' => ag['refusals'] }
  end
  unless File.exist?(f)
    bad[:missing_report] << pos
    next
  end
  r = JSON.parse(File.read(f))
  bad[:schema] << pos unless schema.validate(r).none?
  l = r.dig('assessor_stack', 'llm') || {}
  bad[:assessor_stack] << pos unless l['model'] == MODEL && l['effort'] == 'xhigh' && l['provider'] == 'claude_code'
  bad[:id_or_date] << pos unless r['assessor_id'] == ASSESSOR && r['assessed_at'] == o[:date]
  bad[:canonical_id] << pos unless r.dig('canonical_id', 'value') == it['canonical_id']
  b1 = Digest::SHA256.hexdigest([r.dig('canonical_id', 'value'), r['rubric_hash'], r['assessor_id'], r['assessed_at']].join('|'))
  bad[:b1_hash] << pos unless b1 == r.dig('manifest', 'b1_manifest_hash')
  bad[:rubric] << pos unless r['rubric_hash'] == RUBRIC
  bad[:signed] << pos unless r.dig('human_signoff', 'signed') == false
  bad[:fetch_manifest] << pos unless File.exist?(File.join(dir, 'fetch_manifest.json'))
end

# --- quarantine -----------------------------------------------------------------------
moved = []
if o[:q] && !fallback.empty?
  qdir = File.join(o[:q], "attempt_#{o[:label]}")
  FileUtils.mkdir_p(qdir)
  fallback.each do |fb|
    src = File.join(o[:tree], fb['safe_id'])
    next unless Dir.exist?(src)
    FileUtils.mv(src, File.join(qdir, fb['safe_id']))
    moved << fb
  end
  readme = File.join(o[:q], 'README.json')
  doc = File.exist?(readme) ? JSON.parse(File.read(readme)) : {}
  doc[o[:label]] = { 'transcripts' => o[:tx], 'moved' => moved }
  File.write(readme, JSON.pretty_generate(doc) + "\n")
end

# --- bookkeeping for the replacement rule ---------------------------------------------
valid_in_tree = Dir.glob(File.join(o[:tree], '*', '*__rater3.json')).size
quarantined = o[:q] ? Dir.glob(File.join(o[:q], '**', '*__rater3.json')).map { |f| File.basename(File.dirname(f)) } : []
used = Dir.glob(File.join(o[:tree], '*')).map { |d| File.basename(d) } + quarantined
idx_of = order.to_h { |x| [x['safe_id'], x['idx']] }
max_used = used.map { |s| idx_of[s] }.compact.max || 0
need = [o[:target] - valid_in_tree, 0].max
next_positions = order.map { |x| x['idx'] }.select { |i| i > max_used }.first(need)

models = agents.values.each_with_object(Hash.new(0)) { |a, h| a['models'].each { |m, k| h[m] += k } }
puts JSON.pretty_generate(
  'label' => o[:label], 'positions_checked' => positions.size, 'problems' => bad,
  'model_responses' => models, 'fallback_reads' => fallback, 'quarantined_now' => moved.map { |m| m['position'] },
  'valid_reads_in_tree' => valid_in_tree, 'target' => o[:target], 'replacements_needed' => need,
  'next_unused_positions' => next_positions)
