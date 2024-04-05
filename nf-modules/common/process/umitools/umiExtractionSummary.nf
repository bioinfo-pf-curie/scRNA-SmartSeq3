/*
 * Umitools extract UMI
 */

process umiExtractionSummary {
  tag "${meta.id}"
  label 'umiTools'
  label 'lowCpu'
  label 'lowMem'

  input: 
  tuple val(meta), path(raw_reads), path(umiExtraction_r1), path(umiExtraction_r2)

  output:
  tuple val(meta), path("*_pUMIs.txt"), emit: percentUmi
  tuple val(meta), path("*_nbTotFrag.txt"), emit: nbTotFrag

  script:
  def args = task.ext.args ?: ''
  def prefix = task.ext.prefix ?: "${meta.id}"
  """
  ############## Save % UMIs reads
  nb_lines=`wc -l < <(gzip -cd ${raw_reads[0]})`
  nb_totFrag=\$(( \$nb_lines / 4 ))
  echo "totFrag: \$nb_totFrag" > ${prefix}_nbTotFrag.txt

  nb_line_R1=`wc -l < <(gzip -cd ${umiExtraction_r1[0]}) `
  nb_umis_R1=\$(( \$nb_line_R1 / 4 ))
  echo "#UMIs in R1: \$nb_umis_R1" >> ${prefix}_nbTotFrag.txt

  nb_line_R2=`wc -l < <(gzip -cd ${umiExtraction_r2[0]}) `
  nb_umis_R2=\$(( \$nb_line_R2 / 4 ))
  echo "#UMIs in R2: \$nb_umis_R2" >> ${prefix}_nbTotFrag.txt

  tot_umis=\$(( \$nb_umis_R1 + \$nb_umis_R2 ))
  echo "#UMIs R1+R2: \$tot_umis" >> ${prefix}_nbTotFrag.txt

  tot_umis_percent=\$(( (\$nb_umis_R1 + \$nb_umis_R2 / \$nb_totFrag) * 100 ))
  echo "percentUMI: \$tot_umis_percent" > ${prefix}_pUMIs.txt
  ##############

  
  """
}