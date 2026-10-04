# Regulatory check — the line, and why it is not a package yet

Three artefacts in a line. Only the first is a SkillSet; the other two are deliberately not,
and this file records the condition under which that changes.

```
(1) watch                    (2) frame                     (3) check
genomicschain_regwatch       guidance.json                 check_record.json
67 watched sources           41 points, 67 sources         one subject, one date
digest drift + countdown     articles, quotes, verdicts    questions, discrepancies
        │                            │                            │
        │  a source moves            │  a point goes stale         │  a record goes stale
        └────────────────────────────┴────────────────────────────┘
                     scripts/gc_regcheck_staleness.rb
```

The join is the load-bearing piece. Before 2026-09-14 the frame's freshness was one
hand-set `as_of` covering the whole page, and nothing said which of the sixteen claims that
date actually covered. The answer, once computed, was **three**. Eleven rest on
`eurlex-consolidated`, which EUR-Lex will not serve to an automated client, so no machine
can ever mark them fresh — only a person reading the Official Journal can re-date them.

A published check that cannot tell a reader the text underneath it moved should not be
published. That is why the join came before the publication and not after.

## What exists

| Piece | Where | State |
|---|---|---|
| Watch | `genomicschain_regwatch` v0.1.2 — 67 sources (37 added 2026-10-04: FDA, Swissmedic, FADP, GDPR, CRA, the sources the two published pages cite, and eight Swiss statutes through the fedlex SPARQL version list), `gc_regwatch_scan`, `gc_regwatch_report` | SkillSet, installed normally. Baseline recorded for 64 of 67 on 2026-10-04 (the other 3 cannot be fetched); before that only 6 of 30 had one, so 24 sources had never been compared |
| Frame | `GenomicsChain_2025/data/eu_ai_act/guidance.json` v0.2.0 at `/eu-ai-act`, and `data/data_regulation/guidance.json` v0.1.0 at `/data-regulation` (GCP, FDA, Swiss research law, GDPR, FADP) — neither deployed as of 2026-10-04 | Rails data files, not a package |
| Join | `scripts/gc_regcheck_staleness.rb` rules 0.1.0 | Operator script, alongside `gc_submit_client.rb` |
| Check, run 1 | kept outside this repository — subject a third party's internal system | Record 0.1.1. **Not published** — operator decision 2026-09-14: the subject is someone else's system |
| Check, run 2 | kept outside this repository — subject the hosted site | Record 0.2.0, `trust_tier: self_reported` |
| Check, run 3 | kept outside this repository — subject core / tier1 / tier2 / tier3 | Record 0.2.1. **Publishable**: our own MIT-licensed code, every cited line openable by a reader |

## The packaging rule

**The rule was: do not extract a `genomicschain_regcheck` package until run 3. Run 3 happened
on 2026-09-14. The condition is met and has deliberately not been exercised.**

The reason is what the three runs did to the record shape. It moved every time:

```
0.1.1  run 1  a third party's system, under a brief
              no frame block — a record can only be aged against law_version,
              and therefore reads fresher than it is
0.2.0  run 2  the hosted site
              + frame.points_relied_on, + trust_tier, + precommitment
0.2.1  run 3  the distributed packages
              + subject.kind (service | distributed_software)
```

`subject.kind` had to exist because **the same question has a different correct answer
depending on what kind of thing is being checked**. Q0 and Q2 are `settled` for a service
with an open endpoint and `undecided` for source code in a repository; Art. 2(12) is
irrelevant to one and central to the other. Version 0.2.0 had no field saying which was
being answered, so its answers were unsituated.

Three shape changes in three runs is not a shape that has stopped moving. Extracting now
would freeze into a schema whatever run 4 turns out to need to say differently. This follows
the selective-survival stance: implement, observe, let unfit configurations die, package what
survives contact — and a form that changed on every one of its three uses has not yet
survived anything.

**Revised condition**: extract when two consecutive runs need no new field.

**When it is extracted, two things move into the schema rather than staying in prose:**

1. The verdict vocabulary has no value meaning "compliant". It is not that the word is
   discouraged — there is no field it can go in. Same construction as Tier-1's
   `human_signoff.signed`, which is always `false` because R5 needs a human.
2. `trust_tier` is required, and `self_reported` is the default. A record that does not say
   how weak it is, is weaker than one that does.

## The publication gate

Publishing is the operator's decision, per operation, and is separate from any decision
about a public route for anchor records.

Prepared, not deployed, as of 2026-09-14:

- `/eu-ai-act` now carries per-claim freshness and a page-level line saying how much of it
  cannot be machine-checked. `/eu-ai-act/staleness` serves the join for audit.
- `log/regwatch/report/regwatch_{en,ja}.html` — the watch report, standalone, both languages.
  A narrowed scan now says so in the masthead; before 2026-09-14 a 7-of-30 pass rendered
  identically to a full sweep.
- The run-2 check record and its Japanese report.

**Run 3 is the publication candidate.** Subject is our own MIT-licensed code in a public
repository, so every file and line the record cites can be opened and checked against it.
No third party's system, names or infrastructure appear.

**Run 1 is not published.** Operator decision, 2026-09-14: its subject is someone else's
internal system. That is a decision about whose system it is, not about whether the text
could be scrubbed — subject consent, not redaction, is the gate on any check whose subject
is someone else. The record is kept outside this repository.

## What run 3 found that is not a legal matter at all

Tier-1 sends no `temperature` to the model, so scoring determinism is given up and the
provider default applies. The decision is sound — Sonnet 5 rejects a non-default temperature
with a 400 — and it is recorded in a code comment at
`genomicschain_tier1/lib/genomicschain_tier1/assess/assessor.rb:148-151`, and **nowhere a
user looks**: not `README.md`, not the Tier-1 `SKILL.md`.

So the tool that scores reproducibility does not itself produce reproducible scores, and
nothing published says so. A report records `provider`, `model` and `invoked_at`, so the
fact is recoverable after a run and undiscoverable before one. This is the finding the
warranty rule speaks to most directly — we guarantee our record and our procedure, and the
procedure has a variance the published description does not carry.

Two things would settle how much it matters, and neither was done: read the Tier-1 prompts
(a prompt can constrain variance the parameter no longer does), and read the 28 stored
reports from 2026-09-08 to see whether the variance is visible in practice.

## Next step, named

No run so far has had an independent checker. Run 2 was the worst case — the context that
built the join also used it. Run 3 is one step better: core, tier1, tier2 and tier3 were not
touched in that session, so the checker was not reviewing its own code, but it did author
the frame join and the record shape it wrote into. Run 1 was strongest on this axis and is
the model: a checker with no conversational context, handed only the brief.

The repair is the same for both and it is cheap: hand `PRECOMMITMENT.md` to a context-free
checker, run it, and diff the two records. Until that is done, `self_reported` on runs 2 and
3 is the accurate grade rather than a formality.
