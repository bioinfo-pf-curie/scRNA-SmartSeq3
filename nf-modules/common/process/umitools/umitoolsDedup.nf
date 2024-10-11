/*
 * Umitools remove PCR duplicates
 */

process umitoolsDedup {
  tag "${meta.id}"
  label 'umiTools'
  label 'lowCpu'

  input: 
  tuple val(meta), path(bam), path(bai)

  output:
  tuple val(meta), path("*.bam"), emit: bam
  tuple val(meta), path("*.log"), emit: log
  path("versions.txt"), emit: versions

  script:
  def args = task.ext.args ?: ''
  def prefix = task.ext.prefix ?: "${bam.baseName}"
  """
  umi_tools count ${args} \\
    -I ${bam} -S ${prefix}_umitoolsDedup.bam > ${prefix}_umitoolsDedup.log
  umi_tools --version | cut -f1,3 -d" " &> versions.txt
  """
}