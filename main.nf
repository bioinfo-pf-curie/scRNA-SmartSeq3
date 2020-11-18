#!/usr/bin/env nextflow

/*
Copyright Institut Curie 2020
This software is a computer program whose purpose is to analyze high-throughput sequencing data.
You can use, modify and/ or redistribute the software under the terms of license (see the LICENSE file for more details).
The software is distributed in the hope that it will be useful, but "AS IS" WITHOUT ANY WARRANTY OF ANY KIND.
Users are therefore encouraged to test the software's suitability as regards their requirements in conditions enabling the security of their systems and/or data.
The fact that you are presently reading this means that you have had knowledge of the license and that you accept its terms.

This script is based on the nf-core guidelines. See https://nf-co.re/ for more information
*/

/*
========================================================================================
<!-- TODO - Pipeline Name -->
========================================================================================
 #### Homepage / Documentation
<!-- TODO - Pipeline code url -->
----------------------------------------------------------------------------------------
*/

// File with text to display when a developement version is used
devMessageFile = file("$baseDir/assets/devMessage.txt")

def helpMessage() {
  if ("${workflow.manifest.version}" =~ /dev/ ){
     log.info devMessageFile.text
  }

  log.info """
  v${workflow.manifest.version}
  ======================================================================

  Usage:
  nextflow run main.nf --reads '*_R{1,2}.fastq.gz' --genome 'hg19' -profile conda
  nextflow run main.nf --samplePlan samplePlan --genome 'hg19' -profile conda

  Mandatory arguments:
    --reads [file]                Path to input data (must be surrounded with quotes)
    --samplePlan [file]           Path to sample plan input file (cannot be used with --reads)
    --genome [str]                Name of genome reference
    -profile [str]                Configuration profile to use. test / conda / multiconda / path / multipath / singularity / docker / cluster (see below)
  
  Inputs:
    --design [file]               Path to design file for extended analysis  
    --singleEnd [bool]            Specifies that the input is single-end reads

  Options:
      --minCountPerCell1             First minimum umi counts per cell. Default: 500
      --minCountPerCell2             Second minimum umi counts per cell. Default: 1000
      --minCountPerCellGene1         First minimum gene counts per cell. Default: 100
      --minCountPerCellGene2         Second minimum gene counts per cell. Default: 200

  Skip options: All are false by default
    --skipSoftVersion [bool]      Do not report software version
    --skipMultiQC [bool]          Skips MultiQC

  Other options:
    --outDir [file]               The output directory where the results will be saved
    -name [str]                   Name for the pipeline run. If not specified, Nextflow will automatically generate a random mnemonic
 
  =======================================================
  Available Profiles

    -profile test                Set up the test dataset
    -profile conda               Build a single conda for with all tools used by the different processes before running the pipeline
    -profile multiconda          Build a new conda environment for each tools used by the different processes before running the pipeline
    -profile path                Use the path defined in the configuration for all tools
    -profile multipath           Use the paths defined in the configuration for each tool
    -profile docker              Use the Docker containers for each process
    -profile singularity         Use the singularity images for each process
    -profile cluster             Run the workflow on the cluster, instead of locally

  """.stripIndent()
}

/**********************************
 * SET UP CONFIGURATION VARIABLES *
 **********************************/

// Show help message
if (params.help){
  helpMessage()
  exit 0
}

// Configurable reference genomes

// TODO - ADD HERE ANY ANNOTATION

if (params.genomes && params.genome && !params.genomes.containsKey(params.genome)) {
  exit 1, "The provided genome '${params.genome}' is not available in the genomes.config file. Currently the available genomes are ${params.genomes.keySet().join(", ")}"
}

//Stage config files
Channel
  .fromPath(params.multiqcConfig, checkIfExists: true)
  .set{chMultiqcConfig}
chOutputDocs = file("$baseDir/docs/output.md", checkIfExists: true)
chOutputDocsImages = file("$baseDir/docs/images/", checkIfExists: true)

//Has the run name been specified by the user?
//This has the bonus effect of catching both -name and --name
customRunName = params.name
if( !(workflow.runName ==~ /[a-z]+_[a-z]+/) ){
  customRunName = workflow.runName
}

/************
 * CHANNELS *
 ************/

// Validate inputs
if ((params.reads && params.samplePlan) || (params.readPaths && params.samplePlan)){
  exit 1, "Input reads must be defined using either '--reads' or '--samplePlan' parameters. Please choose one way."
}

if ( params.metadata ){
  Channel
    .fromPath( params.metadata )
    .ifEmpty { exit 1, "Metadata file not found: ${params.metadata}" }
    .set { chMetadata }
}else{
  chMetadata=Channel.empty()
}                 


/* ADDED -------------*/
if( params.gtf ){
  genomeGtf=Channel
    .fromPath(params.gtf)
    .ifEmpty { exit 1, "GTF annotation file not found: ${params.gtf}" }
}
//genomeGtf.into {gtfSTARCh, gtfFeatureCountsCh}

if ( params.starIndex ){
  genomeIndex=Channel
    .fromPath(params.starIndex)
    .ifEmpty { exit 1, "Star not found: ${params.starIndex}" }
}
//genomeIndex.into { chStar; chStarNOT }

/*----------------*/

// Create a channel for input read files
if(params.samplePlan){
  if(params.singleEnd){
    Channel
      .from(file("${params.samplePlan}"))
      .splitCsv(header: false)
      .map{ row -> [ row[0], [file(row[2])]] }
      .into { rawReadsFastqc; chMergeReadsFastq }
  }else{
    Channel
      .from(file("${params.samplePlan}"))
      .splitCsv(header: false)
      .map{ row -> [ row[0], [file(row[2]), file(row[3])]] }
      .into { rawReadsFastqc ; chMergeReadsFastq}
   }
  params.reads=false
}
else if(params.readPaths){
  if(params.singleEnd){
    Channel
      .from(params.readPaths)
      .map { row -> [ row[0], [file(row[1][0])]] }
      .ifEmpty { exit 1, "params.readPaths was empty - no input files supplied." }
      .into { rawReadsFastqc ; chMergeReadsFastq}
  } else {
    Channel
      .from(params.readPaths)
      .map { row -> [ row[0], [file(row[1][0]), file(row[1][1])]] }
      .ifEmpty { exit 1, "params.readPaths was empty - no input files supplied." }
      .into { rawReadsFastqc ; chMergeReadsFastq}
  }
} else {
  Channel
    .fromFilePairs( params.reads, size: params.singleEnd ? 1 : 2 )
    .ifEmpty { exit 1, "Cannot find any reads matching: ${params.reads}\nNB: Path needs to be enclosed in quotes!\nNB: Path requires at least one * wildcard!\nIf this is single-end data, please specify --singleEnd on the command line." }
    .into { rawReadsFastqc ; chMergeReadsFastq}
}

// Make sample plan if not available
/**********************************/

if (params.samplePlan){
  Channel
    .fromPath(params.samplePlan)
    .into {chSplan; chSplanCheck}
}else if(params.readPaths){
  if (params.singleEnd){
    Channel
      .from(params.readPaths)
      .collectFile() {
        item -> ["sample_plan.csv", item[0] + ',' + item[0] + ',' + item[1][0] + '\n']
       }
      .into{ chSplan; chSplanCheck }
  }else{
     Channel
       .from(params.readPaths)
       .collectFile() {
         item -> ["sample_plan.csv", item[0] + ',' + item[0] + ',' + item[1][0] + ',' + item[1][1] + '\n']
        }
       .into{ chSplan; chSplanCheck }
  }
} else if(params.bamPaths){
  Channel
    .from(params.bamPaths)
    .collectFile() {
      item -> ["sample_plan.csv", item[0] + ',' + item[0] + ',' + item[1][0] + '\n']
     }
    .into{ chSplan; chSplanCheck }
  params.aligner = false
} else {
  if (params.singleEnd){
    Channel
      .fromFilePairs( params.reads, size: 1 )
      .collectFile() {
         item -> ["sample_plan.csv", item[0] + ',' + item[0] + ',' + item[1][0] + '\n']
      }     
      .into { chSplan; chSplanCheck }
  }else{
    Channel
      .fromFilePairs( params.reads, size: 2 )
      .collectFile() {
         item -> ["sample_plan.csv", item[0] + ',' + item[0] + ',' + item[1][0] + ',' + item[1][1] + '\n']
      }     
      .into { chSplan; chSplanCheck }
   }
}


/***************
 * Design file *
 ***************/

// TODO - UPDATE BASED ON YOUR DESIGN

if (params.design){
  Channel
    .fromPath(params.design)
    .ifEmpty { exit 1, "Design file not found: ${params.design}" }
    .into { chDesignCheck; chDesignControl; chDesignMqc }

  chDesignControl
    .splitCsv(header:true)
    .map { row ->
      if(row.CONTROLID==""){row.CONTROLID='NO_INPUT'}
      return [ row.SAMPLEID, row.CONTROLID, row.SAMPLENAME, row.GROUP, row.PEAKTYPE ]
     }
    .set { chDesignControl }

  // Create special channel to deal with no input cases
  Channel
    .from( ["NO_INPUT", ["NO_FILE","NO_FILE"]] )
    .toList()
    .set{ chNoInput }
}else{
  chDesignControl = Channel.empty()
  chDesignCheck = Channel.empty()
  chDesignMqc = Channel.empty()
}


/*******************
 * Header log info *
 *******************/

if ("${workflow.manifest.version}" =~ /dev/ ){
   log.info devMessageFile.text
}

log.info """=======================================================

smartSeq3 v${workflow.manifest.version}
======================================================="""
def summary = [:]

/* ADDED -------------*/
summary['Pipeline Name']  = 'SmartSeq3'
summary['Pipeline Version'] = workflow.manifest.version
//summary['Run Name']     = custom_runName ?: workflow.runName
summary['Command Line'] = workflow.commandLine
if (params.samplePlan) {
   summary['SamplePlan']   = params.samplePlan
}else{
   summary['Reads']        = params.reads
}
summary['Genome']       = params.genome
summary['First min Count umis per Cell']  = params.minCountPerCell1
summary['Second min Count umis per Cell']  = params.minCountPerCell2
summary['First min Count genes per Cell']  = params.minCountPerCellGene1
summary['Second min Count genes per Cell']  = params.minCountPerCellGene2
/*--------------------------------*/

summary['Max Memory']     = params.maxMemory
summary['Max CPUs']       = params.maxCpus
summary['Max Time']       = params.maxTime
summary['Container Engine'] = workflow.containerEngine
summary['Current home']   = "$HOME"
summary['Current user']   = "$USER"
summary['Current path']   = "$PWD"
summary['Working dir']    = workflow.workDir
summary['Output dir']     = params.outDir
summary['Config Profile'] = workflow.profile
log.info summary.collect { k,v -> "${k.padRight(15)}: $v" }.join("\n")
log.info "========================================="

// TODO - ADD YOUR NEXTFLOW PROCESS HERE

process umiExtraction {
  tag "${prefix}"
  label 'umiTools'
  label 'medCpu'
  label 'medMem'
  publishDir "${params.outDir}/umiExtraction", mode: 'copy'

  input: 
  set val(prefix), file(reads) from rawReadsFastqc

  output:
  set val(prefix), file("*_UMIsExtracted.R1.fastq"), file("*_UMIsExtracted.R2.fastq") into chUmiExtracted
  set val(prefix), file("*_umiExtract.log") into chUmiExtractedLog
  file("v_umi_tools.txt") into chUmiToolsVersion

  script:
  length_umi = params.umi_size
  opts ="--extract-method=regex --bc-pattern='(?P<discard_1>.*ATTGCGCAATG)(?P<umi_1>.{$length_umi})(?P<discard_2>GGG).*' --stdin=${reads[0]} --stdout=${prefix}_UMIsExtracted.R1.fastq --read2-in=${reads[1]} --read2-out=${prefix}_UMIsExtracted.R2.fastq "
  """
  # Extract barcdoes and UMIs and add to read names
  umi_tools extract $opts --log=${prefix}_umiExtract.log 

  umi_tools --version &> v_umi_tools.txt
  """
}

process mergeReads {
  tag "${prefix}"
  label 'seqkit'
  label 'medCpu'
  label 'medMem'
  publishDir "${params.outDir}/mergeReads", mode: 'copy'

  input:
  set val(prefix), file(reads) from chMergeReadsFastq
  set val(prefix), file(umiReads_R1), file(umiReads_R2) from chUmiExtracted

  output:
  set val(prefix), file("*_totReads.R1.fastq"), file("*_totReads.R2.fastq") into chMergeReads
  set val(prefix), file("*_percent_umi.txt") into chPercentUMI

  script:
  """
  # Get UMI reads
  seqkit seq -n -i ${umiReads_R1} | cut -f1 -d_ > ${prefix}_umisReadsIDs

  # Extract non umis reads
  seqkit grep -v -f ${prefix}_umisReadsIDs ${reads[0]} -o ${prefix}_nonUMIs.R1.fastq
  seqkit grep -v -f ${prefix}_umisReadsIDs ${reads[1]} -o ${prefix}_nonUMIs.R2.fastq

  # Merge non umis reads + umi reads (with umi in read names)
  cat ${umiReads_R1} > ${prefix}_totReads.R1.fastq
  cat ${prefix}_nonUMIs.R1.fastq >> ${prefix}_totReads.R1.fastq

  cat ${umiReads_R2} > ${prefix}_totReads.R2.fastq
  cat ${prefix}_nonUMIs.R2.fastq >> ${prefix}_totReads.R2.fastq

  ## Save % UMIs reads 
  nb_lines=`wc -l < <(gzip -cd ${reads[0]})`
  echo \$nb_lines > test
  nb_totreads=\$(( \$nb_lines / 4 ))
  echo \$nb_totreads >> test
  nb_umis=`wc -l < ${prefix}_umisReadsIDs`
  echo \$nb_umis >> test
  `echo \$(( \$nb_umis * 100 / \$nb_totreads ))` > ${prefix}_percent_umi.txt
  """
}

process trimmSeq{
  tag "${prefix}"
  label 'seqkit'
  label 'medCpu'
  label 'medMem'
  publishDir "${params.outDir}/mergeReads", mode: 'copy'

  input:
  set val(prefix), file(totReadsR1), file(totReadsR2) from chMergeReads

  output:
  set val(prefix), file("*_trimmed.R1.fastq"), file("*_trimmed.R2.fastq") into chTrimmedReads
  set val(prefix), file("*_trimmed.log") into chtrimmedReadsLog

  script:
  """
  cutadapt -G XGCATACGAT{30} --minimum-length=15 -o ${prefix}_trimmed.R1.fastq -p ${prefix}_trimmed.R2.fastq ${totReadsR1} ${totReadsR2} > ${prefix}_trimmed.log
  """
}

/*
process readAlignment {
  tag "${prefix}"
  publishDir "${params.outDir}/readAlignment", mode: 'copy'

  input :
  file genomeIndex from chStar.collect()
  file genomeGtf from gtfSTARCh.collect()
  set val(prefix), file(umiExtractedR1) , file(umiExtractedR2) from umiExtractedCh
	
  output :
  set val(prefix), file("*Aligned.sortedByCoord.out.bam") into alignedBamCh
  file "*.out" into alignmentLogs
  set val(prefix), file ("*_index_mqc.log") into indexCounts

  script:
  opts = " --limitSjdbInsertNsj 2000000 --clip3pAdapterSeq CTGTCTCTTATACACATCT " 
  
  """
  STAR \
    --genomeDir $genomeIndex \
    --sjdbGTFfil $genomeGtf \
    --readFilesIn ${umiExtractedR1},${umiExtractedR2} \
    --runThreadN ${task.cpus} \
    --outFilterMultimapNmax 1 \
    --outFileNamePrefix ${prefix} \
    --outSAMtype BAM SortedByCoordinate \
    --clip3pAdapterSeq CTGTCTCTTATACACATCT
  # --limitSjdbInsertNsj 2000000 --outFilterIntronMotifs RemoveNoncanonicalUnannotated ??????????

  # Add the number of barcoded reads as first line of the index count file
  #barcoded=`grep "Number of input reads" ${prefix}Log.final.out | cut -d'|' -f2 ` 
  #echo "\$(echo 'Barcoded,'\$barcoded | cat - ${bcIndxCounts} )" > ${prefix}_index_mqc.log
  """
}
*/



/***********
 * MultiQC *
 ***********/

process getSoftwareVersions{
  label 'python'
  label 'lowCpu'
  label 'lowMem'
  publishDir path: "${params.outDir}/software_versions", mode: "copy"

  when:
  !params.skipSoftVersions

  input:
  file 'v_umi_tools.txt' from chUmiToolsVersion.first().ifEmpty([])

  output:
  file 'software_versions_mqc.yaml' into softwareVersionsYaml

  script:
  """
  echo $workflow.manifest.version &> v_pipeline.txt
  echo $workflow.nextflow.version &> v_nextflow.txt
  scrape_software_versions.py &> software_versions_mqc.yaml
  """
}

process workflowSummaryMqc {
  when:
  !params.skipMultiQC

  output:
  file 'workflow_summary_mqc.yaml' into workflowSummaryYaml

  exec:
  def yaml_file = task.workDir.resolve('workflow_summary_mqc.yaml')
  yaml_file.text  = """
  id: 'summary'
  description: " - this information is collected when the pipeline is started."
  section_name: 'Workflow Summary'
  section_href: 'https://gitlab.curie.fr/data-analysis/chip-seq'
  plot_type: 'html'
  data: |
        <dl class=\"dl-horizontal\">
  ${summary.collect { k,v -> "            <dt>$k</dt><dd><samp>${v ?: '<span style=\"color:#999999;\">N/A</a>'}</samp></dd>" }.join("\n")}
        </dl>
  """.stripIndent()
}


process multiqc {
  label 'multiqc'
  label 'lowCpu'
  label 'lowMem'
  publishDir "${params.outDir}/MultiQC", mode: 'copy'

  when:
  !params.skipMultiQC

  input:
  file splan from chSplan.collect()
  file multiqcConfig from chMultiqcConfig
  file design from chDesignMqc.collect().ifEmpty([])
  file metadata from chMetadata.ifEmpty([])
  file ('software_versions/*') from softwareVersionsYaml.collect().ifEmpty([])
  file ('workflow_summary/*') from workflowSummaryYaml.collect()

  output: 
  file splan
  file "*_report.html" into multiqc_report
  file "*_data"

  script:
  rtitle = customRunName ? "--title \"$customRunName\"" : ''
  rfilename = customRunName ? "--filename " + customRunName + "_report" : "--filename report"
  metadataOpts = params.metadata ? "--metadata ${metadata}" : ""
  //isPE = params.singleEnd ? "" : "-p"
  designOpts= params.design ? "-d ${params.design}" : ""
  modules_list = "-m custom_content"
  """
  mqc_header.py --splan ${splan} --name "PIPELINE" --version ${workflow.manifest.version} ${metadataOpts} > multiqc-config-header.yaml
  multiqc . -f $rtitle $rfilename -c multiqc-config-header.yaml -c $multiqcConfig $modules_list
  """
}

/****************
 * Sub-routines *
 ****************/

process outputDocumentation {
  label 'python'
  label 'lowCpu'
  label 'lowMem'

  publishDir "${params.outDir}/pipeline_info", mode: 'copy'

  input:
  file output_docs from chOutputDocs
  file images from chOutputDocsImages

  output:
  file "results_description.html"

  script:
  """
  markdown_to_html.py $output_docs -o results_description.html
  """
}

workflow.onComplete {

  // pipelineReport.html
  def reportFields = [:]
  reportFields['version'] = workflow.manifest.version
  reportFields['runName'] = customRunName ?: workflow.runName
  reportFields['success'] = workflow.success
  reportFields['dateComplete'] = workflow.complete
  reportFields['duration'] = workflow.duration
  reportFields['exitStatus'] = workflow.exitStatus
  reportFields['errorMessage'] = (workflow.errorMessage ?: 'None')
  reportFields['errorReport'] = (workflow.errorReport ?: 'None')
  reportFields['commandLine'] = workflow.commandLine
  reportFields['projectDir'] = workflow.projectDir
  reportFields['summary'] = summary
  reportFields['summary']['Date Started'] = workflow.start
  reportFields['summary']['Date Completed'] = workflow.complete
  reportFields['summary']['Pipeline script file path'] = workflow.scriptFile
  reportFields['summary']['Pipeline script hash ID'] = workflow.scriptId
  if(workflow.repository) reportFields['summary']['Pipeline repository Git URL'] = workflow.repository
  if(workflow.commitId) reportFields['summary']['Pipeline repository Git Commit'] = workflow.commitId
  if(workflow.revision) reportFields['summary']['Pipeline Git branch/tag'] = workflow.revision

  // Render the TXT template
  def engine = new groovy.text.GStringTemplateEngine()
  def tf = new File("$baseDir/assets/onCompleteTemplate.txt")
  def txtTemplate = engine.createTemplate(tf).make(reportFields)
  def reportTxt = txtTemplate.toString()

  // Render the HTML template
  def hf = new File("$baseDir/assets/onCompleteTemplate.html")
  def htmlTemplate = engine.createTemplate(hf).make(reportFields)
  def reportHtml = htmlTemplate.toString()

  // Write summary HTML to a file
  def outputSummaryDir = new File( "${params.summaryDir}/" )
  if( !outputSummaryDir.exists() ) {
    outputSummaryDir.mkdirs()
  }
  def outputHtmlFile = new File( outputSummaryDir, "pipelineReport.html" )
  outputHtmlFile.withWriter { w -> w << reportHtml }
  def outputTxtFile = new File( outputSummaryDir, "pipelineReport.txt" )
  outputTxtFile.withWriter { w -> w << reportTxt }

  // onComplete file
  File woc = new File("${params.outDir}/onComplete.txt")
  Map endSummary = [:]
  endSummary['Completed on'] = workflow.complete
  endSummary['Duration']     = workflow.duration
  endSummary['Success']      = workflow.success
  endSummary['exit status']  = workflow.exitStatus
  endSummary['Error report'] = workflow.errorReport ?: '-'
  String endWfSummary = endSummary.collect { k,v -> "${k.padRight(30, '.')}: $v" }.join("\n")
  println endWfSummary
  String execInfo = "Execution summary\n${endWfSummary}\n"
  woc.write(execInfo)

  // final logs
  if(workflow.success){
      log.info "Pipeline Complete"
  }else{
    log.info "FAILED: $workflow.runName"
  }
}
