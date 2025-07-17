/*
 * Samtools - Collate
 */

process samtoolsCollate {
  tag "${meta.id}"
  label 'samtools'
  label 'medCpu'
  label 'medMem'

  input:
  tuple val(meta), path (bam), path(bai)

  output:
  tuple val(meta), path ("*_collate.bam"), emit: bam
  path("versions.txt") , emit: versions

  when:
  task.ext.when == null || task.ext.when

  script:
  def args = task.ext.args ?: ''
  def prefix = task.ext.prefix ?: "${bam.baseName}"
  """
  echo \$(samtools --version | head -1 ) > versions.txt
  samtools collate \\
    ${args} \\
    -@  ${task.cpus}  \\
    -o ${prefix}_collate.bam  \\
    ${bam}
  """
}
