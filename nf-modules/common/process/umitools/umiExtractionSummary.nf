/*
 * Umitools extract UMI
 */

process umiExtractionSummary {
  tag "${meta.id}"
  label 'umiTools'
  label 'lowCpu'
  label 'lowMem'

  input: 
  tuple val(meta), path(raw_reads), path(umiExtraction_r1), path(umiExtraction_r2), path(fastqNoUmi_R1), path(fastqNoUmi_R2)

  output:
  tuple val(meta), path("*_totReads.R1.fastq.gz"), path("*_totReads.R2.fastq.gz"), emit: fastq
  tuple val(meta), path("*_nonUmisReadsIDs.txt"), emit: nonUmiReadId
  tuple val(meta), path("*_pUMIs.txt"), emit: percentUmi
  tuple val(meta), path("*_nbTotFrag.txt"), emit: nbTotFrag

  script:
  def args = task.ext.args ?: ''
  def prefix = task.ext.prefix ?: "${meta.id}"
  """
  # save read IDs that have no umis in a file to extract them after alignment 
  seqkit seq -j ${task.cpus} -n -i ${fastqNoUmi_R2} -o ${prefix}_nonUmisReadsIDs.txt

  # concatenate R1 and R2 umi reads == all umi reads 
  cat ${umiExtraction_r2[0]} >> ${umiExtraction_r1[0]}
  ############## Save % UMIs reads
  nb_lines=`wc -l < <(gzip -cd ${raw_reads[0]})`
  nb_totFrag=\$(( \$nb_lines / 4 ))
  echo "totFrag: \$nb_totFrag" > ${prefix}_nbTotFrag.txt

  nb_lines=`wc -l < <(gzip -cd ${umiExtraction_r1[0]}) `
  nb_umis=\$(( \$nb_lines / 4 ))
  echo "percentUMI:\$(( \$nb_umis * 100 / \$nb_totFrag ))" > ${prefix}_pUMIs.txt
  ##############
  # add non umi reads == all reads 
  cat ${fastqNoUmi_R1} >> ${umiExtraction_r1[0]}
  mv ${umiExtraction_r1[0]} ${prefix}_totReads.R1.fastq.gz

  # concatenate R1 and R2 umi reads
  cat ${umiExtraction_r2[1]} >> ${umiExtraction_r1[1]} 
  # add non umi reads
  cat ${fastqNoUmi_R2} >> ${umiExtraction_r1[1]} 
  mv ${umiExtraction_r1[1]} ${prefix}_totReads.R2.fastq.gz
  """
}