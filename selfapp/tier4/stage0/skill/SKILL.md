**SYNTHETIC — FICTIONAL STUDY. This Skill was distilled from a generated, fictional RNA-seq study (GenomicsChain self-application subject V0); not real data, not a real study.**

# rnaseq_two_group_de — two-group RNA-seq differential expression with a permutation check

GenomicsChain Tier-4 Skill, version 0.1.0. Distilled on 2026-10-03 from the
differential-expression computation of subject V0, after that computation had run
under Tier 3. Tier 4 turns such a computation into a reusable Skill whose
study-specific values are parameters; the computation itself is carried over unchanged.

## What it does

Single-end reads are trimmed, quantified against a transcriptome, summed to genes,
and two groups of samples are compared. Each gene gets a DESeq2 test and, in
addition, a label-permutation p-value.

```
reads (one FASTQ per sample)
   │ fastp: adapter trimming, quality 20, min length 30
   ▼
trimmed reads ──────────────┐
                            │ salmon quant (library type A, selective alignment)
transcript FASTA            │
   │ salmon index (k = 31)  │
   └────────────────────────┤
                            ▼
                 transcript quantifications
                            │ tximport + tx2gene table
                            ▼
                  gene-level counts
                            │ DESeq2 (design + contrast)  and
                            │ permutation check (seed, draws)
                            ▼
      results/synthetic_supplementary_table_S1.tsv
```

The output table has one row per gene, sorted by `gene_id`, tab-separated, values
rounded to 6 significant digits, missing values written `NA`. Columns: `gene_id`,
`baseMean`, `log2FoldChange`, `lfcSE`, `stat`, `pvalue`, `padj` (from DESeq2),
`perm_pvalue`. The permutation p-value is `(k + 1) / (draws + 1)`, where `k` counts
the random relabellings of the samples whose mean log2 difference of normalised counts
(`log2(count + 1)`, numerator group minus denominator group) is at least as large in
absolute value as the observed one.

Intermediate files, tool reports and logs are written under `.work/`; `results/`
receives only the table.

## Parameters

Exactly six, all required, given in one parameter file (YAML or JSON). The schema is
`params.schema.json`; it rejects missing and unknown keys. Paths are relative to the
working directory.

| Parameter | What it is | Subject V0's value |
|---|---|---|
| `sample_table` | Tab-separated table; `#` lines skipped; header must contain `sample` and the column named in `comparison.variable` | `config/samples.tsv` |
| `reference` | `transcripts`: transcript FASTA; `tx2gene`: tab-separated table with header, transcript id then gene id | `data/synthetic_reference/synthetic_SynthRef_r3.transcripts.fa`, `data/synthetic_reference/synthetic_SynthRef_r3.tx2gene.tsv` |
| `comparison` | The comparison formula: `design` (one-sided R formula), `variable` (sample-table column), `numerator` and `denominator` (its two levels; fold change = numerator over denominator) | `~ condition`; `condition`, `treated` over `control` |
| `significance_threshold` | `alpha` given to DESeq2 `results()`; it sets the independent-filtering target and so affects `padj` | `0.05` |
| `permutation_seed` | Seed passed to R `set.seed()` before the relabellings | `20260929` |
| `permutation_draws` | Number of random relabellings | `200` |

`params.example.yaml` holds subject V0's values.

Two-group restriction: every sample's value in the `comparison.variable` column must be
either the numerator or the denominator level; the run stops otherwise.

## Fixed parts (not parameters)

These belong to the computation as distilled and are the same for every use:

- Reads are read from `data/synthetic_reads/synthetic_<sample>.fastq.gz`, one
  single-end file per row of the sample table.
- Adapter `AGATCGGAAGAGCACACGTCTGAACTCCAGTCAC`; fastp `--qualified_quality_phred 20
  --length_required 30`; salmon `--kmerLen 31`, `--libType A`, `--validateMappings`;
  one thread everywhere.
- The output path `results/synthetic_supplementary_table_S1.tsv`.

## How to run it

Working directory before the run:

```
<workdir>/
├── skill/                    this package, unchanged
├── params.yaml               the parameter file (start from skill/params.example.yaml)
├── config/samples.tsv        sample table (or wherever params.yaml points)
└── data/
    ├── synthetic_reads/      synthetic_<sample>.fastq.gz, one per sample
    └── synthetic_reference/  transcript FASTA and tx2gene table (or wherever params.yaml points)
```

Run from `<workdir>`, with one core, in the container image the source computation
ran in:

```sh
docker run --rm --platform linux/amd64 -v "$PWD":/work -w /work synthetic-rnaseq:1.0 \
  snakemake --cores 1 --snakefile skill/Snakefile --configfile params.yaml
```

The image is `synthetic-rnaseq:1.0`, image id
`sha256:004c13e8611f445b5be24dcac9749edd0a38a0aa136a0642a88c9ee7ee236504`, built from
subject V0's `Dockerfile` and `envs/rnaseq.lock` (Snakemake 9.27.0, fastp 1.3.7,
salmon 2.8.0, R 4.5.3, tximport 1.38.2, DESeq2 1.50.2). The package does not include
the image or its build files; see Provenance.

The result is `<workdir>/results/synthetic_supplementary_table_S1.tsv`.

## Package contents

| File | Role |
|---|---|
| `SKILL.md` | this description |
| `Snakefile` | the workflow; validates the parameter file against the schema before anything runs |
| `scripts/tximport.R` | transcript-to-gene aggregation |
| `scripts/deseq2.R` | DESeq2 test and permutation check; writes the table |
| `params.schema.json` | JSON Schema of the parameter file |
| `params.example.yaml` | parameter file with subject V0's values |
| `provenance.json` | where the Skill came from |

No input data and no output table are included; the reads, the reference and the
sample table belong to the user.

## Provenance

Source: subject V0 (`selfapp://synthetic_rnaseq_v1/V0`), the pipeline in
`selfapp/synthetic_rnaseq_v1/synthetic_repo/` at commit
`549accc9b5b6016ccb906b613ea2ea8da73ad4a6`, generated by the GenomicsChain
self-application generator (generator tree sha256
`daf3a8efe8ffca93a6ea90b95a44252d3f181b7f7679c9f2797b453c868e291d`). Its Tier-3 run
of 2026-10-03 has jobspec digest
`32eb8da644fdd8ee2df0d5986e1a6d8398a0b1d83416370d25559d376a8b5da1` and result hash
`227b0657c824fc7750681c17c31ca568b895ecdce90cdbe0f9ce89a74280ad9a`. Distilled by
Claude Opus 5.5 (`claude-opus-5-5`). Details, with hashes of the source files the
body was derived from, are in `provenance.json`.

What changed against the source pipeline:

- Parameterised: sample table, reference paths, alpha, permutation seed and draws now
  come from the parameter file instead of `config/config.yaml`; the design `~ condition`
  and the contrast treated vs control, written into `deseq2.R` in the source, now come
  from `comparison`.
- Kept as is: every tool command line, the tximport script body, the DESeq2 calls,
  the permutation loop, and the table writing.
- Left out: the MultiQC report rule (it reads tool reports and writes only under
  `.work/multiqc/`; nothing downstream uses it), the per-rule `container:` lines (used
  only on the Apptainer route, not on the Docker route the source results came from),
  and the unused `reference_release` setting.

This package states where it came from; it makes no claim about whether its output
matches the source. That is judged outside the package.
