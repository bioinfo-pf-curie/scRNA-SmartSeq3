/*
 * Samtools - Fixmate
 */

process samtoolsFixmate {
  tag "${meta.id}"
  label 'samtools'
  label 'medCpu'
  label 'medMem'

  input:
  tuple val(meta), path (bam)

  output:
  tuple val(meta), path ("*_fixmate.bam"), emit: bam
  path('versions.txt'), emit: versions

  when:
  task.ext.when == null || task.ext.when

  script:
  def args = task.ext.args ?: ''
  def prefix = task.ext.prefix ?: "${bam.baseName}"
  """
  samtools fixmate \\
    -@  ${task.cpus}  \\
    ${bam} \\
    ${prefix}_fixmate.bam \\
    ${args}
  echo \$(samtools --version | head -1 ) > versions.txt
  """
}