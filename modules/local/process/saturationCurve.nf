process saturationCurve {
  label 'r'
  label 'lowCpu'
  label 'highMem'

  input:
  path(fastq)
  path(matrix)

  output:
  path("satCurve.txt"), emit: results

  script:
  """
  # get reads count per cell
  for r1 in *_concat.R1.fastq.gz
  do
    seqkit seq -n --only-id \$r1 | cut -f2 -d_ | sort | uniq -c >> reads_cell
  done
  awk '{print \$2, \$1}' reads_cell >  cell_reads

  # get gene count per cell
  for matrix in *_matrix.tsv.gz; do 
    gzip -cd \$matrix > mat
    samples=\$(awk 'NR==1 {for (i=2; i<=NF; i++) print \$i}' mat)
    totGenes=\$(awk 'NR > 1 {for (i=2; i<=NF; i++) if (\$i > 0) count[i]++} END {for (i=2; i<=NF; i++) print count[i]}' mat)
    paste <(echo "\$samples") <(echo "\$totGenes") >> cell_genes
  done

  # do saturatoin curve
  saturationCurve.r

  """
}




