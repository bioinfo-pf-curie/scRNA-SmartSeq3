/*
 * Umitools extract UMI
 */

process umiExtraction {
  tag "${meta.id}"
  label 'umiTools'
  label 'lowCpu'
  label 'lowMem'

  input: 
  tuple val(meta), path(reads)
  val(stdin_read)

  output:
  tuple val(meta), path("*_UMIsExtractedinR*"), emit: fastq_umi
  tuple val(meta), path("*_noUMIinR*.R1.fastq.gz"), path("*_noUMIinR*.R2.fastq.gz"), emit: fastq_noumi
  tuple val(meta), path("*.log"), emit: log
  path("versions.txt"), emit: versions

  script:
  def args = task.ext.args ?: ''
  def prefix = task.ext.prefix ?: "${meta.id}"
  def inputCmd= stdin_read == "R1" ? "--stdin=${reads[0]} --read2-in=${reads[1]}" : 
                                   "--stdin=${reads[1]} --read2-in=${reads[0]}"
  def outCmd = stdin_read == "R1" ? "--stdout=${prefix}_UMIsExtractedinR1.R1.fastq.gz --read2-out=${prefix}_UMIsExtractedinR1.R2.fastq.gz" : 
                                     "--stdout=${prefix}_UMIsExtractedinR2.R2.fastq.gz --read2-out=${prefix}_UMIsExtractedinR2.R1.fastq.gz"
  def filtredOut = stdin_read == "R1" ? "--filtered-out ${prefix}_noUMIinR1.R1.fastq.gz --filtered-out2 ${prefix}_noUMIinR1.R2.fastq.gz" :
                                      "--filtered-out ${prefix}_noUMIinR2.R2.fastq.gz --filtered-out2 ${prefix}_noUMIinR2.R1.fastq.gz"
  def logOut = stdin_read == "R1" ? "--log=${prefix}_umiExtractR1.log" : 
                                  "--log=${prefix}_umiExtractR2.log"
  """
  umi_tools extract ${args} $inputCmd $outCmd $filtredOut $logOut 
  umi_tools --version | cut -f1,3 -d" " &> versions.txt
  """
}