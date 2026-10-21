---
name: genomicschain_tier3
description: Tier-3 execution (local/thoa backends, two-axis verdict, cost estimation).
---

# genomicschain_tier3

Execution package for Tier-3 evaluation. Record 0.3 is signed by the caller and recorded by `genomicschain_core`;
Tier 3 v0.1 is signed here by `gc_tier3_attest` and recorded by `genomicschain_tier3_record`.

## Tools

- `gc_tier3_execute` — run the pipeline one or more times, compare against a target if one exists,
  return `verdict_result` + `jobspec_json` for submit
- `gc_tier3_estimate` — what a run would cost, before running it. Queries `thoa run --dry-run`
  (spends nothing) or falls back to rates measured 2026-08-17. Given `reachability_proof_id` (0.5.2,
  prov design v0.1.15 §6.3 (8)), it shows beside the estimate the observation's date and, per category,
  the places that did not answer (not_found, access_denied, error, not_attempted), read from this node's
  Synoptis registry; never a gate
- `gc_tier3_attest` (0.6.0, design `docs/design/tier3_design_v0_1.md`) — the Tier 3 executor's side.
  `declare` signs the plan, targets and binding list before building; `attempt` builds once in a fresh
  `work_root/attempt-<n>`, runs `gc_tier3_execute` once if it built, and compares the declared targets
  (relative paths that resolve inside that directory; route B one per bundle row) the run created or
  changed; `attest` signs every attempt row, failures included. Build steps and observes run as argv,
  never through a shell. `attempt` and `attest` hold the process record's lock and use the local copy
  only after it recomputes to the signed declaration (plan, pipeline, targets, the key's `key_id`); an
  interrupted attempt keeps its number and is closed by the next call. Keys never leave the tool;
  `thoa` is refused for salted and option-2 jobs; the process record (0700 / 0600) stays with the
  executor. A commitment key comes from `gc_prov_write --new-commitment-key`. The process record and
  both keys must be protected by the executor's own account: anyone who can write them with the
  executor's rights can also sign, so the tool's checks of the local copy do not stand against them.
  Keep one `work_root` per process record: attempt directories are numbered per record, so two records
  sharing a work_root cannot tell each other's directories apart

The record side — `tier3_declaration` / `tier3_attestation` 0.1, `gc_tier3_record_submit` — is the
package `genomicschain_tier3_record`. The anchor installs that package and never this one, which would
register the execution tools there.

A lone declaration reads 「宣言されたが attestation されていない」. Every reading carries both sentences:

> **ZK 証明（Tier 2.5 の任意の添付）:** 証明が示すのは、指定した段の計算が、記録された入力から正しく行われたことだけ。対象は指定した段だけで、入力が本当にその生データであるかは示さない。

> **Tier 3:** 保証するのは私たちの手順と記録まで。Tier 3 の記録は「その日、宣言どおりの結果になった」という日付つきの観察であり、将来も再現することの約束ではない。

## Two verdict axes (record 0.3)

"Did it run" and "did it match" are separate questions and are reported separately.

| axis | values |
|---|---|
| `execution_verdict` | `completed` / `env_failed` / `data_blocked` / `outputs_unusable` |
| `comparison_verdict` | `no_target_declared` / `match_exact` / `match_normalized` / `mismatch` / `not_attempted` |

`no_target_declared` is the **common** outcome: in the 2026-08-14 survey of the five papers passing
the Tier-1 gate, none published a checksum or nominated an artifact to compare against. It is a
complete result, not an inconclusive one.

Two further fields keep a certificate honest about what actually ran:

- `environment_provenance` — `declared_container` / `declared_lock` / `declared_tools` /
  `authored_by_operator` / `none`. The operator-authored case cannot be derived and must be passed
  explicitly; a certificate must not present it as the environment the paper declared.
- `inputs_provenance` — `public_accession` / `archive_doi` / `controlled_access` /
  `operator_supplied` / `unknown`. Never guessed.

## Repeated runs

`runs` is the operator's choice because cost scales with it directly. Above one run, supply
`run_workdirs` — one distinct directory per run, since a repeat into a populated directory would
re-hash the previous run's outputs and report agreement that never happened.

| runs | what the record can state |
|---|---|
| 1 | the pipeline ran to completion |
| 2 | ...and both runs produced the same result |
| 3+ | ...and all N runs did |

The record states the **number of runs**, never "stable" or "deterministic": a tool that picks one
of two answers at random agrees with itself half the time at N=2, and that judgement belongs to the
reader.

Known limitation (measured 2026-08-14): run-to-run comparison uses `exact_sha256`, which reports
disagreement when byte-identical content sits inside an archive whose header carries a timestamp —
running fastqc twice on one host gave 24/24 identical extracted files and two different `.zip`
digests. A `normalized_tree` comparator that unpacks containers first is the follow-up; it is not
implemented. Read `first_divergence` before concluding a pipeline is nondeterministic.

## Dependencies

- `genomicschain_core` (Manifest, canonical JSON, schema)
- `genomicschain_prov` (gc-commitment-0.1, the `outputs_digest` rule, the Tier-2.5 record)
- `genomicschain_tier3_record` (the record names the executor signs against)

## Tests

```bash
cd genomicschain_tier3
for t in tier3_executor_test tools_test thoa_backend_test estimate_test; do
  ruby -Ilib -Itest -I../genomicschain_core/lib test/$t.rb
done
```
