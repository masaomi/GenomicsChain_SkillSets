# Regulatory check — the line, and why it is not a package yet

Three artefacts in a line. Only the first is a SkillSet; the other two are deliberately not,
and this file records the condition under which that changes.

```
(1) watch                    (2) frame                     (3) check
genomicschain_regwatch       guidance.json                 check_record.json
72 watched sources           41 points, 67 sources         one subject, one date
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
(Superseded 2026-10-04: the consolidated text is now watched through the Publications Office
Cellar list of versions, corrigenda and amending acts, so those claims can be re-dated by machine.)

A published check that cannot tell a reader the text underneath it moved should not be
published. That is why the join came before the publication and not after.

## What exists

| Piece | Where | State |
|---|---|---|
| Watch | `genomicschain_regwatch` v0.1.2 — 80 sources (8 added 2026-10-20: seven GCP sources for Tier 6 and the AI Act harmonised-standards decision; 42 added 2026-10-04: FDA, Swissmedic, FADP, GDPR, CRA, the sources the two published pages cite, eight Swiss statutes through the fedlex SPARQL version list, and five EU acts through the Publications Office Cellar SPARQL list of versions, corrigenda and amending acts), `gc_regwatch_scan`, `gc_regwatch_report` | SkillSet, installed normally. Baseline recorded for 78 of 80 as of 2026-10-20 (the other 2 cannot be fetched: an IVDR page that returns 404, and the EUR-Lex text of the AI omnibus, kept to show the block); before that only 6 of 30 had one, so 24 sources had never been compared |
| Frame | `GenomicsChain_2025/data/eu_ai_act/guidance.json` v0.2.1 at `/eu-ai-act`, and `data/data_regulation/guidance.json` v0.1.1 at `/data-regulation` (GCP, FDA, Swiss research law, GDPR, FADP) — both live at genomicschain.ch, last updated 2026-10-20 | Rails data files, not a package |
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

## The legal boundary

Survey of 2026-10-20, six seats (Switzerland, EU member states, EU horizontal law, the US,
Japan, cross-border enforcement). Research support by agents, not legal advice. The full survey
is kept by the operator and not published: it contains the question lists prepared for lawyers.
This section governs both the check (Tier 5) and anything published from the watch.

**This section is dated, not watched.** The statutes and guidance it cites (RDG, Loi n° 71-1130,
弁護士法, the Japanese MOJ guidelines, the Swiss Ukraine ordinance) are not on the regwatch
watchlist, so nothing here goes stale automatically. Read it as of 2026-10-20.

**Publishing general information is outside the reserved work everywhere surveyed.**
RDG § 2 Abs. 3 Nr. 5 and Loi n° 71-1130 art. 66-1 say so expressly; 弁護士法 72条 and US UPL
law reach application to a concrete matter, not general commentary. The rules for pages and
summaries built from regwatch findings live in `genomicschain_regwatch/plugin/SKILL.md`
§ Publishing what the watch finds: stay general, never the label 法律相談 / legal advice
(弁護士法 74条), a person reads the full text before release (EU AI Act Art. 50(4)
exemption), every item dated and sourced.

**For the check itself, free and anonymous is riskier than paid B2B on almost every axis.**
Without a contract there is no forum clause, no liability cap and no GDPR Art. 28 processor
contract, consumers are in scope, and an EU user can sue at home and enforce in Zurich under
the Lugano Convention. "Free" does not lift the German reservation (RDG § 6 Abs. 2 requires a
qualified person even for free services), does not lift US UPL in most states, and does not
lift Swiss liability for gross negligence (OR Art. 100 Abs. 1).

**Three places where the current design leaks**, found independently by the DE, US and JP seats:

1. A legal term inside a "technical" question ("does it process personal data?") makes the
   LLM classify under law. Rewrite in technical terms ("does it read columns holding name,
   birth date or genome sequence — which line?").
2. Showing, hiding or reordering legal text according to the customer's code facts is the
   software-applies-law-to-facts pattern (*Parsons*, *Janson v. LegalZoom*). Legal text is
   identical and in the same order for every customer.
3. LLM prose that summarises legal meaning reaching the customer (JP MOJ グレーゾーン回答
   2025-08-04; OLG Hamm 4 UKl 3/25 attributes chatbot statements to the operator).

Strongest additional measure proposed: all legal text in one public, versioned frame
document; the per-customer report carries only code facts, cited lines and the frame
version. For Germany, keep German national law out of the frame to preserve the RDG
§ 1 Abs. 2 argument (a service given only from abroad is covered only if its subject is
German law).

**What does not work:** the user's lawyer-check consent helps on liability, not on whether
the activity is reserved (JP グレーゾーン回答 2022-10-14); any benefit from lawyer referrals is
周旋 under Japanese law. Disclaimers were decisive only in Texas.

**Hard requirement:** block Russia and the annexed territories — Swiss Ukraine ordinance
Art. 28e bans legal advisory, IT consultancy and AI-model access services to Russian
entities, free or not.

**Packaging a free skill.** Releasing summaries or the check as a downloadable skill tied to
a paid tier counts as monetisation (AI Act recital 103, PLD recital 14, CRA recital 15 — CRA
Art. 14 reporting applies since 2026-09-11) and as possible indirect remuneration in Japan
(2023 MOJ guideline § 1(2)) and France (art. 54 requires paid activity). A free package not
used to sell anything keeps those exemptions. Decided 2026-10-20: Tier 5 is published as free OSS under four conditions (no tie to a paid service; users run it with their own LLM keys; the design rules above stay in the code; no individual consultation), and Tier 6 (GCP self-assessment checklist) follows the same conditions. GenomicsChain itself runs Tier 5 and Tier 6 only on its own system — code, hosted service and procedures — and not on data registered on the chain (signer identities would otherwise be sent to LLM providers). Paid services are limited to reproducibility. Recorded in the operator's KairosChain instance (L2 `decision_tier5_oss_tier6_gcp_20261020`, `decision_tier56_own_system_scope_b2b_reproducibility_20261020`).

No lawyer has been consulted yet. Planned order: Switzerland, then Germany, then Japan before Japanese customers.

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
