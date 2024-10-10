/*
 * Umitools count UMIs to generate tab delimited matrix
 */

process umitoolsCount {
  tag "${meta.id}"
  label 'umiTools'
  label 'lowCpu'
  label 'medMem'

  input: 
  tuple val(meta), path(bam)

  output:
  tuple val(meta), path("*_matrix.tsv.gz"), emit: matrix
  tuple val(meta), path("*.log"), emit: log
  path("versions.txt"), emit: versions

  script:
  def args = task.ext.args ?: ''
  def prefix = task.ext.prefix ?: "${meta.id}"
  """
  umi_tools count ${args} \\
    -I ${bam} -S ${prefix}_matrix.tsv.gz > ${prefix}_UmiCounts.log
  umi_tools --version | cut -f1,3 -d" " &> versions.txt
  """
}