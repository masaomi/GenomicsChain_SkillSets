# Fixture: nf-core/demo 1.2.0 run with nf-prov 1.7.0 (U0, 2026-09-20)

Verbatim provenance bundles from one real Nextflow run, captured for design v0.1 §9 U0
(`docs/design/prov_anchoring_design_v0_1.md`). Nothing in these files was edited after the run.

## How they were produced

```
conda create -n nextflow -c conda-forge -c bioconda nextflow     # Nextflow 26.04.6 build 12646
export NXF_HOME=/tmp/gc_u0_demo/.nextflow NXF_WORK=/tmp/gc_u0_demo/work
nextflow run nf-core/demo -profile test,docker --outdir /tmp/gc_u0_demo/results -c prov.config
```

| item | value |
|---|---|
| pipeline | nf-core/demo 1.2.0, `master` = commit `555d145b9e701c012f53996a2f17efb2daff5fe7` |
| plugin | nf-prov 1.7.0 (registry.nextflow.io, published 2026-01-05, requires Nextflow >= 25.10.0) |
| runtime | Nextflow 26.04.6; Docker Desktop 20.10.23 on macOS aarch64 (amd64 images under emulation) |
| run | 2026-09-20 18:02–18:04 CEST, 8 tasks completed, 0 failed, 0 cached |
| launch dir | `/tmp/gc_u0_demo` — absolute paths inside the bundles point there |

## Files

| file | bytes | sha256 (file) | note |
|---|---|---|---|
| `bco.json` | 88,536 | `16865d01c3293cd84876d4f372ff8900339f7af6a80fd820cd727cfd985132e1` | BCO, `spec_version` https://w3id.org/ieee/ieee-2791-schema/2791object.json. Canonical-JSON sha256 (= `bundle_digest`, design §6): `9bd92601c9c6f362a526018751b213041c710b272d40c9dad2d625216dfa5e95` |
| `ro-crate-metadata.json` | 98,789 | `a56f9ca50bb53f0b6b20e7d45364a76656b6f3930068b2b45c12f7a6fcb00bb1` | Workflow Run RO-Crate, profiles `wfrun/{process,workflow,provenance}/0.1`. Canonical-JSON sha256: `c35b53d366b3deeb560d50818c97fe0750c4176d3e544cf8c24607872de92962` |
| `nf_core_demo_software_mqc_versions.yml` | 143 | — | nf-core's per-module tool versions (cowpy 1.1.5, fastqc 0.12.1, seqtk 1.4-r122). Not in either bundle |
| `execution_trace.txt` | 1,189 | — | Nextflow trace, default 14 columns (no `container` column) |
| `command_run_fastqc.sh` | — | — | `work/7a/51f65b…/.command.run` of one FASTQC task; its `docker run` line names the image `quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0` |
| `container_digests.txt` | — | — | `docker images --digests` for the 4 images the run pulled |
| `prov.config` | 396 | — | the `-c` config that enabled nf-prov (bco + wrroc) |

## What the bundles do and do not carry (measured)

- BCO `io_domain`: 8 inputs, 16 outputs, **0 checksums** on either side; inputs are 5 https URLs, 2 `work/tmp/` relative paths, 1 `file://` under the outdir.
- BCO `execution_domain.software_prerequisites`: **one entry, Nextflow 26.04.6** — no per-task tools, no containers.
- BCO `extension_domain`: SCM extension present (repository, commit, path) because the pipeline was launched from its remote.
- BCO `parametric_domain`: 376 params with values, mostly defaults and iGenomes entries; no seed-like param.
- WRROC: 129 nodes; 8 `SoftwareApplication` **without versions**; 10 `File` **without `sha256`**; 0 `ContainerImage`.

Design v0.1 §5 grades for `bco.json` as-is (predicate 0.2.0): workflow `immutable`, runtime `versioned`, software `absent`,
container `absent`, environment `absent` (0/8 stages name anything), inputs `local_path` (8 inputs, none shown as produced
by the run; 3 local paths, 5 https) → overall **`absent`**. The enrichment path is in design §13.
