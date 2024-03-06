process addBcInHeader {
  label 'seqkit'
  label 'minCpu'
  label 'minMem'
  tag "$meta.id"

  input:
  tuple val(meta), path(reads)

  output:
  tuple val("rename_${meta.id}"), path("*.fastq.gz"), emit: reads

  script:
  """
  for fastq in ${reads}/*.fastq.gz
  do
  prefix=\$(basename \$fastq R{1,2}.fastq.gz)
  seqkit replace -p " " -r '_CELL'\$prefix' '  \$fastq > "rename_"${reads[0]}
  done
  """
}