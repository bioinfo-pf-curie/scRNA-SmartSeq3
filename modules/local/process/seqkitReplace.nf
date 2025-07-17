// in each read name, add the barcode info at the end
process seqkitReplace {
  label 'seqkit'
  label 'medCpu'
  label 'medMem'
  tag "$meta.id"

  input:
  tuple val(meta), path(dir)
  path(sampleDescitpion)

  output:
  tuple val(meta), path("barcodedFastq/"), emit: reads
  path('versions.txt'), emit: versions

  script:
  def prefix = task.ext.prefix ?: "${meta.id}"
  def sampleDes = sampleDescitpion ? "${sampleDescitpion}" : "sampleDescitpion.txt"
  """
  mkdir -p barcodedFastq/

  n1=\$(ls ${dir} | grep -E '(^|[^0-9])R1([^0-9]|\$)' | wc -l)
  n2=\$(ls ${dir} | grep -E '(^|[^0-9])R2([^0-9]|\$)' | wc -l)
  if [[ \$n1 != \$n2 ]] 
  then
    echo "Number of R1 file is different from R2 files. Please, be sure that the "R1/R2" tags are used in the file names"
    exit -1
  fi 

  if [ -f ${sampleDes} ]; then
    for fastq in \$(ls ${dir} | grep -E '(^|[^0-9])R1([^0-9]|\$)')
    do
    # Extract prefix
    prefix=\$(echo \$fastq | sed -e 's/.fastq.gz//')
    prename=\$(echo \$prefix | sed -E "s/(.*).R[12].*/\\1/")
    # Get prefix corresponding bioname in the 2nd column of the sample descritption
    # no _ is accepted in the bioname because it is used as field separator in read name !
    #if name of the fastq is the bioname then remove _Si_L001
    base=\$(echo \$prename | sed -E 's/_S[0-9]+_L001*//')
    # Get bioname if id 
    bioname=\$(grep -w \$base ${sampleDes} | cut -f2 -d"|" | sed -e 's/_/--/g' )
    seqkit replace -p " " -r '_'\$bioname' ' ${dir}/\$fastq | pigz -p ${task.cpus} -c > "barcodedFastq/"\$base".R1.fastq.gz"
    done

    for fastq in \$(ls ${dir} | grep -E '(^|[^0-9])R2([^0-9]|\$)')
    do
    # Extract prefix
    prefix=\$(echo \$fastq | sed -e 's/.fastq.gz//')
    prename=\$(echo \$prefix | sed -E "s/(.*).R[12].*/\\1/")
    # Get prefix corresponding bioname in the 2nd column of the sample descritption
    base=\$(echo \$prename | sed -E 's/_S[0-9]+_L001*//')
    # Get bioname 
    bioname=\$(grep -w \$base ${sampleDes} | cut -f2 -d"|" | sed -e 's/_/--/g' )
    seqkit replace -p " " -r '_'\$bioname' ' ${dir}/\$fastq | pigz -p ${task.cpus} -c > "barcodedFastq/"\$base".R2.fastq.gz"
    done

  else
    for fastq in \$(ls ${dir} | grep -E '(^|[^0-9])R1([^0-9]|\$)')
    do
    prefix=\$(echo \$fastq | sed -e 's/.fastq.gz//')
    prename=\$(echo \$prefix | sed -E "s/(.*).R[12].*/\\1/")
    #if name of the fastq is the bioname then remove _Si_L001
    base=\$(echo \$prename | sed -E 's/_S[0-9]+_L001*//')
    baseClean=\$(echo \$prename | sed -e 's/_/--/g')
    seqkit replace -p " " -r '_'\$baseClean' ' ${dir}/\$fastq | pigz -p ${task.cpus} -c > "barcodedFastq/"\$base".R1.fastq.gz"
    done

    for fastq in \$(ls ${dir} | grep -E '(^|[^0-9])R2([^0-9]|\$)')
    do
    prefix=\$(echo \$fastq | sed -e 's/.fastq.gz//')
    prename=\$(echo \$prefix | sed -E "s/(.*).R[12].*/\\1/")
    #if name of the fastq is the bioname then remove _Si_L001
    base=\$(echo \$prename | sed -E 's/_S[0-9]+_L001*//')
    baseClean=\$(echo \$prename | sed -e 's/_/--/g')
    seqkit replace -p " " -r '_'\$baseClean' ' ${dir}/\$fastq | pigz -p ${task.cpus} -c > "barcodedFastq/"\$base".R2.fastq.gz"
    done
  fi
  
  seqkit version > versions.txt
  pigz --version >> versions.txt
  """
}
