process createBatch {
  label 'samtools'
  label 'minCpu'
  label 'minMem'

  input:
  path ('reads/*')

  output:
  tuple val(~/^batch_(\d+)/), path("*.R1.fastq.gz"), path("*.R2.fastq.gz"), emit: reads

  script:
  """
  # merge all R1 fastq files per batchSize
  ls -1 reads/*.R1.fastq.gz | xargs -L $params.batchSize echo | awk '{print "cat " \$0 " > batch_"NR".R1.fastq.gz"}' > create_batches.sh && bash create_batches.sh
  # merge all R2 fastq files per batchSize
  ls -1 reads/*.R2.fastq.gz | xargs -L $params.batchSize echo | awk '{print "cat " \$0 " > batch_"NR".R2.fastq.gz"}' > create_batches.sh && bash create_batches.sh
  """
}