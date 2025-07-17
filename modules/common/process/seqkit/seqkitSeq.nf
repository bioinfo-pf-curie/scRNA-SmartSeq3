process seqkitSeq {
  tag "${meta.id}"
  label 'seqkit'
  label 'lowCpu'
  label 'lowMem'

  input: 
  tuple val(meta), path(reads)

  output:
  tuple val(meta), path("*txt"), emit: seq
  path('versions.txt'), emit: versions

  script:
  def args = task.ext.args ?: ''
  def prefix = task.ext.prefix ?: "${meta.id}"
  """
  seqkit seq ${args} --threads ${task.cpus} -i ${reads} -o ${prefix}.txt
  echo \$(seqkit version 2>&1) > versions.txt
  """
}
