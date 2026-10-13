export const meta = {
  name: 'tier1-rater3-batch2-retest',
  description: 'Tier-1 survey rater 3 (Opus 5.5, effort xhigh): batch 2 = draw idx 101-201 minus withdrawn (100) + within-rater retest (20, SEED_RETEST 202609021). Pre-registered as Amendment 2 (GenomicsChain_SkillSets chain #39, 2026-10-01).',
  phases: [
    { title: 'Assess', detail: 'batch 2 first reads; one subagent per paper; rater-3 tree only' },
    { title: 'Retest', detail: 'independent second reads of the 20 drawn papers; retest tree only' },
  ],
}

const MVP2 = '/Users/masa/forback/github/GenomicsChain_MVP2_2026'
const SKS = '/Users/masa/forback/github/GenomicsChain_SkillSets/corpus/repro_survey_2026_07'
const ITEMS2 = SKS + '/survey_v1_1/rater3_batch2_items.json'
const RETEST_ITEMS = SKS + '/survey_v1_1/rater3_retest_items.json'
const TEMPLATE = SKS + '/stage1_assessor_prompt.md'
const GUIDE = MVP2 + '/.kairos/knowledge/repro_tier1_guide/repro_tier1_guide.md'
const SCHEMA = MVP2 + '/log/reproducibility_framework/report_schema_v0_2_5.json'
const OUT_FIRST = SKS + '/survey_v1_1/rater3/by_paper'
const OUT_RETEST = SKS + '/survey_v1_1/rater3/retest'
const EARLIER = [
  MVP2 + '/log/repro_survey_2026_07/survey_v1_1/collection',
  MVP2 + '/log/repro_survey_2026_07/survey_v1_1/rater2',
  MVP2 + '/log/repro_survey_2026_07/collection',
  SKS + '/survey_v1_1/collection',
  SKS + '/collection',
]
const TODAY = '2026-10-01'

const KIND = {
  first: { items: ITEMS2, out: OUT_FIRST, suffix: 'rater3', scratch: 'stage1_r3_', forbidden: EARLIER.concat([OUT_RETEST, '/tmp/stage1_r3rt_* (every such directory)']) },
  retest: { items: RETEST_ITEMS, out: OUT_RETEST, suffix: 'rater3_retest', scratch: 'stage1_r3rt_', forbidden: EARLIER.concat([OUT_FIRST, '/tmp/stage1_r3_* (every such directory)']) },
}

const CAPTURE = ['none', 'floating', 'exact_pins_partial', 'release_snapshot', 'env_lock_claimed', 'container_digest_claimed']
const RESULT = {
  type: 'object',
  required: ['safe_id', 'canonical_id', 'written', 'report_path', 'capture_claim', 'stage2_candidate', 'S', 'W', 'n_NI', 'n_X', 'n_RI', 'repo_found', 'self_reported_model', 'note'],
  properties: {
    safe_id: { type: 'string' }, canonical_id: { type: 'string' },
    written: { type: 'boolean' }, report_path: { type: 'string' },
    capture_claim: { type: 'string', enum: CAPTURE }, stage2_candidate: { type: 'boolean' },
    S: { type: 'integer' }, W: { type: 'integer' }, n_NI: { type: 'integer' }, n_X: { type: 'integer' }, n_RI: { type: 'integer' },
    repo_found: { type: 'boolean' },
    self_reported_model: { type: 'string' },
    note: { type: 'string' },
  },
}

function prompt(k, n) {
  const K = KIND[k]
  return `You are RATER 3 in a pre-registered re-read of a Tier-1 computational-reproducibility survey (Amendments 1 and 2 to re-read pre-registration v1.0, registered before this run; GenomicsChain_SkillSets chain #36 and #39). One paper. Follow these steps exactly.

STEP 1 — your item (draw idx ${n}). Run:
  python3 -c "import json;print(json.dumps([x for x in json.load(open('${K.items}')) if x['idx']==${n}][0],ensure_ascii=False))"
It gives canonical_id, doi, title, jatsxml (a VERSION-PINNED URL — use exactly that URL, not the latest version), biorxiv_url, safe_id.

STEP 2 — read, in full, with the Read tool:
  (a) the rubric guide ${GUIDE} (81 lines; its SHA-256 is the rubric_hash),
  (b) the assessor prompt template ${TEMPLATE} (52 lines),
  (c) the report schema ${SCHEMA}.

STEP 3 — instantiate the template's {{...}} fields from your item ({{today}} = ${TODAY}; {{canonical_id_safe}} = safe_id) and follow the template as your instructions, with EXACTLY these rater-3 overrides and no others:
  - assessor_id: "claude (stage1 subagent, rater3) + masaomi"
  - assessed_at: "${TODAY}"
  - assessor_stack: {"operator_id":"masaomi","llm":{"provider":"claude_code","model":"claude-opus-5-5","effort":"xhigh","invoked_at":"<UTC ISO8601 from: date -u +%Y-%m-%dT%H:%M:%SZ, taken when you start scoring>"},"stage":"stage1-prose-only"}
  - manifest.b1_manifest_hash: sha256 of the pipe-delimited string canonical_id.value|rubric_hash|assessor_id|assessed_at (compute with: printf '%s' '<string>' | shasum -a 256).
  - scratch directory: /tmp/${K.scratch}<safe_id>/ (mkdir -p). NEVER write to a shared /tmp path — assessors run concurrently.
  - OUTPUT: instead of returning the JSON object as text, WRITE it (pretty-printed) with the Write tool to
      ${K.out}/<safe_id>/<safe_id>__stage1__v0.2.5__${K.suffix}.json
    (create the directory first with mkdir -p; if the directory already exists but is empty, that is a leftover from an interrupted earlier attempt — just proceed). It must contain every field the schema marks required, plus stage2_candidate and assessor_stack.

STEP 4 — fetching. biorxiv.org returns HTTP 403 to WebFetch and Cloudflare 429/1015 to plain curl. Do NOT use WebFetch for biorxiv.org. Use:
  curl -sSL -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36" --retry 6 --retry-delay 5 --retry-all-errors -o /tmp/${K.scratch}<safe_id>/paper.xml "<jatsxml>"
If the file is empty or is an HTML error page after that, sleep 20 and retry once; if still failing, fall back to the landing page (biorxiv_url) with the same curl, and if that also fails set assessable.is_assessable=false with reason_if_not and still write the report. Also fetch the code repository landing page / README the paper names, if any (for GitHub, raw.githubusercontent.com README is fine; WebFetch is allowed for non-biorxiv hosts).
MANDATORY before scoring: grep the fetched text for a distinctive phrase from the title. If it is absent you fetched the wrong document — discard, re-fetch, and report the incident in \`note\`.

STEP 5 — fetch manifest. Write ${K.out}/<safe_id>/fetch_manifest.json:
  {"canonical_id": "...", "retrieved_at": "<UTC ISO8601>", "sources": [{"url": "...", "kind": "jats"|"landing"|"repo", "http_ok": true|false, "sha256": "<sha256 of the fetched bytes, via shasum -a 256>"}]}
one entry per URL you fetched (including failed ones, with http_ok=false and sha256="").

STEP 6 — independence. Do NOT open, list, grep, or read anything under any of these locations (other reads of these papers), nor any other file in either repository beyond the ones named above:
${K.forbidden.map(p => '  ' + p).join('\n')}
This read must be blind to every other read.

STEP 7 — return via StructuredOutput: safe_id, canonical_id, written (true only if the report file was written), report_path, capture_claim, stage2_candidate, S, W, n_NI, n_X, n_RI (copied from the report you wrote), repo_found (true if you found a code-repository URL for this paper), self_reported_model (the exact model id your own environment/system information states you are running as — copy it, do not guess; "unknown" if it is not stated), note (short; "" if nothing to report — fetch incidents, wrong-document re-fetches, and assessable=false go here).`
}

const FIRST_IDX = Array.from({ length: 101 }, (_, i) => i + 101).filter(n => n !== 103)
const RETEST_IDX = [30, 32, 34, 55, 75, 76, 83, 86, 97, 101, 105, 114, 141, 142, 144, 157, 159, 171, 188, 198]
const jobs = FIRST_IDX.map(n => ({ k: 'first', n })).concat(RETEST_IDX.map(n => ({ k: 'retest', n })))
log(`jobs: ${FIRST_IDX.length} first reads (idx 101-201 minus 103) then ${RETEST_IDX.length} retests`)

const results = await pipeline(jobs, j =>
  agent(prompt(j.k, j.n), {
    label: `rater3 ${j.k === 'first' ? '' : 'retest '}idx-${j.n}`,
    phase: j.k === 'first' ? 'Assess' : 'Retest',
    schema: RESULT, model: 'opus', effort: 'xhigh',
  }))

const summary = results.map((r, i) => r
  ? { kind: jobs[i].k, idx: jobs[i].n, safe_id: r.safe_id, written: r.written, capture_claim: r.capture_claim, stage2_candidate: r.stage2_candidate, S: r.S, W: r.W, n_NI: r.n_NI, n_X: r.n_X, n_RI: r.n_RI, repo_found: r.repo_found, self_reported_model: r.self_reported_model, note: r.note }
  : { kind: jobs[i].k, idx: jobs[i].n, failed: true })
for (const k of ['first', 'retest']) {
  const s = summary.filter(x => x.kind === k)
  const failed = s.filter(x => x.failed).map(x => x.idx)
  const notWritten = s.filter(x => !x.failed && !x.written).map(x => x.idx)
  log(`${k}: ${s.filter(x => x.written).length}/${s.length} written; not written idx ${notWritten.join(',') || 'none'}; agent failures idx ${failed.join(',') || 'none'}`)
}
const mismatch = summary.filter(x => !x.failed && !/claude-opus-5-5/.test(x.self_reported_model)).map(x => `${x.kind}:${x.idx}:${x.self_reported_model}`)
log(`self-reported model mismatches: ${mismatch.length}${mismatch.length ? ' — ' + mismatch.join('; ') : ''}`)

return { n_first: FIRST_IDX.length, n_retest: RETEST_IDX.length, model_mismatch: mismatch, summary }
