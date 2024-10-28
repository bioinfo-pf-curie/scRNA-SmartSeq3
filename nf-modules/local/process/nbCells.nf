/*
 * Add barcodes info to read group information
 */

process nbCells {
  tag "$meta.id"
  label 'python'
  label 'medCpu'
  label 'medMem'

  input:
  tuple val(meta), path(reads)

  output:
  tuple val(meta), path("*txt"), emit: count
 
  script:
  def prefix = task.ext.prefix ?: "${meta.id}"
  def args = task.ext.args ?: ''
  """
  ls *R1* | wc -l > ${meta.id}_nbCells.txt
  """
}
