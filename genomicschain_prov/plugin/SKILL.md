---
name: genomicschain_prov
description: Read a pipeline's provenance bundle (BioCompute Object; Workflow Run RO-Crate in v0.2) into the seven recorded conditions and grade how far a stranger holding only the bundle could rebuild from it. Reads only — the bundle stays with the customer.
---

# genomicschain_prov

Service (2.5) **provenance anchoring**, the half that runs off the anchor. Prototype, v0.1.1
(adapter 0.3.0, predicate 0.3.0) — design `docs/design/prov_anchoring_design_v0_1.md`, implementation units §9.

```
customer's pipeline ──▶ bundle (bco.json / ro-crate-metadata.json)
                              │
                              ▼
        Adapters::Bco.parse  ──▶  NormalizedProvenance   (U1, this version)
                              │      seven conditions: inputs, code, tools, reference,
                              │      parameters, seed, runtime
                              ▼
        Predicate             ──▶  grade per category, overall = weakest   (U2)
                              │
                              ▼
        gc_prov_check / gc_submit_client --tier prov / gc_prov_verify        (U4, U5)
```

The bundle is the digest subject, verbatim. Normalisation is for grading only; the anchor
re-derives everything from the bundle and records identities and counts, never the bundle.

## What U0 measured (2026-09-20, nf-core/demo 1.2.0, nf-prov 1.7.0, Nextflow 26.04.6)

| condition | in nf-prov's BCO | in nf-prov's WRROC |
|---|---|---|
| input data | URIs only, 0/8 checksums | `File` nodes, 0/10 `sha256` |
| code | SCM extension: repository + commit (remote launch) | `codeRepository`, `version` = commit |
| tools | **Nextflow only** | 8 `SoftwareApplication`, 0/8 with a version |
| container | **no field** | 0 `ContainerImage` |
| parameters | 376, with values | 23 `PropertyValue` |
| seed | none | none |
| runtime | Nextflow 26.04.6 | `runtimePlatform` |

Graded as-is: workflow `immutable`, runtime `versioned`, software `absent`, container `absent`,
inputs `local_path` → **overall `absent`**. The missing tool versions, container names and image
digests all exist in the run directory (`*_versions.yml`, `.command.run`, `docker images --digests`);
`gc_prov_write --from-nextflow-run` (U1b) is the step that folds them into the bundle. The grade then
rises exactly as far as what was collected.

Fixture: `test/fixtures/nfcore_demo_1_2_0/` (verbatim bundles + the run artifacts the enricher reads).

## Rules the adapter applies (all re-derivable from the bundle alone)

- **Runtime** = the engine `execution_domain.script_driver` names; its version is the
  `software_prerequisites` entry of the same name. That entry is not counted as a tool.
- **Stage** = position after sorting the steps on `step_number` (step numbers 10/20/30 are stages
  1/2/3); every per-stage item carries that position. A duplicated or non-integer `step_number` is a
  `FormatError` (review round 2).
- **Software** = workflow-level `software_prerequisites` + every step's `prerequisite`, de-duplicated
  on (name, version, locator, **stage**): a tool two steps declare is two items. **Containers** = the
  software entries whose locator is an OCI image reference (`docker://…`, `…@sha256:…`, or
  `registry/repo:tag`).
- **Internal inputs** (design §13.4-3, revised after review round 2): an input is internal only when
  some step's `output_list` names its `uri` at an earlier position than every step's `input_list`
  that names it. `filename` labels are not matched; a published output carries no step and is not
  ordering evidence; an input no step reads, and an in-place overwrite (one step reads and writes the
  same locator), stay external and graded. Path prefixes are not evidence — they are the producer's
  choice. Counted separately (`inputs_internal`).
- **Reference genome** is a guess by file name and is reported as `reference_hint`, never mixed into
  the signed grade.
- **Producer** is nil unless the bundle states it (nf-prov does not).

## The predicate (U2) — `Predicate.grade(normalized)`

Images are graded by `GenomicsChainTier2::PinStrength.container`; a version string grades by the rule
in words at the top of `predicate.rb` (drop a leading tool-name token, read the first token, drop an
epoch; release-shaped → `versioned`, a constraint / wildcard / literal `x` token → `ranged`, a
`latest`/`unknown`/`SNAPSHOT`-class token anywhere → `floating`); a checksum field is `immutable`. An
input's locator alone never grades above `versioned` (DOI) / `floating` (URL) / `local_path` — a
hash-like substring in a locator is not a checksum (round 2). The environment can be rebuilt by
either of two routes — a container image or a package list — so **per stage** `environment` is the
stronger of the two routes over the items the stage declares **itself**; a stage that declares
nothing falls back to the workflow-level items, and the fallback is never added to a stage's own
declaration (round 2). The category is the **weakest stage** (round 1: one digest-pinned image must
not lift a pipeline whose other stages name nothing), and `absent` when there are no stages. A tool
naming both a version and an image is graded on both routes separately. The overall grade is the
weakest of environment / inputs / workflow / runtime. An empty category is `absent`, not skipped.
Symbolic refs are `floating`; tag-likeness, the reference-genome guess and the seed's presence are
reported beside the grades (`workflow_ref`, `reference`, `seed`), never inside them.
`pin_strength_version` is `PinStrength::RULE_VERSION` (the rule's own version, not the tier2 package's)
and is part of the signed procedure; `outputs_digest_rule` names how `outputs_digest` is derived. One
consequence stays open in design §10-9: a runtime known only by version holds the overall grade at
`versioned`. `counts` carries the numbers the record signs (stages total / with environment / with own
environment, per-level software and container counts, inputs with checksum / internal, outputs with
checksum, `outputs_digest` over the checksum column, params); `coverage` is the `own/total` the claim
carries. `items` carries each item's grade and reason for people.

## Tests

```bash
ruby genomicschain_prov/test/adapter_bco_test.rb
ruby genomicschain_prov/test/predicate_test.rb
```

No gem beyond minitest, no network. The predicate finds `PinStrength` through the sibling
`../genomicschain_tier2/lib` when it is not already on the load path.
