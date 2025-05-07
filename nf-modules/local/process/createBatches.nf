process createBatches {
  label 'seqkit'
  label 'medCpu'
  label 'medMem'
  tag "${meta.id}"

  input:
  tuple val(meta), path(dir)
  path(sampleDescription)

  output:
  tuple val(meta),  path("*.fastq.gz"), emit: reads

  script:
  def prefix = task.ext.prefix ?: "${meta.id}"
  def sampleDes = sampleDescription ? "${sampleDescription}" : "sampleDescription.txt"
  """
  if [ -f ${sampleDes} ]; then
    # tidy fastqs in batches from sampleDescription
    for file in ${dir}/*.fastq.gz; do
      # Extract prefix
      prefix=\$(basename \$file | sed -e 's/.fastq.gz//')
      prename=\$(echo \$prefix | sed -E "s/(.*).R[12].*/\\1/")
      base=\$(echo \$prename | sed -E 's/_S[0-9]+_L001*//')
      # extract batch info from ID
      batch=\$(grep -w \$base ${sampleDes} | cut -d"|" -f2 | sed 's/^[^_]*_//') 
      if [[ \$file =~ "R1.fastq.gz" ]]; then
        cat \$file >> "${prefix}_batch\$batch.R1.fastq.gz"
      else
        cat \$file >> "${prefix}_batch\$batch.R2.fastq.gz"
    fi
    done
  fi
  """
}