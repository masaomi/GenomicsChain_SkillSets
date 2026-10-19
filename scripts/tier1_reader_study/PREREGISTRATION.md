# Pre-registration — Tier-1 reader study, 2026-10-18

**Study id:** `tier1_reader_study_20261018` · **Author/operator:** Masaomi Hatakeyama ·
**Drafted:** 2026-10-18 by the orchestrating Claude Code session (claude-opus-5-5), at the
operator's request · **Status:** registered when the SHA-256 of this file and of
`log/tier1_reader_study_20261018/manifest.json` are on the genomics-chain ledger. No read
counted here was made before that record.

## 人向けの要約

```
何を測るか：同じ文書・同じ問いかけ・同じ計算で、読み手（モデル × effort）だけを変えると、
            Tier 1 の数字（工程数、RI・NI の数、主張の種類、欠けの種類）がどれだけ動くか
文書      ：P  = 論文そのもの（v1.0 の preprint.md、draft サービスが採点したのと同じ文面）
            V0 = 架空の論文（対照）  V1 = V0 から Methods の「release 3」を消したもの
読み手    ：17 の組み合わせ（Claude 3 モデル × effort 4 段、Codex gpt-6-astra × 4 段、Cursor composer-2.5）
回数      ：17 × 3 文書 × 3 回 ＝ 153 回
正解      ：ない。読み手による違いを、日付つきの観察として記録するだけ
```

外に出るもの：まだ投稿していない論文の文面が、Anthropic（Claude Code 経由）、OpenAI（Codex 経由）、
Cursor に送られる。2026-10-18 に著者自身が依頼した。

## 1. Purpose, and what this is not

The paper's own claim (§3.4/§3.5/S2.5) is that a Tier-1 figure is a property of the paper
*and* of the reader that produced it. This study applies that claim to the paper itself,
with the paper's own instrument, and adds the fictional manuscripts of the
self-application (V0, V1) so that the same readers are also seen on a text with one
known planted difference.

It is not a search for a configuration that passes. At stage 1, static readiness is 0% by
construction (R★ is unreachable), so no read can "pass". No result changes the manuscript
automatically; any use of the result in the manuscript is a separate, later decision.

## 2. Documents (frozen copies in `log/tier1_reader_study_20261018/inputs/`)

| id | source | transform | content sha256 | bytes |
|---|---|---|---|---|
| P | `docs/zenodo/genomicschain_tiers_preprint_v1.0/preprint.md` (sha256 25784e56…) | `strip` — genomicschain.ch's own transform (`ManuscriptText#call`) | 6b1c5673cc73c6b0… | 214,722 |
| V0 | `selfapp/synthetic_rnaseq_v1/synthetic_manuscript.md` | verbatim | 50adf2936fcd8003… | 11,012 |
| V1 | `selfapp/synthetic_rnaseq_v1_variants/V1/synthetic_manuscript.md` | verbatim | 9ea54b7d247f99c7… | 10,982 |

- P is the text the hosted draft check scored on 2026-10-18 (its `canonical_id` 6b1c5673…
  is the sha256 of this exact text; the hosted run is "data point zero", recorded at
  `docs/preprint/zenodo_v1_0_prep/tier1_runs/hosted_draft_sonnet55_default_20261018_preprint_v1_0.json`).
  It is supplied without S1/S2, as in the hosted run. It contains two `@@` placeholders
  (state of 2026-10-16); they are part of the text read.
- V0/V1 are the round-1 self-application subjects. V1 differs from V0 only in that the
  three occurrences of `SynthRef release 3` between `## Methods` and `## Results` read
  `SynthRef` (`selfapp/variants_v1.json`); the release still appears outside Methods and
  in file names (`synthetic_SynthRef_r3.*`).

## 3. What is fixed (only the reader varies)

- **Prompt.** Built by the shipped package: `genomicschain_tier1` 0.2.4 at git `509e5bf`
  (`Prompts.system_for(stage1)`, `user_for`, `output_schema`; rubric v0.2.5, rubric_hash
  4024d4d8… — the same as the hosted run). The source block is
  `{kind: paper_text, ref, content}`; P also declares its sha256, as the hosted service
  does; V0/V1 do not, as round 1 did not.
- **Delivery.** System prompt, schema and source are flattened into one user turn by
  llm_client's CLI `build_prompt` (identical text in its claude_code, codex and cursor
  adapters). The bytes sent are therefore identical across all 17 configurations:

  | doc | prompt sha256 | bytes |
  |---|---|---|
  | P | 4bb75028e241589e… | 219,534 |
  | V0 | 73733196cdd1b8f6… | 15,764 |
  | V1 | 217c7c593b71fe53… | 15,734 |

  V0 and V1 are byte-identical to the requests recorded in round 1
  (`log/selfapp/ddc_inputs_v1/tier1/{V0,V1}/exchange.json`, flattened the same way).
  `run_read.rb` recomputes the prompt before every call and refuses to send on mismatch.
- **Scoring.** Every answer goes through the package's own phases (pre-commit, derivation
  and guards, schema validation) via `Assessor.new(llm: <callable>)`; counts are computed
  by Ruby, never by a model. `assessed_at` = 2026-10-18 and
  `assessor_id` = `tier1_reader_study/0.1` for every read (pre-commit only; not in the prompt).
- **Code.** Hashes of every file the reads depend on are in `manifest.json`
  (`code_sha256`), with the CLI versions: Claude Code 2.1.302, codex-cli 0.163.0,
  cursor-agent 2026.10.16-e3cb207, Ruby 3.4.10. The shipped Tier-1 tool is not modified.

## 4. Configurations and call paths

| family | configurations | model requested | effort | path |
|---|---|---|---|---|
| Claude | opus55-{low,medium,high,xhigh} | claude-opus-5-5 | `--effort` | `claude -p` (operator's subscription) |
| | fable51-{…} | claude-fable-5-1 | `--effort` | same |
| | sonnet55-{…} | claude-sonnet-5-5 | `--effort` | same |
| Codex | astra-{low,medium,high,xhigh} | gpt-6-astra | `-c model_reasoning_effort=` | `codex exec` (operator's subscription) |
| Cursor | composer25 | composer-2.5 (fast off) | none — the model has no setting | `cursor-agent -p --mode ask` |

The exact argv per family is `ReaderStudy.argv_for` in `study.rb`. Every read runs in a
fresh empty working directory, prompt on stdin, as its own process.

**Isolation, and what each path still adds.** The agentic CLIs carry their own preamble,
which cannot be removed; it is constant within a family and differs between families.
Measured on 2026-10-18 with short non-study prompts:

| path | isolation applied | preamble left | tools left |
|---|---|---|---|
| Claude | `--system-prompt ""`, `--tools ""`, no MCP, `--setting-sources ""`, no slash commands, no session persistence; `CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000` | ≈ 640 tokens: "You are a Claude agent, built on Anthropic's Claude Agent SDK.", an environment block (working directory, platform, model name, date) and a reminder carrying the operator's e-mail address | none |
| Codex | fresh `CODEX_HOME` holding only a link to `~/.codex/auth.json`; `--ignore-user-config --ignore-rules --ephemeral`; read-only sandbox; `web_search=disabled`; features apps, plugins, skill_search, browser_use(_external), computer_use, shell_tool, multi_agent, goals, image_generation, tool_suggest disabled | ≈ 11,000 tokens of Codex's own instructions and four built-in skills (imagegen, openai-docs, skill-creator, skill-installer) | MCP resource listing only (empty) |
| Cursor | fresh `HOME` holding a link to `~/Library/Keychains` (auth) and a copy of `~/.cursor/cli-config.json` whose permissions deny `Shell(*) Read(**) Write(**) WebFetch(*) Mcp(*:*)`, web search not auto-accepted; ask mode | ≈ 10,000 tokens of Cursor's own instructions and built-in skills; an account-level setting makes it answer in Japanese | glob/grep (the working directory is empty); reads and web denied |

Why the isolation exists: in the harness check (§8) the default Cursor home read
`~/.claude/skills/genomicschain_tier1/SKILL.md` on its own, and the default Codex home
listed the operator's skills and plugins and offered web search.

**Not reported by the CLI.** Codex and Cursor do not return the identifier of the model
that answered (Cursor returns the display name "Composer 2.5"); the record says so rather
than echoing the request. Claude Code returns it (`modelUsage`), and the record keeps it.
Effort means different things to different providers; the label is what was sent, not a
claim that the levels are comparable across families.

## 5. Procedure

- **k = 3** reads per (document, configuration). 153 reads.
- **Order.** Five streams in parallel (opus55, fable51, sonnet55, astra, composer25); within
  a stream one read at a time, ordered by repetition, then document (P, V0, V1), then effort
  (low → xhigh). `run_plan.rb --list` prints the order.
- **Retries.** A transport failure — non-zero exit, timeout (3,600 s per attempt) or an empty
  answer — is retried after 60 s, then after 300 s; every attempt is kept. An answer that
  arrives but does not score (no JSON, schema error, derivation error) is a result:
  outcome `invalid`, not retried. A read whose attempts all fail is `failed`. Both count in k.
- **No re-runs.** A read with a `record.json` is never repeated. Reads after the third of a
  cell do not exist by construction.
- **Logging.** `runs.jsonl` gets a start entry before each call and an end entry after it.
- **Deviations** from this text are appended to §10 with the time and the reason, before
  the analysis is run.

## 6. Endpoints and analysis (descriptive; no ground truth, no tests)

Per read: outcome; counts `S, n_R, n_RI, n_NI, n_X, W`; `capture_claim`; `stage2_candidate`;
number of gaps and their type labels; number of tool calls and `outside_access` (a tool call
targeting anything but the empty working directory, or a successful web call); seconds;
model as returned.

Per cell (document × configuration), the three values of each endpoint, and whether the
tuple (S, n_RI, n_NI, n_X) is identical across the three reads.

Comparisons, all descriptive: within a cell (spread); across effort within a model (any
trend); across models at the same effort label; Claude, Codex and Cursor families. Step
identity is not compared across reads (labels differ), and no step-matching rule is used.

**V-arm detection.** Two rules, decided now, applied by `analyze.rb`:

- **D2 (this study's rule).** A gap *names the reference release* when the text of the gap
  object (every string or number in it, recursively, including its type label) matches
  `synthref|reference|transcriptome|リファレンス|参照|トランスクリプトーム` **and**
  `release|version|リリース|バージョン|版`, case-insensitive. A read flags when at least
  one gap does. Reported per configuration as V1 x/3 and V0 y/3. This rule differs from
  round 1's: it accepts descriptive type labels, which round 1's numeric-type test never
  did.
- **R1 (round 1's rule, for continuity).** Exactly `selfapp/expected_v1.json`
  `rules.tier1_capture_rule`: type `2`, `2a` or `13`, and `where`/`missing` containing
  `salmon` or `synthref`.
- **Secondary, graded.** The mean version-axis score over steps whose label matches
  `salmon|quantif|tximport|aggregat|reference|index|定量|集計`, V1 against V0 per configuration.

**Data point zero.** sonnet55-high on P is set beside the hosted run (S 7, RI 4, NI 3,
`env_lock_claimed`, stage-2 candidate). The paths differ — Bedrock with the prompt in the
system field and provider-default effort, against Claude Code with the flattened prompt in
the user turn, the ≈ 640-token preamble and effort sent — so the comparison cannot separate
harness from model; it is reported as two observations, not as a test.

**Sensitivity.** Reads with `outside_access` are listed and every summary is also given
without them.

**Reporting.** As a dated observation of reader dependence on one paper and two fictional
manuscripts; never as a validation of the paper or of any reader.

## 7. Data flow and consent

The unposted preprint (P), and V0/V1, go to Anthropic (via the operator's Claude Code
subscription), OpenAI (via the operator's Codex/ChatGPT subscription) and Cursor (via the
operator's Cursor account, for its own model composer-2.5). The operator requested this
on 2026-10-18. The texts describe the author's own work and fictional subjects; no
third-party data is sent. The Claude Code preamble carries the operator's e-mail address,
which that provider already holds. Raw responses stay on the author's machine under
`log/tier1_reader_study_20261018/` (git-ignored).

## 8. Harness check before registration (not data)

Before freezing, each path was exercised on `pilot_text.md` (a 751-byte fictional note) and
on non-study prompts; those records are under `pilot/` and in `pilot_runs.jsonl` and are not
analysed. Findings that shaped §4: the Cursor and Codex isolation described there; Codex
`web__run` present until `web_search=disabled`; both CLIs accepted a 383 KB stdin prompt
(≈ 100k tokens) without truncation; Claude's empty system prompt was accepted.

## 9. Records

- `manifest.json` — documents, prompt hashes, configurations, code hashes, CLI versions,
  git head (frozen once by `freeze_inputs.rb`, which refuses to run again).
- `reads/<doc>/<config>/rep<k>/` — `attempt<n>.stdout|stderr` (raw bytes), `answer.txt`,
  `report.json`, `record.json`.
- `analysis/` — `reads.tsv`, `cells.tsv`, `summary.json` from `analyze.rb`.
- Ledger: one `chain_record` before the first read (this file's and the manifest's
  SHA-256), one after the analysis (the analysis files' SHA-256 and the deviation list).

## 10. Deviations

The registered bytes of this file (sha256 5d9918c8…, ledger block #72) are kept unchanged at
`log/tier1_reader_study_20261018/PREREGISTRATION_registered.md`; this section is appended after
registration.

- **D-1 (2026-10-18T15:07Z, found after 5 reads, before any analysis).** `outside_access` for
  Cursor misclassifies. `parse_cursor` collects a grep's *pattern* into the same `target` list as
  paths, and `analyze.rb` counts any non-workdir target with a successful result as outside
  access; the V0/composer25/rep1 read ran `grep "."` in the empty working directory, which this
  would count. The §6 definition is unchanged ("a tool call targeting anything but the empty
  working directory, or a successful web call"); only its implementation is corrected: the
  analysis re-reads the tool-call arguments from the raw `attempt<n>.stdout` and treats as a
  target only path-valued arguments (`path`, `targetDirectory`), a call without one targeting
  the working directory. Both classifications — as registered and as corrected — are reported.
  The reads themselves are unaffected.
- **D-2 (2026-10-19, found by the pre-flight falsifier of review round 5, after the analysis of
  ledger block 73).** D-1's corrected check treated every path containing `reader_study_` as the
  working directory, and the fresh home of §4 carries the same prefix (`reader_study_home_…`). The
  V0/composer25/rep2 read listed that fresh home (`globToolCall`, 0 files), which §6's definition
  counts as outside access. The check now treats as inside only paths under the working directory
  (`/reader_study_` not followed by `home_`). Result: corrected outside access 1 of 153 (that read),
  attempted 1 of 153; as registered, 7 of 153 unchanged. No other column of `reads.tsv` and no figure
  of `cells.tsv` other than that cell's count changes; the files of block 73 are kept at
  `log/tier1_reader_study_20261018/analysis_block73/`. Sensitivity (§6): without that read, every
  figure reported is unchanged except that V0 has 50 reads (D2 28 of 50).
- **D-3 (2026-10-19, the operator's decision after review round 5 of the paper).** §7 says the raw
  responses stay on the author's machine. They are deposited instead, with the reports, the analysis
  files, the harness check's records and the hosted run's report, in `Tier1_reader_study_v1.0.zip`
  with version 1.0 of the paper: they describe that paper, the fictional V0 and V1 and the fictional
  pilot note only. Before deposit the 826 files were searched for the operator's e-mail address
  (none found). One record of the harness check
  (`pilot/composer25/2026-10-18T133349.562Z/attempt1.stdout`) holds the operator's home path and the
  28-line description of this repository's own Tier-1 skill, which the default Cursor run opened
  (§4). No read, analysis or figure changes.
