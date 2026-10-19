---
name: genomicschain_prov
description: Write a pipeline's provenance bundle, or fill in one that was written thin, and read it back into the seven recorded conditions — grading how far a stranger holding only the bundle could rebuild from it. The bundle stays with the customer.
---

# genomicschain_prov

Service (2.5) **provenance anchoring**. Prototype, v0.5.0 (writer 0.3.0, adapter 0.4.0, predicate
0.3.7, resources rule gc-resources-0.1, record_version 0.4, admission rule prov-admission-0.2;
reachability rule gc-reachability-0.1, record prov_reachability 0.1) — design
`docs/design/prov_anchoring_design_v0_1.md` (frozen at v0.1.10, now v0.1.14 with four individual
revisions; v0.1.15 in `docs/design/prov_v0_1_15_reachability_draft.md`), implementation units §9:
U0–U5 done; v0.1.14 (computing resources) implemented; v0.1.15 (reachability) R0–R4 implemented.

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

## The record (U3–U5, design §6–§8, §6.1)

| tool | where it runs | what it does |
|---|---|---|
| `bin/gc_prov_check.rb BUNDLE [--items] [--zk-receipt F] [--json]` | customer, no network | digest, grade with reasons, the params to sign, and whether the anchor would issue a record; exit 0 / 1 / 2 |
| `scripts/gc_submit_client.rb --tier prov --bundle F [--zk-receipt F]` | customer → anchor `/mcp` | signs the params `Identity.derive` gives and sends the bundle as the exact text checked |
| `scripts/gc_submit_client.rb --tier prov-reach --bundle F --prov-proof-id ID` | customer → anchor `/mcp` | signs `Reach::SignedParams` (a new `observation_nonce` every run); the proof_id goes beside it, unsigned |
| `gc_prov_reach` (MCP, anchor profile only) | anchor | the reachability observation below, recorded over the bundle's prov record; `dry_run` asks nothing |
| `gc_prov_submit` (MCP, anchor profile only) | anchor | Gate A (2 MB, depth 32) → ZK declarations → receipt checks ①–④ → Synoptis proof, 100-year TTL. Any grade is recorded as computed (no grade gate since v0.1.13) |
| `GET /place/web/prov/proof/<id>` (place extension) | anchor, no authentication | the envelope fields + manifest + revoked; prov records and their reachability observations only; 404 otherwise |
| `bin/gc_prov_verify.rb BUNDLE --proof-id ID [--anchor-pubkey PEM] [--submitter-pubkey K] [--zk-receipt F] [--prov-proof-id ID]` | anyone | CONFIRMED / THE ANCHOR SAYS / NOT CHECKED, then the statements; exit 0 / 1 / 2. The verifier is chosen by the record's type: an observation is read by `ReachVerifier` (counts per category and result with their meanings, never summed; `--prov-proof-id` checks which prov record it is laid over) |
| `zk_verifier/` → `gc_zk_verify` (Rust, risc0-zkvm =3.0.6, Cargo.lock) | anchor (required for receipts), optional elsewhere | `gc_zk_verify <image_id_hex> < receipt`: verifies one receipt, prints one JSON line with the journal's input digest and output sha256. Build: `cargo build --release --locked`; point `GC_ZK_VERIFY_BIN` at it |

The ZK receipt checks: ① the bytes are the receipt the bundle declares; ② `Receipt::verify` against
the declared image ID; ③ the journal's input digest is the step's recorded input SHA-256; ④ the
SHA-256 of the journal's output bytes is the step's recorded output SHA-256 (journal convention
`gc-zk-journal-0.1`). The record carries the receipt's identity only, never its bytes or journal.

The writer adds `platform` (CPU architecture, OS name and release — never the host name; by default
for `--plan`, only with `--platform-of-this-machine` for a Nextflow run) and `zk_receipts[]`
(`--zk-receipts FILE` or a plan's `zk_receipts`). Extension schema:
`genomicschain_core/schemas/bco_extension_genomicschain_v0_1.json` (not yet published at its URL).

When installing on an anchor, install from a copy without `zk_verifier/target/` (`skillset install`
copies the whole directory, and a release build tree is ~330 MB).

## Reachability observation (v0.1.15, design §6.3)

The anchor asks the places a bundle names for its environment whether they still answer, and records
the dated counts as a `prov_reachability` record laid over the bundle's prov record (which must exist,
be of the same bundle and not be revoked). Nothing is fetched: a manifest's head, a git ref
advertisement, a URL's head, a conda release's status.

```
bundle → items per category (workflow_repository → workflow_commit → runtime → containers → software)
       → each distinct locator once → budget (200; per host 100 public / 20 other; 3 failures stop a host; 60 s)
       → gate (https, port 443, no IP literal, every A/AAAA outside IANA special ranges, pinned, SNI, no proxy)
       → one bucket: digest_match | exists | access_denied | not_found | error | not_attempted | not_checkable
```

`digest_match` and `exists` are split by the class of the host the bundle wrote (`public_registry`:
the 12 hosts in `Reach::PUBLIC_REGISTRY_HOSTS`, where `docker.io` is listed as a second name for
Docker Hub; otherwise `other_host`). The record holds counts,
`observed_at`, `same_signer`, `prov_proof_ref` (SHA-256 of the prov proof_id) and five `not_checked`
items; per-item results go to the submitter in the response only. The anchor's own names and addresses
and the operator's denylist come from `genomicschain_core.yml` under `genomicschain.reach`
(`own_names`, `own_addresses`, `denylist`). Code: `lib/genomicschain_prov/reach/` (no `Net::HTTP`; the
HTTP/1.1 reader caps the head at 64 KiB and 100 lines and counts bodies after decompression).

Named and not handled: budgets across observations (none); anchor-wide limits are in process memory
(a restart forgets the day's counts); a commit not at a ref tip reads `not_checkable` (the nf-core
fixture's own commit does, 2026-10-18); a nameserver timeout reads like a name that does not resolve;
a resend of a submission still being observed waits for it (up to 60 s) outside the anchor-wide limits,
and the wait is per attempt: when the observation's record fails, the nonce is released and the next
waiting resend observes again (review r2).

Install core 0.6.2 before prov 0.5.0. The gem loads `tools/*.rb` on every node, and on core 0.6.1 this
tool's require of `genomicschain_core/backing` fails with a `LoadError`, which the gem's loader does not
rescue: no tool on the node registers and the HTTP server does not start (review r1; reproduced in
review r2). An `own_addresses` or `denylist` entry that is not an IP address or CIDR stops the tool
before anything is observed. `own_names` and `own_addresses` are empty by default, and then the gate
does not refuse the anchor's own public names and addresses (the IANA special-purpose ranges, private
and loopback among them, are refused always): set both on a production anchor (operator 2026-10-19).

## Computing resources (v0.1.14, design §6.2)

Tier 3 needs to know what each stage asked for and used, and which GPU the run had, before it can
pick a machine to rebuild on. The bundle's extension gets `resources`: the `machine` and per-stage
`steps[]`. Their grade is separate and never enters `grade_overall`.

```
absent   nothing readable
partial  something, but not every stage
steps    every stage has requested (cpus + memory_bytes) or observed (peak_memory_bytes + realtime_seconds)
full     every stage has both, and the machine has cpu_model, logical_cores, memory_total_bytes and a GPU answer
```

| where the values come from | `gc_prov_write` | what it gives |
|---|---|---|
| this machine | `--plan` by default (`--no-machine` to leave out); a Nextflow run only with `--machine-of-this-machine` | CPU model, logical cores, memory, free disk, GPUs via `nvidia-smi` / `rocm-smi` / `system_profiler`. Never a host name, user, serial, UUID, MAC or PCI id. A probe command whose own process has not exited after 10 s is killed (`result: timeout`). `gpus` is written when some probe answered; a probe that cannot read a GPU it reported counts as failed and contributes none (`gpus: []` = looked, none, for the vendors in `gpu_vendors_probed`). On macOS, a plan whose stages used containers (a tool's or the runtime's `image`, or an OCI image `uri`; a Singularity `.sif` or `https://` image is not recognised) gets no GPU lines, and a Nextflow run enriched on macOS never does (nf-prov names no container even when tasks ran in one). Probe output in a shape this code cannot read is `failed`. A process SIGKILL cannot end (a wedged driver) is still waited for: use `--no-machine` |
| the plan | `machine` (with `gpus[].count`) and each stage's `resources.requested` | requested values only — a plan that states an observed value is refused |
| a Nextflow trace | `--from-nextflow-run` reads every `pipeline_info/execution_trace*.txt` (or `--trace`) | requested `cpus memory time disk accelerator`, observed `peak_rss realtime %cpu read_bytes write_bytes cpu_model`; joined by task hash, one to one within a trace file and among the bundle's steps (a short hash two of them share is not read; across trace files the same short hash is taken as the same task); under `-resume` a later file wins per field. Set `trace.raw = true` for exact values; `trace.fields` replaces the default list, so list the defaults beside what you add |
| a measuring tool's file | `--resources PATH` (repeatable), format `gc-resources-input-0.1` | `{format, measured_by, steps: [{step_number, requested, observed}]}`, bytes and seconds as plain numbers |

The record (0.4) adds nine fields: `resources_rule_version`, `grade_resources`,
`stages_with_requested_resources`, `stages_with_observed_resources`, `gpus_total`, `gpu_models`,
`gpu_vendors_probed`, `machine_source`, `resources_sources`. Of the resource values, only GPU vendors and models
leave the bundle — beside three closed-vocabulary fields derived from it (`machine_source`, `resources_sources`,
`gpu_vendors_probed`) — filtered by the anchor (vendors nvidia / amd / intel / apple; a model containing a serial,
host name, IP, MAC, UUID or long hex/digit run, or starting with `/`, is left out and still counted in `gpus_total`;
a host name without a dot passes). `not_checked` gains
`resources_as_written`. A client older than 0.4.0 is refused with the anchor's versions; a 0.4.0 client
against a 0.3.0 anchor gets IdentityMismatch instead, so upgrade the anchor first. A 0.3 record
still verifies, and the verifier re-derives the resource fields under their own rule version, apart
from the seven grades.

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
cd genomicschain_prov
T="$(ruby -e 'puts Gem::Specification.find_by_name("kairos-chain").gem_dir')/templates/skillsets"
I="-Ilib -Itest -I../genomicschain_core/lib -I../genomicschain_tier2/lib -I$T/synoptis/lib -I$T/mmp/lib"
ruby $I test/adapter_bco_test.rb   # 48
ruby $I test/predicate_test.rb     # 33
ruby $I test/prov_write_test.rb    # 60
ruby $I test/resources_test.rb     # 37
ruby $I test/prov_check_test.rb    # 6
ruby $I test/prov_submit_test.rb   # 36  (the anchor side; needs synoptis, mmp, ed25519, json-schema)
ruby $I test/reach_test.rb          # 32  (gate, buckets, budgets; no network)
ruby $I test/reach_prober_test.rb   # 23  (questions per kind; real GitHub advertisement fixture)
ruby $I test/reach_transport_test.rb # 19 (a local TLS server that misbehaves)
ruby $I test/reach_submit_test.rb   # 22  (the observation through SubmitCore, the MCP tool, the public route, gc_prov_verify)
ruby $I test/prov_verify_test.rb   # 20  (incl. the prov 0.3.0 record in test/fixtures/record_v0_3)
(cd zk_verifier && cargo test --release)   # 4
```

Tests that need the real `gc_zk_verify` skip, naming the build command, when it is not built; the
logic of ①–④ is also tested with an injected answer. The first three suites need no gem beyond
minitest, no network, no Docker (the writer's tests pass `--no-docker`'s equivalent
and a captured digest file). The predicate finds `PinStrength` through the sibling
`../genomicschain_tier2/lib` when it is not already on the load path. The producer's tests actually
run the two-step computation the principle demo shows — `(223 + 553) / 2 = 388` — so the checksums
in the bundle under test are checksums of files that exist.
