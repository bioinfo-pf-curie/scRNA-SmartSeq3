// in each read name, add the barcode info at the end
process like10xMatrix {
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
  10xlikeMatrix.r ${type}
  gzip 10XlikeMatrix_${type}/*
  zip 10XlikeMatrix_${type}.zip 10XlikeMatrix_${type}/*
  R --version | head -n1 | awk '{print \$1" "\$3}' &> versions.txt  
  """
}
