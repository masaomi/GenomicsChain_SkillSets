#!/usr/bin/env ruby
# Descriptive statistics over a completed Stage-1 collection.
#
# SCOPE WARNING, deliberately enforced here rather than left to the reader:
# Stage 1 assigns NO R-star. Every "readiness" figure below is a CEILING -- an upper
# bound on what a Stage-2 code check could confirm -- never a reproducibility rate.
# The pre-registered headline is the two-lever histogram, and both levers require
# Stage 2. Nothing in this file estimates them.
#
# Confidence intervals use a finite-population correction. The frame is 637 works and
# the draw is 200, a 31% sampling fraction, so ignoring the FPC would overstate the
# intervals by about 21%. Wilson intervals are used rather than Wald because several
# cells are at or near zero, where Wald degenerates.
require 'json'
require 'csv'

ROOT = File.dirname(__FILE__)
COLLECTION = File.join(ROOT, ENV.fetch('COLLECTION', 'survey_v1_1/collection'))
FRAME = Integer(ENV.fetch('FRAME', '637'))   # de-duplicated works in the pre-registered frame

excl_path = File.join(COLLECTION, 'exclusions.json')
EXCL = File.exist?(excl_path) ? JSON.parse(File.read(excl_path))['excluded'].to_a.map { |e| e['canonical_id'] } : []

reports = Dir.glob(File.join(COLLECTION, 'by_paper', '*', '*stage1*v0.2.5.json')).sort.map { |f| JSON.parse(File.read(f)) }
reports.reject! { |r| EXCL.include?(r.dig('canonical_id', 'value')) }
N = reports.size
abort "no reports under #{COLLECTION}" if N.zero?

# --- interval estimation ------------------------------------------------------------
# fpc shrinks the variance; equivalently the effective sample size grows by 1/fpc.
FPC = (FRAME - N).to_f / (FRAME - 1)
N_EFF = N / FPC

def wilson(k, n, z = 1.96)
  return [0.0, 0.0] if n.zero?
  p = k.to_f / n
  d = 1 + z * z / n
  c = p + z * z / (2 * n)
  h = z * Math.sqrt(p * (1 - p) / n + z * z / (4 * n * n))
  [[(c - h) / d, 0.0].max, [(c + h) / d, 1.0].min]
end

# k is the observed count in the real sample; the interval is widened/narrowed via N_EFF
def ci(k, n = N)
  lo, hi = wilson(k * N_EFF / n, N_EFF)
  format('[%4.1f%%, %4.1f%%]', lo * 100, hi * 100)
end

def pct(k, n = N) = format('%5.1f%%', 100.0 * k / n)

def bar(k, n, width = 28)
  filled = (width * k.to_f / n).round
  '#' * filled + '.' * (width - filled)
end

def section(t)
  puts
  puts "== #{t} " + '=' * [0, 76 - t.length].max
end

puts "Stage-1 descriptive statistics"
puts "collection : #{COLLECTION}"
puts "N          : #{N} drawn works (#{EXCL.size} excluded from the denominator, reports retained)"
puts "frame      : #{FRAME} de-duplicated works; sampling fraction #{pct(N, FRAME).strip}"
puts "FPC        : variance x #{format('%.3f', FPC)}  ->  effective n = #{N_EFF.round}"
puts "population : bioRxiv genomics preprints posted 2025-10-01..2025-12-31. Not earlier periods,"
puts "             not other bioRxiv collections, not computational biology generally."

# --- 1. paper-level claim distribution ----------------------------------------------
section 'Capture claim -- what the paper CLAIMS about environment capture'
ORDER = %w[none floating exact_pins_partial release_snapshot env_lock_claimed container_digest_claimed]
claims = reports.group_by { |r| r['capture_claim'] }.transform_values(&:size)
puts format('%-26s %5s %8s  %-28s %s', 'class', 'n', 'share', 'distribution', '95% CI (FPC)')
ORDER.each do |c|
  k = claims[c].to_i
  puts format('%-26s %5d %8s  %-28s %s', c, k, pct(k), bar(k, N), ci(k))
end
puts format('%-26s %5d', 'total', N)
puts
puts "Ordering is by increasing strength of claim. The mass sits at exact_pins_partial:"
puts "exact versions named in prose with no environment closure around them."

# --- 2. the funnel ------------------------------------------------------------------
section 'Stage-2 funnel (pre-registration v1.0 §6)'
POSITIVE = %w[env_lock_claimed container_digest_claimed release_snapshot]
pos = reports.count { |r| POSITIVE.include?(r['capture_claim']) }
nonpos = N - pos
audit = (nonpos * 0.10).round
puts format('  positive gate            %4d  %s   %s', pos, pct(pos), ci(pos))
puts format('  non-positive (terminates)%4d  %s   %s', nonpos, pct(nonpos), ci(nonpos))
puts format('  audit at p=10%%           %4d  slots drawn from the non-positive mass', audit)
puts format('  Stage-2 code-check load  %4d  = %d positive + %d audit', pos + audit, pos, audit)

# --- 3. step-level axis analysis ----------------------------------------------------
section 'Step-level axes -- the statistically richest layer'
csteps = reports.flat_map { |r| r['steps'].select { |s| s['layer'] == 'C' } }
wsteps = reports.flat_map { |r| r['steps'].reject { |s| s['layer'] == 'C' } }
TOT = csteps.size
puts "computational steps: #{TOT}   wet-lab/out-of-scope steps: #{wsteps.size}"
puts "median computational steps per paper: #{reports.map { |r| r['counts']['S'] }.sort[N / 2]}"
puts
puts format('%-10s %8s %8s %8s   %-28s', 'axis', 'score 0', 'score 1', 'score 2', 'mean')
%w[data code version params].each do |ax|
  v = csteps.map { |s| s.dig('axes', ax).to_i }
  d = v.tally
  mean = v.sum.to_f / v.size
  puts format('%-10s %8s %8s %8s   %.2f  %s', ax,
              pct(d[0].to_i, TOT), pct(d[1].to_i, TOT), pct(d[2].to_i, TOT), mean, bar((mean * 100).round, 200))
end

section 'Which axis is binding? (the axis that caps each step)'
# A step's verdict follows the axis minimum; the binding axis is whichever attains it.
binding = Hash.new(0)
csteps.each do |s|
  ax = s['axes'] || {}
  vals = %w[data code version params].to_h { |k| [k, ax[k].to_i] }
  m = vals.values.min
  vals.select { |_, v| v == m }.each_key { |k| binding[k] += 1.0 / vals.count { |_, v| v == m } }
end
binding.sort_by { |_, v| -v }.each do |k, v|
  puts format('  %-10s %6.1f steps  %s  %s', k, v, pct(v.round, TOT), bar(v.round, TOT))
end
puts
puts "Ties are split evenly across the tied axes, so the column sums to #{TOT}."

# --- 4. verdicts --------------------------------------------------------------------
section 'Step verdicts (Stage-1 ceiling: R-star is unreachable by construction)'
vd = csteps.group_by { |s| s['verdict'] }.transform_values(&:size)
%w[R RI NI X].each do |v|
  k = vd[v].to_i
  puts format('  %-4s %6d  %s  %s%s', v, k, pct(k, TOT), bar(k, TOT),
              v == 'R' ? '   <- structurally 0 at Stage 1' : '')
end
puts
zero = reports.count { |r| r['counts']['n_RI'].to_i.zero? }
puts "papers where NO step even reaches RI: #{zero} of #{N} (#{pct(zero)}) #{ci(zero)}"

# --- 5. cross-tab -------------------------------------------------------------------
section 'Paper type x capture claim'
types = reports.group_by { |r| r['paper_type'] }.sort_by { |_, v| -v.size }
puts format('%-20s %5s  %s', 'paper_type', 'n', ORDER.map { |c| c[0, 8].rjust(9) }.join)
types.each do |t, rs|
  cells = ORDER.map { |c| rs.count { |r| r['capture_claim'] == c }.to_s.rjust(9) }.join
  puts format('%-20s %5d  %s', t, rs.size, cells)
end

# --- 6. gaps ------------------------------------------------------------------------
section 'Gap types (13-type dictionary), by how many papers exhibit each'
gaps = Hash.new(0)
# `type` is written as an integer by some assessors and as a string by others; normalise
# to the string form before tallying, or the same gap type lands in two buckets.
# A minority of reports write `gaps` as an object of named counts instead of the
# schema's array of typed instances. Those cannot be folded in without inventing a
# mapping from the named keys onto the numeric dictionary, so they are counted out
# loud and excluded from the tally rather than silently coerced.
malformed = reports.reject { |r| r['gaps'].is_a?(Array) }
tallyable = reports.select { |r| r['gaps'].is_a?(Array) }
tallyable.each { |r| r['gaps'].map { |g| g['type'].to_s }.reject(&:empty?).uniq.each { |t| gaps[t] += 1 } }
unless malformed.empty?
  puts "  NOTE: #{malformed.size} report(s) store gaps as an object of named counts, not the"
  puts "        schema's array of typed instances. Excluded from this tally; denominator is"
  puts "        #{tallyable.size}, not #{N}. Affected: #{malformed.map { |r| r.dig('canonical_id', 'value') }.join(', ')}"
  puts
end
gaps.sort_by { |t, v| [-v, t.to_i] }.each do |t, k|
  puts format('  type %-3s %4d papers  %s  %s', t, k, pct(k, tallyable.size), bar(k, tallyable.size))
end

# --- 7. coverage --------------------------------------------------------------------
section 'Computational coverage S/(S+W) per paper'
cov = reports.map { |r| c = r['counts']; s = c['S'].to_i; w = c['W'].to_i; (s + w).zero? ? 0.0 : s.to_f / (s + w) }.sort
q = ->(f) { cov[(f * (cov.size - 1)).round] }
puts format('  min %.0f%%   p25 %.0f%%   median %.0f%%   p75 %.0f%%   max %.0f%%',
            q.(0) * 100, q.(0.25) * 100, q.(0.5) * 100, q.(0.75) * 100, q.(1) * 100)
puts format('  papers that are entirely computational (W=0): %d (%s)',
            reports.count { |r| r['counts']['W'].to_i.zero? }, pct(reports.count { |r| r['counts']['W'].to_i.zero? }))

puts
puts "-- end. Every figure above is a Stage-1 ceiling. No R-star is assigned anywhere in this file."
