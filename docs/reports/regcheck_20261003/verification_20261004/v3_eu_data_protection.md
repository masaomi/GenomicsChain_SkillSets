Fact-check of bundle v3, as of 2026-10-04. I checked all 8 points against the primary sources. 5 points have problems, 3 are OK.
GDPR text: EUR-Lex blocks automated clients, so I used the Publications Office Cellar instead (http://publications.europa.eu/resource/celex/32016R0679, Accept: application/xhtml+xml, which resolves to cellar 3e485e15-…0006.03, the OJ L 119 of 4.5.2016). The 2018 corrigendum (celex 32016R0679R(02)) does not touch Art. 3, 9, 17, 27, 28, 30, 32, 33 or 35.

gdpr-erasure-append-only: OK. The quote is verbatim in Art. 17(3)(d). Art. 28(3)(g) says "deletes or returns all the personal data … after the end of the provision of services". The CJEU press release No 139/26 confirms 1 Oct 2026, AG Medina, C-12/25 (Bisdom Gent): striking through while the entry stays legible "does not constitute erasure", and the data "must be rendered illegible … so that the person is no longer identified or easily identifiable". The release also says the opinion is not binding. Labels are correct.

edpb-hash-onchain: PROBLEM — §53 does not say perfectly hiding commitments are "preferred". It only says that once the original data and the witness are deleted, a perfectly hiding commitment is "useless", and the original data can be neither recovered nor recognised. The nearest preference wording is in §54: "it is better to store on-chain … a pointer, a cryptographic commitment or a hash generated from a keyed hash function". That sentence does not rank commitments above keyed hashes. https://www.edpb.europa.eu/system/files/2026-07/edpb_guidelines_202502_blockchain_v2_en.pdf
Everything else checks out:
- v2.0 was "Adopted on 07 July 2026".
- The §52 quote is verbatim, including the sentence on unsalted or unkeyed hashes.
- §104 says clear-text, encrypted or hashed personal data "should be stored off-chain".
- I compared with v1.1 (2025-04 PDF): the hashing, commitment and erasure text is the same in substance.

genetic-personal-default: PROBLEM — the first of the three anonymisation tests is not "no singling out". The guidelines call it "No Record Isolation": no unique combination of attribute values for one person (§§52–55). Singling out is a separate, later analysis step for when a test fails (§52, section 3.5.3). The correct names are No Record Isolation, No Linkage and No Inference. https://www.edpb.europa.eu/system/files/2026-09/edpb_guidelines_202602_anonymisation_v1_en_0.pdf
Everything else checks out:
- The consultation runs from 8 July to 30 October 2026.
- The 1/2026 quote is verbatim in §165; §167 covers relatives and "the rest of their lives and beyond". This is the consultation version, adopted 15 Apr 2026.
- CNIL: the decision is dated 26 May 2026 (published 28 May), €5M. The CNIL found IQVIA's data "not anonymous, but only pseudonymous".
- Conseil d'État n°498628, read on 13 Feb 2026 (point 9): data is anonymous after pseudonymisation only "si le risque d'identification est insignifiant", citing C-479/22.

gdpr-dpia: PROBLEM (two small issues).
(1) NL: the entry reads "Grootschalige verwerkingen en/of stelselmatige monitoring van genetische persoonsgegevens", i.e. large-scale processing and/or systematic *monitoring*, not "systematic processing". https://zoek.officielebekendmakingen.nl/stcrt-2019-64418.html
(2) ES: item 6 does say "genetic data for any purpose". But the list's own rule is that a DPIA is needed "in the majority of cases" when processing meets two or more criteria. Genetic data also meets item 4 (special categories), so it reaches two criteria on its own. Presenting it as a stand-alone trigger, next to Germany's "+1 criterion", overstates the difference. https://www.aepd.es/sites/default/files/2019-09/listas-dpia-en-35-4.pdf
Everything else checks out: DE item 2 is genetic data "wenn mindestens ein weiteres … Kriterium aus WP 248" applies. Art. 35(1) "prior to the processing" is verbatim. Art. 35(3)(b) and Art. 9(1) (genetic data) are correct.

gdpr-records: OK. Art. 30(5) reads "fewer than 250 persons unless … the processing includes special categories". Labels are correct.

gdpr-breach-security: PROBLEM — the title says "two fines that turned on basic security", but only one decision is cited. Of its €2.4M, the €0.4M part is under Art. 33 for notifying well past 72 hours, not for security. The body itself is correct: €2.0M under Art. 5(1)(f) (Art. 83.5) and €0.4M under Art. 33 (Art. 83.4), in the "RESUELVE" (operative part) of https://www.aepd.es/documento/ps-00140-2025.pdf (the file is numbered EXP202316010).
Other checks:
- The quote and Art. 32(1)(a)/(d), 33(1), 33(2) and 33(5) are verbatim or correct.
- The PDF has no written date. Its signature code "938-101025" is consistent with 10 Oct 2025, which is DataGuidance's date; other reports give July 2026 publication. That is my inference from the code, not a confirmed date. So "two secondary sources differ" holds.

gdpr-representative: OK. The quote is verbatim in Art. 27(1). Art. 27(2)(a) has the three cumulative conditions. Art. 3(2) is correct.

cra-reporting: PROBLEM — the quote "Article 14 shall apply from 11 September 2026" is not in either cited Commission page. It is verbatim in CRA Art. 71(2) ("However, Article 14 shall apply from 11 September 2026"), which neither source cites. The CRA text is Regulation (EU) 2024/2847, http://publications.europa.eu/resource/celex/32024R2847; either add it as a source or quote the reporting page ("As of 11 September 2026, manufacturers are required to report…").
The body is supported:
- 24 h early warning and 72 h notification (Art. 14(2)).
- The Single Reporting Platform has been "operational as of 11 September 2026".
- Free and open-source software that is not monetised "should not be considered to be a commercial activity".
- Stewards: Art. 24 duties; Art. 64(10)(b) says no administrative fines.
- Steward reporting starts 11 Dec 2027 (Art. 71(2) with Art. 24(3), per https://digital-strategy.ec.europa.eu/en/policies/cra-reporting).
Labels are correct.

