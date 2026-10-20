# Regulatory and standards watchlist — GenomicsChain / KairosChain

**Seeded 2026-09-01** from the ten-pass primary-source survey recorded at L2
`eu_clinical_data_regulation_survey_2026_09`. Every entry from that seeding earned its
place by appearing in the survey as either a dated trigger or an unresolved question.

**Second admission route, from 2026-09-14.** An entry may also be added because a
*published* page of ours rests on it. The EU AI Act page at `/eu-ai-act` names 15 sources;
each now carries a `watch_status`, and the 7 marked `watched` point at ids on this list.
The join is recorded on the guidance side (`data/eu_ai_act/guidance.json`, key `watch`) and
computed by `scripts/gc_regcheck_staleness.rb`, so that a published claim can be told that
the text underneath it moved. An entry admitted this way says so in its `why`.

## How to edit this file

One `## <id>` section per watched item, then `- key: value` lines. Keys:

| key | meaning |
|---|---|
| `kind` | `dated` (a countdown) or `undated` (watch the bytes). Default `undated`. |
| `due` | ISO date. Required when `kind: dated`. |
| `title` | One line, human-readable. |
| `url` | What to fetch. Omit only if nothing is fetchable. |
| `watch` | `text` (default, markup stripped), `full` (raw bytes — right for PDFs), or `pattern:<regex>` (compare only what the regex matches). |
| `binds` | Who carries the obligation. |
| `why` | Why this is on the list. Keep it to the sentence that would make a future reader care. |

**Two rules learned the hard way.** A source that blocks automated fetch is reported
`unreachable` forever, and must be read by hand — it is never scored as unchanged;
several entries below are permanently in that state and that is the point. And the
scanner never rules on whether a change matters: it says a digest moved, and the
operator decides what that means.

---

# Dated triggers

## ivdr-class-c-nb-agreement
- kind: dated
- due: 2026-09-26
- title: IVDR class C — written agreement with a notified body
- url: https://health.ec.europa.eu/medical-devices-topics-interest/vitro-diagnostic-medical-devices-ivds_en
- watch: text
- binds: IVD manufacturers with legacy class C devices
- why: Applying is not enough — the agreement must be concluded within four months of application. Miss it and the device loses its transition benefit. This is a customer's deadline, not ours, but it is the sharpest conversation opener with anyone holding a companion diagnostic.

## eu-gdi-project-end
- kind: dated
- due: 2026-10-31
- title: EU Genomic Data Infrastructure — project end
- url: https://gdi.onemilliongenomes.eu/
- watch: text
- binds: European Commission / GDI consortium
- why: Not a procurement window. Three nodes finished phase 1 of 3; the production catalogue holds 20 datasets of which at least 12 are synthetic; the final deliverable is a video; Genome EDIC does not exist. Watch what replaces it, if anything.

## eic-accelerator-cutoff
- kind: dated
- due: 2026-11-04
- title: EIC Accelerator cut-off
- url: https://eic.ec.europa.eu/eic-funding-opportunities/eic-accelerator_en
- watch: text
- binds: applicant
- why: Switzerland has been associated to Horizon Europe with EIC access since 2025. Grant up to EUR 2.5M plus EUR 0.5–10M equity. Requires an incorporated SME, so it is out of reach until incorporation.

## ich-e6-r3-annex-2-eu-applies
- kind: dated
- due: 2027-01-15
- title: ICH E6(R3) Annex 2 applies in the EU
- url: https://www.ema.europa.eu/en/scientific-guidelines/ich-e6-good-clinical-practice
- watch: text
- binds: sponsors and investigators in the EU
- why: Added 2026-10-04. ICH adopted Annex 2 at Step 4 on 2026-06-03; the EU applies it from 2027-01-15. FDA still listed it as draft on 2026-10-03 and the Swiss application date could not be found, so the same text arrives on three different dates. Annex 2 is where decentralised and pragmatic trial elements, and the data they generate, are addressed.

## ehds-art73-implementing-act
- kind: dated
- due: 2027-03-26
- title: EHDS Art. 73(5) — secure processing environment technical implementing act
- url: https://health.ec.europa.eu/ehealth-digital-health-and-care/european-health-data-space-regulation-ehds_en
- watch: text
- binds: European Commission
- why: The highest-leverage open door found anywhere in the survey. Drafting closes December 2026 and nobody has written a word about what a secure processing environment must technically be — the EDPB–EDPS joint opinion on the EHDS proposal contains zero occurrences of the phrase. TEHDAS2's draft input is a virtual desktop with no mention of trusted execution.

## gdpr-procedural-regulation-applies
- kind: dated
- due: 2027-04-02
- title: GDPR procedural regulation (EU) 2025/2518 applies
- url: https://publications.europa.eu/webapi/rdf/sparql?query=PREFIX+cdm%3A+%3Chttp%3A%2F%2Fpublications.europa.eu%2Fontology%2Fcdm%23%3E+PREFIX+xsd%3A+%3Chttp%3A%2F%2Fwww.w3.org%2F2001%2FXMLSchema%23%3E+SELECT+DISTINCT+%3Fcelex+WHERE+%7B+%7B+%3Fw+cdm%3Aresource_legal_id_celex+%3Fcelex+.+FILTER%28STRSTARTS%28STR%28%3Fcelex%29%2C+%2202025R2518%22%29+%7C%7C+STRSTARTS%28STR%28%3Fcelex%29%2C+%2232025R2518R%22%29%29+%7D+UNION+%7B+%3Fb+cdm%3Aresource_legal_id_celex+%2232025R2518%22%5E%5Exsd%3Astring+.+%3Fa+cdm%3Aresource_legal_amends_resource_legal+%3Fb+.+%3Fa+cdm%3Aresource_legal_id_celex+%3Fcelex+.+%7D+%7D+ORDER+BY+%3Fcelex
- watch: text
- binds: supervisory authorities; parties to cross-border complaints and investigations
- why: Added 2026-10-04. In force 2026-01-01, applies from 2027-04-02, and its Chapters III-IV only to complaints and ex officio investigations started after that date. It changes how a cross-border case against a controller runs, not what the controller must do. Watched through the Cellar SPARQL list of its versions, corrigenda and amending acts (EUR-Lex itself refuses automated clients); the countdown is the point.

## bsi-c5-2026-applies
- kind: dated
- due: 2027-06-01
- title: BSI C5:2026 applies — OPS-32 / OPS-33 become auditable criteria
- url: https://www.bsi.bund.de/EN/Themen/Unternehmen-und-Organisationen/Informationen-und-Empfehlungen/Empfehlungen-nach-Angriffszielen/Cloud-Computing/Kriterienkatalog-C5/kriterienkatalog-c5_node.html
- watch: text
- binds: cloud service providers offering confidential computing
- why: The only European text that gives confidential computing an auditable vocabulary, and the only body that accepts TEE attestation as evidence at all. Conditional — it applies only if a provider offers confidential computing — so it legitimises a market rather than creating one. OPS-33.01AC's four-level attestation-strength ladder is the design constraint: provider-verifies-and-returns-only-the-result is graded weak.

## ai-act-annex-iii-high-risk
- kind: dated
- due: 2027-12-02
- title: AI Act Annex III high-risk obligations apply
- url: https://artificialintelligenceact.eu/article/6/
- watch: text
- binds: providers and deployers of Annex III systems
- why: Deferred from 2026-08-02 by Regulation (EU) 2026/1744, in force 2026-07-27. Annex III lists none of drug discovery, trial analytics or variant calling — so this date mostly does not bite. Watch it anyway, because the omnibus proved the Commission will move deadlines under pressure and no harmonised standard is yet cited in the Official Journal.

## cra-steward-reporting
- kind: dated
- due: 2027-12-11
- title: Cyber Resilience Act — open-source steward reporting obligation (Art. 24(3)) applies
- url: https://digital-strategy.ec.europa.eu/en/policies/cra-open-source
- watch: text
- binds: open-source software stewards
- why: Added 2026-10-04. Manufacturer reporting (Art. 14: early warning within 24 hours) has applied since 2026-09-11. Supplying non-monetised free and open-source software is not a commercial activity, and stewards carry Art. 24 duties without fines (Art. 64(10)); steward reporting starts on this date. Our assessment code is MIT-licensed and public, so which of these roles we occupy is the question to settle before then. Guidance C(2026) 5252 (2026-07-27) annex not yet read.

## ai-act-annex-i-high-risk
- kind: dated
- due: 2028-08-02
- title: AI Act Annex I high-risk — including MDR/IVDR products
- url: https://artificialintelligenceact.eu/annex/1/
- watch: text
- binds: providers of AI that is, or is a safety component of, an MDR/IVDR device
- why: This is where a genomic pipeline actually gets caught: MDR is Annex I Section A item 11, IVDR item 12, and the Art. 6(3) escape filters are not available to Annex I. The trigger is the intended purpose, not the algorithm — the same pipeline is out of scope in internal R&D and high-risk inside a companion diagnostic.

## ehds-secondary-use-omics
- kind: dated
- due: 2031-03-26
- title: EHDS secondary use — genomic, omics and clinical-trial data
- url: https://health.ec.europa.eu/ehealth-digital-health-and-care/european-health-data-space-regulation-ehds_en
- watch: text
- binds: data holders
- why: Not 2029. And a Swiss entity cannot be an EHDS data user before roughly 2035 without an EU establishment, because the Art. 91(2) reciprocity implementing act does not exist and Art. 75(5) carries a ten-year transition.

---

# Undated — watch the bytes

## ema-computerised-systems-gcp
- kind: undated
- title: EMA guideline on computerised systems and electronic data in clinical trials (EMA/INS/GCP/112288/2023)
- url: https://www.ema.europa.eu/en/documents/regulatory-procedural-guideline/guideline-computerised-systems-and-electronic-data-clinical-trials_en.pdf
- watch: full
- binds: sponsors and investigators
- why: The operative instrument for this whole business. Section 6.6 is the only place in the European corpus that names a distributed tamper-proof ledger, and section 4.4 is the obligation with no method ("it should be possible to validate the correct operation of the processing"). If either sentence moves, the business case moves. A PDF, so raw bytes are the right comparison. Scope note, 2026-10-04: the section 4.4 sentence sits under "Source data" and is about processing that happens during data capture, before recording — it is the obligation with no method, but it is about capture-time processing, not analysis pipelines in general. Do not cite it wider than that. EMA expects a mature draft of a GCP annex on computerised systems in late 2026 (minutes EMA/143308/2026); that is the next text likely to move here.

## eudralex-annex-22-ai
- kind: undated
- title: EU GMP Annex 22 (Artificial Intelligence) — draft, no finalisation date
- url: https://health.ec.europa.eu/medicinal-products/eudralex/eudralex-volume-4_en
- watch: text
- binds: manufacturers (GMP scope only)
- why: The most attestation-shaped text in European law — §6 test-data independency demands proof of a negative — but it governs manufacturing, not genomics or clinical analytics. No finalisation date exists, and EMA is reconsidering the central exclusion (a blanket ban on generative AI in critical GMP applications). Watching the EudraLex volume 4 index is the only way to notice. Moved 2026-10-02: EMA published the expert report of the Annex 22 workshop (EMA/156789/2026); the drafting group discussed bringing generative AI and LLMs in GMP applications into scope under a documented, risk-based control strategy. No revised text and no date; EMA minutes of 2026-06-16 say publication early 2027.

## eudralex-annex-11-revision
- kind: undated
- title: EU GMP Annex 11 (Computerised Systems) — revision, still draft
- url: https://health.ec.europa.eu/medicinal-products/eudralex/eudralex-volume-4_en
- watch: text
- binds: manufacturers (GMP scope only)
- why: The Commission page still serves the January 2011 text. The revision contains zero occurrences of AI/ML/model — AI was split into Annex 22 so the two could move independently. Its §12.6 independent audit-trail review (a peer who was not involved in the activity) is novel and, if it propagates to GCP, becomes directly relevant.

## edpb-blockchain-guidelines
- kind: undated
- title: EDPB Guidelines 02/2025 on processing personal data through blockchain — final v2.0 adopted 2026-07-07
- url: https://www.edpb.europa.eu/documents/guideline/guidelines-022025-on-processing-of-personal-data-through-blockchain_en
- watch: text
- binds: controllers
- why: Final v2.0 adopted 2026-07-07; on a mechanical comparison §52, §53 and §104 are identical to the consultation version apart from one comma. This one document determines the architecture. §52 makes the hash itself personal data and rejects unsalted, unkeyed hashes — reversing CNIL 2018. §104 rules out clear-text, encrypted and hashed personal data on-chain alike. §53 prefers perfectly-hiding commitments, which is the primitive a selective-disclosure protocol wants anyway. Watch the guidance index for a v3 or for sector guidance. URL changed 2026-10-20: the guidelines index used before had been redirecting to the public-consultations list since at least 2026-08-29, so it could not show a new version; this is the document page itself.

## edpb-scientific-research-guidelines
- kind: undated
- title: EDPB Guidelines 1/2026 on the processing of personal data for scientific research
- url: https://www.edpb.europa.eu/public-consultations/guidelines-12026-on-processing-of-personal-data-for-scientific-research_en
- watch: text
- binds: sponsors, research institutions
- why: Still a consultation draft; adoption no earlier than the 2026-09-17 plenary. Two paragraphs decide a lot: §135 (a controller even if it processes no personal data at all — so "we never see the data" is not a shield) and §165 (genetic profiles are personal data by default, anonymous only in exceptional circumstances). URL replaced 2026-10-04: the consultations index this entry used to watch returns 404. On 2026-10-03 it was still the consultation version adopted 2026-04-15 (consultation closed 2026-06-25); the 2026-09-17 plenary did not finalise it.

## ich-e6-r3-annex-2
- kind: undated
- title: ICH E6(R3) Good Clinical Practice — Annex 2 and the consolidated guideline
- url: https://www.ema.europa.eu/en/scientific-guidelines/ich-e6-good-clinical-practice
- watch: text
- binds: sponsors and investigators
- why: Principles and Annex 1 in force in the EU since 2025-07-23; Annex 2 and the consolidated text from 2027-01-15. The new §4 data governance is the substantive change. Note R3 deleted R2's retention rule and weakened the certified-copy definition, while both EMA guidelines still carry the R2 wording — plan against R2 until that is reconciled.

## ema-tmf-guideline
- kind: undated
- title: EMA guideline on the content, management and archiving of the clinical trial master file (EMA/INS/GCP/856758/2018)
- url: https://www.ema.europa.eu/en/documents/scientific-guideline/guideline-content-management-and-archiving-clinical-trial-master-file-paper-andor-electronic_en.pdf
- watch: full
- binds: sponsors and investigators
- why: In force, unrevised, and still written against ICH E6(R2) and the Directives. No revision is in the GCP IWG work plan and the ACT EU priority action that would have carried one has closed. If a revision appears it will reset the certified-copy and archiving rules this business depends on.

## rats-multi-verifier-draft
- kind: undated
- title: IETF RATS — draft-ietf-rats-multi-verifier (cascaded verification)
- url: https://datatracker.ietf.org/doc/draft-ietf-rats-multi-verifier/
- watch: pattern:(?i)(?:draft-ietf-rats-multi-verifier-\d+|Expires:\s*[^<\n]+|(?:Internet-Draft|Proposed Standard|RFC \d+))
- binds: —
- why: Standardises the case where one Verifier's Attestation Result becomes another Verifier's input. That is the composition leg of a mutual-attestation protocol being standardised in public, this year. Watching the draft revision number is enough.

## scitt-composite-evidence-draft
- kind: undated
- title: SCITT — draft-nobuo-scitt-composite-evidence-verification
- url: https://datatracker.ietf.org/doc/draft-nobuo-scitt-composite-evidence-verification/
- watch: pattern:(?i)(?:draft-nobuo-scitt-composite-evidence-verification-\d+|Expires:\s*[^<\n]+)
- binds: —
- why: Composite verification over statement graphs, with portable evidence bundles and "provide only the evidence needed for the profile". Closest published thing to the Synoptis composition. About 21 SCITT profile drafts are colonising this space; a clinical-trials profile would go here.

## slsa-verification-summary
- kind: undated
- title: SLSA Verification Summary Attestation
- url: https://slsa.dev/spec/v1.1/verification_summary
- watch: text
- binds: —
- why: The composition leg, already standardised and deployed: a verifier evaluates a producer's evidence against policy and emits a signed summary consumers use instead of the underlying attestations. Critically, it does NOT require its verifier to be independent — which is exactly the gap the Synoptis novelty claim sits in. Watch for that requirement appearing.

## ro-crate-signing
- kind: undated
- title: RO-Crate — the open signing issue
- url: https://github.com/ResearchObject/ro-crate/issues/312
- watch: text
- binds: —
- why: RO-Crate 1.3 puts integrity out of scope and the signing issue has been open since 2023-12-18 with four abandoned proposals. Workflow Run RO-Crate has shipped one release (0.5.0, June 2024). Nextflow's nf-prov already emits both WRROC and BioCompute Objects and signs neither. If someone closes this issue, the sharpest available wedge closes with it.

## nf-prov-releases
- kind: undated
- title: Nextflow nf-prov plugin — releases
- url: https://github.com/nextflow-io/nf-prov/releases
- watch: text
- binds: —
- why: The concrete insertion point. It already emits WRROC and IEEE 2791 BioCompute Objects into an installed base of pharma users, and signs nothing. A signing release from upstream would remove the wedge; a quiet one would mean the door is still open.

## seqera-gxp
- kind: undated
- title: Seqera — GxP offering
- url: https://seqera.io/solutions/gxp/
- watch: text
- binds: —
- why: The incumbent that owns the customer — "14 of 20 top pharma" — launched a full GxP tier on 2026-04-30 with GAMP5 templates and Part 11 / Annex 11 aligned change tracking. Its own GxP page returns zero for "cryptograph" and "signature". The estimated open water is 12–18 months; this page is how that estimate gets revised.

## swissethics-general-consent
- kind: undated
- title: swissethics — General Consent templates, and the genomic-research consent template (published 2025-11-11)
- url: https://swissethics.ch/en/documents/generalkonsent
- watch: text
- binds: Swiss research institutions
- why: The General Consent is still the 2019 generation. Corrected 2026-10-03: a template for genomic research, "Information und Einwilligung für genomische Forschung" v2025-1.0, was announced as published on 2025-11-11 (optional, germline only), so the earlier note on this list that no such template existed was already wrong when written. The documents page still marks it "under review" while the announcement calls it usable — that disagreement is unresolved. Coded genetic data needs actual consent under HFG Art. 32(2) (coded non-genetic data runs on information plus a right to object under HFG Art. 33(2) and HFV Art. 32). Watch for the template leaving review.

## sphn-ethical-framework
- kind: undated
- title: SPHN — Ethical Framework and ELSI guidance
- url: https://sphn.ch/document-categories/ethical-framework/
- binds: SPHN member institutions
- why: The clearest unmet requirement found in Europe: the framework obliges institutions to have mechanisms ensuring consent revocations are "swiftly acted upon across the Network", and ships no mechanism. Also note SPHN has already committed its federated-query layer to Tune Insight (homomorphic encryption plus secure multi-party computation) — a TEE-first pitch lands in the other camp.

## ai-act-definition-guidelines
- kind: undated
- title: Commission guidelines on the definition of an AI system
- url: https://digital-strategy.ec.europa.eu/en/library/commission-publishes-guidelines-ai-system-definition-facilitate-first-ai-acts-rules-application
- watch: text
- binds: providers and deployers
- why: Admitted by the second route — the `/eu-ai-act` page cites it as `definition-guidelines`. It decides whether a rule-based pipeline is an AI system at all, which is the first question every check has to answer and the one that keeps most genomics tooling outside the Regulation. If it moves, the point `not-every-tool-is-an-ai-system` moves with it.

## ai-act-gpai-guidelines
- kind: undated
- title: Commission guidelines on the scope of the obligations for providers of general-purpose AI models
- url: https://digital-strategy.ec.europa.eu/en/library/guidelines-scope-obligations-providers-general-purpose-ai-models-under-ai-act
- watch: text
- binds: providers of general-purpose AI models, and anyone who fine-tunes one
- why: Admitted by the second route — cited as `gpai-guidelines`. It carries the fine-tuning threshold that decides whether someone adapting a third-party model becomes a downstream provider. Two published points rest on it (`calling-an-api`, `fine-tuning`), and both are the answer researchers most often get wrong.

## ai-act-transparency-guidelines
- kind: undated
- title: Commission guidelines on transparency obligations for AI-generated content (Art. 50)
- url: https://digital-strategy.ec.europa.eu/en/policies/guidelines-transparency-ai-generated-content
- watch: text
- binds: providers and deployers of systems that interact with people or generate content
- why: Admitted by the second route — cited as `transparency-guidelines`. Article 50 is the one obligation that actually reaches this project's own services, so this is the single most self-implicating page on the list: our published pages are themselves AI-drafted text about AI regulation. Two points rest on it (`art-50-is-live`, `art-50-carve-outs`), and the record already carries one discrepancy about this document's own date.

## ai-act-highrisk-draft-guidelines
- kind: undated
- title: Draft Commission guidelines on the classification of high-risk AI systems
- url: https://digital-strategy.ec.europa.eu/en/library/draft-commission-guidelines-classification-high-risk-ai-systems
- watch: text
- binds: providers of Annex I and Annex III systems
- why: Admitted by the second route — cited as `highrisk-draft-guidelines`. Still marked draft on 2026-09-13, and its finalisation is precisely the event the published page needs to notice, because `no-conformity-target-yet` says out loud that no harmonised target exists to build against.

## ai-act-highrisk-guidelines-page
- kind: undated
- title: Commission status page for the high-risk classification guidelines
- url: https://digital-strategy.ec.europa.eu/en/policies/guidelines-ai-high-risk-systems
- watch: text
- binds: —
- why: Admitted by the second route — cited as `highrisk-guidelines-page`. The status page usually moves before the document does, so it is the earlier of the two signals that the draft above has been settled.

## mdcg-2025-6-mdr-ai-interplay
- kind: undated
- title: MDCG 2025-6 — interplay between the Medical Device Regulations and the AI Act
- url: https://health.ec.europa.eu/document/download/b78a17d7-e3cd-4943-851d-e02a2f22bbb4_en?filename=mdcg_2025-6_en.pdf
- watch: full
- binds: manufacturers of AI that is, or is a safety component of, an MDR/IVDR device
- why: Admitted by the second route — cited as `mdcg-2025-6`. It is the bridge between the dated trigger `ai-act-annex-i-high-risk` and what a genomic pipeline inside a companion diagnostic actually has to do, and it is the only guidance that reads the two regimes together. A PDF, so raw bytes are the right comparison.

## eur-lex-ai-omnibus
- kind: undated
- title: Regulation (EU) 2026/1744 — the AI omnibus, Official Journal text
- url: https://eur-lex.europa.eu/eli/reg/2026/1744/oj/eng
- watch: text
- binds: —
- why: Permanently unreachable, and since 2026-09-14 the mechanism is known rather than assumed: EUR-Lex answers this route with **HTTP 202 and a 2,038-byte script-only interstitial**. Stripping the script leaves the empty string, whose digest is `e3b0c442…b855`. Recorded as a baseline it would have read `unchanged` on every later run — a permanent green light on the Official Journal text that the published high-risk dates rest on. The fetcher now rejects both halves (non-200, and a body that normalises to nothing), so this reports `unreachable`. Since 2026-10-04 the act is also watched through Cellar (`eurlex-omnibus-versions`), which closes the gap for change detection; this entry stays so that the EUR-Lex block itself keeps showing: the dates were corroborated across four law-firm analyses, the OJ text has never been read first-hand, and whether the co-legislators kept a standards-readiness trigger or fixed dates is still unresolved.

---

# Added 2026-10-04 — the sources the first seeding left out

The 2026-10-03 agent-team check found that FDA, Swissmedic and the Swiss data protection law had no entry at all, although the project ledger said they were being watched. Admitted by both routes: as unresolved questions from that check, or because the published page cites them.

## ai-act-art50-guidelines-text
- kind: undated
- title: Commission guidelines on Article 50 transparency obligations, C(2026) 5054 final — the document itself
- url: https://ai-act-service-desk.ec.europa.eu/sites/default/files/2026-07/guidelines_on_the_implementation_of_the_transparency_obligations_for_certain_ai_systems_under_article_50_of_the_ai_act_bzptwqhk0ikg1dtlddap41psfy_131215.pdf
- watch: full
- binds: providers and deployers under Art. 50
- why: Admitted by the second route — cited as `art50-guidelines-text`. The published page cites its paragraph numbers (21, 42-45, 131, 133-136), so a new revision of the PDF would move claims. Content approved 2026-07-20; publication as a formal Commission communication not found on 2026-10-03. A PDF, so raw bytes.

## ai-act-highrisk-consultation
- kind: undated
- title: Commission targeted consultation on the draft high-risk classification guidelines
- url: https://digital-strategy.ec.europa.eu/en/consultations/targeted-consultation-draft-guidelines-classification-high-risk-artificial-intelligence-systems
- watch: text
- binds: —
- why: Admitted by the second route — cited as `highrisk-consultation`. Closed 2026-07-23 and carries the only stated date for the final guidelines: "by the end of 2026".

## ai-act-enforcement-page
- kind: undated
- title: Commission page on the enforcement framework of the AI Act
- url: https://digital-strategy.ec.europa.eu/en/policies/enforcement-ai-act
- watch: text
- binds: —
- why: Admitted by the second route — cited as `enforcement-page`. On 2026-10-03 it described the framework and listed no decision. The `penalties` point says no confirmed enforcement exists; this is where the first one is most likely to appear first-hand.

## fda-ai-drug-decision-guidance
- kind: undated
- title: FDA draft guidance FDA-2024-D-4689 — AI to support regulatory decision-making for drugs and biologics
- url: https://www.fda.gov/regulatory-information/search-fda-guidance-documents/considerations-use-artificial-intelligence-support-regulatory-decision-making-drug-and-biological
- watch: text
- binds: sponsors using AI to produce evidence for FDA
- why: Settled on 2026-10-03 after a month of contradictory reports: still "Draft Level 1 Guidance" (content current 2025-01-06), and the only Federal Register notice is the 2025-01-07 draft. The "final by Q2 2026" claim traced to a CRO blog. Finalisation is the event.

## fda-e6r3-annex-2
- kind: undated
- title: FDA page for ICH E6(R3) Annex 2
- url: https://www.fda.gov/regulatory-information/search-fda-guidance-documents/e6r3-good-clinical-practice-annex-2
- watch: text
- binds: sponsors and investigators under FDA
- why: E6(R3) principles and Annex 1 are final at FDA (Federal Register 2025-09-09). Annex 2 reached ICH Step 4 on 2026-06-03 but the FDA page still showed draft on 2026-10-03.

## fda-cdrh-guidance-plan
- kind: undated
- title: CDRH proposed guidances for the coming fiscal year (A-list and B-list)
- url: https://www.fda.gov/medical-devices/guidance-documents-medical-devices-and-radiation-emitting-products/cdrh-proposed-guidances-fiscal-year-2027-fy-2027
- watch: text
- binds: device manufacturers, including AI-enabled device software
- why: The FY2027 list (2026-10-01) put the AI-enabled device software lifecycle guidance, now titled "Marketing Submission and Lifecycle Management Recommendations for AI-Enabled Device Software Functions", on the A-list for finalisation, and carries the all-device PCCP draft over. The URL is per fiscal year; replace it each October.

## fda-csa-guidance
- kind: undated
- title: FDA Computer Software Assurance for production and quality management system software
- url: https://www.fda.gov/regulatory-information/search-fda-guidance-documents/computer-software-assurance-production-and-quality-management-system-software
- watch: text
- binds: manufacturers; prospectively sponsors using AI in clinical investigations
- why: Final, revised 2026-02. CDER's July 2026 agenda lists a draft "CSA for AI-Based Systems in Drug Manufacturing and Clinical Investigations" — the first FDA text that would put assurance of AI-based systems inside clinical investigations, which is our ground.

## fda-electronic-systems-qa
- kind: undated
- title: FDA Q&A — electronic systems, records and signatures in clinical investigations (FDA-2017-D-1105)
- url: https://www.fda.gov/regulatory-information/search-fda-guidance-documents/electronic-systems-electronic-records-and-electronic-signatures-clinical-investigations-questions
- watch: text
- binds: sponsors, investigators, IRBs
- why: Final since 2024-10, unrevised on 2026-10-03. The operative FDA text on audit trails and e-signatures in trials while Part 11 audit-trail enforcement stays relaxed under the 2003 guidance.

## doj-data-security-program
- kind: undated
- title: US Department of Justice — Data Security Program (28 CFR Part 202)
- url: https://www.justice.gov/nsd/data-security
- watch: text
- binds: U.S. persons; indirectly their non-US counterparties
- why: Bulk human genomic data is "more than 100 U.S. persons" and may not go to a country of concern. A Swiss company is not a U.S. person, but §202.304 (evasion) is not limited to U.S. persons and US customers may require §202.302 onward-transfer clauses. Last FAQ 2025-09-24; no 2026 amendment on 2026-10-03.

## swissmedic-ich-e6r3
- kind: undated
- title: Swissmedic — introduction of ICH E6(R3) in Switzerland
- url: https://www.swissmedic.ch/swissmedic/en/home/news/mitteilungen/einfuehrung-leitlinie-ich-gcp-e6-r3.html
- watch: text
- binds: sponsors and investigators in Switzerland
- why: ClinO (KlinV) applies E6(R3) principles and Annex 1 from 2025-08-15. The Swiss date for Annex 2 could not be found on 2026-10-03 — the notice is most likely to appear here. Swissmedic had no AI- or computerised-system-specific GCP guidance on that date.

## bag-hfg-revision
- kind: undated
- title: BAG — revision of the Human Research Act (HFG)
- url: https://www.bag.admin.ch/de/humanforschung-revision-hfg-stfg
- watch: text
- binds: Swiss researchers and research institutions
- why: Draft in preparation. On 2026-10-03 this page said consultation opens in Q2 2027 while the BAG overview page still said a draft by end of 2026 — a disagreement inside one office. The consent rules for coded genetic data (HFG Art. 32(2)) are the clause to watch.

## bj-ai-regulation
- kind: undated
- title: Federal Office of Justice — Swiss approach to AI regulation
- url: https://www.bj.admin.ch/de/kuenstliche-intelligenz
- watch: text
- binds: —
- why: Following the Federal Council decision of 2025-02 to ratify the Council of Europe AI Convention, a consultation draft is promised "bis Ende 2026". Not published on 2026-10-03.

## bakom-electronic-signature
- kind: undated
- title: BAKOM — electronic signature (ZertES) and recognition with the EU
- url: https://www.bakom.admin.ch/de/elektronische-signatur
- watch: text
- binds: qualified trust service providers and anyone relying on ZertES signatures in the EU
- why: ZertES itself unchanged since 2020; technical rules updated 2025-11-01. On mutual recognition with eIDAS, BAKOM writes that an agreement before end of 2026 is "wenig wahrscheinlich". Our signing plan assumes ZertES; its value in the EU turns on this page.

## swiss-eu-package
- kind: undated
- title: SECO — Switzerland-EU mutual recognition agreement (MRA), part of the Switzerland-EU package
- url: https://www.seco.admin.ch/de/mra-schweiz-eu
- watch: text
- binds: —
- why: Signed 2026-03-02, sent to parliament 2026-03-13 (26.023). The Council of States began on 2026-09-28; National Council expected in the winter session (press report). The medical device MRA update is part of it and not in force. Watched through the SECO MRA page because the FDFA package page answers automated clients with HTTP 403 (2026-10-04); read that page by hand for the parliamentary stage.

## digisante-health-data-space
- kind: undated
- title: DigiSanté — federal act on a Swiss health data space (BDG)
- url: https://www.digisante.admin.ch/de/bundesgesetz-datenraum-gesundheit
- watch: text
- binds: —
- why: No consultation yet. Two legal opinions on federal competence for this act were published 2026-08-27. The electronic health record act (EGDG) passed the National Council 2026-09-14 (134-53-10).

## edoeb-news-2026
- kind: undated
- title: FDPIC (EDÖB) — 2026 announcements index
- url: https://www.edoeb.admin.ch/de/2026-de
- watch: text
- binds: controllers and processors under the FADP
- why: The cheapest way to notice new FDPIC guidance. On 2026-10-03 there was none specific to pseudonymisation, blockchain or genetic data. Its 33rd annual report (2026-06-30) holds that research reuse is already justified under FADP Art. 31 and 39. The URL is per year; add the next year in January.

## edoeb-data-breach-guide
- kind: undated
- title: FDPIC guide on data security breaches (FADP Art. 24)
- url: https://www.edoeb.admin.ch/de/leitfaden-data-breach
- watch: text
- binds: controllers and processors under the FADP
- why: v1.2 of 2025-04-23. No hour count: "so rasch als möglich". For health and biometric data it says a high risk is to be assumed "in vielen Fällen". The GDPR equivalent is 72 hours; a check service has to carry both.

## bj-adequate-countries
- kind: undated
- title: Federal Office of Justice — countries recognised as providing adequate data protection (FADP Annex 1)
- url: https://www.bj.admin.ch/de/schweizerische-anerkennung-von-staaten-die-einen-angemessenen-datenschutz-gewaehrleisten
- watch: text
- binds: anyone disclosing personal data abroad from Switzerland
- why: 44 entries, last changed 2024-09-15 (US limited to DPF-certified companies). A machine can check a destination against this list; it cannot judge safeguards for countries not on it.

## edpb-anonymisation-guidelines
- kind: undated
- title: EDPB Guidelines 02/2026 on anonymisation — public consultation
- url: https://www.edpb.europa.eu/public-consultations/guidelines-022026-on-anonymisation_en
- watch: text
- binds: anyone claiming data is anonymous
- why: v1.0 adopted 2026-07-07; consultation until 2026-10-30. Three tests: no record isolation, no linkage, no inference. Lists easily reversed pseudonyms as clearly not anonymous. With the French Conseil d'Etat ruling of 2026-02-13 (n°498628) this is the line that decides whether a hash on our chain is personal data.

## ema-gcp-iwg
- kind: undated
- title: EMA GCP Inspectors Working Group — documents and work plan
- url: https://www.ema.europa.eu/en/human-regulatory-overview/research-development/compliance-research-development/good-clinical-practice/good-clinical-practice-inspectors-working-group
- watch: text
- binds: sponsors and investigators in the EU
- why: EMA minutes of 2026-06-16 expect a mature draft of a GCP annex on computerised systems in late 2026. That would be the first revision of the text section 6.6 of our operative guideline lives in.

## ema-fda-ai-principles
- kind: undated
- title: EMA and FDA — guiding principles of good AI practice in drug development (2026-01)
- url: https://www.ema.europa.eu/en/documents/other/guiding-principles-good-ai-practice-drug-development_en.pdf
- watch: full
- binds: developers and users of AI producing evidence for regulators
- why: Admitted by the second route — cited as `ema-fda-ai-principles` on the data-regulation page. Principle 6 asks for provenance, processing steps and analytical decisions to be documented in a traceable and verifiable manner. An earlier note of ours said the document declares itself non-binding; no such sentence was found in the EMA PDF or on the FDA page on 2026-10-03. A PDF, so raw bytes.

## ecfr-part11-versions
- kind: undated
- title: eCFR version history for 21 CFR Part 11
- url: https://www.ecfr.gov/api/versioner/v1/versions/title-21.json?part=11
- watch: full
- binds: anyone keeping electronic records under FDA requirements
- why: Admitted by the second route — cited as `ecfr-part11`. The version list moves when the Part is amended; last amendment 2023-03-02. JSON, so raw bytes.

## fda-part11-scope-guidance
- kind: undated
- title: FDA guidance — Part 11 scope and application (2003)
- url: https://www.fda.gov/regulatory-information/search-fda-guidance-documents/part-11-electronic-records-electronic-signatures-scope-and-application
- watch: text
- binds: anyone keeping electronic records under FDA requirements
- why: Admitted by the second route — cited as `fda-part11-scope`. The source of FDA's enforcement discretion on Part 11 audit trails. Final, unrevised on 2026-10-03; withdrawal or revision would change what Part 11 means in practice.

## cra-reporting-page
- kind: undated
- title: European Commission — Cyber Resilience Act reporting obligations
- url: https://digital-strategy.ec.europa.eu/en/policies/cra-reporting
- watch: text
- binds: manufacturers of products with digital elements
- why: Admitted by the second route — cited as `cra-reporting-page`. Reporting under Art. 14 applies from 2026-09-11 and ENISA's platform opened that day in an initial version that did not yet take voluntary reports.

## ecfr-part202-versions
- kind: undated
- title: eCFR version history for 28 CFR Part 202 (DOJ bulk sensitive data rule)
- url: https://www.ecfr.gov/api/versioner/v1/versions/title-28.json?part=202
- watch: full
- binds: U.S. persons; indirectly their non-US counterparties
- why: Admitted by the second route — cited as `ecfr-part202`. The bulk threshold for human genomic data (more than 100 U.S. persons, §202.205(a)) and the list of countries of concern (§202.601) are read from the rule, not from the DOJ overview page. Last amended 2025-04-18. JSON, so raw bytes.

## bag-hr-overview
- kind: undated
- title: Federal Office of Public Health — overview of human research regulation
- url: https://www.bag.admin.ch/de/die-regelung-der-humanforschung-in-der-schweiz
- watch: text
- binds: —
- why: Admitted by the second route — cited as `bag-hr-overview`. On 2026-10-04 it still said a draft revision of the HFG by end of 2026, while the revision page (`bag-hfg-revision`) said consultation in Q2 2027. Watch for the two converging.

---

# Swiss statutes via the fedlex SPARQL endpoint — added 2026-10-04

## fedlex-hfg-versions
- kind: undated
- title: fedlex — version list of the Human Research Act (Humanforschungsgesetz), SR 810.30 (HFG)
- url: https://fedlex.data.admin.ch/sparqlendpoint?query=PREFIX+jolux%3A+%3Chttp%3A%2F%2Fdata.legilux.public.lu%2Fresource%2Fontology%2Fjolux%23%3E+SELECT+%3Fcons+%3Fdate+WHERE+%7B+%3Fcons+jolux%3AisMemberOf+%3Chttps%3A%2F%2Ffedlex.data.admin.ch%2Feli%2Fcc%2F2013%2F617%3E+%3B+jolux%3AdateApplicability+%3Fdate+.+%7D+ORDER+BY+DESC%28%3Fdate%29
- watch: full
- binds: anyone doing research involving humans in Switzerland
- why: Added 2026-10-04. fedlex serves the consolidated text only through version-specific addresses and a script-rendered page, so the text itself cannot be watched; until today the Swiss statutes on the data-regulation page were carried as `unwatchable`. Their official SPARQL endpoint can list every consolidated version of an act with its date of applicability, and a new version of the text always arrives as a new entry in that list. This watches the list — 7 versions on 2026-10-04, latest applicable from 2023-09-01. A change means a new version exists and must be read; it does not say what changed. The result is XML and its digest was stable across repeated fetches.

## fedlex-hfv-versions
- kind: undated
- title: fedlex — version list of the Human Research Ordinance (Humanforschungsverordnung), SR 810.301 (HFV)
- url: https://fedlex.data.admin.ch/sparqlendpoint?query=PREFIX+jolux%3A+%3Chttp%3A%2F%2Fdata.legilux.public.lu%2Fresource%2Fontology%2Fjolux%23%3E+SELECT+%3Fcons+%3Fdate+WHERE+%7B+%3Fcons+jolux%3AisMemberOf+%3Chttps%3A%2F%2Ffedlex.data.admin.ch%2Feli%2Fcc%2F2013%2F642%3E+%3B+jolux%3AdateApplicability+%3Fdate+.+%7D+ORDER+BY+DESC%28%3Fdate%29
- watch: full
- binds: researchers reusing health data or samples
- why: Added 2026-10-04. fedlex serves the consolidated text only through version-specific addresses and a script-rendered page, so the text itself cannot be watched; until today the Swiss statutes on the data-regulation page were carried as `unwatchable`. Their official SPARQL endpoint can list every consolidated version of an act with its date of applicability, and a new version of the text always arrives as a new entry in that list. This watches the list — 7 versions on 2026-10-04, latest applicable from 2024-11-01. A change means a new version exists and must be read; it does not say what changed. The result is XML and its digest was stable across repeated fetches.

## fedlex-klinv-versions
- kind: undated
- title: fedlex — version list of the Clinical Trials Ordinance (Verordnung über klinische Versuche), SR 810.305 (KlinV / ClinO)
- url: https://fedlex.data.admin.ch/sparqlendpoint?query=PREFIX+jolux%3A+%3Chttp%3A%2F%2Fdata.legilux.public.lu%2Fresource%2Fontology%2Fjolux%23%3E+SELECT+%3Fcons+%3Fdate+WHERE+%7B+%3Fcons+jolux%3AisMemberOf+%3Chttps%3A%2F%2Ffedlex.data.admin.ch%2Feli%2Fcc%2F2013%2F643%3E+%3B+jolux%3AdateApplicability+%3Fdate+.+%7D+ORDER+BY+DESC%28%3Fdate%29
- watch: full
- binds: sponsors and investigators in Swiss clinical trials
- why: Added 2026-10-04. fedlex serves the consolidated text only through version-specific addresses and a script-rendered page, so the text itself cannot be watched; until today the Swiss statutes on the data-regulation page were carried as `unwatchable`. Their official SPARQL endpoint can list every consolidated version of an act with its date of applicability, and a new version of the text always arrives as a new entry in that list. This watches the list — 11 versions on 2026-10-04, latest applicable from 2025-08-15. A change means a new version exists and must be read; it does not say what changed. The result is XML and its digest was stable across repeated fetches.

## fedlex-gumg-versions
- kind: undated
- title: fedlex — version list of the Genetic Testing Act (Bundesgesetz über genetische Untersuchungen beim Menschen), SR 810.12 (GUMG)
- url: https://fedlex.data.admin.ch/sparqlendpoint?query=PREFIX+jolux%3A+%3Chttp%3A%2F%2Fdata.legilux.public.lu%2Fresource%2Fontology%2Fjolux%23%3E+SELECT+%3Fcons+%3Fdate+WHERE+%7B+%3Fcons+jolux%3AisMemberOf+%3Chttps%3A%2F%2Ffedlex.data.admin.ch%2Feli%2Fcc%2F2022%2F537%3E+%3B+jolux%3AdateApplicability+%3Fdate+.+%7D+ORDER+BY+DESC%28%3Fdate%29
- watch: full
- binds: anyone performing or ordering genetic tests
- why: Added 2026-10-04. fedlex serves the consolidated text only through version-specific addresses and a script-rendered page, so the text itself cannot be watched; until today the Swiss statutes on the data-regulation page were carried as `unwatchable`. Their official SPARQL endpoint can list every consolidated version of an act with its date of applicability, and a new version of the text always arrives as a new entry in that list. This watches the list — 2 versions on 2026-10-04, latest applicable from 2025-08-01. A change means a new version exists and must be read; it does not say what changed. The result is XML and its digest was stable across repeated fetches.

## fedlex-dsg-versions
- kind: undated
- title: fedlex — version list of the Federal Act on Data Protection (Datenschutzgesetz), SR 235.1 (DSG / FADP)
- url: https://fedlex.data.admin.ch/sparqlendpoint?query=PREFIX+jolux%3A+%3Chttp%3A%2F%2Fdata.legilux.public.lu%2Fresource%2Fontology%2Fjolux%23%3E+SELECT+%3Fcons+%3Fdate+WHERE+%7B+%3Fcons+jolux%3AisMemberOf+%3Chttps%3A%2F%2Ffedlex.data.admin.ch%2Feli%2Fcc%2F2022%2F491%3E+%3B+jolux%3AdateApplicability+%3Fdate+.+%7D+ORDER+BY+DESC%28%3Fdate%29
- watch: full
- binds: controllers and processors under Swiss law
- why: Added 2026-10-04. fedlex serves the consolidated text only through version-specific addresses and a script-rendered page, so the text itself cannot be watched; until today the Swiss statutes on the data-regulation page were carried as `unwatchable`. Their official SPARQL endpoint can list every consolidated version of an act with its date of applicability, and a new version of the text always arrives as a new entry in that list. This watches the list — 3 versions on 2026-10-04, latest applicable from 2025-07-07. A change means a new version exists and must be read; it does not say what changed. The result is XML and its digest was stable across repeated fetches.

## fedlex-dsv-versions
- kind: undated
- title: fedlex — version list of the Data Protection Ordinance (Datenschutzverordnung), SR 235.11 (DSV / OPDo)
- url: https://fedlex.data.admin.ch/sparqlendpoint?query=PREFIX+jolux%3A+%3Chttp%3A%2F%2Fdata.legilux.public.lu%2Fresource%2Fontology%2Fjolux%23%3E+SELECT+%3Fcons+%3Fdate+WHERE+%7B+%3Fcons+jolux%3AisMemberOf+%3Chttps%3A%2F%2Ffedlex.data.admin.ch%2Feli%2Fcc%2F2022%2F568%3E+%3B+jolux%3AdateApplicability+%3Fdate+.+%7D+ORDER+BY+DESC%28%3Fdate%29
- watch: full
- binds: controllers and processors under Swiss law
- why: Added 2026-10-04. fedlex serves the consolidated text only through version-specific addresses and a script-rendered page, so the text itself cannot be watched; until today the Swiss statutes on the data-regulation page were carried as `unwatchable`. Their official SPARQL endpoint can list every consolidated version of an act with its date of applicability, and a new version of the text always arrives as a new entry in that list. This watches the list — 5 versions on 2026-10-04, latest applicable from 2025-12-01. A change means a new version exists and must be read; it does not say what changed. The result is XML and its digest was stable across repeated fetches.

## fedlex-isg-versions
- kind: undated
- title: fedlex — version list of the Information Security Act (Informationssicherheitsgesetz), SR 128 (ISG)
- url: https://fedlex.data.admin.ch/sparqlendpoint?query=PREFIX+jolux%3A+%3Chttp%3A%2F%2Fdata.legilux.public.lu%2Fresource%2Fontology%2Fjolux%23%3E+SELECT+%3Fcons+%3Fdate+WHERE+%7B+%3Fcons+jolux%3AisMemberOf+%3Chttps%3A%2F%2Ffedlex.data.admin.ch%2Feli%2Fcc%2F2022%2F232%3E+%3B+jolux%3AdateApplicability+%3Fdate+.+%7D+ORDER+BY+DESC%28%3Fdate%29
- watch: full
- binds: operators listed in Art. 74b, including listed hospitals and licensed laboratories
- why: Added 2026-10-04. fedlex serves the consolidated text only through version-specific addresses and a script-rendered page, so the text itself cannot be watched; until today the Swiss statutes on the data-regulation page were carried as `unwatchable`. Their official SPARQL endpoint can list every consolidated version of an act with its date of applicability, and a new version of the text always arrives as a new entry in that list. This watches the list — 4 versions on 2026-10-04, latest applicable from 2025-10-01. A change means a new version exists and must be read; it does not say what changed. The result is XML and its digest was stable across repeated fetches.

## fedlex-zertes-versions
- kind: undated
- title: fedlex — version list of the Federal Act on Electronic Signatures (ZertES), SR 943.03 (ZertES)
- url: https://fedlex.data.admin.ch/sparqlendpoint?query=PREFIX+jolux%3A+%3Chttp%3A%2F%2Fdata.legilux.public.lu%2Fresource%2Fontology%2Fjolux%23%3E+SELECT+%3Fcons+%3Fdate+WHERE+%7B+%3Fcons+jolux%3AisMemberOf+%3Chttps%3A%2F%2Ffedlex.data.admin.ch%2Feli%2Fcc%2F2016%2F752%3E+%3B+jolux%3AdateApplicability+%3Fdate+.+%7D+ORDER+BY+DESC%28%3Fdate%29
- watch: full
- binds: trust service providers and anyone relying on Swiss qualified signatures
- why: Added 2026-10-04. fedlex serves the consolidated text only through version-specific addresses and a script-rendered page, so the text itself cannot be watched; until today the Swiss statutes on the data-regulation page were carried as `unwatchable`. Their official SPARQL endpoint can list every consolidated version of an act with its date of applicability, and a new version of the text always arrives as a new entry in that list. This watches the list — 2 versions on 2026-10-04, latest applicable from 2020-01-01. A change means a new version exists and must be read; it does not say what changed. The result is XML and its digest was stable across repeated fetches.

---

# EU acts via the Publications Office Cellar SPARQL endpoint — added 2026-10-04

## eurlex-aiact-versions
- kind: undated
- title: Cellar — consolidated versions, corrigenda and amending acts of Regulation (EU) 2024/1689 (AI Act)
- url: https://publications.europa.eu/webapi/rdf/sparql?query=PREFIX+cdm%3A+%3Chttp%3A%2F%2Fpublications.europa.eu%2Fontology%2Fcdm%23%3E+PREFIX+xsd%3A+%3Chttp%3A%2F%2Fwww.w3.org%2F2001%2FXMLSchema%23%3E+SELECT+DISTINCT+%3Fcelex+WHERE+%7B+%7B+%3Fw+cdm%3Aresource_legal_id_celex+%3Fcelex+.+FILTER%28STRSTARTS%28STR%28%3Fcelex%29%2C+%2202024R1689%22%29+%7C%7C+STRSTARTS%28STR%28%3Fcelex%29%2C+%2232024R1689R%22%29%29+%7D+UNION+%7B+%3Fb+cdm%3Aresource_legal_id_celex+%2232024R1689%22%5E%5Exsd%3Astring+.+%3Fa+cdm%3Aresource_legal_amends_resource_legal+%3Fb+.+%3Fa+cdm%3Aresource_legal_id_celex+%3Fcelex+.+%7D+%7D+ORDER+BY+%3Fcelex
- watch: full
- binds: providers and deployers of AI systems
- why: Added 2026-10-04. EUR-Lex answers automated clients with a challenge page, so the text of EU acts could only be re-read by hand and every claim resting on them was carried as a permanent gap. The Publications Office's Cellar SPARQL endpoint, which holds the same documents, lists every consolidated version, every corrigendum and every act recorded as amending this one, and all three are how an EU text changes. This watches that list — on 2026-10-04: 2 consolidated versions (latest 02024R1689-20260727), 4 corrigenda, 1 amending act (2026/1744). A change means something new exists and must be read; it does not say what changed, and a consolidated version can lag the amending act by weeks, which is why amending acts are in the list too. The result is XML and its digest was stable across repeated fetches.

## eurlex-omnibus-versions
- kind: undated
- title: Cellar — consolidated versions, corrigenda and amending acts of Regulation (EU) 2026/1744 (Digital Omnibus on AI)
- url: https://publications.europa.eu/webapi/rdf/sparql?query=PREFIX+cdm%3A+%3Chttp%3A%2F%2Fpublications.europa.eu%2Fontology%2Fcdm%23%3E+PREFIX+xsd%3A+%3Chttp%3A%2F%2Fwww.w3.org%2F2001%2FXMLSchema%23%3E+SELECT+DISTINCT+%3Fcelex+WHERE+%7B+%7B+%3Fw+cdm%3Aresource_legal_id_celex+%3Fcelex+.+FILTER%28STRSTARTS%28STR%28%3Fcelex%29%2C+%2202026R1744%22%29+%7C%7C+STRSTARTS%28STR%28%3Fcelex%29%2C+%2232026R1744R%22%29%29+%7D+UNION+%7B+%3Fb+cdm%3Aresource_legal_id_celex+%2232026R1744%22%5E%5Exsd%3Astring+.+%3Fa+cdm%3Aresource_legal_amends_resource_legal+%3Fb+.+%3Fa+cdm%3Aresource_legal_id_celex+%3Fcelex+.+%7D+%7D+ORDER+BY+%3Fcelex
- watch: full
- binds: —
- why: Added 2026-10-04. EUR-Lex answers automated clients with a challenge page, so the text of EU acts could only be re-read by hand and every claim resting on them was carried as a permanent gap. The Publications Office's Cellar SPARQL endpoint, which holds the same documents, lists every consolidated version, every corrigendum and every act recorded as amending this one, and all three are how an EU text changes. This watches that list — on 2026-10-04: the act itself has a German-only corrigendum of 2026-09-29, CELEX 32026R1744R(01). A change means something new exists and must be read; it does not say what changed, and a consolidated version can lag the amending act by weeks, which is why amending acts are in the list too. The result is XML and its digest was stable across repeated fetches.

## eurlex-gdpr-versions
- kind: undated
- title: Cellar — consolidated versions, corrigenda and amending acts of Regulation (EU) 2016/679 (GDPR)
- url: https://publications.europa.eu/webapi/rdf/sparql?query=PREFIX+cdm%3A+%3Chttp%3A%2F%2Fpublications.europa.eu%2Fontology%2Fcdm%23%3E+PREFIX+xsd%3A+%3Chttp%3A%2F%2Fwww.w3.org%2F2001%2FXMLSchema%23%3E+SELECT+DISTINCT+%3Fcelex+WHERE+%7B+%7B+%3Fw+cdm%3Aresource_legal_id_celex+%3Fcelex+.+FILTER%28STRSTARTS%28STR%28%3Fcelex%29%2C+%2202016R0679%22%29+%7C%7C+STRSTARTS%28STR%28%3Fcelex%29%2C+%2232016R0679R%22%29%29+%7D+UNION+%7B+%3Fb+cdm%3Aresource_legal_id_celex+%2232016R0679%22%5E%5Exsd%3Astring+.+%3Fa+cdm%3Aresource_legal_amends_resource_legal+%3Fb+.+%3Fa+cdm%3Aresource_legal_id_celex+%3Fcelex+.+%7D+%7D+ORDER+BY+%3Fcelex
- watch: full
- binds: controllers and processors
- why: Added 2026-10-04. EUR-Lex answers automated clients with a challenge page, so the text of EU acts could only be re-read by hand and every claim resting on them was carried as a permanent gap. The Publications Office's Cellar SPARQL endpoint, which holds the same documents, lists every consolidated version, every corrigendum and every act recorded as amending this one, and all three are how an EU text changes. This watches that list — on 2026-10-04: 1 consolidated version (2016-05-04), 3 corrigenda, no amending act. A change means something new exists and must be read; it does not say what changed, and a consolidated version can lag the amending act by weeks, which is why amending acts are in the list too. The result is XML and its digest was stable across repeated fetches.

## eurlex-ctr-versions
- kind: undated
- title: Cellar — consolidated versions, corrigenda and amending acts of Regulation (EU) No 536/2014 (Clinical Trials Regulation)
- url: https://publications.europa.eu/webapi/rdf/sparql?query=PREFIX+cdm%3A+%3Chttp%3A%2F%2Fpublications.europa.eu%2Fontology%2Fcdm%23%3E+PREFIX+xsd%3A+%3Chttp%3A%2F%2Fwww.w3.org%2F2001%2FXMLSchema%23%3E+SELECT+DISTINCT+%3Fcelex+WHERE+%7B+%7B+%3Fw+cdm%3Aresource_legal_id_celex+%3Fcelex+.+FILTER%28STRSTARTS%28STR%28%3Fcelex%29%2C+%2202014R0536%22%29+%7C%7C+STRSTARTS%28STR%28%3Fcelex%29%2C+%2232014R0536R%22%29%29+%7D+UNION+%7B+%3Fb+cdm%3Aresource_legal_id_celex+%2232014R0536%22%5E%5Exsd%3Astring+.+%3Fa+cdm%3Aresource_legal_amends_resource_legal+%3Fb+.+%3Fa+cdm%3Aresource_legal_id_celex+%3Fcelex+.+%7D+%7D+ORDER+BY+%3Fcelex
- watch: full
- binds: sponsors and investigators
- why: Added 2026-10-04. EUR-Lex answers automated clients with a challenge page, so the text of EU acts could only be re-read by hand and every claim resting on them was carried as a permanent gap. The Publications Office's Cellar SPARQL endpoint, which holds the same documents, lists every consolidated version, every corrigendum and every act recorded as amending this one, and all three are how an EU text changes. This watches that list — on 2026-10-04: 3 consolidated versions (latest 02014R0536-20221205), 11 corrigenda; the pharmaceutical package that amends it was not yet adopted. A change means something new exists and must be read; it does not say what changed, and a consolidated version can lag the amending act by weeks, which is why amending acts are in the list too. The result is XML and its digest was stable across repeated fetches.

## eurlex-cra-versions
- kind: undated
- title: Cellar — consolidated versions, corrigenda and amending acts of Regulation (EU) 2024/2847 (Cyber Resilience Act)
- url: https://publications.europa.eu/webapi/rdf/sparql?query=PREFIX+cdm%3A+%3Chttp%3A%2F%2Fpublications.europa.eu%2Fontology%2Fcdm%23%3E+PREFIX+xsd%3A+%3Chttp%3A%2F%2Fwww.w3.org%2F2001%2FXMLSchema%23%3E+SELECT+DISTINCT+%3Fcelex+WHERE+%7B+%7B+%3Fw+cdm%3Aresource_legal_id_celex+%3Fcelex+.+FILTER%28STRSTARTS%28STR%28%3Fcelex%29%2C+%2202024R2847%22%29+%7C%7C+STRSTARTS%28STR%28%3Fcelex%29%2C+%2232024R2847R%22%29%29+%7D+UNION+%7B+%3Fb+cdm%3Aresource_legal_id_celex+%2232024R2847%22%5E%5Exsd%3Astring+.+%3Fa+cdm%3Aresource_legal_amends_resource_legal+%3Fb+.+%3Fa+cdm%3Aresource_legal_id_celex+%3Fcelex+.+%7D+%7D+ORDER+BY+%3Fcelex
- watch: full
- binds: manufacturers, importers, distributors, open-source stewards
- why: Added 2026-10-04. EUR-Lex answers automated clients with a challenge page, so the text of EU acts could only be re-read by hand and every claim resting on them was carried as a permanent gap. The Publications Office's Cellar SPARQL endpoint, which holds the same documents, lists every consolidated version, every corrigendum and every act recorded as amending this one, and all three are how an EU text changes. This watches that list — on 2026-10-04: 1 consolidated version (2024-11-20), 7 corrigenda, 1 amending act (2025/327, the EHDS Regulation). A change means something new exists and must be read; it does not say what changed, and a consolidated version can lag the amending act by weeks, which is why amending acts are in the list too. The result is XML and its digest was stable across repeated fetches.

---

# Tier 6 — GCP self-assessment checklist sources (added 2026-10-20)

Third admission route, from 2026-10-20: an entry may be added because the Tier 6 GCP
self-assessment checklist rests on it. Tier 6 also rests on these entries already on the list:
`ich-e6-r3-annex-2-eu-applies`, `ich-e6-r3-annex-2`, `ema-computerised-systems-gcp`, the
`ema-tmf-guideline`, `fda-e6r3-annex-2`, `swissmedic-ich-e6r3`,
`ema-gcp-iwg`, `ecfr-part11-versions`, `fedlex-klinv-versions`, `eurlex-ctr-versions`.

## jp-gcp-ordinance-amendment-2027
- kind: dated
- due: 2027-05-20
- title: Japan GCP ordinance (平成九年厚生省令第二十八号) — amendment promulgated 2026-06-30 takes effect
- url: https://laws.e-gov.go.jp/api/2/law_revisions/409M50000100028
- watch: pattern:"law_revision_id":"[^"]+"
- binds: sponsors, investigators and medical institutions conducting clinical trials in Japan
- why: Tier 6. e-Gov lists revision 409M50000100028_20270520_508M60000100110 as UnEnforced, from the 薬機法 amendment's ministerial-ordinance package. Read what changes before the date; the checklist's Japanese items must not describe the old text after it.

## egov-jp-gcp-ordinance-versions
- kind: undated
- title: e-Gov — revision list of the Japan GCP ordinance (GCP省令)
- url: https://laws.e-gov.go.jp/api/2/law_revisions/409M50000100028
- watch: pattern:"law_revision_id":"[^"]+"
- binds: sponsors, investigators and medical institutions conducting clinical trials in Japan
- why: Tier 6. Compares only the revision ids, because the JSON also carries an `updated` timestamp that moves without any change to the text. A new id means a new amendment.

## pmda-ich-e6
- kind: undated
- title: PMDA — ICH-E6 GCP page (Japanese implementation status of E6(R3) and its annexes)
- url: https://www.pmda.go.jp/int-activities/int-harmony/ich/0028.html
- watch: text
- binds: sponsors running trials in Japan
- why: Tier 6. Where Japan's adoption of E6(R3) and Annex 2 shows up first; the ordinance itself changes later, if at all.

## ich-e6-r3-step4-guideline
- kind: undated
- title: ICH E6(R3) Step 4 final guideline (principles and Annex 1), 2025-01-06
- url: https://database.ich.org/sites/default/files/ICH_E6(R3)_Step4_FinalGuideline_2025_0106.pdf
- watch: full
- binds: sponsors and investigators in ICH regions
- why: Tier 6. The source text the checklist adapts (ICH copyright notice permits adaptation with acknowledgement and labelled changes). A PDF, so raw bytes; a change here means ICH reissued the file. The ich.org guideline index is a script-only page and cannot be watched.

## ecfr-part50-versions
- kind: undated
- title: eCFR version history for 21 CFR Part 50 (protection of human subjects)
- url: https://www.ecfr.gov/api/versioner/v1/versions/title-21.json?part=50
- watch: full
- binds: sponsors and investigators under FDA jurisdiction
- why: Tier 6. Informed-consent requirements; last amendment 2024-01-22. JSON, so raw bytes.

## ecfr-part56-versions
- kind: undated
- title: eCFR version history for 21 CFR Part 56 (institutional review boards)
- url: https://www.ecfr.gov/api/versioner/v1/versions/title-21.json?part=56
- watch: full
- binds: IRBs, sponsors and investigators under FDA jurisdiction
- why: Tier 6. IRB requirements. JSON, so raw bytes.

## ecfr-part312-versions
- kind: undated
- title: eCFR version history for 21 CFR Part 312 (investigational new drug application)
- url: https://www.ecfr.gov/api/versioner/v1/versions/title-21.json?part=312
- watch: full
- binds: sponsors and investigators of IND studies
- why: Tier 6. Sponsor and investigator obligations under an IND. JSON, so raw bytes.

## eurlex-ai-hs-decision-versions
- kind: undated
- title: Cellar — consolidated versions, corrigenda and amending acts of Implementing Decision (EU) 2026/2274 (harmonised standards under the AI Act)
- url: https://publications.europa.eu/webapi/rdf/sparql?query=PREFIX+cdm%3A+%3Chttp%3A%2F%2Fpublications.europa.eu%2Fontology%2Fcdm%23%3E+PREFIX+xsd%3A+%3Chttp%3A%2F%2Fwww.w3.org%2F2001%2FXMLSchema%23%3E+SELECT+DISTINCT+%3Fcelex+WHERE+%7B+%7B+%3Fw+cdm%3Aresource_legal_id_celex+%3Fcelex+.+FILTER%28STRSTARTS%28STR%28%3Fcelex%29%2C+%2202026D2274%22%29+%7C%7C+STRSTARTS%28STR%28%3Fcelex%29%2C+%2232026D2274R%22%29%29+%7D+UNION+%7B+%3Fb+cdm%3Aresource_legal_id_celex+%2232026D2274%22%5E%5Exsd%3Astring+.+%3Fa+cdm%3Aresource_legal_amends_resource_legal+%3Fb+.+%3Fa+cdm%3Aresource_legal_id_celex+%3Fcelex+.+%7D+%7D+ORDER+BY+%3Fcelex
- watch: full
- binds: providers of high-risk AI systems
- why: Added 2026-10-20, cited as `oj-2026-2274` on the EU AI Act page. The decision cites EN 18286:2026, the first harmonised standard under the AI Act; further standards would arrive as an amendment. Empty on 2026-10-20 (no corrigendum or amendment yet); the same query shape returns 10 rows for the CRA, so empty here means none, not a broken query. JSON, so raw bytes.
