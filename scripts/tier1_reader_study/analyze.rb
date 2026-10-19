# frozen_string_literal: true

# Descriptive analysis of the registered reads. Computes nothing the
# pre-registration does not name; every number comes from report.json and
# record.json, never from a model.
#
#   ruby scripts/tier1_reader_study/analyze.rb   -> log/<study>/analysis/{reads.tsv,cells.tsv,summary.json}

require_relative 'study'

S = ReaderStudy
OUT = File.join(S::OUT, 'analysis')
FileUtils.mkdir_p(OUT)

# Round-1 capture rule, verbatim from selfapp/expected_v1.json rules.tier1_capture_rule.
def r1_type?(gap)
  Array(gap['type']).any? { |t| %w[2 2a 13].include?(t.to_s.strip.downcase) }
end

def r1_text?(gap)
  %w[where missing].any? do |k|
    v = gap[k]
    text = v.nil? ? '' : (v.is_a?(String) ? v : JSON.generate(v))
    text.downcase.include?('salmon') || text.downcase.include?('synthref')
  end
end

def r1_capture?(gap) = gap.is_a?(Hash) && gap.key?('type') && r1_type?(gap) && r1_text?(gap)

# D2, registered for this study: a gap names the reference's release when its
# text (every string or number in the gap object, recursively) names the
# reference AND a release or version. English and Japanese terms, because one
# CLI path answers in Japanese under an account-level setting.
D2_REF = /synthref|reference|transcriptome|リファレンス|参照|トランスクリプトーム/i
D2_REL = /release|version|リリース|バージョン|版/i

def leaf_text(v)
  case v
  when Hash then v.values.map { |x| leaf_text(x) }.join(' ')
  when Array then v.map { |x| leaf_text(x) }.join(' ')
  when nil then ''
  else v.to_s
  end
end

def d2_mention?(gap)
  t = leaf_text(gap)
  t.match?(D2_REF) && t.match?(D2_REL)
end

REF_STEP = /salmon|quantif|tximport|aggregat|reference|index|定量|集計/i

# A tool call is outside the supplied text when it targets anything but the
# fresh empty working directory, or when a web tool succeeded.
def outside_access?(family, calls)
  Array(calls).any? do |c|
    case family
    when 'claude' then true # --tools "" leaves none; any entry is a deviation
    when 'codex'
      !(c['type'] == 'mcp_tool_call' && %w[list_mcp_resources list_mcp_resource_templates].include?(c['tool']))
    when 'cursor'
      web = c['tool'].to_s.match?(/web/i)
      targets = Array(c['target']).reject { |t| t.to_s.include?('reader_study_') }
      (web && Array(c['result']).include?('success')) ||
        (!web && Array(c['result']).include?('success') && !targets.empty?)
    end
  end
end

# Deviation D-1: the registered check above reads `target`, which mixes grep
# patterns with paths. The corrected check re-reads the raw Cursor events and
# treats only path-valued arguments as targets. Both are reported.
def cursor_calls_from_raw(stdout)
  stdout.each_line.filter_map do |l|
    e = JSON.parse(l) rescue next
    next unless e['type'] == 'tool_call' && e['subtype'] == 'completed'

    name, call = (e['tool_call'] || {}).find { |k, v| k.end_with?('ToolCall') && v.is_a?(Hash) }
    args = call&.dig('args') || {}
    { 'tool' => name, 'path' => args['path'] || args['targetDirectory'],
      'web' => name.to_s.match?(/web/i), 'success' => (call&.dig('result') || {}).key?('success') }
  end
end

def cursor_outside(calls, only_successful:)
  calls.any? do |c|
    next false if only_successful && !c['success']

    # Deviation D-2: the fresh home is also named reader_study_…; only the
    # working directory (reader_study_<date>-…) counts as inside.
    c['web'] || (!c['path'].nil? && !c['path'].to_s.match?(%r{/reader_study_(?!home_)}))
  end
end

rows = []
S::DOC_ORDER.each do |doc|
  S.configs.each do |cfg|
    (1..3).each do |rep|
      dir = File.join(S::OUT, 'reads', doc, cfg[:id], "rep#{rep}")
      rec_path = File.join(dir, 'record.json')
      row = { 'doc' => doc, 'config' => cfg[:id], 'family' => cfg[:family], 'model' => cfg[:model],
              'effort' => cfg[:effort] || 'none', 'rep' => rep }
      unless File.exist?(rec_path)
        rows << row.merge('outcome' => 'not_run')
        next
      end
      rec = JSON.parse(File.read(rec_path))
      last = Array(rec['attempts']).last || {}
      cli = last['cli_report'] || {}
      row.merge!('outcome' => rec['outcome'], 'attempts' => Array(rec['attempts']).size,
                 'seconds' => last['seconds'], 'model_returned' => Array(cli['model_returned']).join('+'),
                 'n_tool_calls' => Array(cli['tool_calls']).size,
                 'outside_access_registered' => outside_access?(cfg[:family], cli['tool_calls']),
                 'error' => rec.dig('error', 'message').to_s[0, 160])
      if cfg[:family] == 'cursor' && !rec['attempts'].to_a.empty?
        raw = File.binread(File.join(dir, "attempt#{rec['attempts'].size}.stdout"))
        calls = cursor_calls_from_raw(raw)
        row['outside_access'] = cursor_outside(calls, only_successful: true)
        row['outside_attempted'] = cursor_outside(calls, only_successful: false)
      else
        row['outside_access'] = row['outside_access_registered']
        row['outside_attempted'] = row['outside_access_registered']
      end
      rep_path = File.join(dir, 'report.json')
      if File.exist?(rep_path)
        report = JSON.parse(File.read(rep_path))
        c = report['counts']
        gaps = Array(report['gaps'])
        ref_steps = Array(report['steps']).select { |s| s['label'].to_s.match?(REF_STEP) }
        vmean = ref_steps.empty? ? nil : (ref_steps.sum { |s| s.dig('axes', 'version').to_f } / ref_steps.size).round(3)
        row.merge!('S' => c['S'], 'n_R' => c['n_R'], 'n_RI' => c['n_RI'], 'n_NI' => c['n_NI'], 'n_X' => c['n_X'],
                   'W' => c['W'], 'capture_claim' => report['capture_claim'],
                   'stage2_candidate' => report['stage2_candidate'], 'n_gaps' => gaps.size,
                   'gap_types' => gaps.map { |g| g.is_a?(Hash) ? Array(g['type']).join('|') : '?' }.join(';'),
                   'd2' => gaps.any? { |g| g.is_a?(Hash) && d2_mention?(g) },
                   'r1' => gaps.any? { |g| r1_capture?(g) },
                   'version_mean_ref_steps' => vmean, 'n_ref_steps' => ref_steps.size)
      end
      rows << row
    end
  end
end

cols = %w[doc config family model effort rep outcome attempts S n_R n_RI n_NI n_X W capture_claim stage2_candidate
          n_gaps d2 r1 version_mean_ref_steps n_ref_steps n_tool_calls outside_access outside_attempted
          outside_access_registered seconds model_returned
          gap_types error]
File.write(File.join(OUT, 'reads.tsv'),
           ([cols.join("\t")] + rows.map { |r| cols.map { |k| r[k].to_s.tr("\t\n", '  ') }.join("\t") }).join("\n") + "\n")

# Per cell (document x configuration): the three values of each endpoint, and
# whether the count tuple (S, n_RI, n_NI, n_X) was identical across the reads.
cells = rows.group_by { |r| [r['doc'], r['config']] }.map do |(doc, cfg), rs|
  ok = rs.select { |r| r['outcome'] == 'assessed' }
  tuples = ok.map { |r| r.values_at('S', 'n_RI', 'n_NI', 'n_X') }
  { 'doc' => doc, 'config' => cfg, 'assessed' => "#{ok.size}/#{rs.size}",
    'S' => ok.map { |r| r['S'] }, 'n_RI' => ok.map { |r| r['n_RI'] }, 'n_NI' => ok.map { |r| r['n_NI'] },
    'n_X' => ok.map { |r| r['n_X'] }, 'capture_claim' => ok.map { |r| r['capture_claim'] },
    'stage2_candidate' => ok.map { |r| r['stage2_candidate'] },
    'tuple_identical' => ok.size > 1 && tuples.uniq.size == 1,
    'd2' => "#{ok.count { |r| r['d2'] }}/#{ok.size}", 'r1' => "#{ok.count { |r| r['r1'] }}/#{ok.size}",
    'version_mean_ref_steps' => ok.map { |r| r['version_mean_ref_steps'] },
    'outside_access' => rs.count { |r| r['outside_access'] },
    'outside_access_registered' => rs.count { |r| r['outside_access_registered'] } }
end
ccols = %w[doc config assessed S n_RI n_NI n_X capture_claim stage2_candidate tuple_identical d2 r1
           version_mean_ref_steps outside_access outside_access_registered]
File.write(File.join(OUT, 'cells.tsv'),
           ([ccols.join("\t")] + cells.map { |c| ccols.map { |k| c[k].is_a?(Array) ? c[k].join(',') : c[k].to_s }.join("\t") })
             .join("\n") + "\n")

summary = {
  'study' => S::STUDY_ID, 'analysed_at' => S.now,
  'outcomes' => rows.group_by { |r| r['outcome'] }.transform_values(&:size),
  'reads_with_outside_access' => rows.select { |r| r['outside_access'] }.map { |r| r.values_at('doc', 'config', 'rep') },
  'reads_with_outside_attempted' => rows.select { |r| r['outside_attempted'] }.map { |r| r.values_at('doc', 'config', 'rep') },
  'reads_with_outside_access_as_registered' =>
    rows.select { |r| r['outside_access_registered'] }.map { |r| r.values_at('doc', 'config', 'rep') },
  'deviations' => ['D-1: outside_access for Cursor corrected; registered classification kept as outside_access_registered',
                   'D-2: the fresh home no longer counts as the working directory in the corrected check'],
  'hosted_run_reference' => { 'reader' => 'claude-sonnet-5-5 on Bedrock, provider default effort',
                              'S' => 7, 'n_RI' => 4, 'n_NI' => 3, 'n_X' => 0, 'capture_claim' => 'env_lock_claimed',
                              'stage2_candidate' => true },
  'manifest_sha256' => S.sha(File.read(S.manifest_path))
}
File.write(File.join(OUT, 'summary.json'), JSON.pretty_generate(summary) + "\n")
puts JSON.pretty_generate(summary['outcomes'])
puts "wrote #{OUT}/reads.tsv, cells.tsv, summary.json"
