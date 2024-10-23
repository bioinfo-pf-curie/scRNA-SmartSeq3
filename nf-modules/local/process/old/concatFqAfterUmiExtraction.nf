process concatFqAfterUmiExtraction {
  tag "${meta.id}"
  label 'umiTools'
  label 'lowCpu'
  label 'lowMem'

  input: 
  tuple val(meta), path(raw_reads), path(umiExtraction_r1), path(umiExtraction_r2),  path(fastqNoUmi_R2)

  output:
  tuple val(meta), path("*_totReads.R1.fastq.gz"), path("*_totReads.R2.fastq.gz"), emit: fastq
  tuple val(meta), path("*_nonUmisReadsIDs.txt"), emit: nonUmiReadId

  script:
  def args = task.ext.args ?: ''
  def prefix = task.ext.prefix ?: "${meta.batch}"
  """
  # save no umi read IDs to extract them after alignment 
  seqkit seq -j 4 -n -i ${fastqNoUmi_R2} -o ${prefix}_nonUmisReadsIDs.txt

  # concat all .R1.fastq.gz [0]
  cp ${umiExtraction_r1[0]} ${prefix}_totReads.R1.fastq.gz
  cat ${umiExtraction_r2[0]}>> ${prefix}_totReads.R1.fastq.gz
  cat ${fastqNoUmi_R2[0]} >> ${prefix}_totReads.R1.fastq.gz

  # concat all .R2.fastq.gz [1]
  cp ${umiExtraction_r1[1]} ${prefix}_totReads.R2.fastq.gz
  cat ${umiExtraction_r2[1]} >> ${prefix}_totReads.R2.fastq.gz
  cat ${fastqNoUmi_R2[1]} >> ${prefix}_totReads.R2.fastq.gz
  """
}
