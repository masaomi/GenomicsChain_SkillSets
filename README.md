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
| `genomicschain_core` | 0.2.1 | Submit path: digest, admission gates, signing, Synoptis recording |
| `genomicschain_tier1` | 0.1.0 | Tier-1 readiness assessment — report schema v0.2.6 and the rubric |
| `genomicschain_tier2` | 0.3.0 | Tier-2 executed-R — execution backends, output comparator |

The three version independently but install as a set: `tier1` and `tier2` both
declare `genomicschain_core >= 0.2.0`.

### The two tiers

**Tier-1** reads a paper and asks what it *claims* about reproducibility — are
versions pinned, is the environment closed, is the data reachable. It never runs
anything, so it produces a ceiling: an upper bound on what a code check could
later confirm, not a reproducibility rate.

**Tier-2** executes a subject on a compute backend and compares the output against
a validated expectation. That is where a reproduction is actually established.

### Tools

| Tool | From | Registered when |
|---|---|---|
| `gc_tier1_submit` | core | `anchor_profile: true` only |
| `gc_tier2_submit` | core | `anchor_profile: true` only |
| `gc_tier2_execute` | tier2 | always |

## Requirements

- **KairosChain >= 3.58.0** (`gem install kairos-chain`). This is declared as
  `min_core_version` in `genomicschain_core/skillset.json` and enforced: on an
  older core the package is skipped with a message rather than loaded.
- `synoptis` and `llm_client` — ship with the gem and install automatically.
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
  tools/   gc_tier1_submit, gc_tier2_submit  (anchor only)
  schemas/ tier1 report submit gate (v0.2.6), tier2 verdict
  config/  deployment profile + anchor example
  test/
genomicschain_tier1/
  assets/    report schema v0.2.6
  knowledge/ repro_tier1_guide.md — the rubric
genomicschain_tier2/
  lib/     execution backends (local, Thoa), comparator, executor
  tools/   gc_tier2_execute
  test/
```

## Tests

The suites fall into three groups, because some of them test integration with
sibling SkillSets and therefore need those siblings to exist.

**Run from a clone, no extra paths** — `genomicschain_core/test/b1_manifest_hash_test.rb`,
`tip_source_test.rb`, and all three of `genomicschain_tier2/test/`:

```sh
cd genomicschain_core && ruby -Ilib -Itest test/b1_manifest_hash_test.rb
cd genomicschain_tier2 && ruby -Ilib -Itest -I../genomicschain_core/lib test/tools_test.rb
```

**Run from a clone with synoptis and mmp on the load path** — `tier1_submit_test.rb`,
`tier2_submit_test.rb`:

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
