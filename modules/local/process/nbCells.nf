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
  path("*txt"), emit: count
 
  script:
  def prefix = task.ext.prefix ?: "${meta.id}"
  def args = task.ext.args ?: ''
  """
  count=$(ls -1 ${dir} | wc -l)
  echo $((count / 2)) > ${meta.id}_nbCells.txt
  """
}
