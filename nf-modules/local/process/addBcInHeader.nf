process addBcInHeader {
  label 'seqkit'
  label 'minCpu'
  label 'minMem'
  tag "$meta.id"

  input:
  tuple val(meta), path(reads)

  output:
  tuple val("${meta.id}"), path("addBcInHeader"), emit: reads

  script:
  """
  mkdir addBcInHeader
  for fastq in ${reads}/*.fastq.gz
  do
  prefix=\$(basename \$fastq .fastq.gz)
  seqkit replace -p " " -r '_CELL'\$prefix' '  \$fastq > "addBcInHeader/rename_"\$prefix".fastq"
  gzip "addBcInHeader/rename_"\$prefix".fastq"
  done
  """
}