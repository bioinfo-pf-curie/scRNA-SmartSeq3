/*
 * Get barcodes of the batch from bam read ids
 */

process barcodeListPerBatch {
  tag "$meta.id"
  label 'samtools'
  label 'medCpu'
  label 'medMem'

  input:
  tuple val(meta), path(bam)

  output:
  tuple val(meta), path("*txt"), emit: barcodes
 
  script:
  def prefix = task.ext.prefix ?: "${meta.id}"
  def args = task.ext.args ?: ''
  """
  samtools view -@ ${task.cpus} $bam | awk -F'\t' '{split(\$1, a, "_"); print a[2]}' | sort -u > ${prefix}_barcodes.txt
  """
}
