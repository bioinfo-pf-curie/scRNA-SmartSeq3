/*
 * MultiQC for RNA-seq report
 * External parameters :
 * @ params.singleEnd :	is data	single-end sequencing ?
 */

process multiqc {
  label 'multiqc'
  label 'minCpu'
  label 'lowMem'

  input:
  val customRunName
  path splan
  path metadata
  path multiqcConfig
  path ('softwareVersions/*')
  path ('workflowSummary/*')
  path warnings
  path preseq
  path rseqc_genecov
  path rseqc_readquality
  path rseqc_bamstat
  path rseqc_innerdist
  path rseqc_junctannot
  path rseqc_junctsat
  path rseqc_readdistrib
  
  output:
  path splan, emit: splan
  path "*report.html", emit: report
  path "*_data", emit: data

  script:
  rtitle = customRunName ? "--title \"$customRunName\"" : ''
  rfilename = customRunName ? "--filename " + customRunName + "_rnaseq_report" : "--filename rnaseq_report"
  metadataOpts = params.metadata ? "--metadata ${metadata}" : ""
  splanOpts = params.samplePlan ? "--splan ${params.samplePlan}" : ""
  isPE = params.singleEnd ? 0 : 1
    
  modulesList = "-m custom_content -m samtools -m star -m featurecounts -m deeptools -m preseq -m rseqc"
  warn = warnings.name == 'warnings.txt' ? "--warn warnings.txt" : ""
  """
  mqc_header.py --name "RNA-seq" --version ${workflow.manifest.version} ${metadataOpts} ${splanOpts} ${warn} > multiqc-config-header.yaml
  multiqc . -f $rtitle $rfilename -c $multiqcConfig -c multiqc-config-header.yaml $modulesList
  """    
}
