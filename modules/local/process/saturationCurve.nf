process saturationCurve {
  label 'unix'
  label 'lowCpu'
  label 'medMem'

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
    paste <(echo "\$samples") <(echo "\$totGenes") >> genes_cell
  done

  sort -k2 reads_cell > reads_cell.sorted
  sort -k1 genes_cell > genes_cell.sorted
  join -1 2 -2 1 reads_cell.sorted genes_cell.sorted | tr ' ' ',' > satCurve.txt
  """
}




