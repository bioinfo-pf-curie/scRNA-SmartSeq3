/*
 * Merge Fastq files
 */

process concatFastq {
  label 'samtools'
  tag "${meta.id}"
  label 'minCpu'
  label 'minMem'

  input:
  tuple val(meta), val(by) ,path(reads, stageAs: "input*/*")
  

  output:
  tuple val(meta), path("*.merged.fastq.gz"), emit: reads
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
      cat ${readList.join(' ')} > ${prefix}.merged.fastq.gz
      echo "cat "\$(cat --version 2>&1| head -1 | sed 's/^.*coreutils) //') > versions.txt
      """
  } else {
    if (by == 2) {
      def read1 = readList[(0..maxIdx).step(2)]
      def read2 = readList[(1..maxIdx).step(2)]
      """
      cat ${read1.join(' ')} > ${prefix}_R1.merged.fastq.gz
      cat ${read2.join(' ')} > ${prefix}_R2.merged.fastq.gz
      echo "cat "\$(cat --version 2>&1| head -1 | sed 's/^.*coreutils) //') > versions.txt
      """
    } else if (by == 3) {
      def read1 = readList[(0..maxIdx).step(3)]
      def read2 = readList[(1..maxIdx).step(3)]
      def read3 = readList[(2..maxIdx).step(3)]
      """
      cat ${read1.join(' ')} > ${prefix}_R1.merged.fastq.gz
      cat ${read2.join(' ')} > ${prefix}_R2.merged.fastq.gz
      cat ${read3.join(' ')} > ${prefix}_R3.merged.fastq.gz
      echo "cat "\$(cat --version 2>&1| head -1 | sed 's/^.*coreutils) //') > versions.txt
      """
    }
  }
}