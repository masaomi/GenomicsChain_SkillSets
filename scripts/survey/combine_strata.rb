# Combined estimate over the two strata of the rater-3 (claude-opus-5-5) survey.
#
#   ruby combine_strata.rb [OUT.json]
#
# Reads the valid per-paper reports (Q4: survey_v1_1/{rater3,extension}/by_paper; Q3: survey_q3_2025/by_paper),
# counts with the same rules as stats_rater3.rb, and combines q4_frame and q3_sample from the counts:
#   - paper-level shares: weighted by the analysable frame sizes (Q4 635, Q3 666);
#     interval = Q4 share taken as fixed (near-census) + the Q3 Wilson interval with finite-population
#     correction, both weighted. The Q4 exclusion bound (7/635) is not in the interval.
#   - step-level shares and means: each stratum's steps expanded by N/n (ratio estimator).
# Also reports, per step, whether the version axis is the unique lowest axis or one of several, because
# stage 1 caps version at 1 by construction and the tie-split capping share mixes the two.
# The per-stratum figures it prints must equal stats_rater3.json; it aborts if they do not.
require 'json'

ROOT = File.dirname(File.expand_path(__FILE__))
out_path = ARGV[0] || File.join(ROOT, 'survey_v1_1', 'agreement', 'combined_strata.json')
STATS = File.join(ROOT, 'survey_v1_1', 'agreement', 'stats_rater3.json')
FRAME = { 'q4' => 635, 'q3' => 666 }.freeze
Q4_EXCLUDED = 7
CLAIMS = %w[none floating exact_pins_partial release_snapshot env_lock_claimed container_digest_claimed].freeze
POSITIVE = %w[env_lock_claimed container_digest_claimed release_snapshot].freeze
AXES = %w[data code version params].freeze

def reads(*globs) = globs.flat_map { |g| Dir.glob(File.join(ROOT, g)) }.sort.map { |f| JSON.parse(File.read(f)) }

def wilson(k, n, z = 1.96)
  p = k.to_f / n; d = 1 + z * z / n; c = p + z * z / (2 * n)
  h = z * Math.sqrt(p * (1 - p) / n + z * z / (4 * n * n))
  [[(c - h) / d, 0.0].max, [(c + h) / d, 1.0].min]
end

# Wilson interval with finite-population correction, as in stats_rater3.rb (percent, unrounded)
def ci_fpc(k, n, frame)
  fpc = (frame - n).to_f / (frame - 1); n_eff = n / fpc
  wilson(k * n_eff / n, n_eff).map { |x| 100 * x }
end

def counts(rs)
  cs = rs.flat_map { |r| (r['steps'] || []).select { |s| s['layer'] == 'C' } }
  bind = Hash.new(0.0); uniq = Hash.new(0); among = Hash.new(0)
  cs.each do |s|
    v = AXES.to_h { |k| [k, s.dig('axes', k).to_i] }; m = v.values.min
    t = v.select { |_, x| x == m }.keys
    t.each { |k| bind[k] += 1.0 / t.size; among[k] += 1 }
    uniq[t.first] += 1 if t.size == 1
  end
  gaps = Hash.new(0)
  rs.select { |r| r['gaps'].is_a?(Array) }.each { |r| r['gaps'].map { |g| g['type'].to_s }.reject(&:empty?).uniq.each { |t| gaps[t] += 1 } }
  {
    'n' => rs.size, 'steps' => cs.size,
    'claims' => CLAIMS.to_h { |c| [c, rs.count { |r| r['capture_claim'] == c }] },
    'eligible' => rs.count { |r| POSITIVE.include?(r['capture_claim']) },
    'no_step_at_RI' => rs.count { |r| r.dig('counts', 'n_RI').to_i.zero? },
    'without_wetlab' => rs.count { |r| r.dig('counts', 'W').to_i.zero? },
    'paper_type' => rs.map { |r| r['paper_type'] }.tally,
    'gaps' => gaps,
    'axis' => AXES.to_h { |ax| t = cs.map { |s| s.dig('axes', ax).to_i }.tally; [ax, { 0 => t[0].to_i, 1 => t[1].to_i, 2 => t[2].to_i, 'sum' => cs.sum { |s| s.dig('axes', ax).to_i } }] },
    'bind' => bind, 'bind_unique' => uniq, 'bind_among' => among,
    'verdicts' => cs.map { |s| s['verdict'] }.tally,
  }
end

q4 = counts(reads('survey_v1_1/rater3/by_paper/*/*__rater3.json', 'survey_v1_1/extension/by_paper/*/*__rater3.json'))
q3 = counts(reads('survey_q3_2025/by_paper/*/*__rater3.json'))

# consistency with stats_rater3.json
st = JSON.parse(File.read(STATS))['strata'].to_h { |s| [s['stratum'], s] }
{ 'q4_frame' => q4, 'q3_sample' => q3 }.each do |name, c|
  s = st.fetch(name)
  ok = s['n'] == c['n'] && s['computational_steps'] == c['steps'] &&
       CLAIMS.all? { |k| s['capture_claim'][k]['k'] == c['claims'][k] } &&
       s['stage2_positive']['k'] == c['eligible'] && s['papers_no_step_at_RI']['k'] == c['no_step_at_RI'] &&
       %w[R RI NI X].all? { |v| s['verdicts'][v]['k'] == c['verdicts'][v].to_i }
  abort "#{name}: counts differ from stats_rater3.json" unless ok
end

n_tot = FRAME.values.sum.to_f
w4 = FRAME['q4'] / n_tot; w3 = FRAME['q3'] / n_tot
r1 = ->(x) { x.round(1) }
paper = lambda do |k4, k3, ci: true|
  p4 = 100.0 * k4 / q4['n']; p3 = 100.0 * k3 / q3['n']
  h = { 'q4_k' => k4, 'q3_k' => k3, 'pct' => r1.(w4 * p4 + w3 * p3), 'pct_exact' => (w4 * p4 + w3 * p3).round(4) }
  if ci
    lo, hi = ci_fpc(k3, q3['n'], FRAME['q3'])
    h['ci95'] = [r1.(w4 * p4 + w3 * lo), r1.(w4 * p4 + w3 * hi)]
  end
  h
end
e4 = FRAME['q4'].to_f / q4['n']; e3 = FRAME['q3'].to_f / q3['n']
den = e4 * q4['steps'] + e3 * q3['steps']
step = ->(c4, c3) { r1.(100.0 * (e4 * c4 + e3 * c3) / den) }
step_exact = ->(c4, c3) { (100.0 * (e4 * c4 + e3 * c3) / den).round(4) }

out = {
  'generated_by' => 'combine_strata.rb', 'frame' => FRAME,
  'weights_paper_level' => { 'q4' => w4.round(4), 'q3' => w3.round(4) },
  'weights_step_level' => { 'q4' => (e4 * q4['steps'] / den).round(4), 'q3' => (e3 * q3['steps'] / den).round(4) },
  'q4_exclusion_bound_pp' => (100.0 * w4 * Q4_EXCLUDED / FRAME['q4']).round(2),
  'capture_claim' => CLAIMS.to_h { |c| [c, paper.(q4['claims'][c], q3['claims'][c])] },
  'stage2_positive' => paper.(q4['eligible'], q3['eligible']),
  'papers_no_step_at_RI' => paper.(q4['no_step_at_RI'], q3['no_step_at_RI']),
  'papers_without_wetlab' => paper.(q4['without_wetlab'], q3['without_wetlab'], ci: false),
  'paper_type' => (q4['paper_type'].keys | q3['paper_type'].keys).to_h { |t| [t, paper.(q4['paper_type'].fetch(t, 0), q3['paper_type'].fetch(t, 0), ci: false)] },
  'gap_types' => (q4['gaps'].keys | q3['gaps'].keys).sort_by(&:to_i).to_h { |t| [t, paper.(q4['gaps'].fetch(t, 0), q3['gaps'].fetch(t, 0), ci: false)] },
  'steps' => { 'q4' => q4['steps'], 'q3' => q3['steps'] },
  'axis_scores_pct' => AXES.to_h do |ax|
    a = q4['axis'][ax]; b = q3['axis'][ax]
    [ax, { '0' => step.(a[0], b[0]), '1' => step.(a[1], b[1]), '2' => step.(a[2], b[2]),
           'mean' => ((e4 * a['sum'] + e3 * b['sum']) / den).round(2) }]
  end,
  'binding_axis_pct' => AXES.to_h { |ax| [ax, step.(q4['bind'][ax], q3['bind'][ax])] },
  'binding_axis_exact' => AXES.to_h { |ax| [ax, step_exact.(q4['bind'][ax], q3['bind'][ax])] },
  'unique_lowest_axis_pct' => AXES.to_h { |ax| [ax, step.(q4['bind_unique'][ax], q3['bind_unique'][ax])] }
                                   .merge('tie' => step.(q4['steps'] - q4['bind_unique'].values.sum, q3['steps'] - q3['bind_unique'].values.sum)),
  'unique_lowest_axis_per_stratum_pct' => {
    'q4' => AXES.to_h { |ax| [ax, r1.(100.0 * q4['bind_unique'][ax] / q4['steps'])] },
    'q3' => AXES.to_h { |ax| [ax, r1.(100.0 * q3['bind_unique'][ax] / q3['steps'])] },
  },
  'among_lowest_axes_pct' => AXES.to_h { |ax| [ax, step.(q4['bind_among'][ax], q3['bind_among'][ax])] },
  'verdicts_pct' => %w[R RI NI X].to_h { |v| [v, step.(q4['verdicts'][v].to_i, q3['verdicts'][v].to_i)] },
}
File.write(out_path, JSON.pretty_generate(out) + "\n")
puts JSON.pretty_generate(out)
