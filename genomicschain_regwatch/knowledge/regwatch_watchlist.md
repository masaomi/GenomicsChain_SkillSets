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

## ehds-art73-implementing-act
- kind: dated
- due: 2027-03-26
- title: EHDS Art. 73(5) — secure processing environment technical implementing act
- url: https://health.ec.europa.eu/ehealth-digital-health-and-care/european-health-data-space-regulation-ehds_en
- watch: text
- binds: European Commission
- why: The highest-leverage open door found anywhere in the survey. Drafting closes December 2026 and nobody has written a word about what a secure processing environment must technically be — the EDPB–EDPS joint opinion on the EHDS proposal contains zero occurrences of the phrase. TEHDAS2's draft input is a virtual desktop with no mention of trusted execution.

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
- why: The operative instrument for this whole business. Section 6.6 is the only place in the European corpus that names a distributed tamper-proof ledger, and section 4.4 is the obligation with no method ("it should be possible to validate the correct operation of the processing"). If either sentence moves, the business case moves. A PDF, so raw bytes are the right comparison.

## eudralex-annex-22-ai
- kind: undated
- title: EU GMP Annex 22 (Artificial Intelligence) — draft, no finalisation date
- url: https://health.ec.europa.eu/medicinal-products/eudralex/eudralex-volume-4_en
- watch: text
- binds: manufacturers (GMP scope only)
- why: The most attestation-shaped text in European law — §6 test-data independency demands proof of a negative — but it governs manufacturing, not genomics or clinical analytics. No finalisation date exists, and EMA is reconsidering the central exclusion (a blanket ban on generative AI in critical GMP applications). Watching the EudraLex volume 4 index is the only way to notice.

## eudralex-annex-11-revision
- kind: undated
- title: EU GMP Annex 11 (Computerised Systems) — revision, still draft
- url: https://health.ec.europa.eu/medicinal-products/eudralex/eudralex-volume-4_en
- watch: text
- binds: manufacturers (GMP scope only)
- why: The Commission page still serves the January 2011 text. The revision contains zero occurrences of AI/ML/model — AI was split into Annex 22 so the two could move independently. Its §12.6 independent audit-trail review (a peer who was not involved in the activity) is novel and, if it propagates to GCP, becomes directly relevant.

## edpb-blockchain-guidelines
- kind: undated
- title: EDPB Guidelines 02/2025 on processing personal data through blockchain — final v2.0
- url: https://www.edpb.europa.eu/our-work-tools/general-guidance/guidelines-recommendations-best-practices_en
- watch: text
- binds: controllers
- why: This one document determines the architecture. §52 makes the hash itself personal data and rejects unsalted, unkeyed hashes — reversing CNIL 2018. §104 rules out clear-text, encrypted and hashed personal data on-chain alike. §53 prefers perfectly-hiding commitments, which is the primitive a selective-disclosure protocol wants anyway. Watch for a v3 or for sector guidance.

## edpb-scientific-research-guidelines
- kind: undated
- title: EDPB Guidelines 1/2026 on the processing of personal data for scientific research
- url: https://www.edpb.europa.eu/our-work-tools/documents/public-consultations_en
- watch: text
- binds: sponsors, research institutions
- why: Still a consultation draft; adoption no earlier than the 2026-09-17 plenary. Two paragraphs decide a lot: §135 (a controller even if it processes no personal data at all — so "we never see the data" is not a shield) and §165 (genetic profiles are personal data by default, anonymous only in exceptional circumstances).

## ich-e6-r3-annex-2
- kind: undated
- title: ICH E6(R3) Good Clinical Practice — Annex 2 and the consolidated guideline
- url: https://www.ema.europa.eu/en/ich-e6-good-clinical-practice-scientific-guideline
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
- title: swissethics — General Consent templates (genomic research template still absent)
- url: https://swissethics.ch/en/documents/generalkonsent
- watch: text
- binds: Swiss research institutions
- why: The General Consent is still the 2019 generation and a General Consent for genomic research is marked "under review — no template yet". Coded genetic data needs actual consent under HFG Art. 32(2); opt-out is not available for genetics. That absent template is open product surface, and its arrival would change the shape of the opportunity.

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
- why: Permanently unreachable, and since 2026-09-14 the mechanism is known rather than assumed: EUR-Lex answers this route with **HTTP 202 and a 2,038-byte script-only interstitial**. Stripping the script leaves the empty string, whose digest is `e3b0c442…b855`. Recorded as a baseline it would have read `unchanged` on every later run — a permanent green light on the Official Journal text that the published high-risk dates rest on. The fetcher now rejects both halves (non-200, and a body that normalises to nothing), so this reports `unreachable`. It stays on the list precisely so the gap keeps showing: the dates were corroborated across four law-firm analyses, the OJ text has never been read first-hand, and whether the co-legislators kept a standards-readiness trigger or fixed dates is still unresolved.
