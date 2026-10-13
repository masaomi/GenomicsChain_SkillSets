# Descriptive statistics over rater-3 (claude-opus-5-5, xhigh) stage-1 reads, per stratum.
#
# Same quantities as stats_stage1.rb (which stays the regenerator of the July rater-1 figures).
# Every readiness figure is a stage-1 CEILING; R-star is unreachable at stage 1 by construction.
#
#   ruby stats_rater3.rb [OUT.json]
#
# Strata:
#   q4_original_200  the 200 analysed papers of the v1.1 draw (frame 637, 2 withdrawn)
#   q4_frame         every valid read of the 2025-Q4 frame (635 analysable works, 7 excluded
#                    for a mid-read model switch; a near-census, so the 7 bound every share)
#   q3_sample        the 2025-Q3 sample, once it exists (frame of eligible works given below)
require 'json'

ROOT = File.dirname(File.expand_path(__FILE__))
V11 = File.join(ROOT, 'survey_v1_1')
Q3 = File.join(ROOT, 'survey_q3_2025')
CLAIMS = %w[none floating exact_pins_partial release_snapshot env_lock_claimed container_digest_claimed]
POSITIVE = %w[env_lock_claimed container_digest_claimed release_snapshot]
AXES = %w[data code version params]

def reads(glob) = Dir.glob(glob).sort.map { |f| JSON.parse(File.read(f)) }

def wilson(k, n, z = 1.96)
  return [0.0, 0.0] if n <= 0
  p = k.to_f / n; d = 1 + z * z / n; c = p + z * z / (2 * n)
  h = z * Math.sqrt(p * (1 - p) / n + z * z / (4 * n * n))
  [[(c - h) / d, 0.0].max, [(c + h) / d, 1.0].min]
end

def stratum(name, rs, frame:, excluded: 0, note: nil)
  n = rs.size
  return { 'stratum' => name, 'n' => 0, 'note' => 'no reads yet' } if n.zero?
  fpc = frame ? (frame - n).to_f / (frame - 1) : 1.0
  n_eff = fpc <= 0 ? Float::INFINITY : n / fpc
  ci = lambda do |k|
    return nil unless frame && fpc.positive?
    lo, hi = wilson(k * n_eff / n, n_eff); [(lo * 100).round(1), (hi * 100).round(1)]
  end
  share = ->(k, d = n) { (100.0 * k / d).round(1) }
  cs = rs.flat_map { |r| (r['steps'] || []).select { |s| s['layer'] == 'C' } }
  ws = rs.flat_map { |r| (r['steps'] || []).reject { |s| s['layer'] == 'C' } }
  sizes = rs.map { |r| r.dig('counts', 'S').to_i }.sort
  bind = Hash.new(0.0)
  cs.each do |s|
    v = AXES.to_h { |k| [k, s.dig('axes', k).to_i] }; m = v.values.min
    t = v.select { |_, x| x == m }.keys; t.each { |k| bind[k] += 1.0 / t.size }
  end
  vd = cs.map { |s| s['verdict'] }.tally
  no_ri = rs.count { |r| r.dig('counts', 'n_RI').to_i.zero? }
  pos = rs.count { |r| POSITIVE.include?(r['capture_claim']) }
  tallyable = rs.select { |r| r['gaps'].is_a?(Array) }
  gaps = Hash.new(0)
  tallyable.each { |r| r['gaps'].map { |g| g['type'].to_s }.reject(&:empty?).uniq.each { |t| gaps[t] += 1 } }
  cov = rs.map { |r| s = r.dig('counts', 'S').to_i; w = r.dig('counts', 'W').to_i; (s + w).zero? ? nil : s.to_f / (s + w) }.compact.sort
  {
    'stratum' => name, 'n' => n, 'frame' => frame, 'excluded_reads' => excluded, 'note' => note,
    'fpc' => fpc.round(4), 'n_eff' => n_eff.finite? ? n_eff.round(1) : 'census',
    'assessable' => rs.count { |r| r.dig('assessable', 'is_assessable') },
    'capture_claim' => CLAIMS.to_h { |c| k = rs.count { |r| r['capture_claim'] == c }; [c, { 'k' => k, 'pct' => share.(k), 'ci95' => ci.(k) }] },
    'stage2_positive' => { 'k' => pos, 'pct' => share.(pos), 'ci95' => ci.(pos) },
    'paper_type' => rs.map { |r| r['paper_type'] }.tally,
    'computational_steps' => cs.size, 'wetlab_steps_listed' => ws.size,
    'wetlab_steps_counted' => rs.sum { |r| r.dig('counts', 'W').to_i },
    'S_median' => sizes.size.odd? ? sizes[sizes.size / 2] : (sizes[sizes.size / 2 - 1] + sizes[sizes.size / 2]) / 2.0,
    'S_range' => sizes.minmax,
    'axis_scores_pct' => AXES.to_h { |ax| t = cs.map { |s| s.dig('axes', ax).to_i }.tally; [ax, { '0' => share.(t[0].to_i, cs.size), '1' => share.(t[1].to_i, cs.size), '2' => share.(t[2].to_i, cs.size), 'mean' => (cs.sum { |s| s.dig('axes', ax).to_i }.to_f / cs.size).round(2) }] },
    'binding_axis_pct' => AXES.to_h { |ax| [ax, (100.0 * bind[ax] / cs.size).round(1)] },
    'verdicts' => %w[R RI NI X].to_h { |v| [v, { 'k' => vd[v].to_i, 'pct' => share.(vd[v].to_i, cs.size) }] },
    'papers_no_step_at_RI' => { 'k' => no_ri, 'pct' => share.(no_ri), 'ci95' => ci.(no_ri) },
    'coverage_median_pct' => cov.empty? ? nil : (100 * cov[(cov.size - 1) / 2]).round(0),
    'papers_without_wetlab' => rs.count { |r| r.dig('counts', 'W').to_i.zero? },
    'gap_types' => { 'denominator' => tallyable.size, 'malformed' => n - tallyable.size,
                     'papers' => gaps.sort_by { |t, k| [-k, t.to_i] }.to_h { |t, k| [t, { 'k' => k, 'pct' => share.(k, tallyable.size) }] } },
  }
end

orig = reads(File.join(V11, 'rater3', 'by_paper', '*', '*__rater3.json'))
ext = reads(File.join(V11, 'extension', 'by_paper', '*', '*__rater3.json'))
q3 = reads(File.join(Q3, 'by_paper', '*', '*__rater3.json'))
q3_frame = File.exist?(File.join(Q3, 'frame_summary.json')) ? JSON.parse(File.read(File.join(Q3, 'frame_summary.json')))['eligible'] : nil
quarantined = Dir.glob(File.join(V11, 'extension', 'model_fallback_quarantine', '**', '*__rater3.json')).map { |f| File.basename(File.dirname(f)) }.uniq.size

out = {
  'generated_by' => 'stats_rater3.rb', 'reader' => 'claude-opus-5-5, effort xhigh, rubric v0.2.5, stage 1',
  'strata' => [
    stratum('q4_original_200', orig, frame: 637),
    stratum('q4_frame', orig + ext, frame: nil, excluded: quarantined,
            note: "near-census of 635 analysable works; #{quarantined} works excluded for a mid-read model switch, so every share can move by at most #{quarantined}/635 if they were included"),
    stratum('q3_sample', q3, frame: q3_frame),
  ],
}
path = ARGV[0] || File.join(V11, 'agreement', 'stats_rater3.json')
File.write(path, JSON.pretty_generate(out) + "\n")
out['strata'].each do |s|
  next puts("== #{s['stratum']}: #{s['note']}") if s['n'].zero?
  puts "== #{s['stratum']}: n=#{s['n']} frame=#{s['frame'].inspect} fpc=#{s['fpc']} excluded=#{s['excluded_reads']}"
  puts "  claims " + s['capture_claim'].map { |c, v| "#{c}=#{v['k']}(#{v['pct']}% #{v['ci95'].inspect})" }.join(' ')
  puts "  stage2 positive #{s['stage2_positive'].inspect}; types #{s['paper_type'].inspect}"
  puts "  steps C=#{s['computational_steps']} W listed=#{s['wetlab_steps_listed']} counted=#{s['wetlab_steps_counted']} median S=#{s['S_median']} range=#{s['S_range'].inspect}"
  puts "  axes #{s['axis_scores_pct'].inspect}"
  puts "  binding #{s['binding_axis_pct'].inspect}; verdicts #{s['verdicts'].inspect}"
  puts "  no step at RI #{s['papers_no_step_at_RI'].inspect}; coverage median #{s['coverage_median_pct']}%; W=0 papers #{s['papers_without_wetlab']}; assessable #{s['assessable']}"
  puts "  gaps (n=#{s['gap_types']['denominator']}, malformed #{s['gap_types']['malformed']}) " + s['gap_types']['papers'].map { |t, v| "#{t}:#{v['k']}(#{v['pct']}%)" }.join(' ')
end
puts "written #{path}"
