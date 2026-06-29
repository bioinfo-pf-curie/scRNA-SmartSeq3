#!/usr/bin/env Rscript

.libPaths(setdiff(.libPaths(), normalizePath(Sys.getenv("R_LIBS_USER"))))

library(tidyverse)
library(data.table)

##### Generate saturation curve 
####----------------------------------------
genes <- read.table("cell_genes", sep = "\t", header = FALSE, stringsAsFactors = FALSE)
reads <- read.table("cell_reads", sep = " ", header = FALSE, stringsAsFactors = FALSE)

# Renommer colonnes
colnames(genes) <- c("cell", "gene_count")
colnames(reads) <- c("cell", "read_count")
genes$cell <- as.character(genes$cell)
reads$cell <- as.character(reads$cell)

# Faire la jointure
merged <- inner_join(reads, genes, by = "cell")


# Sauvegarder en CSV
write.table(merged, file = "satCurve.txt", sep = ",", row.names = FALSE, col.names = FALSE, quote = FALSE)
