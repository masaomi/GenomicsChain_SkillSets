export const meta = {
  name: 'tier1-survey-extension-trial100',
  description: 'Tier-1 survey v1.1 prefix extension, first 100 (positions 202-302 minus withdrawn 300), read by rater 3 (Opus 5.5, effort xhigh). Chain #47, 2026-10-12. Also a plan-usage measurement trial.',
  phases: [{ title: 'Assess', detail: 'one subagent per paper; extension tree only' }],
}

const MVP2 = '/Users/masa/forback/github/GenomicsChain_MVP2_2026'
const SKS = '/Users/masa/forback/github/GenomicsChain_SkillSets/corpus/repro_survey_2026_07'
const ITEMS = SKS + '/survey_v1_1/extension_items_trial100.json'
const TEMPLATE = SKS + '/stage1_assessor_prompt.md'
const GUIDE = MVP2 + '/.kairos/knowledge/repro_tier1_guide/repro_tier1_guide.md'
const SCHEMA = MVP2 + '/log/reproducibility_framework/report_schema_v0_2_5.json'
const OUT = SKS + '/survey_v1_1/extension/by_paper'
const FORBIDDEN = [
  MVP2 + '/log/repro_survey_2026_07/survey_v1_1/collection',
  MVP2 + '/log/repro_survey_2026_07/survey_v1_1/rater2',
  MVP2 + '/log/repro_survey_2026_07/collection',
  SKS + '/survey_v1_1/collection',
  SKS + '/survey_v1_1/rater3',
  SKS + '/collection',
]
const TODAY = '2026-10-12'

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

function prompt(n) {
  return `You are RATER 3, the Stage-1 reader for a pre-registered prefix extension of a Tier-1 computational-reproducibility survey (sampling pre-registration v1.1 §4; extension recorded before this run on GenomicsChain_SkillSets chain #47). One paper. Follow these steps exactly.

STEP 1 — your item (draw position ${n}). Run:
  python3 -c "import json;print(json.dumps([x for x in json.load(open('${ITEMS}')) if x['idx']==${n}][0],ensure_ascii=False))"
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
  - scratch directory: /tmp/stage1_r3x_<safe_id>/ (mkdir -p). NEVER write to a shared /tmp path — assessors run concurrently.
  - OUTPUT: instead of returning the JSON object as text, WRITE it (pretty-printed) with the Write tool to
      ${OUT}/<safe_id>/<safe_id>__stage1__v0.2.5__rater3.json
    (create the directory first with mkdir -p; if the directory already exists but is empty, that is a leftover from an interrupted earlier attempt — just proceed). It must contain every field the schema marks required, plus stage2_candidate and assessor_stack.

STEP 4 — fetching. biorxiv.org returns HTTP 403 to WebFetch and Cloudflare 429/1015 to plain curl. Do NOT use WebFetch for biorxiv.org. Use:
  curl -sSL -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36" --retry 6 --retry-delay 5 --retry-all-errors -o /tmp/stage1_r3x_<safe_id>/paper.xml "<jatsxml>"
If the file is empty or is an HTML error page after that, sleep 20 and retry once; if still failing, fall back to the landing page (biorxiv_url) with the same curl, and if that also fails set assessable.is_assessable=false with reason_if_not and still write the report. Also fetch the code repository landing page / README the paper names, if any (for GitHub, raw.githubusercontent.com README is fine; WebFetch is allowed for non-biorxiv hosts).
MANDATORY before scoring: grep the fetched text for a distinctive phrase from the title. If it is absent you fetched the wrong document — discard, re-fetch, and report the incident in \`note\`.

STEP 5 — fetch manifest. Write ${OUT}/<safe_id>/fetch_manifest.json:
  {"canonical_id": "...", "retrieved_at": "<UTC ISO8601>", "sources": [{"url": "...", "kind": "jats"|"landing"|"repo", "http_ok": true|false, "sha256": "<sha256 of the fetched bytes, via shasum -a 256>"}]}
one entry per URL you fetched (including failed ones, with http_ok=false and sha256="").

STEP 6 — independence. Do NOT open, list, grep, or read anything under any of these directories (other survey reports), nor any other file in either repository beyond the ones named above:
${FORBIDDEN.map(p => '  ' + p).join('\n')}

STEP 7 — return via StructuredOutput: safe_id, canonical_id, written (true only if the report file was written), report_path, capture_claim, stage2_candidate, S, W, n_NI, n_X, n_RI (copied from the report you wrote), repo_found (true if you found a code-repository URL for this paper), self_reported_model (the exact model id your own environment/system information states you are running as — copy it, do not guess; "unknown" if it is not stated), note (short; "" if nothing to report — fetch incidents, wrong-document re-fetches, and assessable=false go here).`
}

const idxs = Array.from({ length: 101 }, (_, i) => i + 202).filter(n => n !== 300)
log(`extension trial: ${idxs.length} papers (positions 202-302 minus withdrawn 300)`)
phase('Assess')
const results = await pipeline(idxs, n =>
  agent(prompt(n), { label: `ext pos-${n}`, phase: 'Assess', schema: RESULT, model: 'opus', effort: 'xhigh' }))

const ok = results.filter(Boolean)
const failedIdx = idxs.filter((n, i) => !results[i])
const notWritten = ok.filter(r => !r.written).map(r => r.safe_id)
const mismatch = ok.filter(r => !/claude-opus-5-5/.test(r.self_reported_model)).map(r => `${r.safe_id}:${r.self_reported_model}`)
log(`extension trial: ${ok.filter(r => r.written).length}/${idxs.length} written; not written ${notWritten.length}; agent failures ${failedIdx.length} (${failedIdx.join(',') || 'none'}); model mismatches ${mismatch.length}`)

return {
  n: idxs.length, failed_idx: failedIdx, not_written: notWritten, model_mismatch: mismatch,
  summary: results.map((r, i) => r ? { pos: idxs[i], safe_id: r.safe_id, written: r.written, capture_claim: r.capture_claim, stage2_candidate: r.stage2_candidate, S: r.S, W: r.W, n_NI: r.n_NI, n_X: r.n_X, n_RI: r.n_RI, repo_found: r.repo_found, self_reported_model: r.self_reported_model, note: r.note } : { pos: idxs[i], failed: true }),
}
