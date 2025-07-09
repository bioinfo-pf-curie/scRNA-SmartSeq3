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
  // MODULES
  path ('cutadapt/*')
  //path preseq ne marche plus
  path ('rseqc/*')
  //path rseqc_bamstat
  path ('rseqc/*')
  path ('rseqc/*')
  path ('rseqc/*')
  path ('qualimap/*')
  //path rseqc_readquality not a module
  //path rseqc_readdistrib //not working
  // stat2mqc
  path('umitools/*')
  path('umitools/*')
  path ('nbCells/*')
  path ('star/*')
  path fastqc
  path mt
  path fcAll 
  path ('stats/*')

  output:
  path splan, emit: splan
  path "*report.html", emit: report
  path "*_data", emit: data

  script:
  rtitle = customRunName ? "--title \"$customRunName\"" : ''
  rfilename = customRunName ? "--filename " + customRunName + "_report" : "--filename ${params.protocol}_report"
  metadataOpts = params.metadata ? "--metadata ${metadata}" : ""
  splanOpts = params.samplePlan ? "--splan ${params.samplePlan}" : ""
  isPE = params.singleEnd ? 0 : 1
    
  modulesList = "-m custom_content -m samtools -m star -m featurecounts -m deeptools -m preseq -m rseqc -m cutadapt -m qualimap -m fastqc -m umi_tools"
  warn = warnings.name == 'warnings.txt' ? "--warn warnings.txt" : ""
  """
  mqc_header.py --name "scRNA-seq" --version ${workflow.manifest.version} ${metadataOpts} ${splanOpts} ${warn} > multiqc-config-header.yaml
  multiqc . -f $rtitle $rfilename -c $multiqcConfig -c multiqc-config-header.yaml $modulesList
  """    
}
