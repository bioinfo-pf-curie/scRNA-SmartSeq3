// in each read name, add the barcode info at the end
process 10xlikeMatrix {
  label 'R'
  label 'medCpu'
  label 'medMem'
  tag "$meta.id"

  input:
  path(matrices)
  val(type)

  output:
  path("${type}Matrix_10Xlike.zip"), emit: matrix
  path('versions.txt'), emit: versions

  script:
  def prefix = task.ext.prefix ?: "${meta.id}"
  """
  10xlikeMatrix.r ${matrices} ${type}
  """
}
