---
name: genomicschain_tier3_record
description: Tier-3 record side on the anchor — tier3_declaration / tier3_attestation 0.1 and gc_tier3_record_submit.
---

# genomicschain_tier3_record

The record side of Tier 3 v0.1 (design `docs/design/tier3_design_v0_1.md`). The anchor installs this
package with `genomicschain_core` and `genomicschain_prov`, and never `genomicschain_tier3`: loading
tier3 would register the execution tools on the anchor. The executor side, `gc_tier3_attest`, lives in
`genomicschain_tier3`, which depends on this package for the record names.

## Tools

- `gc_tier3_record_submit` (anchor profile only) — records the executor's signed `tier3_declaration`
  and `tier3_attestation` (record_version 0.1) as Synoptis proofs, 100-year TTL. Checks form, route B's
  `route_ref` and `outputs_digest` recount, the option-2 salt rule, human data, refused sources, the
  same signing key and binding list, one attestation per declaration and `1 ≤ attempts ≤
  attempts_max`. Only records this tool wrote count in those lookups, and route B resolves only a
  Tier-2.5 record gc_prov_submit wrote. Receives no key and no output
  file; refusals name the condition, never a proof_id

A lone declaration reads 「宣言されたが attestation されていない」. Every reading (`Wording.read`)
carries both sentences:

> **ZK 証明（Tier 2.5 の任意の添付）:** 証明が示すのは、指定した段の計算が、記録された入力から正しく行われたことだけ。対象は指定した段だけで、入力が本当にその生データであるかは示さない。

> **Tier 3:** 保証するのは私たちの手順と記録まで。Tier 3 の記録は「その日、宣言どおりの結果になった」という日付つきの観察であり、将来も再現することの約束ではない。

## Dependencies

- `genomicschain_core` (SubmitCore, canonical JSON, Backing)
- `genomicschain_prov` (the `outputs_digest` rule, the Tier-2.5 record)

## Tests

```bash
cd genomicschain_tier3_record   # T = the kairos-chain gem's templates/skillsets
for t in declaration_record_test attestation_record_test wording_test registration_test install_script_test; do
  ruby -Ilib -Itest -I../genomicschain_core/lib -I../genomicschain_tier2/lib -I../genomicschain_prov/lib \
       -I$T/synoptis/lib -I$T/mmp/lib test/$t.rb
done
```
