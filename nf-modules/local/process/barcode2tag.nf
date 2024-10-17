/*
 * Add barcodes info to read group information
 */

process barcode2tag {
  tag "$meta.id"
  label 'python'
  label 'medCpu'
  label 'medMem'

  input:
  tuple val(meta), path(bam), path(barcodes)

  output:
  tuple val(meta), path("*bam"), emit: bam
  path ("versions.txt"), emit: versions
 
  script:
  def prefix = task.ext.prefix ?: "${meta.id}"
  def args = task.ext.args ?: ''
  def barcodesOpts = barcodes ? "--barcode ${barcodes}" : ''
  """
  barcode2tag.py -i ${bam} -o ${prefix}_BCtag.bam ${barcodesOpts} -SM ${meta.id} ${args} 2> ${prefix}_barcode2rg.log
  echo \$(python --version 2>&1) > versions.txt 
  """
}
