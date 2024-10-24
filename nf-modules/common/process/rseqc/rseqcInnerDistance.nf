/*
 * RSeQC 
 */

process rseqcInnerDistance {
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

  inner_distance.py \\
      -i ${bam} \\
      -o ${prefix}_innerDist_rseqc ${args} &> ${prefix}_innerDist_rseqc_log.txt
  """  
}
