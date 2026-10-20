# zk_sizefactor_s1_v02 — real gc-zk-journal-0.2 receipts for tests (TEST-ONLY)

Made on 2026-10-19 for design v0.1.16 (`docs/design/prov_v0_1_16_zk_confidentiality_draft.md`
§6.2, §10 T2/T4/T5) with the test-only host in `genomicschain_prov/zk_checkers/`. Nothing
here is customer data: the inputs are the synthetic S1 example of `../zk_sizefactor_s1/`.

**The keys are test keys, not secrets.** `test_key.bin` is the bytes 0x00..0x1f and
`test_key_b.bin` the bytes 0x20..0x3f. A real `gc-commitment-0.1` key is 32 bytes from a
cryptographic random source (design §5). Never use these outside tests.

## Files

| file | what |
|---|---|
| `S1_odd.kmat`, `S1_odd__valid_exact.sfq3` | copies of `../zk_sizefactor_s1/` (132 and 32 bytes; sha256 `5cb5cfc3…4a86aede3`, `7d8c0532…ec9b4515`) |
| `S1_odd__altered_output.sfq3` | the claim with its last size factor + 1 (one Q32 unit; still within the checker's tolerance, so the guest accepts it) |
| `test_key.bin`, `test_key_b.bin` | test keys A and B (above) |
| `image_id_v02.txt` | image ID of `zk_checkers/methods/guest_v02` (checker_v02) |
| `image_id_v01.txt` | image ID of `zk_checkers/methods/guest_v01` (claude_01 rebuilt here; see the note on image IDs) |
| `receipt_v02.bin` | succinct, 0.2, key A, valid claim |
| `receipt_v02_key_b.bin` | succinct, 0.2, key B, valid claim |
| `receipt_v02_altered_output.bin` | succinct, 0.2, key A, altered claim (for T4: a bundle declaring the valid claim must fail ④) |
| `receipt_v02_composite.bin` | **composite**, 0.2, key A, valid claim — must be refused (`receipt_not_succinct`) |
| `receipt_v01.bin` | succinct, 0.1, valid claim (same guest as the 0.1 fixture, this build's image ID) |
| `receipt_v01_64byte_output.bin` + `S7_seven_samples.kmat`, `S7__valid_exact.sfq3` | succinct, 0.1, on a 5×7 matrix: the claim is 64 bytes, so the 0.1 journal is 388 bytes — the 0.2 length. Only the tag separates them (review r2 N5) |
| `expected_journal_v02*.json` | key_id, C(input), C(output) computed **independently in Ruby** by `expected_journal.rb` (OpenSSL), for the three 0.2 receipts |
| `t5_runs.jsonl` | T5 raw measurements (below) |
| `regenerate.sh`, `make_seven_sample.rb`, `expected_journal.rb` | how everything here was made |

All three 0.2 receipts verified with `gc_zk_verify 0.2.0 --journal gc-zk-journal-0.2`, and the
three values it reported equal the Ruby values (asserted by `zk_verifier/tests/v02.rs`).

## Versions

risc0-zkvm 3.0.6, risc0-build 3.0.6, r0vm 3.0.6, cargo-risczero 3.0.6, RISC Zero guest rust
1.97.0 (rzup), host rust 1.98.1. Guests: sha2 =0.10.9 (plain RustCrypto, as the demo checker
claude_01 used — not the RISC Zero accelerated fork), hmac =0.12.1 (0.2 only). Lock files:
`zk_checkers/Cargo.lock`, `zk_checkers/methods/guest_v0{1,2}/Cargo.lock`.

**Image IDs depend on where the guest is built.** The 0.1 guest here is byte-for-byte the
source of the `../zk_sizefactor_s1/` checker (claude_01), yet its image ID is `3533a22e…`, not
`189ece21…`: the ELF embeds source paths (panic locations). Rebuilding in another checkout
changes both image IDs; the receipts here stay valid under the IDs in these files. A
path-independent build (risc0's docker build) was not used.

## Regenerate

```
cd genomicschain_prov/test/fixtures/zk_sizefactor_s1_v02
PATH=$HOME/.cargo/bin:$HOME/.risc0/bin:$PATH bash regenerate.sh
```

Receipts are not byte-reproducible (the seal is randomised); image IDs (same checkout path) and
journals are. Regenerating rewrites `t5_runs.jsonl`.

## T5 — proving cost, 0.1 vs 0.2 (raw numbers, no pass/fail)

Apple M2 Max, 12 cores, CPU only, succinct receipts (`ProverOpts::succinct()`), same S1 example,
key A, run sequentially 2026-10-19, three times each.

| convention | user cycles | total cycles (segments) | prove s (3 runs) | receipt bytes | journal bytes |
|---|---|---|---|---|---|
| gc-zk-journal-0.1 | 110,873 ×3 | 262,144 (1) ×3 | 26.91, 26.71, 26.57 | 223,746 ×3 | 260 |
| gc-zk-journal-0.2 | 166,934 ×3 | 262,144 (1) ×3 | 26.94, 27.84, 27.48 | 224,002 ×3 | 388 |

User cycles rise by 56,061 (+50.6 %) — the HMACs and key_id in software SHA-256. At this size
both fit in one 2^18-cycle segment, so the proved trace (total cycles) and the prove time are
the same within run-to-run noise. Key B gave 166,909 user cycles (key-dependent by a few
cycles). The 0.1 user-cycle count equals the 2026-09-30 demo's (110,873).

## T2 — journal content (run by `zk_verifier/tests/t2_journal_content.rs`)

The real 0.2 journal is 388 bytes and starts with the tag 0x475A4B32 (little-endian). Searched
raw and as one-byte-per-u32-word (risc0 serde) expansion:

| probe | 0.2 journal | 0.1 journal (control) |
|---|---|---|
| output bytes (32) | not found, either form | found, word-expanded form |
| SHA-256(input) | not found, either form | found, word-expanded form |
| SHA-256(output) | not found | not found (0.1 carries the output itself, not its digest) |
| input bytes (132) | not found | not found (0.1 carries only the input digest) |
