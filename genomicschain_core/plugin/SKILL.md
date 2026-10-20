---
name: genomicschain_core
description: GenomicsChain shared substrate — Synoptis-only SubmitCore, TipSource, anchor-profile submit tools (design v0.4.1).
---

# genomicschain_core

Shared package for the GenomicsChain SkillSet split (v0.4.1).

## Tools (anchor profile only — §3.2)

Registered **only** when `genomicschain.anchor_profile: true`:

- `gc_tier1_submit` — Tier-1 report → Synoptis proof
- `gc_tier2_submit` — Tier-2 code-reading adjudication → Synoptis proof (self_reported proposal)
- `gc_tier3_submit` — Tier-3 verdict → Synoptis proof (no operational chain write)

Off-anchor nodes (team workstation, genomicschain.ch app tier) use an empty tool surface from this package.

Since 0.6.0 any SkillSet may list `anchor_profile_tool_classes` in its own `skillset.json`; `genomicschain_prov` uses this for `gc_prov_submit`. 0.6.0 also lets a verdict spec name its proof lifetime (`proof_ttl`), passed through `SubmitCore.store_proof!` and `SynoptisAttestor#issue(ttl:)`; specs without one keep the engine default, so Tier-1/2/3 proofs are unchanged.

0.6.1 adds `resources` to the BCO extension schema (`schemas/bco_extension_genomicschain_v0_1.json`): the machine and each stage's requested and observed values, which `genomicschain_prov` 0.4.0 writes and grades (design v0.1.14 §6.2). Nothing else in core changes.

0.6.2 (prov design v0.1.15 §6.3 (7), (11)): `SubmitCore::SUBMISSION_KEYED` lists the record types whose idempotency key is `sha256(submission_key)` — `prov_attestation` and now `prov_reachability`; every other type keeps its derivation, pinned before the change in `test/fixtures/idempotency_keys_r0.json`. Adds `Backing` (the label vocabulary `gc-backing-0.1`) and `ProvProofRef.for(proof_id)` (how a record points at a prov record without naming it).

0.6.3 (prov design v0.1.16 §6.1, §9): the BCO extension schema's `checksums[]` items carry exactly one of `sha256` or `hmac_sha256` (the salted fingerprint `gc-commitment-0.1`), the extension may carry `commitment` `{rule, key_id}`, and a ZK receipt's `journal` may be `gc-zk-journal-0.2`. The schema URL stays `v0_1` (not yet published). Whether a bundle may use them is the prov adapter's rule, not the schema's. The anchor example config documents `genomicschain.zk.confidential_receipts` (default `false`), read only by `gc_prov_submit`.

## Deployment profiles

| Node | Packages | anchor_profile | Submit tools |
|------|----------|----------------|--------------|
| meeting.genomicschain.io (anchor) | core + tier1 + tier2 + tier3 + prov | `true` | yes (prov adds `gc_prov_submit`, `gc_prov_reach`) |
| Team workstation | core + tier1 | `false` | no |
| Tier-3 compute node | core + tier3 | `false` | no |
| Customer workstation (provenance) | core + tier2 + prov | `false` | no (`gc_prov_check`, the submit client) |
| Verifier | mmp + synoptis + core + tier2 + prov | `false` | no (`gc_prov_verify`) |

Example off-anchor config: `config/genomicschain_core.off-anchor.yml.example`

## Tests

```bash
RBENV_VERSION=3.4.10 ruby -Ilib .kairos/skillsets/genomicschain_core/test/tier3_submit_test.rb
RBENV_VERSION=3.4.10 ruby -Ilib .kairos/skillsets/genomicschain_core/test/tier1_submit_test.rb
RBENV_VERSION=3.4.10 ruby -Ilib .kairos/skillsets/genomicschain_core/test/tier2_submit_test.rb
RBENV_VERSION=3.4.10 ruby -Ilib .kairos/skillsets/genomicschain_core/test/topology_test.rb
```
