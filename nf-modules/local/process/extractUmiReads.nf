/* Extract reads having an underscore in id */

process extractUmiReads {
  tag "${meta.id}"
  label 'umiTools'
  label 'lowCpu'
  label 'medMem'

  input: 
  tuple val(meta), path(bam)

  output:
  tuple val(meta), path("*_umi.bam"), emit: bam

  script:
  def args = task.ext.args ?: ''
  def prefix = task.ext.prefix ?: "${bam.baseName}"
  """
  samtools view -h ${bam} | awk 'BEGIN{OFS="\t"} /^@/ {print; next} \$1 ~ /_/ {print}' | samtools view -b -o ${prefix}_umi.bam
  """
}

