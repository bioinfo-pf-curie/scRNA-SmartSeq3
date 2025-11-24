/*
 * RSeQC 
 */

process rseqcJunctionAnnotation {
  tag "${meta.id}"
  label 'rseqc'
  label 'medCpu'
  label 'lowMem'

  input:
  tuple val(meta), path(bam)
  path bed12 

  output:
  path "${meta.id}*.{txt,pdf,r,xls}", optional: true, emit: results
  path("versions.txt"), emit: versions

  when:
  task.ext.when == null || task.ext.when

  script:
  def prefix = task.ext.prefix ?: "${meta.id}"
  def args   = task.ext.args ?: ''
  """
  echo \$(infer_experiment.py --version | awk '{print "rseqc "\$2}') > versions.txt    

  junction_annotation.py \\
      -i ${bam} \\
      -o ${prefix}_junctionAnnot_rseqc \\
      -r $bed12 ${args} &> ${prefix}_junctionAnnot_rseqc_log.txt
  """  
}
