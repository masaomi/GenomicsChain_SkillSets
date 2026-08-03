---
name: genomicschain_tier1
description: Tier-1 readiness assessment assets and report schema v0.2.6 for GenomicsChain.
---

# genomicschain_tier1

Tier-1 package for the GenomicsChain SkillSet split (design v0.4.1).

## Scope

- `report_schema_v0_2_6.json` — canonical report.json with required `assessor_stack`
- Rubric / collection knowledge under `knowledge/`
- **Submit** is implemented in `genomicschain_core` as `gc_tier1_submit` (anchor profile only)

## Off-anchor workflow

Assess off-anchor (future `gc_tier1_assess`); submit on anchor only.

## report_content_hash

Server recomputes from submitted `report_json`, excluding only:

- `manifest.chain_record`
- `report_content_hash` itself

Pre-scoring `manifest.b1_manifest_hash` remains in the digest and is verified separately.
