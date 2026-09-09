---
name: genomicschain_tier2
description: Read a workflow repository's declared resources, classify how strongly each is pinned, and read a Tier-1 report against them. Static only — never runs the workflow.
---

# genomicschain_tier2

The **code-reading tier**: between reading the paper and executing the workflow. Prototype, v0.3.0.

Two layers, and the split is the point:

```
A  gc_tier2_scan             what the repository DECLARES        deterministic, no other input
        │                    (software / container / data, each with a pin strength)
        ↓
B  gc_tier2_adjudicate  what that MEANS for the Tier-1 report
                             (env_capture_class A/B/C, per-step caps, the two levers)
                             deterministic, LLM-free, proposes only
```

Numbered by the one scheme the project uses everywhere since 2026-09-09: Tier-1 reads the paper
(`genomicschain_tier1`), Tier-2 reads the code (this package), Tier-3 executes (`genomicschain_tier3`).
Package names, tool names, schemas and the signed claim prefixes all carry the same number. Before
that date execution was called Tier-2 and this package was `genomicschain_codescan`; documents from
before then use the old names. `trust_tier` on a record is not a tier index — it is the guarantee
level (`self_reported` / `peer_verified` / `hardware_attested`).

Two identifiers keep the word *codescan*: the rubric versions `codescan-static-0.1.0` and
`codescan-adjudication-0.1.0`, and the record fields `codescan_evidence_digest` / `codescan_toolchain`.
They name a rule set and its evidence, not a tier, and the 28 stored reports from 2026-09-08 carry them.

## Tools

- `gc_tier2_scan` — takes a directory that is already on disk; returns every declared software,
  container and data resource, each classified and anchored to a file and line.
- `gc_tier2_adjudicate` — takes a Tier-1 report plus a scan; assigns `env_capture_class`,
  proposes per-step caps, recomputes the two levers from code, reports disagreements.

## The rubric — six levels, by what a stranger holding only the repository can do

| level | meaning |
|---|---|
| `immutable` | the bytes are named by their own hash; a re-fetch cannot differ |
| `versioned` | a name that should not move, but nothing enforces it (a tag, an exact conda version, a DOI) |
| `ranged` | a constraint admitting more than one answer, today and later |
| `floating` | a bare name, a branch, `:latest` — whatever is current at fetch time |
| `local_path` | a filesystem path, with nothing saying how to obtain it |
| `absent` | referenced but never declared |

## What it will not do

**Reads. Never evaluates.** `snakemake --dry-run` and `nextflow -stub-run` answer more than parsing
does, and both execute arbitrary code out of the repository being examined. That is the execution
tier's cost and trust profile. The line is drawn here explicitly rather than discovered later.

**No network, no subprocess.** Cloning is the operator's action, kept outside so a scan has no side
effects — and so the party being scanned can re-run it on their own copy and get the same answer.

**No comparison against the paper.** Whether a finding contradicts what was claimed needs the
Tier-1 report as its other half, and is a separate layer. That separation is the point: this half is
deterministic, so its findings are re-derivable by their subject. A finding you can re-derive is one
you can contest; a judgement you can only disagree with is not the same thing.

## Findings

Structural observations, each carrying the declarations it came from:

| code | fires when |
|---|---|
| `container_not_digest_pinned` | a container reference has no `@sha256:` |
| `data_declared_but_not_obtainable` | a data path does not exist in the repo and carries no URL, DOI or hash |
| `software_pinned_data_not` | packages are hash-pinned while data is unobtainable — the asymmetry |
| `data_source_named_only_in_prose` | data is unobtainable *and* DOIs appear only in prose or comments |
| `software_env_unpinned` | declarations naming no exact version |

## Measured on NBISweden/aMeta (2026-09-01, 35 files parsed)

```
698  software packages  immutable    two conda-lock files, URL + md5
 82  software packages  floating/ranged
  1  container          floating     container: "docker://continuumio/miniconda3"  — no tag at all
  8  data locators      local_path   config/config.yaml, none present in the repo
  6  DOIs in prose only README.md lines 31, 81, 85, 89, 95, 360
```

The shape of the result: **the software is pinned completely and the data is not pinned at all.**
The five figshare DOIs the README offers appear only in comments of a config *example*; the shipped
`config/config.yaml` carries bare local paths and no DOI. A comment is not a declaration, which is
why a parser finds this without being told to look for it.

## Layer B — the Tier-1 report read against the code

The rubric asked for this layer and named the gate. `env_capture_class` is defined as "a **Stage-2
code-verified** classification", and Stage-1 is told not to assign it: *"Without the code-check
(Stage-1 prose-only), do NOT assign A/B/C — leave `n/a` and set `funnel_stage: stage1-prose-only`;
R★ requires Stage-2 verification."* A Stage-1 report holding R★ steps is therefore not wrong; it is
**unverified**. This layer verifies it.

| class | rubric definition | cap |
|---|---|---|
| `A_verified_in_code` | a rule fetches a specific versioned artifact (versioned DOI/accession/URL, or a digest) | none — keeps R★ eligibility |
| `B_pin_prose_only` | the workflow consumes a user-supplied local path; the pin lives only in README/paper prose | **RI** (`fetch-pin-prose-only`) |
| `C_mutable_latest` | the code fetches a rolling/unversioned resource (`latest`, a `master`-branch raw file) | **RI** (`mutable-fetch-fatal`) |

Steps link to Snakemake rules by name; each rule takes the **worst** class among the resources it
reads. The two paper-level levers are recomputed from code and compared against what the report
claimed.

**No LLM.** The judgement is one versioned mapping table (`Adjudicator::CAPS` and `#classify`);
applying it is deterministic. That is why this half is worth building without a model: the assessed
party can re-run it and argue with the **rule** rather than with a verdict they cannot inspect.
The step linkage is a name match, which is exactly where a human is most needed, so nothing here
applies a stage transition. What CAN be signed is the adjudication itself: `gc_tier2_submit` (in
`genomicschain_core`, anchor profile only) records it on the same path as Tier-1 and Tier-3 — a
Synoptis proof on the anchor, no separate chain. The record binds `adjudication_digest`,
`codescan_evidence_digest`, the Tier-1 `report_content_hash`, both levers, the counts, the Ruby
version, and (when the operator states it) the repository commit; `stage_transition.applied` stays
false in the record. The claim string reads `tier2:<lock_state>:<proposed_demotions>:<digest>:<key>`.

### Measured against the recorded ground truth

The rubric's own fixture records a real code check of aMeta (branch main, 2026-07-21):
**10 Class-B + 3 Class-C = 13 demotions of 30 steps, giving 17 R★ / 13 RI. Lever 1 = yes, Lever 2 = no.**

Fed a reconstructed prose-stage report (all steps R★, `stage1-prose-only`, both levers claimed true):

| | recorded | this tool | agrees |
|---|---|---|---|
| Lever 1 — software env lock | yes | yes | ✅ |
| Lever 2 — in-code DB pin class A | no | no | ✅ |
| Class B | 10 | 9 | ✗ |
| Class C | 3 | 2 (one rule, declared twice) | ✗ |
| demotions | **13** | **10** | ✗ |

**The tool under-reports by 3, and the direction is the one its own stated limit predicts.** The
rubric says a class-C resource "poisons every downstream consumer"; reaching those consumers needs
the dependency graph, which needs workflow evaluation, which this tier refuses. `NCBIMapTre`
produces `ncbi.tre`/`ncbi.map`, which `Malt_Extract` consumes. Every proposal is therefore reported
as a **lower bound** (`demotion_proposal_is_a_lower_bound: true`). The gap is not closed and is not
claimed to be.

## Determinism — what "the same answer" means here

Measured 2026-09-09 over the 28 scanned papers. Same repository bytes, same interpreter: 28/28 scans
and 28/28 adjudications identical to the previous day's, identical after copying the repository to
another path (only the scan's `target.root` changes; the adjudication carries no path), identical after a JSON round-trip, identical after
converting every file to CRLF (only `evidence_digest` changes). The scan is deterministic given
**the bytes and the interpreter** — and the second half of that is not a footnote:

```
Ruby 3.4.10   2204 declarations   Lever 1 declared lock 16/28   <- the adopted results
Ruby 3.2.3      11 declarations   Lever 1 declared lock  6/28   same evidence digests
Ruby 2.7       does not load (Ruby >= 3.0 required)
```

The 3.2.3 case was a bug (`Date` not loaded; the NameError was swallowed and every YAML file parsed
as nothing), fixed in v0.2.1. The lesson survives the fix: interpreter version is part of the
record's identity. Every scan therefore carries `target.toolchain` (Ruby, platform, psych, rubric
version) and every adjudication carries both `codescan_toolchain` and `adjudication_toolchain`,
so whatever is signed names the interpreter that produced it. YAML files that could not be parsed
are listed in `target.files_unparsed` rather than passed off as files that declare nothing.

Not recorded, still: the git commit of the checkout (the scanner skips `.git`), so an author
reproducing a scan must be told the revision separately.

## Known limits — reported inside every scan

1. Declarations only. A resource referenced from a script but never declared is invisible.
2. No evaluation, so a value computed at runtime is not resolved.
3. Prose DOIs are not sorted into data deposits vs. citations — aMeta's own paper DOI is among the
   six above. That sorting is a judgement and belongs to the next layer.
4. A lock file is reported as covering software; it is not checked against the environment files.
5. Parsers: conda env, conda-lock, Snakemake `container:`, Dockerfile, YAML config.
   **Nextflow, CWL and WDL are not parsed.**
6. Deterministic per interpreter, not across interpreters. The interpreter is recorded; the
   checkout's git commit is not.

## Provenance of the rubric

Three exclusions in `PinStrength.locator_shaped?` and the fixture scoping in `Scanner` are not
design. They are false positives the first run against aMeta produced — JSON Schema `$ref` pointers,
MultiQC globs, and a `.test/` copy of the shipped config, which together inflated 8 findings to 31.
Each has a `_regression` test.

## Tests

```bash
ruby genomicschain_tier2/test/scanner_test.rb
```

No gem and no network: every case builds its own repository in a tmpdir.
