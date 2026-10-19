# A fictional note used only to check the reader-study harness

This text describes no real study. It exists so that each command-line path can
be exercised end to end before the registered reads begin.

## Methods

Reads from six fictional samples were trimmed with fastp 0.23.4 (default
parameters) and quantified against a fictional transcriptome, ExampleRef
release 2, with salmon 1.10.3 (`--validateMappings`). Gene-level counts were
aggregated with tximport 1.30 and tested with DESeq2 1.42 (design `~ group`,
alpha 0.05). The analysis ran in a conda environment exported to
`environment.yml`.

## Data availability

The fictional reads are not deposited anywhere.

## Code availability

The analysis script is described here but not published.
