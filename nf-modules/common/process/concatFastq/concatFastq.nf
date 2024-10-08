/*
 * Merge Fastq files
 */

process concatFastq {
  label 'unix'
  tag "${meta.id}"
  label 'minCpu'
  label 'minMem'

  input:
  tuple val(meta), path(reads, stageAs: "input*/*")
  val(by)

  output:
  tuple val(meta), path("*.concat.fastq.gz"), emit: reads
  path "versions.txt"                       , emit: versions

  when:
  task.ext.when == null || task.ext.when

  script:
  def args = task.ext.args ?: ''
  def prefix = task.ext.prefix ?: "${meta.id}"
  def readList = reads instanceof List ? reads.collect{ it.toString() } : [reads.toString()]
  def maxIdx = readList.size() - 1
  if (by == 1 || meta.single_end){
      """
      zcat ${readList.join(' ')} > ${prefix}.concat.fastq
      gzip ${prefix}.concat.fastq
      echo "gzip "\$(gzip --version | awk 'NR==1{print \$NF}') > versions.txt
      """
  } else if (by == 2) {
      def read1 = readList[(0..maxIdx).step(2)]
      def read2 = readList[(1..maxIdx).step(2)]
      """
      zcat ${read1.join(' ')} > ${prefix}_R1.concat.fastq
      zcat ${read2.join(' ')} > ${prefix}_R2.concat.fastq
      gzip *.fastq
      echo "gzip "\$(gzip --version | awk 'NR==1{print \$NF}') > versions.txt
      """
  } else if (by == 3) {
      def read1 = readList[(0..maxIdx).step(3)]
      def read2 = readList[(1..maxIdx).step(3)]
      def read3 = readList[(2..maxIdx).step(3)]
      """
      zcat ${read1.join(' ')} > ${prefix}_R1.concat.fastq
      zcat ${read2.join(' ')} > ${prefix}_R2.concat.fastq
      zcat ${read3.join(' ')} > ${prefix}_R3.concat.fastq
      gzip *.fastq
      echo "gzip "\$(gzip --version | awk 'NR==1{print \$NF}') > versions.txt
      """
  }
}