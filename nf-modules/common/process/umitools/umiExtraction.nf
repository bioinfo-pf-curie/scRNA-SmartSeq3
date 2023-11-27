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
  """
  umi_tools extract --stdin=${reads[0]} --stdout=${meta}_UMIsExtractedin${stdin_read[0]}.${stdin_read[0]}.fastq.gz \\
                    --read2-in=${reads[1]} --read2-out=${meta}_UMIsExtractedin${stdin_read[0]}.${stdin_read[1]}.fastq.gz \\
                    --filtered-out ${prefix}_noUMIin${stdin_read[0]}.${stdin_read[0]}.fastq.gz --filtered-out2 ${prefix}_noUMIin${stdin_read[0]}.${stdin_read[1]}.fastq.gz \\
                    --log=${prefix}_umiExtract${stdin_read[0]}.log ${args}

  umi_tools --version &> versions.txt
  """
}