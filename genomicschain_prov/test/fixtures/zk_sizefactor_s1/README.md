# zk_sizefactor_s1 — one real RISC Zero receipt and the files it binds

Copied verbatim on 2026-10-12 from KairosChain_2026 (commit 9f017e7, directory
`log/zk_demo_sizefactor_20260929/`, which is git-ignored there):

| file here | source | sha256 |
|---|---|---|
| `receipt.succinct.bin` | `03_proofs/out/claude_01/S1_odd__valid_exact.succinct.bin` | `d0237407…2dc79988` |
| `image_id.txt` | `03_proofs/out/claude_01/image_id.txt` (checker `claude_01`) | — |
| `S1_odd.kmat` | `00_prereg/inputs/S1_odd.kmat` (synthetic 132-byte count matrix) | `5cb5cfc3…4a86aede3` |
| `S1_odd__valid_exact.sfq3` | `00_prereg/claims/S1_odd__valid_exact.sfq3` (claimed size factors) | `7d8c0532…ec9b4515` |

The receipt is a succinct receipt (223,746 bytes) produced by risc0-zkvm 3.0.6
on 2026-09-30 for instance `S1_odd__valid_exact` (pre-registered in
`00_prereg/instances.csv`, expected ACCEPT). Its journal follows the
`gc-zk-journal-0.1` convention of design v0.1.12 §6.1: the pair
(sha256 of `S1_odd.kmat`, the bytes of `S1_odd__valid_exact.sfq3`).

What the receipt shows: the checker program named by `image_id.txt` accepted
these size factors for this matrix. Nothing about where the matrix came from —
it is synthetic test data.
