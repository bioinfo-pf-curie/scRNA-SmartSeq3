#!/usr/bin/env Rscript

.libPaths(setdiff(.libPaths(), normalizePath(Sys.getenv("R_LIBS_USER"))))

library(tidyverse)
library(data.table)

##### Generate saturation curve 
####----------------------------------------
genes <- read.table("cell_genes", sep = "\t", header = FALSE, stringsAsFactors = FALSE)
reads <- read.table("cell_reads", sep = "\t", header = FALSE, stringsAsFactors = FALSE)

# Renommer colonnes
colnames(genes) <- c("cell", "genes_count")
colnames(reads) <- c("read_count", "cell")
genes$cell <- as.character(genes$cell)
reads$cell <- as.character(reads$cell)
genes <- genes[order(genes$cell), ]
reads <- reads[order(reads$cell), ]

# Faire la jointure
merged <- merge(reads, genes, by = "cell", all = FALSE)

# Sauvegarder en CSV
write.table(merged, file = "satCurve.txt", sep = ",", row.names = FALSE, col.names = FALSE, quote = FALSE)
