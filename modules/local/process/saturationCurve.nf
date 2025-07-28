process saturationCurve {
  label 'unix'
  label 'lowCpu'
  label 'highMem'

  input:
  path(fastq)
  path(matrix)

  output:
  path("satCurve.txt"), emit: results

  script:
  """
  for r1 in *_concat.R1.fastq.gz
  do
    seqkit seq -n --only-id \$r1 | cut -f2 -d_ | sort | uniq -c >> reads_cell
  done

  for matrix in *_matrix.tsv.gz; do 
    gzip -cd \$matrix > mat
    samples=\$(awk 'NR==1 {for (i=2; i<=NF; i++) print \$i}' mat)
    totGenes=\$(awk 'NR > 1 {for (i=2; i<=NF; i++) if (\$i > 0) count[i]++} END {for (i=2; i<=NF; i++) print count[i]}' mat)
    paste <(echo "\$samples") <(echo "\$totGenes") >> cell_genes
  done

  LC_ALL=C sort -t \$'\t' -k1 -T ./ cell_genes > cell_genes.sorted
  awk '{print \$2, \$1}' reads_cell >  cell_reads
  LC_ALL=C sort -t \$'\t' -k1 -T ./ cell_reads > cell_reads.sorted

  join -1 1 -2 1 cell_reads.sorted cell_genes.sorted | tr ' ' ',' > satCurve.txt
  """
}




