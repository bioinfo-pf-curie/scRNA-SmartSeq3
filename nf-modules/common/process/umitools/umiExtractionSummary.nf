/*
 * Umitools extract UMI
 */


process umiExtractionSummary {
  tag "${meta.id}"
  label 'umiTools'
  label 'lowCpu'
  label 'lowMem'

  input: 
  tuple val(meta), path(R1), path(R2), path(umiExtraction_fastqR1_R1), path(umiExtraction_fastqR1_R2), path(umiExtraction_fastqR2_R1), path(umiExtraction_fastqR2_R2), (fastqNoUmi_R1), path(fastqNoUmi_R2)

  output:
  tuple val(meta), file("*_totReads.R1.fastq.gz"), file("*_totReads.R2.fastq.gz"), emit: fastq
  tuple val(meta), file("*_nonUmisReadsIDs.txt"), emit: nonUmiReadId
  tuple val(meta), file("*_pUMIs.txt"), emit: percentUmi
  tuple val(meta), file("*_nbTotFrag.txt"), emit: nbTotFrag

  script:
  """
  # save read IDs that have no umis in a file to extract them after alignment 
  seqkit seq -j ${task.cpus} -n -i ${fastqNoUmi_R2} -o ${meta}_nonUmisReadsIDs.txt

  # concatenate R1 and R2 umi reads == all umi reads 
  cat ${umiExtraction_fastqR2_R1} >> ${umiExtraction_fastqR1_R1}
  ############## Save % UMIs reads
  nb_lines=`wc -l < <(gzip -cd ${R1})`
  nb_totFrag=\$(( \$nb_lines / 4 ))
  echo "totFrag: \$nb_totFrag" > ${meta}_nbTotFrag.txt

  nb_lines=`wc -l < <(gzip -cd ${umiExtraction_fastqR1_R1}) `
  nb_umis=\$(( \$nb_lines / 4 ))
  echo "percentUMI:\$(( \$nb_umis * 100 / \$nb_totFrag ))" > ${meta}_pUMIs.txt
  ##############
  # add non umi reads == all reads 
  cat ${fastqNoUmi_R1} >> ${umiExtraction_fastqR1_R1}
  mv ${umiExtraction_fastqR1_R1} ${meta}_totReads.R1.fastq.gz

  # concatenate R1 and R2 umi reads
  cat ${umiExtraction_fastqR2_R2} >> ${umiExtraction_fastqR1_R2} 
  # add non umi reads
  cat ${fastqNoUmi_R2} >> ${umiExtraction_fastqR1_R2} 
  mv ${umiExtraction_fastqR1_R2} ${meta}_totReads.R2.fastq.gz
  """
}