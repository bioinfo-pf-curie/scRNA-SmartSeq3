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
  path ("${meta.id}*log"), emit: logs
  path ("versions.txt"), emit: versions

  when:
  task.ext.when == null || task.ext.when

  script:
  def prefix = task.ext.prefix ?: "${meta.id}"
  def args = task.ext.args ?: ''
  """
  cutadapt \
    ${args} \
    --cores=${task.cpus} \
    -o ${prefix}_trimmed_R1.fastq.gz -p ${prefix}_trimmed_R2.fastq.gz \
    ${reads} > ${prefix}_cutadapt.log
  echo "cutadapt "\$(cutadapt --version) > versions.txt
  """
}