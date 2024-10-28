/*
 * Add barcodes info to read group information
 */

process nbCells {
  tag "$meta.id"
  label 'python'
  label 'medCpu'
  label 'medMem'

  input:
  tuple val(meta), path(dir)

  output:
  tuple val(meta), path("*txt"), emit: count
 
  script:
  def prefix = task.ext.prefix ?: "${meta.id}"
  def args = task.ext.args ?: ''
  """
  ls ${dir}/*R1* | wc -l > ${meta.id}_nbCells.txt
  """
}
