/*
 * Umitools remove PCR duplicates
 */

process umitoolsGroup {
  tag "${meta.id}"
  label 'umiTools'
  label 'lowCpu'

  input: 
  tuple val(meta), path(bam)

  output:
  tuple val(meta), path("*_umitoolsgroup.bam"), emit: bam
  tuple val(meta), path("*.log"), emit: log
  path("versions.txt"), emit: versions

  script:
  def args = task.ext.args ?: ''
  def prefix = task.ext.prefix ?: "${bam.baseName}"
  """
  umi_tools group \
  -I ${bam} \
  --output-bam ${prefix}_umitoolsgroup.bam \
  --log=${prefix}_umitoolsgroup.log \
  ${args}

  umi_tools --version | cut -f1,3 -d" " &> versions.txt
  """
}