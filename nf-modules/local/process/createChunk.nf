process createChunk {
  label 'seqkit'
  label 'medCpu'
  label 'medMem'
  tag "${meta.id}"

  input:
  tuple val(meta), path(dir)
  val(chunkSize)

  output:
  tuple val(meta),  path("*.fastq.gz"), emit: reads

  script:
  def prefix = task.ext.prefix ?: "${meta.id}"
  """
    # merge all R1 fastq files per chunkSize
    ls -1 "$dir"/*R1.fastq.gz | parallel -N $chunkSize --tmpdir ${params.tmpDir} 'cat {} > '${prefix}'_chunk{#}.R1.fastq.gz'
    # merge all R2 fastq files per chunkSize
    ls -1 "$dir"/*R2.fastq.gz | parallel -N $chunkSize --tmpdir ${params.tmpDir} 'cat {} > '${prefix}'_chunk{#}.R2.fastq.gz'
  """
}