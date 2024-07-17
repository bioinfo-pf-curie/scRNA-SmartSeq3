process seqkitReplace {
  label 'seqkit'
  label 'lowCpu'
  label 'medMem'
  tag "$meta.id"

  input:
  tuple val(meta), path(dir)

  output:
  tuple val(meta), path("barcodedFastq/"), emit: reads
  path('versions.txt'), emit: versions

  script:
  """
  mkdir barcodedFastq/
  for fastq in ${dir}/*.fastq.gz
  do
  prefix=\$(basename \$fastq | sed -e 's/.fastq.gz//')
  base=\$(echo \$prefix | sed -e 's/.R[1,2]//')
  seqkit replace -p " " -r '_'\$base' ' \$fastq > "barcodedFastq/"\$prefix".fastq"
  gzip "barcodedFastq/"\$prefix".fastq"
  done

  echo \$(seqkit version 2>&1) > versions.txt
  """
}