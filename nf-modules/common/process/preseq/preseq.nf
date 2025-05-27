/*
 * Preseq - Saturation Curves
 * External parameters :
 * @ params.preseqDefect : run preseq in defect mode
 */

process preseq {
  tag "${meta.id}"
  label 'preseq'
  label 'minCpu'
  label 'highMem'

  input:
  tuple val(meta), path(bam)

  //errorStrategy 'ignore'

  output:
  path("*ccurve.txt"), emit: curves
  path("versions.txt"), emit: versions

  when:
  task.ext.when == null || task.ext.when

  script:
  //def defectMode = task.attempt > 1 ? '-D' : ''
  def peOpts = meta.singleEnd ? '' : '-pe'
  def prefix = task.ext.prefix ?: "${meta.id}"
  def args = task.ext.args ?: ''
  """
  echo \$(preseq 2>&1 | awk '\$0~"Version"{print "Preseq",\$2}') > versions.txt
  samtools index ${bam}
  preseq lc_extrap -B ${bam} -o ${prefix}_extrap_ccurve.txt ${args} ${peOpts}
  """
}
