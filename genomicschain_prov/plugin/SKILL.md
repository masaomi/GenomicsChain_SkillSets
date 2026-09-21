---
name: genomicschain_prov
description: Write a pipeline's provenance bundle, or fill in one that was written thin, and read it back into the seven recorded conditions — grading how far a stranger holding only the bundle could rebuild from it. The bundle stays with the customer.
---

# genomicschain_prov

Service (2.5) **provenance anchoring**, the half that runs off the anchor. Prototype, v0.1.5
(writer 0.1.0, adapter 0.3.7, predicate 0.3.7) — design `docs/design/prov_anchoring_design_v0_1.md`
(frozen at v0.1.10), implementation units §9.

```
        a computation ─────────┐
        (shell / R / Python)   │  gc_prov_write --plan            (U1b)
                               ▼
customer's pipeline ──▶ bundle (bco.json / ro-crate-metadata.json)
        (Nextflow + nf-prov)   ▲
                               │  gc_prov_write --from-nextflow-run  (U1b, enricher)
                               │
                              ▼
        Adapters::Bco.parse  ──▶  NormalizedProvenance   (U1)
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
  on (name, version, locator, checksum, **stage**): a tool two steps declare is two items. A tool's or the
  runtime's SHA-256 comes from the GenomicsChain extension's `checksums[]` joined by locator, like inputs
  (round 3). A step that is not an object is a `FormatError`; error messages carry no bundle values. **Containers** = the
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
in words at the top of `predicate.rb` (a `latest`/`unknown`/`SNAPSHOT`-class word anywhere vetoes →
`floating`; the words carrying a digit are candidates, left to right: a constraint / wildcard / literal
`x` piece → `ranged`, release-shaped → `versioned`, else the next candidate — so `python3 3.11.4` is
versioned); a checksum field is `immutable`. An input's locator alone never grades above `versioned`
(the whole locator is a DOI) / `floating` (URL) / `local_path` — a hash-like or DOI-like substring is a
name, not a checksum (rounds 2–3). The runtime is digest-pinned only when its locator is an OCI image
reference carrying `@sha256:`, never a URL with that suffix. The environment can be rebuilt by
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

## The writer (U1b) — `gc_prov_write`, two faces of one tool

`bin/gc_prov_write.rb`. It lives in `bin/`, not `tools/`, because `Skillset#load!` requires every
`tools/*.rb` on every node and a CLI's option parsing would then run when the anchor starts
(design §7, review round 3). The logic is in `lib/` and a Tier-3 executor calls it directly.

**Producer** — `--plan plan.json`. The customer writes the stages; the tool collects what the
machine can measure. Nothing is tied to Nextflow: the adapter reads the format, so a shell, R or
Python computation reaches the same record.

```jsonc
{ "name": "two-step-arithmetic", "script": "run.sh",
  "runtime": { "engine": "sh", "version_command": "/bin/sh --version", "uri": "/bin/sh" },
  "params":  [{ "param": "divisor", "value": "2", "step": 2 }],
  "stages":  [{ "name": "add", "inputs": ["a.txt", "b.txt"], "outputs": ["sum.txt"],
                "tools": [{ "name": "add.sh", "version": "1.0.0", "uri": "tools/add.sh" }] }] }
```

**Enricher** — `--from-nextflow-run <launch_dir>`. nf-prov's bundle grades `absent` (above);
everything missing is still in the run directory.

| read from | written to | why there |
|---|---|---|
| `results/pipeline_info/*_versions.yml` | that stage's `prerequisite[]` | per-stage only: copied up to `software_prerequisites[]` it becomes a fallback covering every stage and the coverage in the claim stops meaning anything (round 2) |
| `work/<hash>/.command.run` (or a trace with a container column) + `docker image inspect` | the same entry's `uri`, as `ref@sha256:…` | the one form the container route reads as `immutable` (§5) |
| the framework jar, the script, the io files | extension `checksums[]`, keyed by the item's own locator; io SHA-1 in `sha1_checksum` | the exact-locator join is what the adapter reads for a tool, the runtime and the script alike (round 3) |

Collection rules, both faces: **never substitute** — a file that is not there, a Docker that is not
running, a jar that is not found each leave the field empty, add a note and let the grade fall;
**never run a plan's commands** unless `--run-version-commands` says so, because a plan is a data
file and a `version_command` in it is a command line. `docker image inspect` is a fixed argv and
stays on (`--no-docker` turns it off). Every note goes to stderr beside the grade, because the one
moment to see the gaps is before the bundle is signed.

Measured on the fixture, `--no-docker --container-digests <capture>`: `0/8` → `7/8` stages with
their own environment, container `absent` → `immutable`, runtime `versioned` → `immutable` with
`--nextflow-jar`. Overall stays `absent`: the fixture's `versions.yml` names no tool for MULTIQC and
that stage's work directory is gone, and the environment is the weakest stage. The rule working, not
a defect in it.

## Tests

```bash
ruby genomicschain_prov/test/adapter_bco_test.rb   # 44
ruby genomicschain_prov/test/predicate_test.rb     # 33
ruby genomicschain_prov/test/prov_write_test.rb    # 26 — 103 / 644 assertions in all
```

No gem beyond minitest, no network, no Docker (the writer's tests pass `--no-docker`'s equivalent
and a captured digest file). The predicate finds `PinStrength` through the sibling
`../genomicschain_tier2/lib` when it is not already on the load path. The producer's tests actually
run the two-step computation the principle demo shows — `(223 + 553) / 2 = 388` — so the checksums
in the bundle under test are checksums of files that exist.
