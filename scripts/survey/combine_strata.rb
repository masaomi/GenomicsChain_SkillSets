# Combined estimate over the two strata of the rater-3 (claude-opus-5-5) survey.
#
#   ruby combine_strata.rb [STATS.json] [OUT.json]
#
# Reads the per-stratum figures written by stats_rater3.rb and combines q4_frame and q3_sample:
#   - paper-level shares: weighted by the analysable frame sizes (Q4 635, Q3 666);
#     interval = Q4 share taken as fixed (near-census) + Q3 Wilson-with-FPC interval, both weighted.
#     The Q4 exclusion bound (7/635) is not in the interval and is reported separately.
#   - step-level shares and means: each stratum's steps expanded by N/n (ratio estimator), so a
#     stratum weighs by its estimated number of steps in the frame.
# Inputs are the rounded per-stratum figures (0.1 percentage point), so combined values carry up to
# about 0.05 points of rounding.
require 'json'

ROOT = File.dirname(File.expand_path(__FILE__))
stats_path = ARGV[0] || File.join(ROOT, 'survey_v1_1', 'agreement', 'stats_rater3.json')
out_path = ARGV[1] || File.join(ROOT, 'survey_v1_1', 'agreement', 'combined_strata.json')

FRAME = { 'q4_frame' => 635, 'q3_sample' => 666 }.freeze
Q4_EXCLUDED = 7

strata = JSON.parse(File.read(stats_path))['strata'].to_h { |s| [s['stratum'], s] }
q4 = strata.fetch('q4_frame'); q3 = strata.fetch('q3_sample')
abort "q3_sample has no reads" unless q3['n'].to_i.positive?
n_tot = FRAME.values.sum.to_f
w4 = FRAME['q4_frame'] / n_tot; w3 = FRAME['q3_sample'] / n_tot

paper = lambda do |p4, p3, ci3|
  c = w4 * p4 + w3 * p3
  h = { 'pct' => c.round(1) }
  h['ci95'] = [(w4 * p4 + w3 * ci3[0]).round(1), (w4 * p4 + w3 * ci3[1]).round(1)] if ci3
  h
end
share = ->(k, n) { 100.0 * k / n }

out = { 'generated_by' => 'combine_strata.rb', 'source' => File.basename(stats_path),
        'frame' => FRAME, 'weights_paper_level' => { 'q4' => w4.round(4), 'q3' => w3.round(4) },
        'q4_exclusion_bound_pp' => (100.0 * w4 * Q4_EXCLUDED / FRAME['q4_frame']).round(2) }

out['capture_claim'] = q4['capture_claim'].keys.to_h do |k|
  [k, paper.(q4['capture_claim'][k]['pct'], q3['capture_claim'][k]['pct'], q3['capture_claim'][k]['ci95'])]
end
out['stage2_positive'] = paper.(q4['stage2_positive']['pct'], q3['stage2_positive']['pct'], q3['stage2_positive']['ci95'])
out['papers_no_step_at_RI'] = paper.(q4['papers_no_step_at_RI']['pct'], q3['papers_no_step_at_RI']['pct'],
                                     q3['papers_no_step_at_RI']['ci95'])
out['papers_without_wetlab'] = paper.(share.(q4['papers_without_wetlab'], q4['n']),
                                      share.(q3['papers_without_wetlab'], q3['n']), nil)
out['paper_type'] = (q4['paper_type'].keys | q3['paper_type'].keys).to_h do |k|
  [k, paper.(share.(q4['paper_type'].fetch(k, 0), q4['n']), share.(q3['paper_type'].fetch(k, 0), q3['n']), nil)]
end
out['gap_types'] = q4['gap_types']['papers'].keys.to_h do |t|
  [t, paper.(q4['gap_types']['papers'][t]['pct'], q3['gap_types']['papers'].fetch(t, { 'pct' => 0.0 })['pct'], nil)]
end

# step level: weight = estimated steps in the frame
sw4 = FRAME['q4_frame'].to_f / q4['n'] * q4['computational_steps']
sw3 = FRAME['q3_sample'].to_f / q3['n'] * q3['computational_steps']
step = ->(a, b) { ((sw4 * a + sw3 * b) / (sw4 + sw3)).round(1) }
step2 = ->(a, b) { ((sw4 * a + sw3 * b) / (sw4 + sw3)).round(2) }
out['weights_step_level'] = { 'q4' => (sw4 / (sw4 + sw3)).round(4), 'q3' => (sw3 / (sw4 + sw3)).round(4),
                              'estimated_frame_steps' => (sw4 + sw3).round }
out['axis_scores_pct'] = q4['axis_scores_pct'].keys.to_h do |ax|
  a = q4['axis_scores_pct'][ax]; b = q3['axis_scores_pct'][ax]
  [ax, { '0' => step.(a['0'], b['0']), '1' => step.(a['1'], b['1']), '2' => step.(a['2'], b['2']),
         'mean' => step2.(a['mean'], b['mean']) }]
end
out['binding_axis_pct'] = q4['binding_axis_pct'].keys.to_h { |ax| [ax, step.(q4['binding_axis_pct'][ax], q3['binding_axis_pct'][ax])] }
out['verdicts_pct'] = q4['verdicts'].keys.to_h { |v| [v, step.(q4['verdicts'][v]['pct'], q3['verdicts'][v]['pct'])] }

File.write(out_path, JSON.pretty_generate(out) + "\n")
puts JSON.pretty_generate(out)
