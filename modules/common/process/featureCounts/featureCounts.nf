/**************************************
 * Feature counts on GTF/SAF file
 */

process featureCounts{
  label 'featurecounts'
  label 'medCpu'
  label 'lowMem'
  tag("${meta.id}")

  input:
  tuple val(meta), path(bams), path(bai), path(annot)

  output:
  tuple val(meta), path("*bam"), emit: bam
  tuple val(meta), path("*csv"), emit: counts
  path("*summary"), emit: summary
  path("*log"), emit: log
  path("versions.txt"), emit: versions 

  when:
  task.ext.when == null || task.ext.when

  script:
  def args   = task.ext.args ?: ''
  def featureCountsDirection = 0
  if (meta.strandness == 'forward'){
      featureCountsDirection = 1
  } else if ((meta.strandness == 'reverse')){
      featureCountsDirection = 2
  }
  def peOpts = meta.single_end ? '' : '-p'
  def prefix = task.ext.prefix ?: "${bam.baseName}"
  def inOpts = annot.toString().endsWith('.saf') ? "-F SAF" : ""
  """
  echo \$(featureCounts -v 2>&1 | sed '/^\$/d') > versions.txt
  featureCounts -a ${annot} ${inOpts} \\
                -o ${prefix}.csv \\
                -T ${task.cpus} \\
                -s ${featureCountsDirection} \\
                ${peOpts} \\
                ${args} \\
                ${bams} 2> ${prefix}_featureCounts.log
  """
}
