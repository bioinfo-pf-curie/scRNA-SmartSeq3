// in each read name, add the barcode info at the end
process 10xlikeMatrix {
  label 'R'
  label 'lowCpu'
  label 'medMem'

  input:
  path(matrices)
  val(type) // reads or umis

  output:
  path("10XlikeMatrix_${type}.zip"), emit: matrix
  path('versions.txt'), emit: versions

  script:
  """
  mkdir 10XlikeMatrix_${type}
  10xlikeMatrix.r ${matrices} ${type}
  zip 10XlikeMatrix_${type}.zip 10XlikeMatrix_${type}/*
  R --version &> versions.txt  
  """
}
