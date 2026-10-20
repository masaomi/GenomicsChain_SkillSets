# Writes a synthetic 5-gene x 7-sample KMAT and its exact SFQ3 claim. The claim
# is 8 + 7*8 = 64 bytes, so a gc-zk-journal-0.1 receipt over it has a journal
# of (32 + 1 + 64) words = 388 bytes — the same length as gc-zk-journal-0.2.
# Only the tag separates the two (design §6.2; review r2 N5). Deterministic.
#
# Size factors: DESeq2 median-of-ratios, computed as the claude_01 checker
# does (natural log, per-gene mean over samples, median per sample), encoded
# as u64 fixed point with 32 fractional bits.
# Usage: ruby make_seven_sample.rb <kmat out> <sfq3 out>
counts = [
  [120, 98, 143, 110, 87, 130, 101],
  [15, 22, 18, 11, 19, 25, 14],
  [560, 610, 498, 702, 533, 590, 640],
  [33, 41, 29, 38, 44, 31, 36],
  [7, 9, 6, 12, 8, 10, 5]
]
g = counts.size
n = counts.first.size
kmat = 'KMAT'.b + [g, n].pack('L<L<') + counts.flatten.pack('Q<*')
logs = counts.map { |row| row.map { |v| Math.log(v) } }
means = logs.map { |row| row.sum / n }
factors = (0...n).map do |j|
  r = logs.each_with_index.map { |row, i| row[j] - means[i] }.sort
  med = g.odd? ? r[g / 2] : (r[g / 2 - 1] + r[g / 2]) * 0.5
  (Math.exp(med) * 2**32).round
end
sfq3 = 'SFQ3'.b + [n].pack('L<') + factors.pack('Q<*')
abort "claim is #{sfq3.bytesize} bytes, want 64" unless sfq3.bytesize == 64
File.binwrite(ARGV[0], kmat)
File.binwrite(ARGV[1], sfq3)
