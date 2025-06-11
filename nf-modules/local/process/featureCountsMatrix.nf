process featureCountsMatrix {
  label 'featurecounts'
  label 'lowCpu'
  label 'medMem'
  tag "$meta.id"

  input:
  tuple val(meta), path(counts)
  tuple val(meta), path(bam) // only to get the name

  output:
  tuple val(meta), path("*_matrix.csv"), emit: matrix

  script:
  """
  cut -f1,7- ${counts} | sed -e "1d" > tmp
  sed "s/$bam://g" tmp > ${counts.baseName}_matrix.csv
  """
}