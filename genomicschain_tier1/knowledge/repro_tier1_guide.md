---
name: repro_tier1_guide
description: repro_tier1_assessor scoring guide (rubric v0.2.5) — operational brain for Tier-1 (static, no-compute) computational-reproducibility readiness assessment of a genomics/bioinformatics paper. Standards-aligned (NASEM 2019, ACM Artifact Badging), 4-axis scoring, symmetric env-closure gating, per-step env_capture_class (A/B/C, code-verified), two orthogonal levers, 13-type gap dictionary, human-sign-off gate.
tags: [reproducibility, tier1, scoring-rubric, genomics, assessment, self-contained]
readme_lang: en
---

# repro_tier1_assessor — Scoring Guide (rubric v0.2.5, self-contained)

Operational brain for a Tier-1 (static, no-compute) computational-reproducibility **readiness** assessment of a genomics/bioinformatics paper. Consumer: the assessor LLM. Canonical output: `report.json` (schema `report_schema_v0_2_5.json`); the human report is RENDERED from it. Human-in-the-loop is MANDATORY: the LLM PROPOSES; a human reviewer signs off before any attestation/publication (AI extraction is weak — CORE-Bench best agent 21% on hardest tier).

**Tier-1 = READINESS, not reproduction.** Never call a paper "reproducible" from Tier-1 — say "ready for a reproduction attempt / documented sufficiently". "Reproduced" is Tier-2 only.

**Metric-semantics stamp.** Every report carries `metric_semantics_version: "0.2.5"`. `static_readiness` changed meaning between v0.2.1 (`strict`) and v0.2.5. Pooling MUST refuse to mix versions; label any old column "v0.2.1 strict (different definition)".

## Standards alignment (cite, don't reinvent)
- Scope = **NASEM 2019 "reproducibility"** (same input data+code+methods → consistent results). Not replicability, not scientific validity, not wet-lab.
- Verdicts map to **ACM Artifact Badging v1.1**: R★≈Available+Functional (→Results Reproduced on Tier-2); RI≈Available-not-turnkey; NI≈below Evaluated; X≈not Available. ACM: "exact reproduction not required, within tolerance" → stochastic steps score by distributional match.
- Graduated tiers echo **Essawy 2020** ("runnable"≈RI). Scale precedent = **FAIRsoft** (43,987 tools) — but FAIRness ≠ re-execution reproducibility.

## R★ — what the Tier-1 top verdict means (read first)
**R★ = "declared-environment closure (unexecuted)".** All four axes captured + statically valid for the DECLARED environment, but NOT executed. Tier-1 cannot detect UNDECLARED dependencies. Tier-2 `R` (executed + matched) is a different, higher bar.
- Quote R★ ONLY with the "unexecuted" qualifier.
- Apply the qualifier SYMMETRICALLY: a `static_readiness = 0` must never be quoted without "under-claims by construction — Tier-1 cannot credit an undeclared-but-present dependency." Both the high number and the zero are bounded statements about *declared* state, not ground truth.

## Step 0 — Paper-type router (human-confirmed, contestable — route dominates the score)
- **pure-computational (application)** → evidence = Methods prose. Target = reproduce results.
- **mixed (application)** → scope-split; wet-lab = OOS.
- **pure-wet-lab** → "not applicable / documentation-audit only".
- **tool/methods (workflow)** → evidence = CODE REPO. Metric = **"pipeline executability readiness"** (NOT "reproducibility"). Denominator = PIPELINE steps only. Matching authors' externally-deposited EXACT outputs is a Tier-2 target.
- **hybrid (application+shipped pipeline)** → dual-score (flag for human decision).

## Steps 1–7 — build the step list
1. **Granularity anchor (critical — |S| controls every ratio):** derive steps from an OBJECTIVE source. If a workflow file exists (Snakefile/CWL/Nextflow/WDL/Makefile) → one step per distinct rule/tool-invocation. Else → one step per named tool invocation. Record `step_source`, `n_steps`, `granularity_note`. For inter-rater work use a SHARED canonical step list.
2. Resolve every artifact; record VERBATIM liveness (200/403/auth/dead) + timestamp + network context. A dead link may survive in an AUTHORITATIVE archive → redundancy-rescue (bounded search only).
3. Static-analyze code: hardcoded paths, floating vs pinned versions, bugs. **Detect environment capture** (pixi.lock/conda-lock/renv.lock/Docker digest) → score via the symmetric env-closure gate (Step 8, Version axis). Record `lock-present-unexecuted`.
4. License-classify each tool: open / **commercial-but-pinned** (`license-gated`, Version=1) / unknown (Version=0).
5. Scope-split each step C (computational) or W (wet-lab → OOS).
6. Tag gaps against the 13-type dictionary.

## Step 8 — score (per C-step, 4 axes 0/1/2)
- **Data**: 2 = public+accessible OR **controlled-access legitimate** (accession resolves + DAC path documented → flag `controlled-access`, NOT penalized); 1 = accidental gating/missing id; 0 = absent/lost.
- **Code**: 2 public+exact; 1 reconstructable; 0 absent/private.
- **Version (SYMMETRIC ENV-CLOSURE GATING):** version=2 (exact capture) ONLY if the capture — by ANY mechanism — provides **environment closure**, statically evidenced: pins interpreter/runtime version, pins package source/channel/index (not just names+versions), declares the platform(s) claimed, AND covers the declared-manifest direct deps. A true lockfile / recorded-digest image typically satisfies this. **Scattered `==` pins in prose or a bare `requirements.txt` without interpreter+channel+platform → version=1**, subflag `exact_pins_partial`. Unpinned/`>=` → version=1. `license-gated` → 1. Unknown → 0.
  - **version_subtier** (report when version=1, ordered): `release_snapshot` (dated BioC/CRAN release + stated interpreter) > `exact_pins_partial` (exact pins, no env closure) > `floating` (`>=`/unpinned/mutable tag).
  - Static form ≠ resolves/installs: a never-built but well-formed lock is `capture-static-only` and still only reaches R★ (never Tier-2 R). The "covers system libraries the code imports" check is Tier-2 (`syslib-closure-unchecked`).
- **Params**: 2 all; 1 partial; 0 none.

Verdict from axis-min + ceilings: **R★=all 2** (declared-env closure, unexecuted); RI=every axis≥1; NI=any 0 but recoverable; X=unrecoverable; OOS=wet-lab (excluded from |S|). Ceilings: proprietary→max NI (exact X); private-though-"public"→NI unless fully described (→RI); stochastic no-seed→max RI `distributional-only` (a `seed` clears it only if shown CONSUMED).

## fetch-required — external reference resources (DB/genome/index/taxonomy); classify by reading the WORKFLOW, not prose
For every step consuming an external reference resource, assign exactly one `env_capture_class`, decided by the executable workflow (this is a **Stage-2 code-verified** classification — collection protocol Δ-B):
- **A_verified_in_code** — a download rule/script fetches a specific versioned artifact (versioned DOI/accession/URL-with-fixed-version, or a digest). Cite the rule. → keeps **R★-eligibility** (subflag `fetch-required`).
- **B_pin_prose_only** — the workflow consumes a user-supplied local path / directory; the pinned DOI/version lives ONLY in README/paper prose. The *workflow* pins nothing. → caps the step at **RI** (`fetch-pin-prose-only`).
- **C_mutable_latest** — code fetches a rolling/unversioned resource (`latest`, current-NCBI-nt, a `master`-branch raw file, a `:latest` image tag). → **fatal** below R★ (`mutable-fetch-fatal`); poisons every downstream consumer.
- `n/a` — pure compute on workflow-internal intermediates (no external resource).
Rules: "large or external" is NOT disqualifying if class A. `mutable/latest → fatal` overrides that. Without the code-check (Stage-1 prose-only), do NOT assign A/B/C — leave `n/a` and set `funnel_stage: stage1-prose-only`; R★ requires Stage-2 verification.

## Headline — TWO orthogonal levers lead; per-paper ratios are secondary
Let n(V)=count of C-steps with verdict V; |S|=total C-steps.
- **Survey headline = two independent paper-level Bernoulli levers (report SEPARATELY, never merged):**
  - **Lever 1 — software environment lock:** % papers shipping a statically-complete environment lock (RESOLUTION UNVERIFIED) for a declared platform. (Never "validated" — Tier-1 declines the resolve test.)
  - **Lever 2 — in-code reference-DB pinning:** % papers whose workflow obtains ALL external DBs via class A (no B, no C).
- **static_readiness = n(R★)/|S|** — a WITHIN-paper descriptor, reported ONLY when `has_validated_env_capture=true`. FORBIDDEN to present without the inline "unexecuted; declared env statically valid but not verified" qualifier AND co-reporting `n_exact_capture_unexecuted` + `n_fetch_required` (a static_readiness whose R★ steps are mostly `fetch-required` hides the Tier-2 download burden).
- **Upper bound** = (n(R★)+n(RI))/|S| — "readiness upper bound", never "reproducible".
- 要調査率 = n(NI)/|S| · 不能率 = n(X)/|S| · 計算被覆率 = |S|/(|S|+|W|)
- **ReproIndex** (1.0·R★+0.6·RI+0.2·NI+0·X)/|S|: weights are GUESSES until Tier-2. Emit ONLY as tuple `(index, coverage, |S|)`; refuse when |S|<4; 1-sig-fig.
- **§10 cross-paper firewall:** cross-paper statements use the two levers + per-axis version-subtier distributions. NEVER rank papers by any within-paper ratio; drop the ratio column from cross-paper tables.
- **Assessability (R14):** if the paper can't be assessed, that is a SCORED outcome, not a silent drop; the assessable fraction is a headline.

## Gap-type dictionary (13 + rescue patterns)
1 検体対応欠落 · 2a 版記載なし / 2b 浮動版下限 · 3 リンク腐敗(権威あるミラーで救済) · 4 確率的(seed欠落→分布一致) · 5 custom DB/script非公開 · 6 サブパイプライン外部化 · 7 環境ハードコード · 8 公開コードのバグ · 9 非公開コード · 10 非計算wet-lab(OOS) · 11 プロプライエタリ依存 · 12 解析コード未寄託/未リンク · 13 帯域外/未pin参照DB配布(prose-DOI-only=B, mutable=C).
Rescue (check before penalizing): **redundancy-rescue** (authoritative mirror only). NOTE: lockfile presence no longer auto-caps at RI — it is scored through the Step-8 symmetric env-closure gate (a lock passing the gate reaches R★).

## Output & attestation
Emit `report.json` (schema `report_schema_v0_2_5.json`) with raw counts, per-step array (stable step_id, `env_capture_class`, `version_subtier`), the `levers` block, gaps, verbatim liveness, `contested_corrected`, `human_signoff`, `manifest` (B1 hash pre-committed BEFORE scoring), `metric_semantics_version`, `funnel_stage`. Render the human report from it. **MANDATORY: human sign-off before any on-chain attestation or per-paper publication** (R5). Deliverable is an "assessment / evidence report", NOT a "certificate". Scores are contestable + SUPERSEDABLE per Prop 10. genomicschain.ch shows AGGREGATE stats only (two levers, denominators, funnel counts, assessable fraction); a NAMED per-paper score requires sign-off + author right-of-reply first.

## Validation fixtures (gold set — scoring-layer calibration)
- **aMeta (10.1186/s13059-023-03083-9) = canonical fetch-required Class-B/C example.** Real Snakemake code check (branch main, 2026-07-21): conda-lock (linux-64) is a genuine software env lock, but 0 rules fetch a pinned DB (10 Class-B local paths, 3 Class-C rolling-master taxonomy). Prose+repo-landing scored 30/30 R★; the CODE gives **17 R★ / 13 RI**. Lever 1 = yes, Lever 2 = no. This is why R★ requires Stage-2 code verification.
- Pilot n=9 under v0.2.5: Lever 1 (software env lock) = 1/9, Lever 2 (in-code DB pin, class A) = 0/9; the other 8 have no env closure (version=1/floating/code-bound) → static_readiness 0.
- Extraction-layer validation (independent re-assessment = inter-rater κ study) is deferred, NOT done — see `repro_collection_protocol` (two-stage funnel + agreement subset).
