---
name: genomicschain_tier3
description: Tier-3 execution (local/thoa backends, two-axis verdict, cost estimation).
---

# genomicschain_tier3

Execute-only package for Tier-3 evaluation. Signing and recording live in `genomicschain_core`.

## Tools

- `gc_tier3_execute` — run the pipeline one or more times, compare against a target if one exists,
  return `verdict_result` + `jobspec_json` for submit
- `gc_tier3_estimate` — what a run would cost, before running it. Queries `thoa run --dry-run`
  (spends nothing) or falls back to rates measured 2026-08-17

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

## Tests

```bash
cd genomicschain_tier3
for t in tier3_executor_test tools_test thoa_backend_test estimate_test; do
  ruby -Ilib -Itest -I../genomicschain_core/lib test/$t.rb
done
```
