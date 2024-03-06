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
  def prefix = task.ext.prefix ?: "${meta.id}"
  """
  for fastq in ${reads}
  do
  seqkit replace -p " " -r '_CELL'${prefix}' '  fastq > "rename_"${reads[0]}
  done
  """
}