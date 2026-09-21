---
name: genomicschain_prov
description: Read a pipeline's provenance bundle (BioCompute Object; Workflow Run RO-Crate in v0.2) into the seven recorded conditions and grade how far a stranger holding only the bundle could rebuild from it. Reads only — the bundle stays with the customer.
---

# genomicschain_prov

Service (2.5) **provenance anchoring**, the half that runs off the anchor. Prototype, v0.1.0 —
design `docs/design/prov_anchoring_design_v0_1.md`, implementation units §9.

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
- **Software** = workflow-level `software_prerequisites` + every step's `prerequisite`, de-duplicated
  on (name, version, locator). **Containers** = the software entries whose locator is an OCI image
  reference (`docker://…`, `…@sha256:…`, or `registry/repo:tag`).
- **Internal inputs** (design §13.4-3, revised after review round 1): an input is internal only when
  the same locator appears as a step output or a published output in the bundle. Path prefixes are
  not evidence — they are the producer's choice. Counted separately (`inputs_internal`).
- **Reference genome** is a guess by file name and is reported as `reference_hint`, never mixed into
  the signed grade.
- **Producer** is nil unless the bundle states it (nf-prov does not).

## The predicate (U2) — `Predicate.grade(normalized)`

Images and locators are graded by `GenomicsChainTier2::PinStrength`; a version string grades by
shape (release-shaped → `versioned`, a constraint or wildcard → `ranged`, `latest`/`unknown` →
`floating`); a checksum is `immutable`. The environment can be rebuilt by either of two routes — a
container image or a package list — so **per stage** (own items plus inherited workflow-level items)
`environment` is the stronger of the two routes, and the category is the **weakest stage** (review
round 1, 2026-09-20: one digest-pinned image must not lift a pipeline whose other stages name
nothing). A tool naming both a version and an image is graded on both routes separately. The overall
grade is the weakest of environment / inputs / workflow / runtime. An empty category is `absent`, not
skipped. Symbolic refs are `floating`; tag-likeness and the reference-genome guess are reported
beside the grades (`workflow_ref`, `reference`), never inside them. `pin_strength_version` (= the
tier2 package version) is part of the signed procedure. One consequence stays open in design §10-9:
a runtime known only by version holds the overall grade at `versioned`. `counts` carries the numbers the record signs (stages, per-level
software and container counts, inputs with checksum / internal, outputs with checksum, `outputs_digest`
over the checksum column, params, seed). `items` carries each item's grade and reason for people.

## Tests

```bash
ruby genomicschain_prov/test/adapter_bco_test.rb
ruby genomicschain_prov/test/predicate_test.rb
```

No gem beyond minitest, no network. The predicate finds `PinStrength` through the sibling
`../genomicschain_tier2/lib` when it is not already on the load path.
