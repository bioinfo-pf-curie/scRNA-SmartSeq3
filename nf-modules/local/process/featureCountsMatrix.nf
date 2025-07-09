process featureCountsMatrix {
  label 'featurecounts'
  label 'lowCpu'
  label 'medMem'
  tag "$meta.id"

  input:
  tuple val(meta), path(counts), path(bam) // only to get the name

  output:
  tuple val(meta), path("*_matrix.csv.gz"), emit: matrix

  script:
  """
  cut -f1,7- ${counts} | sed -e "1d" > tmp

  awk 'NR==1 {print; next} {
    sum = 0
    for (i = 2; i <= NF; i++) sum += \$i
    if (sum != 0) print
  }' tmp > nonzero_rows

  sed "s/$bam://g" nonzero_rows > ${counts.baseName}_matrix.csv
  gzip ${counts.baseName}_matrix.csv 
  """
}