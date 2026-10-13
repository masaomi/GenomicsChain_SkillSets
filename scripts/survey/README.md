# scripts/survey — the Tier-1 survey procedure

These are the scripts and prompts that drew, read and analysed the Tier-1 readiness survey of bioRxiv
genomics preprints (rubric v0.2.5). They are **byte-identical copies** of the files as run in the
author's `corpus/repro_survey_2026_07/`; they were not edited for publication, so their SHA-256 can be
checked against the hashes recorded on the author's instance ledger before each run. That is also why
absolute paths of the author's machine remain in some of them.

What is **not** here, and why: the per-paper reports, the item and order lists (they name every paper),
the fetch manifests and the excluded reads. A named per-paper score is published only with the authors'
sign-off and right of reply, and none has had either (decision of 2026-09-25, commit `ece3856`). Without
those files the analysis scripts cannot be run; they are published so that the procedure behind every
aggregate figure can be read and contested, and checked against a later deposit.

The sample itself is re-derivable from public data: `frame_fetch.rb` and `extension_items.rb` /
`q3_draw.rb` rebuild the frames from the bioRxiv API and refuse to draw unless the registered frame hashes
match. Which papers were drawn is therefore checkable; how each one scored is not published.

| File | Role | Ledger record of its hash |
|---|---|---|
| `sampler.rb` | the July 2026 draw: builds the 2025-Q4 frame from the bioRxiv API and takes the seeded shuffle | sampling pre-registration v1.1, 2026-07-27 (on the earlier instance's ledger) |
| `stage1_assessor_prompt.md` | stage-1 assessor prompt (rubric v0.2.5) | held constant since July; `ca714cda…` in the re-read registrations |
| `stage2_assessor_prompt.md` | stage-2 assessor prompt | — |
| `rater3_batch1_workflow_2026_09_30.js` | rater 3 (claude-opus-5-5, xhigh), original draw idx 1–100 | launch record, 2026-09-30 |
| `rater3_batch2_retest_workflow_2026_10_01.js` | rater 3, idx 101–201 and the 20-paper retest | launch record, 2026-10-01 |
| `extension_items.rb` | rebuilds the 2025-Q4 frame from the July API cache; next positions of the July shuffle | extension record, 2026-10-12 |
| `extension_trial100_workflow_2026_10_12.js` | Q4 extension, positions 202–302 | launch record, 2026-10-12 |
| `extension_workflow.js` | Q4 extension, positions 303–637 (items via args) | launch records, 2026-10-12/13 |
| `frame_fetch.rb` | builds and hashes the 2025-Q3 frame, no draw | Q3 sampling pre-registration, 2026-10-13 |
| `q3_draw.rb` | the registered Q3 draw (seed 202610131, n = 372) | Q3 sampling pre-registration, 2026-10-13 |
| `q3_workflow.js` | Q3 reads (items via args) | launch record (to come) |
| `stats_stage1.rb` | statistics of the July reading (claude-opus-4-6) | — |
| `stats_rater3.rb` | statistics of the rater-3 reading, per stratum | — |
| `agreement.rb` | agreement between readers (κ, AC1, ICC, Bland–Altman) | analysis rules fixed 2026-10-13 before first run |
| `aggregate.rb`, `build_submit_set.rb`, `add_report_content_hash.rb`, `b1_manifest_hash.rb` | July pipeline: aggregate page, submit set, report content hashes | — |

The workflow scripts run under Claude Code's Workflow tool: one subagent per paper, ten in parallel. After
every run the reads are checked from outside — schema, assessor fields, the pre-committed manifest hash,
the model identifiers in the subagent transcripts (a read in which any response came from a model other
than the registered one is excluded), and a scan of the subagents' tool calls for access to other readers'
reports.
