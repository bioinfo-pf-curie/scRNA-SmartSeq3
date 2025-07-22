/*
 * RSeQC 
 */

process rseqcReadQuality {
  tag "${meta.id}"
  label 'rseqc'
  label 'medCpu'
  label 'lowMem'

  input:
  tuple val(meta), path(bam)

  output:
  path "${meta.id}*.{txt,pdf,r,xls}", emit: results
  path("versions.txt"), emit: versions

  when:
  task.ext.when == null || task.ext.when

  script:
  def prefix = task.ext.prefix ?: "${meta.id}"
  def args   = task.ext.args ?: ''
  """
  echo \$(infer_experiment.py --version | awk '{print "rseqc "\$2}') > versions.txt    

  read_quality.py \\
      -i ${bam} \\
      -o ${prefix}_readQuality_rseqc ${args} &> ${prefix}_readQuality_rseqc_log.txt
  """  
}
