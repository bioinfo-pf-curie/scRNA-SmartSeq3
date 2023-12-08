/*
 * Cutadapt - trim reads
 */

process trimLinker {
  tag "${meta.id}"
  label 'cutadapt'
  label 'extraCpu'
  label 'lowMem'

  input:
  tuple val(meta), path(R1), path(R2)

  output:
  tuple val(meta),  path("*.R1.fastq.gz"), path("*.R2.fastq.gz"), emit: fastq
  tuple val(meta), path("*_cutadapt.log"), emit: log
  path("versions.txt"), emit: versions

  script:
  def args = task.ext.args ?: ''
  def prefix = task.ext.prefix ?: "${meta.id}"
  // 5' part removing on sens (polyA to the left)
  def cmd_sensStrandR1_5 = params.protocol == "flashseq" ? "-g A{30}GTACTCTGCGTTGATACCACTGCTT -g A{20}GTACTCTGCGTTGATACCACTGCTT -g A{15}GTACTCTGCGTTGATACCACTGCTT" : ""
  def cmd_sensStrandR2_5 = params.protocol == "flashseq" ? "-G A{30}GTACTCTGCGTTGATACCACTGCTT -G A{20}GTACTCTGCGTTGATACCACTGCTT -G A{15}GTACTCTGCGTTGATACCACTGCTT" : ""
  // 3' part removing on sens  (polyA to the left)
  def cmd_sensStrandR1_3 = params.protocol == "smartseq3"  ? "-a A{30}TCGTATGCTGCT -a A{20}TCGTATGCTGCT" : ""
  def cmd_sensStrandR2_3 = params.protocol == "smartseq3" ? "-A A{30}TCGTATGCTGCT -A A{20}TCGTATGCTGCT" : ""
  // 5' part removing 
  def cmd_antisensStrandR1_5 = params.protocol == "flashseq" ? "-g AAGCAGTGGTATCAACGCAGAGTACT{30} -g AAGCAGTGGTATCAACGCAGAGTACT{20} -g AAGCAGTGGTATCAACGCAGAGTACT{15}" : 
                                                                                        "-g ATCAGCAGCATACGAT{30} -g ATCAGCAGCATACGAT{20}"
  def cmd_antisensStrandR2_5 = params.protocol == "flashseq" ? "-G AAGCAGTGGTATCAACGCAGAGTACT{30} -G AAGCAGTGGTATCAACGCAGAGTACT{20} -G AAGCAGTGGTATCAACGCAGAGTACT{15}" : 
                                                                                        "-G ATCAGCAGCATACGAT{30} -G ATCAGCAGCATACGAT{20}"
  """
  cutadapt ${cmd_sensStrandR1_5} ${cmd_sensStrandR2_5} ${cmd_sensStrandR1_3} ${cmd_sensStrandR2_3} \
    ${cmd_antisensStrandR1_5} ${cmd_antisensStrandR2_5} \
    --minimum-length=20 \
    --cores=${task.cpus} \
    -o ${prefix}_trimmed.R1.fastq.gz -p ${prefix}_trimmed.R2.fastq.gz \
    ${R1} ${R2} &> ${prefix}_cutadapt.log

  echo cutadapt \$(cutadapt --version) &> versions.txt
  """
}