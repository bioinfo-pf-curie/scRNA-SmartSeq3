/*
 * Umitools count UMIs to generate tab delimited matrix
 */

process umitoolsCount {
  tag "${meta.id}"
  label 'umiTools'
  label 'lowCpu'

  input: 
  tuple val(meta), path(bam), path(bai)

  output:
  tuple val(meta), path("*_matrix.tsv.gz"), optional: true, emit: matrix
  tuple val(meta), path("*.log"), emit: log
  path("versions.txt"), emit: versions

  script:
  def args = task.ext.args ?: ''
  def prefix = task.ext.prefix ?: "${bam.baseName}"
  """
  umi_tools count ${args} \\
    -I ${bam} -S ${prefix}_matrix.tsv.gz > ${prefix}_umitoolsCount.log

  # as umitools still create the matrix even if it is empty, I removed it afterworads if empty
  count=\$(awk '/reads counted:/ {print \$NF}' "${prefix}_umitoolsCount.log")
  if [ "\$count" -lt 1 ]; then
      rm ${prefix}_matrix.tsv.gz
  fi

  umi_tools --version | cut -f1,3 -d" " &> versions.txt
  """
}