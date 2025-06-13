process fastqcForMqc {
  label 'fastqc'
  label 'lowCpu'
  label 'medMem'
  tag "$meta.id"

  input:
  tuple val(meta), path(zip)

  output:
  tuple val(meta), path("*.txt"), emit: results

  script:
  """
  unzip $zip
  dir=$(basename $zip .zip)
  python $projectDir/bin/filter_fastqc_sections.py \$dir
  """
}