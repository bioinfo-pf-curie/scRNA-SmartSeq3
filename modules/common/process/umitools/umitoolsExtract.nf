/*
 * Umitools extract UMI
 */

process umitoolsExtract {
  tag "${meta.id}"
  label 'umiTools'
  label 'lowCpu'
  label 'medMem'

  input: 
  tuple val(meta), path(reads)

  output:
  tuple val(meta), path("*_UMIsExtracted*"), emit: fastq
  tuple val(meta), path("*_noUMI*"), emit: noumi
  tuple val(meta), path("*.log"), emit: log
  path("versions.txt"), emit: versions

  script:
  def args = task.ext.args ?: ''
  def prefix = task.ext.prefix ?: "${meta.id}"
  """
  umi_tools extract ${args} \
  --stdin=${reads[0]} --read2-in=${reads[1]} \
  --stdout=${prefix}_UMIsExtracted.R1.fastq.gz --read2-out=${prefix}_UMIsExtracted.R2.fastq.gz \
  --filtered-out ${prefix}_noUMI.R1.fastq.gz --filtered-out2 ${prefix}_noUMI.R2.fastq.gz \
  --log=${prefix}_umiExtract.log
  umi_tools --version | cut -f1,3 -d" " &> versions.txt
  """
}