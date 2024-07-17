/*
 * Cutadatp
 */

process cutadapt {
  tag "${meta.id}"
  label 'cutadapt'
  label 'medCpu'
  label 'medMem'

  input:
  tuple val(meta), path(reads)

  output:
  tuple val(meta), path("*trimmed*fastq.gz"), emit: fastq
  tuple val(meta), path("*log"), emit: logs
  path ("versions.txt"), emit: versions

  when:
  task.ext.when == null || task.ext.when

  script:
  def prefix = task.ext.prefix ?: "${meta.id}"
  def args = task.ext.args ?: ''
  def outputs = meta.singleEnd ? "-o ${prefix}_trimmed.fastq.gz" : "-o ${prefix}_trimmed_R1.fastq.gz -p ${prefix}_trimmed_R2.fastq.gz"
  """
  cutadapt \
    ${args} \
    --cores=${task.cpus} \
    ${outputs} \
    ${reads} > ${prefix}_cutadapt.log
  echo "cutadapt "\$(cutadapt --version) > versions.txt
  """
}