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
  if (( ${batchSize} =! 0 )); then

    # merge all R1 fastq files per batchSize
    ls -1 $reads/*R1.fastq.gz | xargs $bsizeOpts echo | awk '{print "zcat " \$0 " > ${prefix}_batch"NR".R1.fastq"}' | bash
    # merge all R2 fastq files per batchSize
    ls -1 $reads/*R2.fastq.gz | xargs $bsizeOpts echo | awk '{print "zcat " \$0 " > ${prefix}_batch"NR".R2.fastq"}' | bash

  else

    mkdir -p batchDir
    # tidy fastqs in batch repositories
    for file in *.fastq.gz; do
        batch=$(echo "$file" | cut -d"." -f1 | cut -d"_" -f2) 
        # create directory if not existing
        mkdir -p batchDir/"$batch"
        cp "$file" batchDir/"$batch"
    done
    # Concatenate all R1 and R2 seperatly for each batch
    for dir in batchDir/*; do
        batch=$(basename $dir)
        zcat "$dir"/*R1.fastq.gz > "${prefix}_${batch}.R1.fastq"
        zcat "$dir"/*R2.fastq.gz > "${prefix}_${batch}.R2.fastq"
    done
    rm -rf batchDir

  fi

  gzip *.fastq

  echo "gzip "\$(gzip --version | awk 'NR==1{print \$NF}') > versions.txt  
  """
}