---
name: genomicschain_regwatch
description: >
  Regulatory and standards watch for GenomicsChain and KairosChain. Use when checking
  whether a watched regulation, guideline or standards draft has moved, when a deadline
  is approaching, or when producing a bilingual HTML status report of the watchlist.
---

# Regulatory Watch

Two tools over one hand-edited watchlist. The watchlist is markdown, at
`knowledge/regwatch_watchlist.md`, seeded 2026-09-01 from a ten-pass primary-source
survey (L2 `eu_clinical_data_regulation_survey_2026_09`).

## The three design decisions, and why

**Dated and undated items do not share a mechanism.** "IVDR class C notified-body
agreement, 2026-09-26" is a countdown. "EU GMP Annex 22 finalisation" has *no date* —
EMA is still weighing the consultation outcome — so the only way to notice is to watch
the bytes. Merging them loses whichever one you did not design for.

**Unreachable is a finding, never a pass.** EUR-Lex, ich.org and edps.europa.eu each
blocked automated retrieval during the survey and will sit permanently at
`unreachable`. That is the point: a watcher that reports a blocked source as
"unchanged" converts a blind spot into a green light. Same discipline as Tier-3
reporting `no_target_declared` as a complete result rather than quietly scoring a pass.

**The scanner reports; the operator judges.** A moved digest means a page was edited,
not that an obligation changed. Ruling on which it was is a judgement, and the context
that produced the finding is the wrong one to make it — INV-5, and independently
BSI C5:2026 OPS-33.01AC, which grades "provider verifies in its own service and returns
only the result" as the weakest of four arrangements. So the tool emits a status and stops.

| status | meaning |
|---|---|
| `changed` | the normalised digest differs from the baseline. **Someone must read the source.** |
| `unchanged` | fetched, compared, identical |
| `unreachable` | could not be fetched. Not a pass — a hole. Also covers two answers that *look* like success: any 2xx other than 200, and a 200 whose body normalises to nothing |
| `new` | fetched, but no baseline exists for this id yet |
| `not_checked` | an offline pass: nothing fetched, nothing compared |

`not_checked` exists because the first cut of this package lacked it, and an offline pass
therefore reported all 24 sources as `unchanged` — committing, in its own offline path,
exactly the error the package was built to prevent.

The same error arrived a second time, from outside, on 2026-09-14. EUR-Lex answers an
automated request with **HTTP 202 and a script-only interstitial**; 202 is a 2xx, so the
fetch counted as success, and `text` normalisation stripped the script and left the empty
string. The digest recorded would have been the SHA-256 of nothing, and that source would
have read `unchanged` forever — a permanent green light on the Official Journal text the
published high-risk dates rest on. Both halves are now rejected. The lesson generalises:
**the guard asked whether the fetch failed, and this fetch succeeded.** A blocked source
does not always arrive as an error.

## Workflow

```
gc_regwatch_scan                    → what moved, what is coming due
   ↓  read the changed sources by hand
context_save / chain_record         → your ruling, attributed to you
   ↓
gc_regwatch_scan(record: true)      → accept the new digests as the baseline
gc_regwatch_report                  → standalone HTML, en + ja
```

Scanning has **no side effect**. Recording the baseline is a separate switch, because a
check that rewrites its own reference point on every run cannot be re-run. Record only
*after* reading — recording first discards the finding.

## Tools

### `gc_regwatch_scan`
Fetch each watched source, compare a normalised digest against the baseline, count down
the dated triggers.

- `watchlist` (string): path to the watchlist markdown. Defaults to the shipped one.
- `baseline` (string): path to the baseline JSON. Defaults to `state/regwatch_baseline.json` beside the package.
- `only` (array of string): limit to these ids. A full sweep is slow and invites rate limiting.
- `horizon_days` (integer): how far ahead to list dated triggers (default 120). Overdue items are always listed, with a negative count.
- `offline` (boolean): skip fetching, report the countdown only. Digests are not compared and the report says so.
- `record` (boolean): write the observed digests as the new baseline (default false).

### `gc_regwatch_report`
Render a scan result as standalone HTML — no external CSS, no fonts, no data fetches.

- `scan_json` (string) or `scan_path` (string): the scan result.
- `out_dir` (string): defaults to `log/research/regwatch` under the working directory.
- `lang` (string): `en`, `ja`, or `both` (default).
- `basename` (string): filename stem; the language tag and `.html` are appended.

Status is never carried by colour alone — every chip pairs a glyph and a word with its
colour, because the light-mode warning and serious steps sit below 3:1 contrast by design.

## Watchlist format

One `## <id>` section per item, then `- key: value` lines.

```markdown
## ehds-art73-implementing-act
- kind: dated
- due: 2027-03-26
- title: EHDS Art. 73(5) — secure processing environment implementing act
- url: https://health.ec.europa.eu/...
- watch: text
- binds: European Commission
- why: Drafting closes December 2026 and nobody has written a word about what an SPE must technically be.
```

`watch` selects how much is compared:

| value | behaviour | use for |
|---|---|---|
| `text` (default) | markup and whitespace stripped | ordinary web pages |
| `full` | raw bytes | PDFs — stable, and there is no markup to strip |
| `pattern:<regex>` | only what the regex matches, joined | when one version string or date is the whole signal |

`pattern:` is the answer to a noisy page. Watching an IETF datatracker page whole fires
on every unrelated edit; watching `draft-…-\d+` fires only when the revision moves.

## What it cannot see

- A moved digest does not tell you *what* moved. No text is archived — only a digest.
- A dated item whose date slips without the page changing is invisible. The countdown is
  only as good as the `due` field, which is hand-maintained.
- Normalisation strips layout, so a layout-only change is invisible and a change to
  unrelated boilerplate on the same page still fires. Narrow with `pattern:` when it matters.
