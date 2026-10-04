Fact-check of bundle v1, done 2026-10-04. Two of the ten points have problems. The other eight check out: every quote is verbatim, and the dates, numbers and section labels match the sources.

**Two points with problems**
- **ctr-tmf-traceable:** the cited Council document does not show the 2026-09-28 adoption date. The date itself is correct, so the fix is to swap or add a citation.
- **ai-evidence-provenance:** the claim about "reports" that the FDA guidance would be final by mid-2026 has no support in either cited source.

**How each source was read**
- I downloaded each source with curl and read the PDFs as text with pdftotext.
- EUR-Lex opened over plain HTTP, so I read Article 58 in the Official Journal text itself.
- I read 28 CFR 202 and 21 CFR Part 11 through the eCFR API.
- I read the Federal Register notices through the federalregister.gov API.

gcp-traceability: OK — The 3.16.2(c) quote is verbatim, and (f) matches ("dated and time stamped, protected against any changes"). The EU in-force date of 2025-07-23 matches the EMA page and the Step 5 PDF. The FDA final guidance (principles plus Annex 1) matches Federal Register 2025-17311, published 2025-09-09. The Swiss date matches the Swissmedic page: in effect 2025-08-15, with the reference in ClinO Annex 1 No. 2 amended. Section numbers are the same in the 2026 consolidated text.

gcp-audit-trail: OK — The 6.2.1 quote is verbatim. 6.2.1 also says "secure, computer generated and timestamped" and that 'normal' users cannot deactivate the trail. ICH E6(R3) 4.2.2(b) says audit trails are "not disabled", and 4.2.2(d) gives UTC as the example.

gcp-no-exclusive-control: OK — The 6.6 quote is verbatim. 6.6 also says the data must be "verifiable to a copy of these data that is not held (or that has not been held) by the sponsor", and names an "independent (distributed) tamper-proof ledger" as an alternative that must be justified and documented. The claim that this is the only such mention in EU texts is your own statement and cannot be checked against a source.

gcp-capture-processing: OK — The 4.4 quote is verbatim, the context about processing during capture is accurate, and the section gives no method.

gcp-migration: OK — The 6.10 quote is verbatim, and so is "no less focus than the validation of the system itself".

ctr-tmf-traceable: PROBLEM — The cited Council document ST-12262-2026-INIT is a note dated 21 September 2026 (an 'I/A' item note, i.e. one passed without debate). It only asks that the Council adopt its position "at a forthcoming meeting"; it does not show adoption on 2026-09-28. The date is correct: Council document ST-13768-2026 (Commission communication COM(2026) 527) says "Date of adoption of the position of the Council: 28 September 2026" — https://data.consilium.europa.eu/doc/document/ST-13768-2026-INIT/en/pdf. Everything else checks out:
- Article 58 says "at least 25 years", and the quote is verbatim. Source: the EUR-Lex text for CELEX 32014R0536.
- The package does amend 536/2014: the subject line of ST-12262 says so.
- "Not in the OJ on 2026-10-03" is consistent with the Parliament's procedure tracker (OEIL) for 2023/0131(COD), which reads "Awaiting Parliament 2nd reading", with 23/11/2026 given as the indicative plenary date.

ai-evidence-provenance: COULD NOT VERIFY "despite reports that it would be final by mid-2026" — Neither cited source says this. The EMA-FDA principles PDF and the FDA guidance page say nothing about expected finalisation. A web search turned up only one unnamed industry analysis predicting "Q2 2026"; I did not open it, so I cannot cite it. The rest is verified:
- The 10 principles are dated January 2026, and the EMA news item gives 14 January 2026.
- The principle 6 quote is verbatim.
- FDA-2024-D-4689 is still marked "Draft" on the FDA page fetched 2026-10-04 (dated January 2025, content current as of 01/06/2025).

part11-audit-trail: OK — The 11.10(e) text and the quote are verbatim on eCFR. The 2003 scope guidance is "Final", dated September 2003 (docket FDA-2003-D-0143). It states enforcement discretion on "validation, audit trail, record retention, and record copying". The Q&A guidance under FDA-2017-D-1105 is "Final", dated October 2024. The eCFR history shows the last amendment on 2023-03-02.

part11-signature-link: OK — The 11.70 quote and the body text are verbatim on eCFR.

us-bulk-genomic-data: OK, with one naming note — The DOJ page does not itself give the thresholds, so I checked the primary eCFR text:
- 202.205(a): for human genomic data, bulk means "more than 100 U.S. persons".
- 202.601: the countries of concern are China, Cuba, Iran, North Korea, Russia and Venezuela. Switzerland is not among them.
- 202.302 is the onward-transfer contract clause, and it applies to data brokerage.
- 202.303 restricts U.S. persons.
- 202.304(a) applies to "any transaction" with an evasive purpose and is not limited to U.S. persons.
- Public Law 119-60 was approved December 18, 2025. Its § 851(a) and (b) cover contracts, grants and loans.
- Federal Register 2026-11571 (2026-06-10, the Department of Defense's section 1260H list) names BGI Group, MGI Tech Co., Ltd., WuXi AppTec Co., Ltd. and Novogene Company Limited.

The naming note: the words "BIOSECURE Act" do not appear in Public Law 119-60. § 851 is titled "Prohibition on contracting with certain biotechnology providers". "BIOSECURE" is an informal name, not the name in the law.

