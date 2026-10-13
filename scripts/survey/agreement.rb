# Inter-reader agreement for the Tier-1 survey re-read.
#
# Pre-registration: re-read v1.0 (chain #24), amendments 1-2 (#36, #39); the drift rule, the K=30
# procedure and the derived quantities were fixed at #55 before this file was first run.
# Readers: r1 = claude-opus-4-6 (July), r2 = claude-opus-5 (49 papers, suspended),
# r3 = claude-opus-5-5 (all 200) and its 20-paper retest. Pairs are never pooled.
#
#   ruby agreement.rb [OUT.json]
require 'json'

ROOT = File.dirname(File.expand_path(__FILE__))
V11 = File.join(ROOT, 'survey_v1_1')
MVP2_R2 = '/Users/masa/forback/github/GenomicsChain_MVP2_2026/log/repro_survey_2026_07/survey_v1_1/rater2/by_paper'
SEED_KAPPA_BOOT = 202609023
SEED_AGREEMENT = 202607273
BOOT = 10_000
CODE_HOST = /(github\.com|gitlab\.|bitbucket\.org|codeberg\.org|sourceforge\.net|softwareheritage\.org)/i

CLAIMS = %w[none floating exact_pins_partial release_snapshot env_lock_claimed container_digest_claimed]
POSITIVE = %w[env_lock_claimed container_digest_claimed release_snapshot]
TYPES = %w[pure-computational mixed pure-wet-lab tool-methods hybrid]

excluded = JSON.parse(File.read(File.join(V11, 'collection', 'exclusions.json')))['excluded'].map { |e| e['canonical_id'] }
load = ->(glob) { Dir.glob(glob).map { |f| JSON.parse(File.read(f)) }.reject { |r| excluded.include?(r.dig('canonical_id', 'value')) }.to_h { |r| [r.dig('canonical_id', 'value'), r] } }
R1 = load.(File.join(V11, 'collection', 'by_paper', '*', '*stage1*v0.2.5.json'))
R3 = load.(File.join(V11, 'rater3', 'by_paper', '*', '*__rater3.json'))
R3RT = load.(File.join(V11, 'rater3', 'retest', '*', '*__rater3_retest.json'))
R2 = load.(File.join(MVP2_R2, '*', '*__rater2.json'))
IDX = (JSON.parse(File.read(File.join(V11, 'rater3_batch1_items.json'))) +
       JSON.parse(File.read(File.join(V11, 'rater3_batch2_items.json')))).to_h { |x| [x['canonical_id'], x['idx']] }

# --- field extraction ------------------------------------------------------------------
def counts(r) = r['counts'] || {}
def num(r, q)
  c = counts(r)
  case q
  when 'upper_bound'
    s = c['S'].to_i
    s.zero? ? nil : (c['n_R'].to_i + c['n_RI'].to_i).to_f / s
  when 'coverage'
    t = c['S'].to_i + c['W'].to_i
    t.zero? ? nil : c['S'].to_f / t
  else
    c[q].nil? ? nil : c[q].to_f
  end
end
def cat(r, q)
  case q
  when 'capture_claim' then r['capture_claim']
  when 'stage2_candidate' then r.key?('stage2_candidate') ? r['stage2_candidate'] : POSITIVE.include?(r['capture_claim'])
  when 'paper_type' then r['paper_type']
  when 'software_env_lock' then r.dig('levers', 'software_env_lock')
  when 'in_code_db_pin_classA' then r.dig('levers', 'in_code_db_pin_classA')
  when 'is_assessable' then r.dig('assessable', 'is_assessable')
  end
end
CLASSES = { 'capture_claim' => CLAIMS, 'stage2_candidate' => [true, false], 'paper_type' => TYPES,
            'software_env_lock' => [true, false], 'in_code_db_pin_classA' => [true, false], 'is_assessable' => [true, false] }
NUMERIC = %w[S W n_NI n_X n_RI n_R upper_bound coverage]
has_repo = ->(r) { (r['liveness'] || []).any? { |l| l.is_a?(Hash) && l['artifact'].to_s =~ CODE_HOST } }

# --- statistics ------------------------------------------------------------------------
def mean(a) = a.sum.to_f / a.size
def sd(a)
  return 0.0 if a.size < 2
  m = mean(a); Math.sqrt(a.sum { |x| (x - m)**2 } / (a.size - 1))
end
def t975(df) # Cornish-Fisher expansion of the t quantile; adequate for df >= 10
  z = 1.959964
  z + (z**3 + z) / (4.0 * df) + (5 * z**5 + 16 * z**3 + 3 * z) / (96.0 * df**2) +
    (3 * z**7 + 19 * z**5 + 17 * z**3 - 15 * z) / (384.0 * df**3)
end
def icc21(a, b) # two-way random, absolute agreement, single measure (Shrout & Fleiss ICC(2,1))
  n = a.size; k = 2.0
  return nil if n < 3
  rows = a.zip(b); gm = (a.sum + b.sum) / (n * k)
  rm = rows.map { |x, y| (x + y) / k }; cm = [mean(a), mean(b)]
  ssr = k * rm.sum { |m| (m - gm)**2 }; ssc = n * cm.sum { |m| (m - gm)**2 }
  sst = rows.sum { |x, y| (x - gm)**2 + (y - gm)**2 }; sse = sst - ssr - ssc
  msr = ssr / (n - 1); msc = ssc / (k - 1); mse = sse / ((n - 1) * (k - 1))
  den = msr + (k - 1) * mse + k * (msc - mse) / n
  den.zero? ? nil : (msr - mse) / den
end
def kappa(pairs)
  n = pairs.size.to_f; return nil if n.zero?
  po = pairs.count { |x, y| x == y } / n
  cats = pairs.flatten.uniq
  pe = cats.sum { |c| (pairs.count { |x, _| x == c } / n) * (pairs.count { |_, y| y == c } / n) }
  pe >= 1.0 ? nil : (po - pe) / (1 - pe)
end
def ac1(pairs, classes)
  n = pairs.size.to_f; q = classes.size
  po = pairs.count { |x, y| x == y } / n
  pe = classes.sum { |c| pi = (pairs.count { |x, _| x == c } + pairs.count { |_, y| y == c }) / (2 * n); pi * (1 - pi) } / (q - 1)
  (po - pe) / (1 - pe)
end

def compare(name, a_reads, b_reads, ids, has_repo)
  ids = ids.select { |i| a_reads[i] && b_reads[i] }.sort_by { |i| IDX[i] || 0 }
  out = { 'pair' => name, 'n' => ids.size, 'numeric' => {}, 'categorical' => {} }
  NUMERIC.each do |q|
    pr = ids.map { |i| [num(a_reads[i], q), num(b_reads[i], q)] }
    dropped = pr.count { |x, y| x.nil? || y.nil? }; pr = pr.reject { |x, y| x.nil? || y.nil? }
    next if pr.size < 3
    a = pr.map(&:first); b = pr.map(&:last); d = pr.map { |x, y| y - x }
    m = mean(d); s = sd(d); h = t975(d.size - 1) * s / Math.sqrt(d.size)
    out['numeric'][q] = { 'n' => pr.size, 'dropped_undefined' => dropped, 'mean_a' => mean(a).round(4), 'mean_b' => mean(b).round(4),
                          'diff_mean_b_minus_a' => m.round(4), 'diff_sd' => s.round(4), 'diff_ci95' => [(m - h).round(4), (m + h).round(4)],
                          'bland_altman_loa' => [(m - 1.96 * s).round(4), (m + 1.96 * s).round(4)],
                          'icc21' => icc21(a, b)&.round(4), 'provisional_mean_column' => mean(a.zip(b).map { |x, y| (x + y) / 2.0 }).round(4) }
  end
  CLASSES.each do |q, classes|
    pr = ids.map { |i| [cat(a_reads[i], q), cat(b_reads[i], q)] }
    missing = pr.count { |x, y| x.nil? || y.nil? }; pr = pr.reject { |x, y| x.nil? || y.nil? }
    next if pr.empty?
    raw = pr.count { |x, y| x == y }.to_f / pr.size
    top = pr.map(&:first).tally.values.max.to_f / pr.size
    res = { 'n' => pr.size, 'missing' => missing, 'raw_agreement' => raw.round(4), 'reader_a_top_class_share' => top.round(4),
            'confusion_a_rows_b_cols' => classes.to_h { |ca| [ca.to_s, classes.to_h { |cb| [cb.to_s, pr.count { |x, y| x == ca && y == cb }] }] } }
    if top > 0.95
      res['note'] = 'reader-A marginal > 95% in one class: raw agreement only (v1.0 6.1)'
    else
      k = kappa(pr); rng = Random.new(SEED_KAPPA_BOOT)
      boots = Array.new(BOOT) { kappa(Array.new(pr.size) { pr[rng.rand(pr.size)] }) }.compact.sort
      res['kappa'] = k&.round(4)
      res['kappa_boot_ci95'] = [boots[(0.025 * boots.size).floor].round(4), boots[(0.975 * boots.size).ceil - 1].round(4)]
      res['kappa_boot_valid_resamples'] = boots.size
      res['gwet_ac1'] = ac1(pr, classes).round(4)
    end
    out['categorical'][q] = res
  end
  out['possible_drift'] = ids.count { |i| has_repo.(a_reads[i]) != has_repo.(b_reads[i]) }
  out
end

# --- side-by-side description of two readers on the same papers ------------------------
def describe(reads, ids)
  rs = ids.map { |i| reads[i] }.compact
  cs = rs.flat_map { |r| (r['steps'] || []).select { |s| s['layer'] == 'C' } }
  bind = Hash.new(0.0)
  cs.each do |s|
    v = %w[data code version params].to_h { |k| [k, s.dig('axes', k).to_i] }; m = v.values.min
    t = v.select { |_, x| x == m }.keys; t.each { |k| bind[k] += 1.0 / t.size }
  end
  vd = cs.map { |s| s['verdict'] }.tally
  sizes = rs.map { |r| r.dig('counts', 'S').to_i }.sort
  { 'papers' => rs.size, 'capture_claim' => CLAIMS.to_h { |c| [c, rs.count { |r| r['capture_claim'] == c }] },
    'stage2_positive' => rs.count { |r| POSITIVE.include?(r['capture_claim']) },
    'paper_type' => rs.map { |r| r['paper_type'] }.tally,
    'computational_steps' => cs.size, 'S_sum_counts' => sizes.sum,
    'S_median' => sizes.size.odd? ? sizes[sizes.size / 2] : (sizes[sizes.size / 2 - 1] + sizes[sizes.size / 2]) / 2.0,
    'S_range' => sizes.minmax,
    'verdicts' => %w[R RI NI X].to_h { |v| [v, vd[v].to_i] },
    'axis_mean' => %w[data code version params].to_h { |k| [k, (cs.sum { |s| s.dig('axes', k).to_i }.to_f / [cs.size, 1].max).round(3)] },
    'binding_axis_share' => bind.transform_values { |v| (v / [cs.size, 1].max).round(4) },
    'papers_no_step_at_RI' => rs.count { |r| r.dig('counts', 'n_RI').to_i.zero? } }
end

ids200 = R1.keys & R3.keys
k30 = ids200.sort_by { |i| IDX[i] }.sample(30, random: Random.new(SEED_AGREEMENT))
report = {
  'generated_by' => 'agreement.rb', 'fixed_at_chain' => '#55',
  'readers' => { 'r1' => 'claude-opus-4-6 (2026-07-27/28, effort not recorded)', 'r2' => 'claude-opus-5 xhigh (2026-09-02, 49 papers)',
                 'r3' => 'claude-opus-5-5 xhigh (2026-09-30/10-01)', 'r3_retest' => 'claude-opus-5-5 xhigh (2026-10-01, 20 papers)' },
  'counts_loaded' => { 'r1' => R1.size, 'r2' => R2.size, 'r3' => R3.size, 'r3_retest' => R3RT.size },
  'pairs' => [
    compare('r1_vs_r3', R1, R3, ids200, has_repo),
    compare('r3_vs_r3_retest', R3, R3RT, R3RT.keys, has_repo),
    compare('r1_vs_r2', R1, R2, R2.keys, has_repo),
    compare('r2_vs_r3', R2, R3, R2.keys, has_repo),
    compare('r1_vs_r3_k30_continuity', R1, R3, k30, has_repo),
  ],
  'side_by_side_200' => { 'r1' => describe(R1, ids200), 'r3' => describe(R3, ids200) },
}
out = ARGV[0] || File.join(V11, 'agreement', 'agreement_report.json')
Dir.mkdir(File.dirname(out)) unless Dir.exist?(File.dirname(out))
File.write(out, JSON.pretty_generate(report) + "\n")
report['pairs'].each do |p|
  puts "== #{p['pair']} (n=#{p['n']}, possible_drift=#{p['possible_drift']})"
  p['categorical'].each { |q, r| puts format('  %-22s raw %.3f  kappa %-7s %-18s AC1 %s %s', q, r['raw_agreement'], r['kappa'].inspect, r['kappa_boot_ci95'].inspect, r['gwet_ac1'].inspect, r['note'] ? '(' + r['note'][0, 30] + ')' : '') }
  p['numeric'].each { |q, r| puts format('  %-12s n=%-3d A %.3f B %.3f  diff %.3f [%.3f, %.3f]  LoA [%.2f, %.2f]  ICC %s', q, r['n'], r['mean_a'], r['mean_b'], r['diff_mean_b_minus_a'], *r['diff_ci95'], *r['bland_altman_loa'], r['icc21'].inspect) }
end
puts "written #{out}"
