



process extractUmiReads {
  tag "${meta.id}"
  label 'umiTools'
  label 'lowCpu'

  input: 
  tuple val(meta), path(bam)

  output:
  tuple val(meta), path("*_umi.bam"), emit: bam
  tuple val(meta), path("*.log"), emit: log
  path("versions.txt"), emit: versions

  script:
  def args = task.ext.args ?: ''
  def prefix = task.ext.prefix ?: "${bam.baseName}"
  """
  samtools view -h ${bam} | awk 'BEGIN{OFS="\t"} /^@/ {print; next} \$1 ~ /_/ {print}' | samtools view -b -o ${prefix}_umi.bam
  """
}

