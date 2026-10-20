#!/bin/bash
# Regenerates the receipts in this directory and the T5 measurements.
# TEST-ONLY. Needs the RISC Zero toolchain (rzup: r0vm 3.0.6) and builds
# genomicschain_prov/zk_checkers. Sequential by design: CPU proving uses every
# core, so parallel runs would distort the timings. Receipts are not
# byte-reproducible (the STARK seal is randomised); image IDs and journals are.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
ws=$here/../../../zk_checkers
unset RISC0_DEV_MODE
(cd "$ws" && cargo build --release -p gc_zk_test_prove)
H=$ws/target/release/gc_zk_test_prove
tmp=$(mktemp -d)
cd "$here"
# S1_odd__altered_output.sfq3: the last size factor + 1 (Q32 unit), still within the checker's tolerance.
ruby -e 'b = File.binread(ARGV[0]); v = b[-8, 8].unpack1("Q<") + 1; File.binwrite(ARGV[1], b[0...-8] + [v].pack("Q<"))' \
  S1_odd__valid_exact.sfq3 S1_odd__altered_output.sfq3
IN=S1_odd.kmat
OUT=S1_odd__valid_exact.sfq3
p01() { "$H" --journal gc-zk-journal-0.1 --input "$IN" --output "$1" --receipt "$2" "${@:3}"; }
p02() { "$H" --journal gc-zk-journal-0.2 --key "$1" --input "$IN" --output "$2" --receipt "$3" "${@:4}"; }

: > t5_runs.jsonl
for i in 1 2 3; do
  p01 "$OUT" "$tmp/v01_$i.bin" | sed "s/^{/{\"run\":$i,/" >> t5_runs.jsonl
  p02 test_key.bin "$OUT" "$tmp/v02_$i.bin" | sed "s/^{/{\"run\":$i,/" >> t5_runs.jsonl
done
cp "$tmp/v01_1.bin" receipt_v01.bin
cp "$tmp/v02_1.bin" receipt_v02.bin
p02 test_key_b.bin "$OUT" receipt_v02_key_b.bin
p02 test_key.bin S1_odd__altered_output.sfq3 receipt_v02_altered_output.bin
p02 test_key.bin "$OUT" receipt_v02_composite.bin --kind composite
# A 0.1 receipt whose journal is 388 bytes too (64-byte claim): only the tag separates it from 0.2.
ruby make_seven_sample.rb S7_seven_samples.kmat S7__valid_exact.sfq3
"$H" --journal gc-zk-journal-0.1 --input S7_seven_samples.kmat --output S7__valid_exact.sfq3 \
  --receipt receipt_v01_64byte_output.bin
ruby expected_journal.rb test_key.bin "$IN" "$OUT" > expected_journal_v02.json
ruby expected_journal.rb test_key_b.bin "$IN" "$OUT" > expected_journal_v02_key_b.json
ruby expected_journal.rb test_key.bin "$IN" S1_odd__altered_output.sfq3 > expected_journal_v02_altered_output.json
rm -rf "$tmp"
