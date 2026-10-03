---
name: selfapp_tier4_stage1_verdict_table
description: SYNTHETIC -- FICTIONAL STUDY. Apply GenomicsChain's deterministic Tiers (Tier-2 scan, Tier-2 adjudication, Tier-2.5 grade, Tier-3 comparison of frozen run directories, Tier-1 replay of recorded LLM responses) to a frozen input bundle of the fictional RNA-seq self-application subject, and write results/verdict_table.tsv. Tier-4 stage-1 distillation of a computation that passed Tier 3 on 2026-10-03.
---

# selfapp_tier4_stage1_verdict_table

> **SYNTHETIC -- FICTIONAL STUDY.** This Skill belongs to the GenomicsChain
> self-application demonstration. Its subject is a generated RNA-seq study with
> planted defects (variants V0-V8). It is not real data and not a real study.
> Nothing it writes describes a real experiment.

## Summary

You give it two things: how the subjects were made (generator, variant spec,
`make_variants.rb`) and a frozen input bundle. You run it with a checker and a
Ruby. It writes `results/verdict_table.tsv`: one row per comparison body, the
same rows the source computation writes. It also writes `skill_record.json`,
which records what the inputs were and how the bundle compares with the
variant spec. That record never changes the table.

## Working directory and invocation

```
WORK/                         a fresh directory
├── skill/                    this package, copied as is
└── params.json               the parameter file (any name; its path is given below)

cd WORK
ruby skill/bin/run.rb --checker-root CHECKER_ROOT --params params.json

WORK/ afterwards
├── skill/                    unchanged
├── params.json               unchanged
├── harness_out/              written by vendor/ddc_harness.rb (bodies/, environment.json,
│                             errors.json, loaded_files.txt, tier1_requests.json)
├── results/verdict_table.tsv written by vendor/verdict_table.rb   <- the output
└── skill_record.json         written by bin/run.rb (identities, steps, observations)
```

- **Command:** `ruby skill/bin/run.rb --checker-root CHECKER_ROOT --params PARAMS_FILE`,
  run with `WORK` as the current directory. Outputs go to the current directory.
- **`CHECKER_ROOT`** is environment, not a parameter: a directory holding the five
  checker packages as directories (`genomicschain_core`, `genomicschain_tier1`,
  `genomicschain_tier2`, `genomicschain_tier3`, `genomicschain_prov`, each with
  `lib/`). In the source repository this is `.kairos/skillsets`.
- **Ruby** is environment, not a parameter: whatever interpreter runs `run.rb`.
  Both steps are started with that same executable (`RbConfig.ruby`), and gems
  resolve as that interpreter resolves them. The source run used Ruby 3.4.10 with
  host rubygems and no bundler.

## The two parameters

| | Key in the parameter file | What it is | In the source repository |
|---|---|---|---|
| 1 | `subject_generation.generator_dir` | the subject generator (a directory) | `selfapp/generator` |
| 1 | `subject_generation.variant_spec` | the planted-fault variant spec (JSON) | `selfapp/variants_v1.json` |
| 1 | `subject_generation.make_variants` | the script that applies the spec | `scripts/selfapp/make_variants.rb` |
| 2 | `input_bundle` | a directory holding `inputs_manifest.json` and exactly the files it names | `log/selfapp/ddc_inputs_v1` |

**Parameter file.** JSON, exactly the keys above and no others; every value a
non-empty string. Schema: `params.schema.json` (JSON Schema 2020-12). Example:
`params.example.json` — replace `<repo>` with the repository root. A relative
path resolves against the directory that holds the parameter file; an absolute
path is used as is. `run.rb` checks the same rules by hand (standard library
only) and stops if they fail.

## What it does, in order

```
1 preflight      parameter file valid? paths exist? vendored copies match provenance.json?
                 harness_out / results/verdict_table.tsv / skill_record.json absent?
                 working directory outside bundle, generator, checker root?
                 checker root holds the five packages?
                     any "no"  -> exit 2, nothing written
2 computation    ruby vendor/ddc_harness.rb --checker-root CHECKER_ROOT --inputs BUNDLE --out harness_out
                 mkdir -p results
                 ruby vendor/verdict_table.rb harness_out results/verdict_table.tsv
                     a step fails -> skill_record.json written, exit with that step's status, no later step
3 observations   parameter 1 read against the bundle (record only, read only)
                 -> skill_record.json, exit 0
```

Step 2 is the source computation, unchanged: the same two scripts (byte-identical
copies, see Provenance), the same arguments, the same output names, the same
order, and the second step only after the first exits 0 (the source joined them
with `&&`). The harness first checks every bundle file against
`inputs_manifest.json` and stops on any difference.

## What happens to parameter 1, and why the table cannot change

The table depends only on the bytes of the two vendored scripts and
`ddc_common.rb`, the checker root, the Ruby and its gems, and the bundle.
Parameter 1 reaches none of these. It is never passed to the harness or the
table script, and step 3 starts only after the table file exists. Step 3 opens
nothing for writing except `skill_record.json`.

What step 3 does with each part of parameter 1:

- **Generator — identified, never run.** Its tree is hashed (every regular file,
  dot files included, symlinks not followed; lines `"<sha256>  <relpath>\n"`
  sorted bytewise; sha256 of the concatenation). Every `generator_manifest.json`
  the bundle names is read, and its `generator.tree_sha256` is compared with that
  hash. The generator is not run, because the bundle's subjects are not plain
  generator output: V0 was later filled by an author run, so regenerating would
  not reproduce them.
- **Variant spec and `make_variants.rb` — planned, never written.** The spec's
  `base.tree_sha256` is looked up among the directories of the bundle (directory
  hashes are computed from the `inputs_manifest.json` file hashes, which the
  harness has just checked against the bytes). If the base is found,
  `bin/plan_variants.rb` loads `make_variants.rb` in a separate process and calls
  only `MakeVariants.plan`, which builds each variant in memory and writes
  nothing. The spec is changed in memory before planning: `base.path` points at
  the bundle directory found, `output_root` names a directory that does not
  exist, and `execution_record` entries are dropped, because they name repository
  paths outside the bundle and are not part of a variant tree. Each planned
  variant is then compared with every bundle directory. Each path the harness
  reads is also compared with the planned variants.
- **Variant labels.** The labels in the bundle manifest are compared with the
  spec's ids (base plus variants). Labels not of the form `V<n>` are listed
  separately. For example, `genomicschain_C` is the checker's own source, scanned
  as a subject.

Everything step 3 finds goes into `skill_record.json` under `observations`, as
observations. A mismatch does not stop the Skill and does not change the exit
status. If step 3 raises an error, the error is recorded there and the table
stays as written.

## Writes, and what it never writes

It writes only `harness_out/`, `results/verdict_table.tsv` and
`skill_record.json`, all in the current directory. It never writes into the
bundle, the generator, the variant spec, `make_variants.rb` or the checker root.
It refuses to start if the current directory is, or lies inside, the bundle, the
generator directory or the checker root. Existing output is never overwritten.

`skill_record.json` carries host paths, because it records this run's
parameters. The package itself carries none.

## Exit status

`0` table written · `2` stopped in preflight, nothing written · any other value:
the harness's or the table script's own exit status (the harness exits 1 when any
item failed).

## Package contents

| Path | Role |
|---|---|
| `SKILL.md` | this file |
| `bin/run.rb` | executable body: preflight, the two steps, step 3, the record |
| `bin/plan_variants.rb` | helper for step 3: loads `make_variants.rb`, calls `MakeVariants.plan`, prints changed-file hashes |
| `vendor/ddc_harness.rb` | copy, unmodified (see below) |
| `vendor/ddc_common.rb` | copy, unmodified (see below) |
| `vendor/verdict_table.rb` | copy, unmodified (see below) |
| `params.schema.json` | JSON Schema of the parameter file |
| `params.example.json` | example parameter file (`<repo>` placeholder) |
| `provenance.json` | provenance, including the copies' sha256 that `run.rb` checks |

The package holds no data from the bundle, no comparison bodies and no verdict
table.

## Provenance

- **Source Tier-3 run** (2026-10-03, backend `local`, trust tier `self_reported`):
  subject_ref `selfapp://tier4/stage1/declared_computation`,
  jobspec_digest `5b6d000918f599602392ecd36546432336d72525ac49e4145f9fb77a83a1ac3a`,
  result_hash `dd97e807f8a7348139f077fd30a652ae3bcf420cb41cc1c3be527f9874af0b91`.
  Record: `log/selfapp/s8/launches/001_declared_computation/result.txt`;
  args: `log/selfapp/s8/args/declared_computation.json` (repository-relative).
- **Source commit:** `549accc9b5b6016ccb906b613ea2ea8da73ad4a6`. `ddc_harness.rb`
  and `ddc_common.rb` were last changed in it. `verdict_table.rb` is not in it;
  it was added in `15d065623f90f4f072b98b12ee0b75a2d1713a34`. All three copies
  were taken at `9cafe13f0cd544bf01e3b7c11047aefe1844a579`, where they had no
  uncommitted changes.

| Copy | From | sha256 |
|---|---|---|
| `vendor/ddc_harness.rb` | `scripts/selfapp/ddc_harness.rb` | `a1b787c7e302480cd21d437c70271054dd036311a3ebb999b8e5125c863dfa5b` |
| `vendor/ddc_common.rb` | `scripts/selfapp/ddc_common.rb` | `b2157892390ed26e9b1758f179180e1703cc68adf34258c62824860d00395ed5` |
| `vendor/verdict_table.rb` | `scripts/selfapp/verdict_table.rb` | `f3e7e2a6466bd1fb2bd6b4b6bf137effc8e4e4ac8d989803bd7bf4ad4c8e81be` |

- **Generator tree sha256:** `daf3a8efe8ffca93a6ea90b95a44252d3f181b7f7679c9f2797b453c868e291d`
  (generator 0.1.0, from `selfapp/synthetic_rnaseq_v1/generator_manifest.json`).
- **Distilled by:** Claude Opus 5.5 (`claude-opus-5-5`), stage-1 distiller,
  2026-10-03.

`provenance.json` holds the same facts in machine-readable form.

## Limits

- `skill_record.json` is written by the Skill about its own run. It is a
  self-report, not an independent judgment of the Skill.
- Step 3 executes parameter code: `make_variants.rb` is loaded in its own
  process. The Skill calls only `MakeVariants.plan`. It relies on that file's
  `$PROGRAM_NAME == __FILE__` guard to keep its command-line entry point from
  running on load.
- The table is reproducible only within the environment it was made in: the
  same checker packages, the same Ruby, the same gems. The Skill records the
  checker tree hash and the Ruby version but does not require particular values.
