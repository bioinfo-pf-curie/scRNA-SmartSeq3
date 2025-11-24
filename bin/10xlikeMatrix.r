#!/usr/bin/env Rscript

.libPaths(setdiff(.libPaths(), normalizePath(Sys.getenv("R_LIBS_USER"))))

library(tidyverse)
library(Matrix)
library(data.table)

typeofcount<-as.character(commandArgs(TRUE)[1])

##### Merge individual matrices
####----------------------------------------
listFile<-list.files(path = ".", pattern= "*.tsv.gz", full.names = T)


if (typeofcount == "reads") { # si reads = format large
  i <- 1
  for (file in listFile) {
    matrix <- read.table(file, header = TRUE, check.names = FALSE, stringsAsFactors = FALSE)
    matrix$Geneid <- as.character(matrix$Geneid)
    
    if (nrow(matrix) > 1) {
      if (i == 1) {
        matrixFinal <- matrix
      } else {
        matrixFinal$Geneid <- as.character(matrixFinal$Geneid)
        matrixFinal <- merge(matrixFinal, matrix, by = "Geneid", all = TRUE)
      }
      i <- 2
    }
  }

  
  # Replace NA by 0 (row= genes/columns=sample)
  matrixFinal[is.na(matrixFinal)]<-0
  matrixFinal %>% pivot_longer(!Geneid, names_to = "cell", values_to = "count")-> longMatx

  longMatx$Geneid=as.factor(longMatx$Geneid)
  longMatx$cell=as.factor(longMatx$cell)
  longMatx$count=as.factor(longMatx$count)
  sparseMtx <- sparseMatrix(i=as.numeric(longMatx$Geneid),
                            j=as.numeric(longMatx$cell),
                            x=as.numeric(longMatx$count),
                            dimnames=list(levels(longMatx$Geneid), levels(longMatx$cell))) 

}else{ # long format "gene	| cell	| count"
  longMatx <- map_dfr(listFile, ~fread(cmd = paste("zcat", .x), header = TRUE, colClasses = list(character = "cell")))

  longMatx$gene=as.factor(longMatx$gene)
  longMatx$cell=as.factor(longMatx$cell)
  longMatx$count=as.factor(longMatx$count)
  sparseMtx <- sparseMatrix(i=as.numeric(longMatx$gene),
                            j=as.numeric(longMatx$cell),
                            x=as.numeric(longMatx$count),
                            dimnames=list(levels(longMatx$gene), levels(longMatx$cell))) 
}

# for features.tsv 1st coloumn = IDs and 2nd = gene names
ngenes <- nrow(sparseMtx)
gene.ids <- paste0("ID", seq_len(ngenes))
gene.names <- rownames(sparseMtx)
features <- data.frame(
  gene.ids,
  gene.names,
  stringsAsFactors = FALSE
)

##  Create 10X like outputs
dirName=paste0("10XlikeMatrix_", typeofcount)

# counts
writeMM(sparseMtx, file = paste0(dirName, "/matrix.mtx"))
# genes
write.table(
  features,
  file = paste0(dirName, "/features.tsv"),
  quote = FALSE,
  sep = "\t",
  row.names = FALSE,
  col.names = FALSE
)
# cell
write.table(
  colnames(sparseMtx),
  file = paste0(dirName, "/barcodes.tsv"),
  quote = FALSE,
  sep = "\t",
  row.names = FALSE,
  col.names = FALSE
)