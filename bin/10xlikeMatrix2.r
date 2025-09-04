#!/usr/bin/env Rscript

.libPaths(setdiff(.libPaths(), normalizePath(Sys.getenv("R_LIBS_USER"))))

library(tidyverse)
library(Matrix)
library(data.table)

typeofcount<-as.character(commandArgs(TRUE)[1])

##### Merge individual matrices
####----------------------------------------
listFile<-list.files(path = ".", pattern= "*.tsv.gz", full.names = T)

if ( typeofcount == "reads"){ #if reads = wide format
    i=1
    for (file in listFile ){
        matrix<-read.table(file, header=TRUE, check.names = F)
        if( nrow(matrix)>0 ){
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
    matrixFinal %>% 
        rename(gene = Geneid) %>%
        pivot_longer(!gene, names_to = "cell", values_to = "count")-> longMatx
    
}else{
    matrixFinal <- map_dfr(listFile, ~fread(cmd = paste("zcat", .x), header = TRUE))
}

longMatx$gene=as.factor(longMatx$gene)
longMatx$cells=as.factor(longMatx$cell)
longMatx$reads=as.factor(longMatx$count)
sparseMtx <- sparseMatrix(i=as.numeric(longMatx$gene),
                          j=as.numeric(longMatx$cell),
                          x=as.numeric(longMatx$cell),
                          dimnames=list(levels(longMatx$gene), levels(longMatx$cell)))