// in each read name, add the barcode info at the end
process seqkitFx2tab {
  label 'seqkit'
  label 'lowCpu'
  label 'medMem'
  tag "$meta.id"

  input:
  tuple val(meta), path(fastqs)

  output:
  tuple val(meta), path("*_initial_nb_barcodes.txt"), emit: count
  path('versions.txt'), emit: versions

  script:
  def prefix = task.ext.prefix ?: "${meta.id}"
  """
  seqkit fx2tab --name --only-id ${fastqs[0]} | awk -F '_' '{count[\$NF]++} END {print length(count)}' > ${prefix}_initial_nb_barcodes.txt
  echo \$(seqkit version 2>&1) > versions.txt
  """
}