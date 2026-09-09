# corpus/

The Tier-1 survey corpus, moved here from `GenomicsChain_MVP2_2026/log/repro_survey_2026_07/`
on 2026-09-09. `GenomicsChain_MVP2_2026` is frozen (last commit 2026-08-03); this directory is
the live copy, and the scripts here read this repository's `genomicschain_core` rather than an
installed instance, so the digest they stamp is the one the anchor recomputes.

```
repro_survey_2026_07/
  survey_v1_1/collection/by_paper/     201 stage-1 reports (rubric v0.2.5), each carrying
                                       report_content_hash recomputed 2026-09-09 after the
                                       canonical-JSON fix (false was serialising as null)
  survey_v1_1/collection/*.json        submit_manifest (198 submittable / 3 rejected),
                                       report_content_hash census, exclusions
  collection/by_paper/                 the six older stage-2 reports (no report_content_hash;
                                       gc_tier2_submit refuses adjudications built on them)
  add_report_content_hash.rb           stamp / --verify the digest (loads core, never reimplements)
  build_submit_set.rb                  derive the submit set through the real Tier1VerdictSpec gates
  stats_stage1.rb, aggregate.rb        the survey-page statistics
  stage1_assessor_prompt.md, stage2_assessor_prompt.md
```

Verify at any time:

```sh
cd corpus/repro_survey_2026_07 && ruby add_report_content_hash.rb --verify
```

`genomicschain.ch` still bootstraps its survey page from the MVP2 path
(`GenomicsChain_2025/data/tier1_survey/scripts/bootstrap_from_mvp2.sh`, `TIER1_SOURCE_ROOT`);
point it here when that repository is next touched.
