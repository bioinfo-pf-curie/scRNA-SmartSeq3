/*
 * Samtools - Markdup
 */

process samtoolsMarkdup {
  tag "${meta.id}"
  label 'samtools'
  label 'medCpu'
  label 'medMem'

  input:
  tuple val(meta), path(bam)

  output:
  tuple val(meta), path ("*_markdup.bam"), emit: bam
  path ("*_markdup.log"), emit: logs
  path ("versions.txt"), emit: versions

  when:
  task.ext.when == null || task.ext.when

  script:
  def args = task.ext.args ?: ''
  def prefix = task.ext.prefix ?: "${meta.id}"
  """
  # remove duplicates 
  samtools markdup \\
    --threads ${task.cpus} \\
    ${args} \\
    ${bam} \\
    ${prefix}_markdup.bam &> ${prefix}_markdup.log

  echo \$(samtools --version | head -1) > versions.txt
  """
}

