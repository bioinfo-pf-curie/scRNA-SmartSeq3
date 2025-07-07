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
  revcomp_seq=\$(echo "${params.primerT}" | tr 'ATCG' 'TAGC' | rev)

  cutadapt \
    -b "${params.primerT}" -b \$revcomp_seq \
    -B "${params.primerT}" -B \$revcomp_seq \
    -b T{10} -b T{15} -b T{20} \
    -B T{10} -B T{15} -B T{20} \
    ${args} \
    --cores=${task.cpus} \
    -o ${prefix}_trimmed_R1.fastq.gz -p ${prefix}_trimmed_R2.fastq.gz \
    ${reads} > ${prefix}_cutadapt.log
  echo "cutadapt "\$(cutadapt --version) > versions.txt
  """
}