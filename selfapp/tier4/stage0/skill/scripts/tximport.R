# SYNTHETIC — FICTIONAL STUDY. Distilled from the GenomicsChain self-application subject V0 (a generated, fictional RNA-seq study); not real data, not a real study.
#
# Aggregate salmon transcript quantifications to genes.
# Usage: Rscript tximport.R <samples.tsv> <tx2gene.tsv> <salmon_dir> <out.rds>

suppressPackageStartupMessages(library(tximport))

args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 4)

samples <- read.delim(args[1], comment.char = "#", stringsAsFactors = FALSE)
tx2gene <- read.delim(args[2], stringsAsFactors = FALSE)

files <- file.path(args[3], samples$sample, "quant.sf")
names(files) <- samples$sample
stopifnot(all(file.exists(files)))

txi <- tximport(files, type = "salmon", tx2gene = tx2gene, dropInfReps = TRUE)
saveRDS(txi, args[4])
