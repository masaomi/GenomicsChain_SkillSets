# Figures 3 and 4 of the tiers preprint (v0.6) from the rater-3 survey statistics.
#
#   ruby make_figures_3_4.rb OUT_DIR
#
# Reads survey_v1_1/agreement/stats_rater3.json (per stratum) and combined_strata.json
# (written by combine_strata.rb). Static SVG for print; each bar carries a <title> tooltip.
require 'json'

ROOT = File.dirname(File.expand_path(__FILE__))
out_dir = ARGV[0] or abort 'usage: ruby make_figures_3_4.rb OUT_DIR'
st = JSON.parse(File.read(File.join(ROOT, 'survey_v1_1/agreement/stats_rater3.json')))['strata'].to_h { |s| [s['stratum'], s] }
cb = JSON.parse(File.read(File.join(ROOT, 'survey_v1_1/agreement/combined_strata.json')))
q4 = st.fetch('q4_frame'); q3 = st.fetch('q3_sample')

SURFACE = '#fcfcfb'; INK = '#0b0b0b'; INK2 = '#52514e'; RULE = '#e5e4e0'
BLUE = '#2a78d6'; BLUE_DARK = '#104281'
FONT = 'Helvetica, Arial, sans-serif'

def esc(s) = s.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
def f1(x) = format('%.1f', x)
def int(n) = n.to_s.reverse.scan(/\d{1,3}/).join(',').reverse

# horizontal bar: square at the baseline x0, 4px rounded data end
def bar(x0, y, w, h, fill, tip)
  return %(<line x1="#{x0}" y1="#{y}" x2="#{x0}" y2="#{y + h}" stroke="#{fill}" stroke-width="2"><title>#{esc(tip)}</title></line>) if w < 1
  r = [4, w].min
  d = "M#{x0},#{y} H#{(x0 + w - r).round(1)} Q#{(x0 + w).round(1)},#{y} #{(x0 + w).round(1)},#{y + r} " \
      "V#{y + h - r} Q#{(x0 + w).round(1)},#{y + h} #{(x0 + w - r).round(1)},#{y + h} H#{x0} Z"
  %(<path d="#{d}" fill="#{fill}"><title>#{esc(tip)}</title></path>)
end

def text(x, y, s, size: 12.5, fill: INK, anchor: 'start', weight: nil)
  w = weight ? %( font-weight="#{weight}") : ''
  %(<text x="#{x}" y="#{y}" font-size="#{size}" fill="#{fill}" text-anchor="#{anchor}"#{w}>#{esc(s)}</text>)
end

def svg(w, h, title, body)
  <<~SVG
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{w} #{h}" width="#{w}" height="#{h}" font-family="#{FONT}" role="img" style="width:100%;max-width:#{w}px;height:auto">
      <title>#{esc(title)}</title>
      <rect x="0" y="0" width="#{w}" height="#{h}" fill="#{SURFACE}"/>
    #{body.map { |l| "  #{l}" }.join("\n")}
    </svg>
  SVG
end

# ---------- Figure 3: environment-capture claim ----------
claims = [
  ['none', 'No pinning stated', false],
  ['floating', 'Floating versions (open ranges, "latest")', false],
  ['exact_pins_partial', 'Exact tool versions named, environment not closed', false],
  ['release_snapshot', 'Dated release snapshot (e.g. Bioconductor)', true],
  ['env_lock_claimed', 'Lockfile or conda environment claimed', true],
  ['container_digest_claimed', 'Container claimed (no paper text cites a digest)', true],
]
x0 = 350; scale = 4.6; y = 80; b = []
b << text(20, 30, 'Environment-capture claim, one per paper (1,000 papers, two strata combined)', size: 16, weight: 'bold')
b << text(20, 50, 'Tier-1 stage 1 reads the paper only. Reader claude-opus-5-5. Ordered from the weakest claim (top) to the strongest (bottom).', fill: INK2)
claims.each do |key, label, eligible|
  c = cb['capture_claim'][key]; a = q4['capture_claim'][key]; z = q3['capture_claim'][key]
  w = c['pct'] * scale; lo, hi = c['ci95']
  b << text(x0 - 12, y + 15, label, anchor: 'end')
  b << bar(x0, y, w, 20, eligible ? BLUE_DARK : BLUE,
           "#{label}: combined #{f1(c['pct'])}% (95% interval #{f1(lo)}–#{f1(hi)}); Q4 #{a['k']} of #{q4['n']} (#{f1(a['pct'])}%), Q3 #{z['k']} of #{q3['n']} (#{f1(z['pct'])}%)")
  b << %(<line x1="#{(x0 + lo * scale).round(1)}" y1="#{y + 10}" x2="#{(x0 + hi * scale).round(1)}" y2="#{y + 10}" stroke="#{INK}" stroke-width="1.5"/>)
  tx = (x0 + [hi, c['pct']].max * scale + 8).round(1)
  b << text(tx, y + 15, "#{f1(c['pct'])}%")
  b << text(tx + 46, y + 15, "Q4 #{f1(a['pct'])} · Q3 #{f1(z['pct'])}", size: 11.5, fill: INK2)
  y += 40
end
el4 = q4['stage2_positive']; el3 = q3['stage2_positive']; elc = cb['stage2_positive']
b << %(<rect x="#{x0}" y="#{y + 12}" width="14" height="14" rx="3" fill="#{BLUE}"/>)
b << text(x0 + 20, y + 24, 'stops at the document reading', size: 12, fill: INK2)
b << %(<rect x="#{x0 + 230}" y="#{y + 12}" width="14" height="14" rx="3" fill="#{BLUE_DARK}"/>)
b << text(x0 + 250, y + 24, "eligible for the code check: #{f1(elc['pct'])}% combined", size: 12, fill: INK2)
b << text(x0 + 250, y + 40, "(Q4 #{el4['k']} of #{q4['n']}, Q3 #{el3['k']} of #{q3['n']})", size: 12, fill: INK2)
b << text(20, y + 66, 'Bars: combined share, strata weighted by frame size (Q4 635, Q3 666 works); line: 95% interval (Q3 sampling only). Beside each bar: the share in each stratum.', size: 11, fill: INK2)
b << text(20, y + 82, 'Source: stats_rater3.rb and combine_strata.rb on the per-paper reports (rubric v0.2.5); counts and intervals in Supplementary S2, Table S2.2.', size: 11, fill: INK2)
fig3 = svg(900, y + 96,
           'What 1,000 bioRxiv genomics preprints (a version posted July–December 2025) claim about capturing their software environment, from the Tier-1 stage-1 reading by claude-opus-5-5. Bars are combined shares over the two strata; the darker bars are the claims that make a paper eligible for the code check.', b)

# ---------- Figure 4: capping axis and step verdicts ----------
b = []
steps = q4['computational_steps'] + q3['computational_steps']
b << text(20, 30, "#{int(steps)} computational steps in 1,000 papers (two strata combined)", size: 16, weight: 'bold')
b << text(20, 50, 'Each step is scored 0–2 on four axes; the lowest axis sets the step verdict. Reader claude-opus-5-5.', fill: INK2)
b << text(20, 86, 'Which axis caps the step (ties split evenly)', size: 13.5, weight: 'bold')
axes = [%w[version Version\ (environment)], %w[data Data], %w[params Parameters], %w[code Code]]
lx = 170; sc = 3.4; y = 104
axes.each do |key, label|
  v = cb['binding_axis_pct'][key]; a = q4['binding_axis_pct'][key]; z = q3['binding_axis_pct'][key]
  b << text(lx - 10, y + 15, label, anchor: 'end')
  b << bar(lx, y, v * sc, 20, BLUE, "#{label} caps #{f1(v)}% of steps combined (Q4 #{f1(a)}%, Q3 #{f1(z)}%)")
  b << text((lx + v * sc + 8).round(1), y + 15, "#{f1(v)}%")
  b << text((lx + v * sc + 8).round(1), y + 29, "Q4 #{f1(a)} · Q3 #{f1(z)}", size: 11, fill: INK2)
  y += 46
end
m = cb['axis_scores_pct']
b << text(20, y + 14, "Mean axis score: data #{format('%.2f', m['data']['mean'])}, code #{format('%.2f', m['code']['mean'])}, version #{format('%.2f', m['version']['mean'])}, parameters #{format('%.2f', m['params']['mean'])}.", size: 11.5, fill: INK2)
u = cb['unique_lowest_axis_pct']
b << text(20, y + 30, "Single lowest axis only: version #{f1(u['version'])}%, data #{f1(u['data'])}%, parameters #{f1(u['params'])}%, code #{f1(u['code'])}%.", size: 11.5, fill: INK2)
b << text(20, y + 46, 'Version cannot reach 2 at stage 1, so it ties for lowest on most steps.', size: 11.5, fill: INK2)
b << %(<line x1="465" y1="70" x2="465" y2="#{y + 50}" stroke="#{RULE}" stroke-width="1"/>)
b << text(490, 86, 'Step verdict', size: 13.5, weight: 'bold')
verdicts = [['R', 'R★  declared closure'], ['RI', 'RI  partially ready'], ['NI', 'NI  needs investigation'], ['X', 'X  blocked']]
rx = 650; sc2 = 2.0; y2 = 104
verdicts.each do |key, label|
  v = cb['verdicts_pct'][key]; a = q4['verdicts'][key]; z = q3['verdicts'][key]
  b << text(rx - 10, y2 + 15, label, anchor: 'end')
  b << bar(rx, y2, v * sc2, 20, BLUE, "#{label}: #{f1(v)}% of steps combined (Q4 #{int(a['k'])}, #{f1(a['pct'])}%; Q3 #{int(z['k'])}, #{f1(z['pct'])}%)")
  vx = (rx + v * sc2 + 8).round(1)
  b << text(vx, y2 + 15, key == 'R' ? '0% (by construction)' : "#{f1(v)}%")
  b << text(vx, y2 + 29, "Q4 #{f1(a['pct'])} · Q3 #{f1(z['pct'])}", size: 11, fill: INK2) unless key == 'R'
  y2 += 46
end
n4 = q4['papers_no_step_at_RI']; n3 = q3['papers_no_step_at_RI']; nc = cb['papers_no_step_at_RI']
b << text(490, y + 14, "No step reaches RI in #{f1(nc['pct'])}% of papers (Q4 #{n4['k']} of #{q4['n']}, Q3 #{n3['k']} of #{q3['n']}).", size: 11.5, fill: INK2)
b << text(490, y + 30, 'Median 19 computational steps per paper; wet-lab steps excluded.', size: 11.5, fill: INK2)
b << text(20, y + 76, 'Combined: each stratum\'s steps weighted by frame size over sample size (Q4 and Q3 then weigh 50% each). Bars in the two panels are on different scales.', size: 11, fill: INK2)
b << text(20, y + 92, 'Source: stats_rater3.rb and combine_strata.rb on the per-paper reports (rubric v0.2.5); counts in Supplementary S2, Table S2.3.', size: 11, fill: INK2)
fig4 = svg(900, y + 106,
           "Step-level results of the Tier-1 stage-1 reading by claude-opus-5-5 over #{int(steps)} computational steps in 1,000 papers. Left: which of the four axes caps each step (ties split evenly). Right: the per-step verdict; the top verdict is unreachable at stage 1 by construction.", b)

File.write(File.join(out_dir, 'fig3_survey_capture_claims.svg'), fig3)
File.write(File.join(out_dir, 'fig4_survey_steps.svg'), fig4)
puts "wrote #{File.join(out_dir, 'fig3_survey_capture_claims.svg')} and fig4_survey_steps.svg"
