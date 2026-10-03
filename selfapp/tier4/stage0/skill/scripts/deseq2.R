# SYNTHETIC — FICTIONAL STUDY. Distilled from the GenomicsChain self-application subject V0 (a generated, fictional RNA-seq study); not real data, not a real study.
#
# Differential expression of one sample-table column, numerator level vs
# denominator level, and a label-permutation check on the size-factor-normalised
# log fold change.
# Usage: Rscript deseq2.R <txi.rds> <samples.tsv> <out.tsv> <alpha> <draws> <seed>
#                         <design> <variable> <numerator> <denominator>

suppressPackageStartupMessages(library(DESeq2))

args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 10)
alpha <- as.numeric(args[4])
draws <- as.integer(args[5])
seed <- as.integer(args[6])
variable <- args[8]
numerator <- args[9]
denominator <- args[10]

# The design arrives as text. Accept only a one-sided formula `~ ...`, and build
# it without evaluating anything else in the text.
design_expr <- str2lang(args[7])
stopifnot(is.call(design_expr), identical(design_expr[[1]], as.name("~")), length(design_expr) == 2)
design <- eval(design_expr)
stopifnot(!is.na(alpha), !is.na(draws), draws >= 1, !is.na(seed),
          variable %in% all.vars(design), numerator != denominator)

txi <- readRDS(args[1])
samples <- read.delim(args[2], comment.char = "#", stringsAsFactors = FALSE)
stopifnot(variable %in% colnames(samples))
samples[[variable]] <- factor(samples[[variable]], levels = c(denominator, numerator))
# Two groups only: every sample must carry the numerator or the denominator level.
stopifnot(!anyNA(samples[[variable]]))
rownames(samples) <- samples$sample

dds <- DESeqDataSetFromTximport(txi, colData = samples, design = design)
dds <- DESeq(dds, quiet = TRUE)
res <- results(dds, contrast = c(variable, numerator, denominator), alpha = alpha)

# Permutation p-value: how often a random relabelling of the samples gives a
# mean log2 difference at least as large as the observed one.
norm <- log2(counts(dds, normalized = TRUE) + 1)
in_numerator <- samples[[variable]] == numerator
mean_diff <- function(labels) rowMeans(norm[, labels, drop = FALSE]) - rowMeans(norm[, !labels, drop = FALSE])
observed <- mean_diff(in_numerator)
set.seed(seed)
exceed <- rep(0L, nrow(norm))
for (i in seq_len(draws)) {
  exceed <- exceed + (abs(mean_diff(sample(in_numerator))) >= abs(observed))
}
perm_p <- (exceed + 1) / (draws + 1)

out <- data.frame(
  gene_id = rownames(res),
  baseMean = signif(res$baseMean, 6),
  log2FoldChange = signif(res$log2FoldChange, 6),
  lfcSE = signif(res$lfcSE, 6),
  stat = signif(res$stat, 6),
  pvalue = signif(res$pvalue, 6),
  padj = signif(res$padj, 6),
  perm_pvalue = signif(perm_p, 6),
  stringsAsFactors = FALSE
)
out <- out[order(out$gene_id), ]
write.table(out, args[3], sep = "\t", quote = FALSE, row.names = FALSE, na = "NA")
