---
name: genomicschain_tier2
description: Tier-2 executed-R execution (local/thoa backends, comparator, gc_tier2_execute).
---

# genomicschain_tier2

Execute-only package for Tier-2 reproduced-R evaluation. Signing and recording live in `genomicschain_core`.

## Tool

- `gc_tier2_execute` — run pipeline, compare outputs, return `verdict_result` + `jobspec_json` for submit

## Dependencies

- `genomicschain_core` (Manifest, canonical JSON)

## Tests

```bash
RBENV_VERSION=3.4.10 ruby -Ilib .kairos/skillsets/genomicschain_tier2/test/tier2_executor_test.rb
RBENV_VERSION=3.4.10 ruby -Ilib .kairos/skillsets/genomicschain_tier2/test/tools_test.rb
RBENV_VERSION=3.4.10 ruby -Ilib .kairos/skillsets/genomicschain_tier2/test/thoa_backend_test.rb
```
