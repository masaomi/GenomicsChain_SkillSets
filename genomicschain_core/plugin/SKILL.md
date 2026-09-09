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

## Deployment profiles

| Node | Packages | anchor_profile | Submit tools |
|------|----------|----------------|--------------|
| meeting.genomicschain.io (anchor) | core + tier1 + tier2 + tier3 | `true` | yes |
| Team workstation | core + tier1 | `false` | no |
| Tier-3 compute node | core + tier3 | `false` | no |

Example off-anchor config: `config/genomicschain_core.off-anchor.yml.example`

## Tests

```bash
RBENV_VERSION=3.4.10 ruby -Ilib .kairos/skillsets/genomicschain_core/test/tier3_submit_test.rb
RBENV_VERSION=3.4.10 ruby -Ilib .kairos/skillsets/genomicschain_core/test/tier1_submit_test.rb
RBENV_VERSION=3.4.10 ruby -Ilib .kairos/skillsets/genomicschain_core/test/tier2_submit_test.rb
RBENV_VERSION=3.4.10 ruby -Ilib .kairos/skillsets/genomicschain_core/test/topology_test.rb
```
