# GenomicsChain_SkillSets

Reproducibility assessment and attestation for genomics research, packaged as
add-on SkillSets for [KairosChain](https://github.com/masaomi/KairosChain_2026).

These are not part of KairosChain. They install into an existing instance and are
removed the same way. KairosChain itself needs no modification to host them.

**This repository is the source of truth for these packages.** Copies under any
instance's `.kairos/skillsets/` are installed artifacts: edit here, then reinstall
there. They were previously developed inside `GenomicsChain_MVP2_2026`, where the
same directory was both the source and a running instance's copy — an arrangement
that makes "which one is authoritative" unanswerable the moment the two differ.

## What is here

| Package | Version | Role |
|---|---|---|
| `genomicschain_core` | 0.5.0 | Submit path: digest, admission gates, signing, Synoptis recording |
| `genomicschain_tier1` | 0.2.1 | Tier-1 readiness assessment — `gc_tier1_assess`, report schema v0.2.6, the rubric |
| `genomicschain_tier2` | 0.3.0 | Tier-2 code reading — `gc_tier2_scan`, `gc_tier2_adjudicate`; static, LLM-free |
| `genomicschain_tier3` | 0.5.0 | Tier-3 execution — backends, comparator, cost estimation |

The four version independently but install as a set: `tier1` and `tier3` declare
`genomicschain_core >= 0.2.0`; `tier2` depends on nothing and reads only what is on disk.

One numbering, everywhere, since 2026-09-09: Tier-1 reads the paper, Tier-2 reads the
code, Tier-3 executes. Package names, tool names, schemas and the signed claim prefixes
(`tier1:`, `tier2:`, `tier3:`) all carry the same number. Documents written before that date call
execution "Tier-2" and the code-reading package `genomicschain_codescan`; they are not
rewritten. `trust_tier` on a record is not a tier index but a guarantee level
(`self_reported` / `peer_verified` / `hardware_attested`).

### The three tiers

**Tier-1** reads a paper and asks what it *claims* about reproducibility — are
versions pinned, is the environment closed, is the data reachable. It never runs
anything, so it produces a ceiling: an upper bound on what a code check could
later confirm, not a reproducibility rate.

**Tier-2** reads the code the paper points at: what the repository declares about
software, containers and data, how strongly each is pinned, and what that means for
the Tier-1 report step by step. Still nothing runs. The workflow is parsed, never
evaluated, so the party being assessed can re-run the scan on their own copy and get
the same answer.

**Tier-3** executes a subject on a compute backend and, *if the paper declares a
comparison target*, checks the output against it.

That proviso is not hedging. A survey on 2026-08-14 of the five papers in a
201-paper corpus that passed the Tier-1 gate found **none** publishing a checksum
or nominating an artifact to compare against. So the two questions Tier-3 answers
are reported on separate axes: `execution_verdict` (did it run) and
`comparison_verdict` (did it match, or was there nothing to match against). A
record whose comparison axis reads `no_target_declared` is a complete result, and
it is the common one.

Records also carry `environment_provenance` and `inputs_provenance`, so a
certificate cannot describe an environment the operator built as the one the
paper declared, and cannot hide that inputs came from a controlled-access source
no third party can reach.

### Tools

| Tool | From | Registered when |
|---|---|---|
| `gc_tier1_assess` | tier1 | always |
| `gc_tier1_submit` | core | `anchor_profile: true` only |
| `gc_tier2_scan` | tier2 | always |
| `gc_tier2_adjudicate` | tier2 | always |
| `gc_tier2_submit` | core | `anchor_profile: true` only |
| `gc_tier3_submit` | core | `anchor_profile: true` only |
| `gc_tier3_execute` | tier3 | always |
| `gc_tier3_estimate` | tier3 | always |

## Requirements

- **KairosChain >= 3.58.0** (`gem install kairos-chain`). This is declared as
  `min_core_version` in `genomicschain_core/skillset.json` and enforced: on an
  older core the package is skipped with a message rather than loaded.
- `synoptis` and `llm_client` — ship with the gem and install automatically.
- `ed25519` and `json-schema` gems (`gem install ed25519 json-schema`).
  `genomicschain_core` verifies operator signatures with the first and validates
  manifests and verdicts with the second; both are required lazily, so a missing
  one surfaces as a `NameError` / `LoadError` at submit time, not at load. The
  kairos-chain gem does not pull them in, so install them on the anchor.
- `mmp` — ships inside the gem but is **not** auto-installed. It supplies the
  anchor's identity and signing key; without it the submit path fails closed.
  `install.sh` installs it for you.

### Why 3.58.0 and not earlier

These packages record through `synoptis`, whose verification semantics changed in
3.58.0: the verifying key now comes from the caller only. Before that, a proof
could be verified against a key recorded inside itself — and since the envelope's
`version` field selects which fields are signed, while `version` is itself a field
of the record, a forged proof relabelled to `1.1.0` verified clean from the record
alone with no key supplied. Measured on the published 3.57.0 gem:

```
forged, version 1.0.0, no key -> valid: false ["identity_outside_signature",
                                               "no_public_key_for_verification"]
forged, version 1.1.0, no key -> valid: true  errors: []
```

On 3.58.0 both return `valid: false`.

The floor is a floor, not a preference: on an older core these packages would
still record, and the proofs they wrote would be verifiable by anyone who
relabelled them. That is why it is a declared minimum rather than a note.

## Install

```sh
git clone https://github.com/masaomi/GenomicsChain_SkillSets.git
cd GenomicsChain_SkillSets
bash install.sh --data-dir /path/to/your/.kairos
```

`install.sh` also installs `mmp`, and checks afterwards that all four packages
are actually listed — see the note on argument order below.

Or by hand, in dependency order:

```sh
export KAIROS_DATA_DIR=/path/to/your/.kairos
kairos-chain skillset install ./genomicschain_core
kairos-chain skillset install ./genomicschain_tier1
kairos-chain skillset install ./genomicschain_tier2
kairos-chain skillset install ./genomicschain_tier3
kairos-chain skillset list
```

`install` copies the package and enables it.

### Argument order matters, and getting it wrong is silent

`--data-dir` must come *after* the subcommand, or not be used at all:

```sh
kairos-chain skillset list --data-dir DIR    # works
KAIROS_DATA_DIR=DIR kairos-chain skillset list    # works
kairos-chain --data-dir DIR skillset list    # starts the server, exits 0, does nothing
```

In the third form `--data-dir` is parsed as a server option and the subcommand is
never reached. It prints two INFO lines and returns success, so a script wrapping
it will report an install that did not happen. `install.sh` passes the target
through the environment for this reason, and verifies the result rather than
trusting the exit status.

## Upgrade

`install` copies rather than links, so `git pull` alone does not change what your
instance runs:

```sh
git pull
bash install.sh --force --data-dir /path/to/your/.kairos
```

`--force` preserves `config/`, so your `anchor_profile` setting is not reset.

## anchor_profile — read this before deploying

`genomicschain_core` ships with `anchor_profile: false`, and off-anchor the submit
tools are **absent from the tool list** rather than present-and-refusing. A node
that was never meant to sign cannot be talked into signing.

Exactly one node in a deployment should be the anchor: the one holding the signing
key and owning the Synoptis proof registry. To make a node the anchor, copy
`genomicschain_core.anchor.yml.example` over `config/genomicschain_core.yml` in the
*installed* copy and restart.

Proofs are append-only. A second anchor recording under a different key cannot be
un-recorded, only superseded.

## Verifying a proof

The verifying key comes from the caller and only from the caller. A key recorded
inside a proof would be a self-report — it tells you which key to check against
only if you already trust whoever wrote the record, which is the thing being
checked. So `attestation_verify` needs the anchor's public key obtained out of
band; omitting it returns `no_public_key_for_verification` and the proof is
reported invalid.

Binding a key to a named attester needs a trusted key list, which this layer does
not have. What a verified proof establishes is that these bytes were signed by
that key and have not changed since.

## Layout

```
genomicschain_core/
  lib/     submit pipeline, manifest, digests, Synoptis attestor
  tools/   gc_tier1_submit, gc_tier2_submit, gc_tier3_submit  (anchor only)
  schemas/ tier1 report submit gate (v0.2.6), tier2 adjudication, tier3 verdict
  config/  deployment profile + anchor example
  test/
genomicschain_tier1/
  assets/    report schema v0.2.6
  knowledge/ repro_tier1_guide.md — the rubric
genomicschain_tier2/
  lib/     scanner, parsers, pin-strength rubric, adjudicator
  tools/   gc_tier2_scan, gc_tier2_adjudicate
  test/
genomicschain_tier3/
  lib/     execution backends (local, Thoa), comparator, executor
  tools/   gc_tier3_execute, gc_tier3_estimate
  test/
```

## Tests

The suites fall into three groups, because some of them test integration with
sibling SkillSets and therefore need those siblings to exist.

**Run from a clone, no extra paths** — `genomicschain_core/test/b1_manifest_hash_test.rb`,
`tip_source_test.rb`, all four of `genomicschain_tier3/test/`, and both of
`genomicschain_tier2/test/`:

```sh
cd genomicschain_core && ruby -Ilib -Itest test/b1_manifest_hash_test.rb
cd genomicschain_tier2 && ruby -Ilib -Itest test/scanner_test.rb
cd genomicschain_tier3 && ruby -Ilib -Itest -I../genomicschain_core/lib test/tools_test.rb
```

**Run from a clone with synoptis and mmp on the load path** — `tier1_submit_test.rb`,
`tier2_submit_test.rb`, `tier3_submit_test.rb`:

```sh
cd genomicschain_core
T="$(ruby -e 'puts Gem::Specification.find_by_name("kairos-chain").gem_dir')/templates/skillsets"
ruby -Ilib -Itest -I"$T/synoptis/lib" -I"$T/mmp/lib" test/tier1_submit_test.rb
```

**Need an installed instance** — `synoptis_attestor_signing_test.rb` and
`topology_test.rb`. Both resolve siblings through `../../`: the signing suite reads
the shipped `synoptis/config/synoptis.yml` rather than a value it chose, and the
topology suite inspects which packages are enabled and which tools register. Run
them from `.kairos/skillsets/genomicschain_core/` after installing.

## Status

Prototype. The schemas and the submit contract are still moving; the digest and
admission gates are covered by tests and by mutation sweeps, but nothing here has
been through external security review.

## License

MIT. See [LICENSE](LICENSE).
