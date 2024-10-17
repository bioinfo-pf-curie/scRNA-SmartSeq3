process featureCountsMatrix {
  label 'featurecounts'
  label 'lowCpu'
  label 'medMem'
  tag "$meta.id"

  input:
  tuple val(meta), path(counts)

  output:
  tuple val(meta), path("*_matrix.csv"), emit: reads

  script:
  """
  cut -f1,7- ${counts} > ${counts.baseName}_matrix.csv
  """
}