/*
 * samtools merge - Merge BAM files
 */

process samtoolsMerge{
  tag "${meta.id}"
  label 'samtools'
  label 'highCpu'
  label 'lowMem'

  input:
  tuple val(meta), path(bams)

  output:
  tuple val(meta), path("*_merged.bam"), emit: bam
  path("versions.txt"), emit: versions

  when:
  task.ext.when == null || task.ext.when

  script:
  def args = task.ext.args ?: ''
  def prefix = task.ext.prefix ?: "${bams.baseName}"
  inputs = bams.collect{"${it}"}.join(' ')
  """
  samtools merge --threads ${task.cpus} ${args} ${prefix}_merged.bam ${inputs}
  echo \$(samtools --version | head -1) > versions.txt
  """
}
