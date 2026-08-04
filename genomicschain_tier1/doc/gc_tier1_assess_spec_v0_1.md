# gc_tier1_assess — I/O specification v0.1 (draft, not implemented)

> **SUPERSEDED by `gc_tier1_assess_spec_v0_2.md` (2026-08-04).** This version was written
> without sight of the assessor prompts that produced the 201-report corpus, and five of its
> rules are wrong — see the v0.2 changelog. Retained for the record only; do not implement
> from this file.

Status: **specification only**. No code exists yet. `genomicschain_core/plugin/SKILL.md`
currently calls this tool "future"; this document is what turns it into work.

Produces a schema-valid Tier-1 `report.json` (schema `report_schema_v0_2_6.json`) for one
paper at a declared funnel stage. The report leaves this tool **unsigned** — human sign-off
(rubric R5) and `gc_tier1_submit` are separate, later steps.

## 1. Placement

| Property | Value |
|---|---|
| Package | `genomicschain_tier1` |
| Class | `KairosMcp::SkillSets::GenomicschainTier1::Tools::GcTier1Assess` |
| Manifest key | `tool_classes` (always registered — **not** `anchor_profile_tool_classes`) |
| Category | `:utility` |
| Depends on | `genomicschain_core` (B1ManifestHash), `llm_client` (CallRouter) |

Registered on every node that installs `genomicschain_tier1`. This follows the existing
split stated in `genomicschain_core/plugin/SKILL.md`: **assess off-anchor, submit on anchor
only**. The anchor also carries tier1, so it gets the tool too — that is the deployment the
genomicschain.ch free service uses.

## 2. Why this is not one LLM call

Three fields in `report.json` must not come from the assessor LLM.

| Field | Why the LLM must not author it |
|---|---|
| `rubric_hash` | Must be the digest of the rubric file **this process actually loaded**. A self-reported hash witnesses nothing. |
| `manifest.b1_manifest_hash` | A *pre-commitment*, computed before scoring (rubric § Output). If it were emitted alongside the scores it would no longer precede them. |
| `counts`, `headline`, `levers` | Pure arithmetic over `steps`. Deriving them in Ruby removes an error class and makes the report internally consistent by construction. |

So the tool runs four phases in one call:

```
  phase 1  PRE-COMMIT          (no LLM)
    rubric_hash   = sha256(repro_tier1_guide.md)          -> 4024d4d8...
    assessed_at   = input or today (UTC date)
    b1_manifest_hash = sha256(canonical_id.value | rubric_hash
                              | assessor_id | assessed_at [| "stage2"])
           |
           v
  phase 2  SCORE               (LLM, temperature 0)
    system = rubric verbatim + output contract
    user   = sources
    -> steps[], gaps[], liveness[], paper_type, ...   (nothing else)
           |
           v
  phase 3  DERIVE + GUARD      (no LLM)
    stage-1 ceiling demotion; counts; headline; levers
           |
           v
  phase 4  VALIDATE            (no LLM)
    report_schema_v0_2_6.json; B1ManifestHash.matches?
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
    { "kind": "paper_text",             // see table below
      "ref":  "biorxiv JATS XML v1",    // human-readable provenance
      "content": "...",                 // inline text, OR
      "sha256": "..." }                 // digest if content was fetched by the caller
  ],
  "funnel_stage": "stage1-prose-only",  // required; | stage2-code-verified
  "assessor_id": "gc_tier1_assess/0.1 (anthropic:claude-opus-5) + masaomi",  // required
  "operator_id": "masaomi",             // required -> assessor_stack.operator_id
  "assessed_at": "2026-08-04",          // optional, default = today UTC (date, not datetime)
  "paper_type": "pure-computational",   // optional; omitted -> LLM proposes (rubric Step 0)
  "step_source": "prose-methods",       // optional; omitted -> LLM derives (rubric Step 1)
  "shared_step_list": [ ... ],          // optional canonical step list for inter-rater work
  "llm": { "provider": "anthropic", "model": "claude-opus-5", "max_tokens": 32000 },
  "dry_run": false                      // validate inputs + gates, no LLM call
}
```

### `sources[].kind`

| kind | Meaning | Counts as code evidence |
|---|---|---|
| `paper_text` | Full text (JATS XML, HTML, md, txt) | no |
| `paper_pdf_text` | Text extracted from a PDF | no |
| `landing_page` | Repo landing page / README only | no |
| `repo_file` | One file's contents (Snakefile, conda-lock.yml, ...) | **yes** |
| `repo_tree` | File listing + selected file contents | **yes** |

## 4. Stage gate (refusals)

Fail closed, before any LLM call. Each returns an error, never a partial report.

| Condition | Result |
|---|---|
| `funnel_stage: stage2-code-verified` and no `repo_file`/`repo_tree` source | **refuse** — rubric line 57: without the code check, A/B/C must not be assigned |
| `sources` empty, or every source has neither `content` nor `sha256` | refuse |
| `canonical_id.value` empty | refuse — it is a b1 pre-commit input |
| `assessor_id` or resolved `assessed_at` empty | refuse — `B1ManifestHash.assert_matches!` requires both non-empty |
| `funnel_stage` not one of the two enum values | refuse |

## 5. LLM contract (phase 2)

**System prompt** = `knowledge/repro_tier1_guide.md` verbatim (81 lines, whole file), followed
by the output contract below. **User message** = the sources, each prefixed with its `kind`
and `ref`. Temperature 0.

The LLM is constrained (`output_schema` on `llm_client`) to author exactly these fields:

| Field | Notes |
|---|---|
| `paper_type` | only when not supplied in input |
| `reproduction_target` | prose |
| `step_source`, `granularity_note` | rubric Step 1 |
| `steps[]` | `step_id`, `label`, `layer` (C/W), `axes` {data,code,version,params}, `verdict`, `env_capture_class`, `version_subtier`, `subflags[]` |
| `gaps[]` | 13-type dictionary |
| `liveness[]` | verbatim status + timestamp + network context |
| `assessable` | `{is_assessable, reason?}` — rubric R14: unassessable is a *scored* outcome |
| `capture_claim` | e.g. `exact_pins_partial` |
| `stage2_candidate` | boolean |
| `env_lock_evidence` | **not in report.json** — `{present: bool, cite: str}`, input to lever 1 derivation |

It must **not** emit: `counts`, `headline`, `levers`, `manifest`, `human_signoff`,
`rubric_hash`, `report_content_hash`, `assessor_stack`, `funnel_stage`. Any such key in the
response is dropped with a `guards.llm_overreach[]` note.

## 6. Deterministic derivation (phase 3)

Let `S` = steps with `layer == "C"`, `W` = steps with `layer == "W"` (OOS, excluded from S).

### 6a. Stage-1 ceiling guard — applied first

When `funnel_stage == "stage1-prose-only"`:

| Rule | Reason |
|---|---|
| every `env_capture_class` → `"n/a"` | rubric line 57 |
| every `verdict == "R"` → `"RI"`, subflag `stage1-ceiling-demoted` | rubric line 57: R★ requires Stage-2 verification |
| `levers.software_env_lock` → `false` | statically-complete lock cannot be judged from prose |
| `levers.in_code_db_pin_classA` → `false` | follows from all-`n/a` |
| `levers.has_validated_env_capture` → `false` | |
| `levers.software_env_platform_coverage` → `"unverified (stage1)"` | matches the 201-report corpus |

Each demotion is listed in `guards.stage1_demotions[]`. This guard is the mechanical form of
the aMeta finding: prose alone scored 30/30 R★, the code check gave 17 R★ / 13 RI.

Corpus check: all 201 reports in `GenomicsChain_2025/data/tier1_survey/collection/` are
`stage1-prose-only` and contain **0 steps with verdict `R`** between them. The guard codifies
what the assessors were already doing by hand.

### 6b. counts

```
n_R  = |{s in S : verdict == "R"}|      n_NI = |{s in S : verdict == "NI"}|
n_RI = |{s in S : verdict == "RI"}|     n_X  = |{s in S : verdict == "X"}|
S = |S|                                 W = |W|
n_fetch_required           = |{s in S : "fetch-required" in subflags}|
n_exact_capture_unexecuted = |{s in S : axes.version == 2}|
```

`n_fetch_required` is confirmed against the corpus (4 of 201 reports carry a non-zero value,
each matching the `fetch-required` subflag count). `n_exact_capture_unexecuted` is **inferred
from the rubric only** — version=2 means exact capture, and Tier-1 never executes, so every
version=2 step is an unexecuted exact capture. All 201 corpus reports have 0 here, so the
corpus cannot confirm it. Worth a second opinion before implementing.

### 6c. headline (all three are strings in the schema)

| Field | Rule |
|---|---|
| `static_readiness` | if `has_validated_env_capture` — `"n_R/S (P%) — unexecuted; declared env statically valid but not verified"` plus the two co-reported counts (rubric forbids the bare ratio). Otherwise the corpus form: `"0/S (0%) - stage1 ceiling only, no R-star (R-star needs stage-2 code verification)"` |
| `inference_inclusive_upper_bound` | `(n_R + n_RI)/S` — labelled "readiness upper bound", never "reproducible" |
| `coverage` | `S/(S+W)` |
| `repro_index` | `null` when `S < 4`. Otherwise `{index, coverage, S}` with `index = (1.0·n_R + 0.6·n_RI + 0.2·n_NI)/S` at 1 significant figure |

### 6d. levers (stage-2 only; stage-1 is forced by 6a)

- `software_env_lock` = LLM's `env_lock_evidence.present` **and** the citation resolves to a
  supplied `repo_file` source.
- `in_code_db_pin_classA` = every step with an external reference resource is
  `A_verified_in_code` (no B, no C).
- `has_validated_env_capture` = `software_env_lock`.

## 7. Output

```jsonc
{
  "status": "assessed",                 // | "dry_run"
  "report_json": "{...}",               // canonical JSON string — the argument gc_tier1_submit takes
  "report": { ... },                    // same, parsed, for rendering
  "derived": { "counts": {...}, "headline": {...}, "levers": {...} },
  "guards": {
    "schema": "ok",
    "b1_manifest_hash": "ok",
    "stage1_demotions": [ {"step_id": "C3", "from": "R", "to": "RI"} ],
    "llm_overreach": []
  },
  "assessor_stack": { "operator_id": "...", "stage": "stage1-prose-only",
                      "llm": {"provider": "anthropic", "model": "...", "invoked_at": "..."} },
  "human_signoff_required": true,
  "next_step": "Human review and sign-off (rubric R5), then gc_tier1_submit on the anchor."
}
```

Fixed in the emitted report:

- `rubric_version` / `metric_semantics_version` = `"0.2.5"` (schema `const`)
- `human_signoff` = `{"signed": false, "reviewer_id": "PENDING (unsigned draft)"}` — **always**.
  This tool cannot sign; R5 is enforced by construction.
- `report_content_hash` — **omitted**. Schema says omit until submit; the server recomputes it.
- `manifest.chain_record` = `"not-yet-recorded"`, `manifest.supersedes` = `null`.

## 8. Failure modes

| Failure | Behaviour |
|---|---|
| LLM returns non-conforming JSON | error, no report. No repair pass in v0.1 |
| Derived report fails schema validation | error, with the failing pointer |
| `B1ManifestHash.matches?` false | error — indicates the pre-commit inputs were mutated |
| LLM provider auth failure | propagated; `llm_client`'s claude_code fallback applies |
| `dry_run: true` | runs §4 gates + pre-commit, reports the b1 hash it *would* commit, no LLM call |

## 9. Use by the genomicschain.ch free service

The free tier calls this tool with `funnel_stage: "stage1-prose-only"` only, and never calls
`gc_tier1_submit`. Two consequences follow from the rubric rather than from policy:

1. Every free-tier result has `n_R == 0` by §6a. The UI must say "Stage-1 ceiling" and must
   not present R★.
2. `human_signoff.signed` is false, so the result is an unsigned draft. Rubric line 76 permits
   genomicschain.ch to publish **aggregate** statistics only; a named per-paper score needs
   sign-off plus author right-of-reply first. Returning the draft privately to the submitter
   is not publication and is unaffected.

One LLM call per assessment, minutes long. The Rails side must run it as a background job;
this tool is synchronous and does not queue.

## 10. Not in v0.1

- Fetching. The caller supplies `sources` already resolved. DOI → bioRxiv retrieval and
  PDF → text extraction live on the genomicschain.ch side.
- Repair/retry of a malformed LLM response.
- Inter-rater agreement runs (`shared_step_list` is accepted and passed through, but no
  agreement computation).
- Any write to Synoptis or the chain.
