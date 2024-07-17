process createBatches {
  label 'unix'
  label 'minCpu'
  label 'medMem'
  tag "${meta.id}"

  input:
  tuple val(meta), path(reads)
  val(batchSize)

  output:
  tuple val(meta),  path("*.fastq.gz"), emit: reads
  path('versions.txt'), emit: versions

  script:
  def bsizeOpts = batchSize ? "-L ${batchSize}" : ""
  def prefix = task.ext.prefix ?: "${meta.id}"
  """
  # merge all R1 fastq files per batchSize
  ls -1 $reads/*R1.fastq.gz | xargs $bsizeOpts echo | awk '{print "zcat " \$0 " > ${prefix}_batch"NR".R1.fastq"}' | bash
  # merge all R2 fastq files per batchSize
  ls -1 $reads/*R2.fastq.gz | xargs $bsizeOpts echo | awk '{print "zcat " \$0 " > ${prefix}_batch"NR".R2.fastq"}' | bash
  gzip *.fastq

  echo "gzip "\$(gzip --version | awk 'NR==1{print \$NF}') > versions.txt  
  """
}