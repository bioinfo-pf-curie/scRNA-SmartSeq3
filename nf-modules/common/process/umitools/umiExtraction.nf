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
  tuple val(meta), file("*_UMIsExtractedinR*.R1.fastq.gz"), file("*_UMIsExtractedinR*.R2.fastq.gz"), emit: fastq_umi
  tuple val(meta), file("*_noUMIinR*.R1.fastq.gz"), file("*_noUMIinR*.R2.fastq.gz"), emit: fastq_noumi
  tuple val(meta), file("*.log"), emit: log
  path("versions.txt"), emit: versions

  script:
  def args = task.ext.args ?: ''
  def outCmd = stdin_read == "R1" ? "--stdout=${meta.id}_UMIsExtractedinR1.R1.fastq.gz --read2-out=${meta.id}_UMIsExtractedinR1.R2.fastq.gz" : 
                                     "--stdout=${meta.id}_UMIsExtractedinR2.R2.fastq.gz --read2-out=${meta.id}_UMIsExtractedinR2.R1.fastq.gz"
  def filtredOut = stdin_read == "R1" ? "--filtered-out ${meta.id}_noUMIinR1.R1.fastq.gz --filtered-out2 ${meta.id}_noUMIinR1.R2.fastq.gz" :
                                      "--filtered-out ${meta.id}_noUMIinR2.R2.fastq.gz --filtered-out2 ${meta.id}_noUMIinR2.R1.fastq.gz"
  def logOut = stdin_read == "R1" ? "--log=${meta.id}_umiExtractR1.log" : 
                                  "--log=${meta.id}_umiExtractR2.log"
  """
  umi_tools extract --stdin=${reads[0]} --read2-in=${reads[1]} ${args} $inputCmd $outCmd $filtredOut $logOut 
  umi_tools --version &> versions.txt
  """
}