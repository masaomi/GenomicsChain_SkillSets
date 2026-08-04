---
name: genomicschain_tier1
description: Tier-1 readiness assessment assets and report schema v0.2.6 for GenomicsChain.
---

# genomicschain_tier1

Tier-1 package for the GenomicsChain SkillSet split (design v0.4.1).

## Scope

- `gc_tier1_assess` — assessment tool, registered on every node
- `report_schema_v0_2_6.json` — canonical report.json with required `assessor_stack`
- Rubric / collection knowledge under `knowledge/`
- **Submit** is implemented in `genomicschain_core` as `gc_tier1_submit` (anchor profile only)

## Off-anchor workflow

Assess off-anchor with `gc_tier1_assess`; submit on anchor only.

Spec: `doc/gc_tier1_assess_spec_v0_2.md` (`..._v0_1.md` is superseded).

### gc_tier1_assess

One LLM call, four phases, none of the arithmetic authored by the LLM:

| Phase | Produces |
|---|---|
| 1 pre-commit | `rubric_hash`, `assessed_at`, `b1_manifest_hash` — fixed **before** scoring |
| 2 score | `steps`, `gaps`, `liveness`, `capture_claim` — the assessor's only output |
| 3 derive | stage guards, `counts`, `headline`, `levers`, `stage2_candidate` |
| 4 validate | schema, b1 recompute, 2 MiB ceiling (`gc_tier1_submit`'s limit) |

Boundaries that hold by construction, not by policy:

- **No fetching.** The caller supplies resolved `sources`.
- **No signing.** `human_signoff.signed` is always `false`; R5 needs a human.
- **No R★ at stage 1.** The version axis is capped at 1, because a lockfile or
  container is only a *claim* until the code is read.
- **Stage 2 needs code.** At least one `repo_file`/`repo_tree` source plus the prior
  stage-1 report, whose `b1_manifest_hash` becomes `manifest.supersedes`.

`has_validated_env_capture` means "≥1 step reached R★", **not** "a lock exists" — a
genuine lock with every DB pinned in prose only reaches zero R★ (the aMeta shape).

Not implemented: the collection protocol's §4b committed-secret side-check, which is
mandatory for every stage-2 paper. **A stage-2 report from this tool is therefore not
protocol-complete** until the caller performs 4b separately.

## Tests

```bash
RBENV_VERSION=3.4.10 ruby .kairos/skillsets/genomicschain_tier1/test/assess_test.rb
```

## report_content_hash

Server recomputes from submitted `report_json`, excluding only:

- `manifest.chain_record`
- `report_content_hash` itself

Pre-scoring `manifest.b1_manifest_hash` remains in the digest and is verified separately.
