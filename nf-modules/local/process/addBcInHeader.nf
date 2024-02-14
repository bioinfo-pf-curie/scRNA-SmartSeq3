process addBcInHeader {
  label 'seqkit'
  label 'minCpu'
  label 'minMem'
  tag "$meta.id"

  input:
  tuple val(meta), path (reads)

  output:
  tuple val("rename_"meta), path("*.fastq.gz"), emit: reads

  script:
  def prefix = task.ext.prefix ?: "${meta.id}"
  """
  seqkit replace -p " " -r '_CELL'${prefix}' ' ${reads[0]} > "rename_"${reads[0]}
  seqkit replace -p " " -r '_CELL'${prefix}' ' ${reads[1]} > "rename_"${reads[1]}
  """
}

