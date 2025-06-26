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
  if [ "${params.protocol}" == "flashseq" ]; then
    seq=${params.fs_primerT}
  elif [ "${params.protocol}" == "smartseq3" ]; then
      seq=${params.ss3_primerT}
  elif [ "${params.protocol}" == "liveseq" ]; then
      seq=${params.live_primerT}
  else
    echo "protocole inconnu"
  fi

  revcomp_seq=\$(echo "\$seq" | tr 'ATCG' 'TAGC' | rev)

  cutadapt \
    -b \$seq -b \$revcomp_seq \
    -B \$seq -B \$revcomp_seq \
    -b T{10} -b T{15} -b T{20} \
    -B T{10} -B T{15} -B T{20} \
    ${args} \
    --cores=${task.cpus} \
    -o ${prefix}_trimmed_R1.fastq.gz -p ${prefix}_trimmed_R2.fastq.gz \
    ${reads} > ${prefix}_cutadapt.log
  echo "cutadapt "\$(cutadapt --version) > versions.txt
  """
}