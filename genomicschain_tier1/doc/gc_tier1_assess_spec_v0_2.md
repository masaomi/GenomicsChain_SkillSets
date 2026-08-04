# gc_tier1_assess — I/O specification v0.2 (draft, not implemented)

Status: **specification only**. No code exists yet. Supersedes v0.1
(`gc_tier1_assess_spec_v0_1.md`), which was written without sight of the assessor prompts
that produced the 201-report corpus and got five rules wrong. See § Changelog.

Produces a schema-valid Tier-1 `report.json` (schema `report_schema_v0_2_6.json`) for one
paper at a declared funnel stage. The report leaves this tool **unsigned** — human sign-off
(rubric R5 / collection protocol §10) and `gc_tier1_submit` are separate, later steps.

## 0. Sources this specification is derived from

| Source | Location | What it fixes |
|---|---|---|
| Rubric v0.2.5 | `genomicschain_tier1/knowledge/repro_tier1_guide.md` (81 lines) | scoring semantics |
| Collection protocol v0.2.6 | MVP2 L1 `repro_collection_protocol` (82 lines) | funnel, gates, storage, publication |
| Stage-1 assessor prompt | `GenomicsChain_MVP2_2026/log/repro_survey_2026_07/stage1_assessor_prompt.md` (53 lines) | the working stage-1 procedure — 201 runs behind it |
| Stage-2 assessor prompt | same directory, `stage2_assessor_prompt.md` (96 lines) | the working stage-2 procedure — 6 runs behind it |
| Corpus | `GenomicsChain_2025/data/tier1_survey/collection/` (201 reports) | numeric rules verified against real output |

Where this specification and a prompt disagree, **the prompt wins** — it has run.

## 1. Placement

| Property | Value |
|---|---|
| Package | `genomicschain_tier1` |
| Class | `KairosMcp::SkillSets::GenomicschainTier1::Tools::GcTier1Assess` |
| Manifest key | `tool_classes` (always registered — **not** `anchor_profile_tool_classes`) |
| Category | `:utility` |
| Depends on | `genomicschain_core` (B1ManifestHash), `llm_client` (CallRouter) |
| New gem dependency | `json_schemer` — add to `skillset.json` `gem_dependencies` (precedent: `llm_client` declares `faraday`) |

On the validator choice: `json-schema` 6.2.0 (present on the dev machine, but not a
kairos-chain dependency either) **cannot read this schema** — it raises
`Schema not found: https://json-schema.org/draft/2020-12/schema`, the draft
`report_schema_v0_2_6.json` declares. It can be coerced by deleting `$schema` and forcing
`version: :draft6`, but that silently validates against a different draft than the artifact
declares. `json_schemer` supports 2020-12 directly. Take the gem, not the coercion.

Registered on every node that installs `genomicschain_tier1`, following the split in
`genomicschain_core/plugin/SKILL.md`: **assess off-anchor, submit on anchor only**. The anchor
also carries tier1, so it gets the tool — that is the deployment genomicschain.ch uses.

## 2. Why this is not one LLM call

Four kinds of field must not come from the assessor LLM.

| Field | Why the LLM must not author it |
|---|---|
| `rubric_hash` | Must be the digest of the rubric file **this process actually loaded**. A self-reported hash witnesses nothing. |
| `manifest.b1_manifest_hash` | A *pre-commitment*, computed before scoring. If emitted alongside the scores it no longer precedes them. |
| `counts`, `headline`, `levers`, `stage2_candidate` | Derivable from `steps` and `capture_claim` by fixed rules. Deriving them in Ruby removes an error class and makes the report internally consistent by construction. |
| `funnel_stage`, `assessor_stack` | Caller-declared identity. The LLM must not be able to promote its own stage. |

Four phases in one call:

```
  phase 1  PRE-COMMIT          (no LLM)
    rubric_hash   = sha256(repro_tier1_guide.md, whole file incl. frontmatter)
                  = 4024d4d8817abb0feb76ca9e91effcb11fcea53b1caae2a2ee4efc985e4ca3b1
    assessed_at   = input or today (UTC date)
    b1_manifest_hash = sha256( canonical_id.value | rubric_hash
                               | assessor_id | assessed_at [| "stage2"] )
           |
           v
  phase 2  SCORE               (LLM, temperature 0)
    system = stage-specific procedure (§5)
    user   = sources (+ prior stage-1 report when stage 2)
    -> steps[], gaps[], liveness[], capture_claim, ...   (nothing else)
           |
           v
  phase 3  DERIVE + GUARD      (no LLM)
    stage guard (§6a/§6b); counts; headline; levers; stage2_candidate
           |
           v
  phase 4  VALIDATE            (no LLM)
    json-schema against report_schema_v0_2_6.json
    B1ManifestHash.matches?; size <= 2 MiB
    human_signoff.signed = false   (always)
           |
           v
       report_json
```

## 3. Input schema

```jsonc
{
  "canonical_id": {                     // required
    "value": "10.1101/2025.11.08.687335",
    "kind": "doi",                      // doi | pmid | pdf_sha256 | repo_url
    "aliases": ["https://www.biorxiv.org/content/10.1101/2025.11.08.687335v1"]
  },
  "sources": [                          // required, minItems 1
    { "kind": "paper_text",             // see §3a
      "ref":  "biorxiv JATS XML v1",    // human-readable provenance
      "content": "...",                 // inline text, OR
      "sha256": "..." }                 // digest if the caller fetched it
  ],
  "funnel_stage": "stage1-prose-only",  // required; | stage2-code-verified
  "prior_report_json": "{...}",         // REQUIRED when funnel_stage = stage2-code-verified
  "assessor_id": "gc_tier1_assess/0.1 (anthropic:claude-opus-5) + masaomi",  // required
  "operator_id": "masaomi",             // required -> assessor_stack.operator_id
  "assessed_at": "2026-08-04",          // optional, default = today UTC (date, not datetime)
  "paper_type": "pure-computational",   // optional; omitted -> LLM proposes (rubric Step 0)
  "step_source": "prose-methods",       // optional; omitted -> LLM derives (rubric Step 1)
  "shared_step_list": [ ... ],          // optional canonical step list for inter-rater work
  "llm": { "provider": "anthropic", "model": "claude-opus-5", "max_tokens": 32000 },
  "dry_run": false                      // validate inputs + gates + pre-commit, no LLM call
}
```

### 3a. `sources[].kind`

| kind | Meaning | Counts as code evidence |
|---|---|---|
| `paper_text` | Full text (JATS XML, HTML, md, txt) | no |
| `paper_pdf_text` | Text extracted from a PDF | no |
| `landing_page` | Repo landing page / README only | no |
| `repo_file` | One file's contents (Snakefile, conda-lock.yml, Dockerfile, ...) | **yes** |
| `repo_tree` | File listing + selected file contents | **yes** |

### 3b. `canonical_id` precedence (collection protocol §1)

`doi` > `pmid` > `pdf_sha256` > `repo_url`. Multiple identifiers for one work: record all in
`aliases`, put the highest-precedence one in `value`. The tool does not de-duplicate across
calls — that is the caller's registry concern.

## 4. Stage gate (refusals)

Fail closed, before any LLM call. Each returns an error, never a partial report.

| Condition | Result |
|---|---|
| `funnel_stage: stage2-code-verified` and no `repo_file`/`repo_tree` source | **refuse** — rubric line 57: without the code check, A/B/C must not be assigned |
| `funnel_stage: stage2-code-verified` and no `prior_report_json` | **refuse** — stage 2 revises stage 1's step list, and `manifest.supersedes` needs stage 1's b1 hash |
| `prior_report_json` present but its `canonical_id.value` ≠ this call's | refuse |
| `sources` empty, or every source has neither `content` nor `sha256` | refuse |
| `canonical_id.value` empty | refuse — b1 pre-commit input |
| `assessor_id` or resolved `assessed_at` empty | refuse — `B1ManifestHash.assert_matches!` requires both non-empty |
| `funnel_stage` not one of the two enum values | refuse |

## 5. LLM contract (phase 2)

The system prompt is **ported from the working assessor prompt for the declared stage**, not
composed from the rubric. Two changes on porting, both removals:

1. **Retrieval is removed.** The prompts tell the assessor to fetch (`curl`, `gh api`,
   `git clone --depth 1`). The tool's caller supplies `sources`, so the assessor never
   fetches. This deletes the prompts' largest hazard — see §5c.
2. **Tool-derived fields are removed from the output list.** The prompts ask the assessor to
   emit `counts`, `headline`, `levers`, `stage2_candidate`, `rubric_hash`, `manifest`,
   `human_signoff`, `assessor_stack`, `funnel_stage`. Phase 3/4 produce all of these.

The rest is kept verbatim, including the worked rules the prompts spell out (§5a, §5b).

### 5a. Stage-1 procedure (ported from `stage1_assessor_prompt.md`)

Prose triage from paper + repo landing page + README **prose only**. No code read.

- Route by paper type (rubric Step 0).
- Record artifacts and **verbatim** liveness — do not pre-interpret.
- Build a coarse step list: one step per named tool/analysis invocation.
- Score axes at the prose level. **Version axis: a lockfile or container is only a *claim* at
  Stage 1, so `version ≤ 1` for every step** (stage-1 prompt line 38).
- `env_capture_class = "n/a"` for every step.
- `capture_claim` ∈ the §6c enum — what the paper/README *claims*.
- Unassessable is a scored outcome: emit the report with `assessable.is_assessable = false`
  and `reason_if_not` (rubric R14 / protocol §5), never a silent drop.

### 5b. Stage-2 procedure (ported from `stage2_assessor_prompt.md`)

Code inspection, not execution, and **not** data download. Env/code artifacts only.

- **Lever 1 — `software_env_lock`.** TRUE only for a statically-complete lock closing
  interpreter + channels + platform + transitive deps: `conda-lock.yml`, `pixi.lock`,
  `renv.lock`, `poetry.lock`, `Pipfile.lock`, `requirements.txt` *with hashes*, a Docker image
  pinned by **digest** (`@sha256:`) on a pinned base, a Singularity image pinned by content
  digest, or `conda env export` output carrying exact build strings (`=h...`) for every
  dependency. FALSE for: a bare `environment.yml` with top-level pins only, an image pinned by
  a mutable **tag** (`:1.0`, `:latest`), prose-only exact versions, or a `release_snapshot` of
  scripts/data. Record `software_env_platform_coverage` (e.g. `"linux-64 only"`); a declared
  but uncovered platform is a finding, not a disqualifier.
- **Lever 2 — `in_code_db_pin_classA`.** TRUE only if **every** external DB/reference is
  `A_verified_in_code`. Any single B or C → FALSE.
- **Per-step re-scoring from code.** `version = 2` only when `env_capture_class = A` **and**
  Lever 1's lock covers that step's toolchain; otherwise `≤ 1`.
- Keep stage 1's step list and granularity; revise axes / verdict / `env_capture_class` /
  `version_subtier`. If the code shows a step was mis-identified, note it in
  `granularity_note`.
- Cite file + snippet for every A/B/C classification (protocol §4.5 — this is what makes κ on
  the classification computable).

### 5c. What porting removes

Lines 17–31 of the stage-1 prompt are entirely a `/tmp` scratch-file isolation rule. On
2026-07-27 two concurrently running assessors shared `/tmp/p.xml`; one overwrote the other's
paper. The affected assessor happened to verify a title phrase and re-fetched. Had it not,
it would have emitted **a schema-valid report describing the wrong paper under the right
canonical id** — an error invisible to every downstream validator, because the report format
carries no link between the assessed text and the identifier.

In the tool the assessor does not fetch, so this hazard class does not exist. The residual
form of it — caller supplies the wrong text — is the caller's to guard; `sources[].sha256`
exists so the caller can record what it passed.

### 5d. Output constraint

The LLM is constrained via `output_schema` (`llm_client` supports it) to author exactly:

`paper_type`, `reproduction_target`, `step_source`, `granularity_note`, `steps[]`, `gaps[]`,
`liveness[]`, `assessable`, `capture_claim`, `contested_corrected[]`, and (stage 2 only)
`lever_evidence` — `{software_env_lock: bool, cite: str, platform_coverage: str,
in_code_db_pin_classA: bool, cite: str}`, which is **not** a report.json field and is consumed
by §6d.

Any tool-derived key appearing in the response is dropped and listed in
`guards.llm_overreach[]`.

## 6. Deterministic derivation (phase 3)

Let `S` = steps with `layer == "C"`, `W` = steps with `layer == "W"` (OOS, excluded from S).

### 6a. Stage-1 guard — applied first, when `funnel_stage == "stage1-prose-only"`

| Rule | Source |
|---|---|
| `axes.version` capped at 1 on every step | stage-1 prompt line 38 — a lock/container is a *claim* at stage 1 |
| every `env_capture_class` → `"n/a"` | rubric line 57 / stage-1 prompt line 39 |
| any `verdict == "R"` → `"RI"`, subflag `stage1-ceiling-demoted` | consequence of the version cap; kept as an explicit backstop |
| `levers.software_env_lock` → `false` | stage-1 prompt line 41 |
| `levers.in_code_db_pin_classA` → `false` | stage-1 prompt line 41 |
| `levers.has_validated_env_capture` → `false` | stage-1 prompt line 41 |
| `levers.software_env_platform_coverage` → `"unverified (stage1)"` | matches all 201 corpus reports |
| `counts.n_fetch_required` → 0, `counts.n_exact_capture_unexecuted` → 0 | follows from the above |

The version cap is the root rule; the R→RI demotion is its consequence. Both are applied so a
malformed LLM response cannot slip an R through. Every intervention is listed in
`guards.stage_demotions[]`.

Corpus check: all 201 reports in `GenomicsChain_2025/data/tier1_survey/collection/` are
`stage1-prose-only` and contain **0 steps with verdict `R`** between them. The guard codifies
what the assessors were already doing by hand.

### 6b. Stage-2 R★ rule — when `funnel_stage == "stage2-code-verified"`

A step may hold `verdict == "R"` only if **all** of:

```
axes.data >= 1  AND  axes.code == 2  AND  axes.version == 2
AND env_capture_class == "A_verified_in_code"
AND Lever 1's lock statically covers this step's toolchain   (LLM-asserted, cited)
```

Any step failing this is demoted to the axis-min verdict and recorded in
`guards.stage_demotions[]`. Note that an embargoed/absent data axis blocks R★ even when env
and code are complete — that is a gap to record, not a reason to relax the rule
(stage-2 prompt line 58).

### 6b-2. Field-shape normalisation (both stages)

Enforced in phase 3, because the corpus shows all three are got wrong in practice (§11).

| Rule | Source |
|---|---|
| `version_subtier` is emitted **only when `axes.version == 1`**, and must be one of `release_snapshot` / `exact_pins_partial` / `floating`. Otherwise the key is **omitted**, never set to `"none"` or `null` | rubric line 45: "report when version=1, ordered" |
| every step carries four integer axes in 0..2, including `layer: "W"` steps — an OOS step scores `0/0/0/0` and is excluded from `S`, not left unscored | schema requires `axes` on every step |
| `gaps` and `liveness` are arrays, even when they hold one entry | schema `type: array` |

### 6c. `capture_claim` and `stage2_candidate`

`capture_claim` is a closed enum (collection protocol §3, stage-1 prompt line 40):

```
none | floating | exact_pins_partial | release_snapshot | env_lock_claimed | container_digest_claimed
```

`stage2_candidate` is **derived, not authored**:

```
stage2_candidate = capture_claim ∈ { env_lock_claimed, container_digest_claimed, release_snapshot }
```

`exact_pins_partial` is deliberately **excluded** (protocol v0.2.6 tightened gate, stage-1
prompt line 50): under rubric Δ2 a correctly-classified `exact_pins_partial` paper is capped
at `version = 1` by the prose read, so a code check yields zero R★ gain. Such papers reach
stage 2 only through the stratified audit gate, which the orchestrator draws separately with
its own seed — **not** through this flag.

### 6d. counts

```
n_R  = |{s in S : verdict == "R"}|      n_NI = |{s in S : verdict == "NI"}|
n_RI = |{s in S : verdict == "RI"}|     n_X  = |{s in S : verdict == "X"}|
S = |S|                                 W = |W|
n_fetch_required           = |{s in S : "fetch-required" in subflags}|
n_exact_capture_unexecuted = |{s in S : axes.version == 2}|
```

`n_fetch_required` is confirmed against the corpus (4 of 201 reports carry a non-zero value,
each matching the `fetch-required` subflag count). `n_exact_capture_unexecuted` is **inferred
from the rubric only** — version=2 means exact capture, and Tier-1 never executes. All 201
corpus reports have 0 here, so the corpus cannot confirm it. Flagged for a second opinion
before implementation.

### 6e. levers (stage 2; stage 1 is forced by §6a)

- `software_env_lock` = `lever_evidence.software_env_lock`, accepted only if its citation
  names a supplied `repo_file`/`repo_tree` source.
- `in_code_db_pin_classA` = no step carries `B_pin_prose_only` or `C_mutable_latest`.
- **`has_validated_env_capture` = `n_R >= 1`** — true iff at least one step reaches R★
  (stage-2 prompt line 59). **Not** an alias for `software_env_lock`: a lock can be upheld
  while every step still falls short of R★ on the data or DB-pin axis, which is exactly the
  aMeta shape.

### 6f. headline (all strings in the schema)

| Field | Rule |
|---|---|
| `static_readiness` | if `has_validated_env_capture` — `"n_R/S (P%)"` plus the mandatory inline qualifier *"unexecuted; declared environment statically valid but not verified as the env that produced the results"* and the co-reported `n_exact_capture_unexecuted` + `n_fetch_required` (rubric line 64 forbids the bare ratio). Otherwise the corpus form: `"0/S (0%) - stage1 ceiling only, no R-star (R-star needs stage-2 code verification)"` |
| `inference_inclusive_upper_bound` | `(n_R + n_RI)/S` — labelled "readiness upper bound", never "reproducible" |
| `coverage` | `S/(S+W)` |
| `repro_index` | `null` when `S < 4`. Otherwise `{index, coverage, S}` with `index = (1.0·n_R + 0.6·n_RI + 0.2·n_NI)/S` at 1 significant figure |

### 6g. manifest

| Field | Rule |
|---|---|
| `b1_manifest_hash` | phase-1 pre-commit; 5 pipe fields with literal `stage2` appended when stage 2 (matches `GenomicschainCore::B1ManifestHash`) |
| `supersedes` | stage 1 → `null`. Stage 2 → **`prior_report_json`'s `manifest.b1_manifest_hash`** (stage-2 prompt line 84) |
| `chain_record` | `"not-yet-recorded"` |

## 7. Output

```jsonc
{
  "status": "assessed",                 // | "dry_run"
  "report_json": "{...}",               // canonical JSON string — the argument gc_tier1_submit takes
  "report": { ... },                    // same, parsed, for rendering
  "derived": { "counts": {...}, "headline": {...}, "levers": {...},
               "capture_claim": "...", "stage2_candidate": false },
  "guards": {
    "schema": "ok",
    "b1_manifest_hash": "ok",
    "report_json_bytes": 41233,
    "stage_demotions": [ {"step_id": "C3", "field": "axes.version", "from": 2, "to": 1,
                          "reason": "stage1-claim-only"} ],
    "llm_overreach": []
  },
  "assessor_stack": { "operator_id": "...", "stage": "stage1-prose-only",
                      "llm": {"provider": "anthropic", "model": "...", "invoked_at": "..."} },
  "human_signoff_required": true,
  "next_step": "Human review and sign-off (rubric R5 / protocol §10), then gc_tier1_submit on the anchor."
}
```

Fixed in the emitted report:

- `rubric_version` / `metric_semantics_version` = `"0.2.5"` (schema `const`). The rubric stays
  at 0.2.5 under collection protocol v0.2.6 — v0.2.6 changed the collection side only, so
  v0.2.5 and v0.2.6 reports remain poolable.
- `human_signoff` = `{"signed": false, "reviewer_id": "PENDING (unsigned draft)"}` — **always**.
  This tool cannot sign; R5 is enforced by construction.
- `report_content_hash` — **omitted**. Schema says omit until submit; the server recomputes it.

## 8. Failure modes

| Failure | Behaviour |
|---|---|
| LLM returns non-conforming JSON | error, no report. No repair pass in v0.2 |
| Derived report fails json-schema validation | error, with the failing pointer |
| `B1ManifestHash.matches?` false | error — the pre-commit inputs were mutated |
| `report_json` exceeds **2 MiB** | error. `VerdictSpec::Tier1::REPORT_JSON_MAX_BYTES = 2 * 1024 * 1024` is what `gc_tier1_submit` accepts; a report that cannot be submitted must not be returned as assessed |
| LLM provider auth failure | propagated; `llm_client`'s claude_code fallback applies |
| `dry_run: true` | runs §4 gates + phase 1, reports the b1 hash it *would* commit, no LLM call |

## 9. Use by the genomicschain.ch free service

The free tier calls with `funnel_stage: "stage1-prose-only"` only, and never calls
`gc_tier1_submit`. Two consequences follow from the rubric and protocol, not from policy:

1. Every free-tier result has `n_R == 0` by §6a. The UI must say "Stage-1 ceiling" and must
   not present R★.
2. `human_signoff.signed` is false, so the result is an unsigned draft. Rubric line 76 and
   protocol §9 permit genomicschain.ch to publish **aggregate** statistics only; a named
   per-paper score requires sign-off plus author right-of-reply first. Returning the draft
   privately to the submitter is not publication and is unaffected.

Protocol §10 additionally gates on-chain attestation on a measured inter-rater κ, which does
not exist yet — a further reason the free tier stops before submit.

One LLM call per assessment, minutes long. The Rails side must run it as a background job;
this tool is synchronous and does not queue.

## 10. Not in v0.2

- **Fetching.** The caller supplies resolved `sources`. DOI → bioRxiv retrieval and PDF → text
  extraction live on the genomicschain.ch side.
- **The committed-secret side-check** (protocol §4b), which is *mandatory for every stage-2
  paper*: scan the opened workflow/env/config/Docker files for apparent committed credentials,
  record hits only in a private incident log, and carry an internal-only
  `committed_secret_flagged` boolean that the export filter must strip. Consequence to state
  plainly: **a stage-2 report produced by this tool is not protocol-complete.** Either the
  caller performs 4b separately, or stage 2 waits for v0.3. Stage 1 is unaffected — 4b applies
  only to the code read.
- Repair / retry of a malformed LLM response.
- Inter-rater agreement computation (`shared_step_list` is accepted and passed through).
- Any write to Synoptis or the chain.

## 11. Corpus conformance finding (2026-08-04) — why phase 4 is load-bearing

Validating all 201 corpus reports against `report_schema_v0_2_6.json` (via `json-schema` with
`$schema` stripped and `version: :draft6` forced, since the gem cannot read 2020-12):

```
validated: 201   pass: 142   fail: 59        (29% of the corpus is not schema-valid)
```

| Cause | Occurrences | Detail |
|---|---|---|
| `version_subtier` outside the enum | 519 | `"none"` ×457, `"env_lock_claimed"` ×29 (a *capture_claim* value in the wrong field), `"exact-pin-prose"` ×25, `"exact-pins-no-closure"` ×4, `"n/a"` ×3, `"major-only"` ×1 |
| `version_subtier` explicitly `null` | 7 | should be omitted, not null |
| `axes.{data,code,version,params}` `null` | 6 each | unscored steps, schema requires integer |
| `gaps` an object, not an array | 1 | |
| `liveness` an object, not an array | 1 | |

Nothing was validating these. The Rails dashboard reads the JSON and aggregates raw counts,
so it never had to parse `version_subtier`; the failures were invisible. Two consequences:

1. **This is the argument for phase 4.** A schema check in the tool is not ceremony — the
   same assessor procedure, run by hand 201 times, produced non-conforming output 29% of the
   time. §6b-2 exists because of this table.
2. **Those 59 reports would fail the submit path.** The corpus README calls the meeting-anchor
   proof path "Phase 2"; that path runs `gc_tier1_submit`, which parses the report. Repairing
   the corpus is a **separate task**, not part of this tool, and it is not blocking — but it
   is now known rather than latent.

## 12. Implementation notes (2026-08-04)

Implemented against this specification; 27 tests pass. Three things the specification
did not anticipate:

1. **The R★ gate must *cap*, not merely re-derive.** §6b said a step failing the R★ rule is
   "demoted to the axis-min verdict". That is not sufficient: a step whose four axes are all 2
   but whose DB pin lives in prose only fails the gate, and axis-min then hands it `R` straight
   back. The gate caps at `RI`. This is precisely the prose-optimism the code check exists to
   catch, so the omission would have defeated stage 2's purpose. Fixed in `Derivation`;
   `settle_verdict!` takes a `cap:`.
2. **`SCHEMA_V0_2_6` pointed outside the package.** `genomicschain_tier1.rb` resolved the schema
   as `../../assets/...` from `lib/`, i.e. the repository root rather than the package. A
   pre-existing defect, invisible until something loaded the schema. Fixed.
3. **The validator runs on the fallback backend today.** `json_schemer` is declared in
   `skillset.json` but is not installed on the dev machine, so `Validator` currently reports
   `json-schema (draft6-coerced; schema declares 2020-12)`. The backend in use is named in
   `guards.schema_validator` on every result rather than left implicit — a validation that
   silently ran against a different draft than the artifact declares is worse than none.

`topology_test.rb`'s `test_tier1_package_has_no_mcp_tools` asserted the pre-`gc_tier1_assess`
state and was replaced by `test_tier1_package_exposes_assess_only`. What it now guards is the
narrower invariant that actually matters: tier1 may register the assessor everywhere, but the
submit path stays in core behind the anchor profile.

## Changelog

**v0.2 (2026-08-04)** — first revision after locating the assessor prompts that produced the
corpus. Five rules in v0.1 were wrong or missing:

| # | v0.1 | v0.2 |
|---|---|---|
| 1 | system prompt = rubric verbatim | ported from the working stage-1 / stage-2 prompts, minus retrieval and minus tool-derived fields (§5) |
| 2 | stage-1 guard = demote `R` → `RI` | root rule is the **version cap ≤ 1**; the demotion is its consequence (§6a) |
| 3 | `capture_claim` a free string | closed 6-value enum (§6c) |
| 4 | `stage2_candidate` LLM-authored | derived; `exact_pins_partial` excluded per the v0.2.6 tightened gate (§6c) |
| 5 | `has_validated_env_capture` = `software_env_lock` | **= `n_R >= 1`** (§6e). The v0.1 form would have marked aMeta-shaped papers as validated when no step reaches R★ |

Also added: `prior_report_json` as a required stage-2 input (§3, §4) — stage 2 revises stage
1's step list and needs its b1 hash for `manifest.supersedes`; the concrete Lever-1 acceptance
list (§5b); the 2 MiB output ceiling (§8); `json_schemer` as a declared gem dependency, after
finding that `json-schema` cannot read the schema's declared draft (§1); the field-shape
normalisation rules (§6b-2); the corpus conformance finding, 59/201 non-valid (§11); and the
protocol §4b gap disclosed in §10.

**v0.1 (2026-08-04)** — initial I/O contract, phase structure, stage gate, derivation formulas.
