#!/usr/bin/env Rscript

.libPaths(setdiff(.libPaths(), normalizePath(Sys.getenv("R_LIBS_USER"))))

library(tidyverse)
library(Matrix)

typeofcount<-as.character(commandArgs(TRUE)[1])

##### Merge individual matrices
####----------------------------------------
listFile<-list.files(path = ".", pattern= "*.tsv.gz", full.names = T)

if ( typeofcount == "reads"){ #if reads = wide format
  i=1
  for (file in listFile ){
    matrix<-read.table(file, header=TRUE, check.names = F)
    if( nrow(matrix)>1 ){
      if(i==1){
        matrixFinal<-matrix
      }else{
        matrixFinal<-merge(matrixFinal, matrix, by = "Geneid", all= TRUE)
      }
      i=2
    }
  }
  
  # Replace NA by 0 (row= genes/columns=sample)
  matrixFinal[is.na(matrixFinal)]<-0
  matrixFinal %>% pivot_longer(!Geneid, names_to = "cells", values_to = "reads")-> longMatx

  longMatx$Geneid=as.factor(longMatx$Geneid)
  longMatx$cells=as.factor(longMatx$cells)
  longMatx$reads=as.factor(longMatx$reads)
  sparseMtx <- sparseMatrix(i=as.numeric(longMatx$Geneid),
                            j=as.numeric(longMatx$cells),
                            x=as.numeric(longMatx$reads),
                            dimnames=list(levels(longMatx$Geneid), levels(longMatx$cells))) 

}else{ # long format "gene	| cell	| count"
  i=1
  for (file in listFile ){
    matrix<-read.table(file, header=TRUE, check.names = F)
    if( nrow(matrix)>1 ){
      if(i==1){
        longMatx<-matrix
      }else{
        longMatx<-rbind(longMatx, matrix[-1,])
      }
      i=2
    }
  }
  longMatx$gene=as.factor(longMatx$gene)
  longMatx$cell=as.factor(longMatx$cell)
  longMatx$count=as.factor(longMatx$count)
  sparseMtx <- sparseMatrix(i=as.numeric(longMatx$gene),
                            j=as.numeric(longMatx$cell),
                            x=as.numeric(longMatx$count),
                            dimnames=list(levels(longMatx$gene), levels(longMatx$cell))) 
}


##  Create 10X like outputs
dirName=paste0("10XlikeMatrix_", typeofcount)
writeMM(sparseMtx, file = paste0(dirName, "/matrix.mtx"))
write.table(rownames(sparseMtx), file = paste0(dirName, "/features.tsv"), quote = FALSE, sep = "\t", row.names = FALSE, col.names = FALSE)
write.table(colnames(sparseMtx), file = paste0(dirName, "/barcodes.tsv"), quote = FALSE, sep = "\t", row.names = FALSE, col.names = FALSE)

