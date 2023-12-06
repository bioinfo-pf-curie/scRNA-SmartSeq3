#!/usr/bin/env nextflow

/*
Copyright Institut Curie 2019-2022
This software is a computer program whose purpose is to analyze high-throughput sequencing data.
You can use, modify and/ or redistribute the software under the terms of license (see the LICENSE file for more details).
The software is distributed in the hope that it will be useful, but "AS IS" WITHOUT ANY WARRANTY OF ANY KIND.
Users are therefore encouraged to test the software's suitability as regards their requirements in conditions enabling the security of their systems and/or data. 
The fact that you are presently reading this means that you have had knowledge of the license and that you accept its terms.
*/

/*
========================================================================================
                         DSL2 Template
========================================================================================
Analysis Pipeline DSL2 template.
https://patorjk.com/software/taag/
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl=2

// Initialize lintedParams and paramsWithUsage
NFTools.welcome(workflow, params)

// Use lintedParams as default params object
paramsWithUsage = NFTools.readParamsFromJsonSettings("${projectDir}/parameters.settings.json")
params.putAll(NFTools.lint(params, paramsWithUsage))

// Run name
customRunName = NFTools.checkRunName(workflow.runName, params.name)

// Custom functions/variables
mqcReport = []
include {checkAlignmentPercent} from './lib/functions'

// Initialize variable from the genome.conf file
params.starIndex = NFTools.getGenomeAttribute(params, 'starIndex')
params.bed12 = NFTools.getGenomeAttribute(params, 'bed12')
params.gtf = NFTools.getGenomeAttribute(params, 'gtf')

/*
===================================
  SET UP CONFIGURATION VARIABLES
===================================
*/

// Genome-based variables
if (!params.genome){
  exit 1, "No genome provided. The --genome option is mandatory"
}

if (params.genomes && params.genome && !params.genomes.containsKey(params.genome)) {
  exit 1, "The provided genome '${params.genome}' is not available in the genomes file. Currently the available genomes are ${params.genomes.keySet().join(", ")}"
}

// Stage config files
multiqcConfigCh = Channel.fromPath(params.multiqcConfig)
outputDocsCh = Channel.fromPath("$projectDir/docs/output.md")
outputDocsImagesCh = file("$projectDir/docs/images/", checkIfExists: true)

/*
==========================
 VALIDATE INPUTS
==========================
*/

if ((params.reads && params.samplePlan) || (params.readPaths && params.samplePlan)){
  exit 1, "Input reads must be defined using either '--reads' or '--samplePlan' parameter. Please choose one way"
}

/*
==========================
 BUILD CHANNELS
==========================
*/

if ( params.metadata ){
  Channel
    .fromPath( params.metadata )
    .ifEmpty { exit 1, "Metadata file not found: ${params.metadata}" }
    .set { metadataCh }
}

chStarIndex  = params.starIndex  ? Channel.fromPath(params.starIndex, checkIfExists: true).collect()         : Channel.empty()
chBed12      = params.bed12    ? Channel.fromPath(params.bed12, checkIfExists: true).collect()         : Channel.empty()
chGtf        = params.gtf   ? Channel.fromPath(params.gtf, checkIfExists: true).collect()               : Channel.empty()

/*
===========================
   SUMMARY
===========================
*/

summary = [
  'Pipeline' : workflow.manifest.name ?: null,
  'Version': workflow.manifest.version ?: null,
  'DOI': workflow.manifest.doi ?: null,
  'Run Name': customRunName,
  'Inputs' : params.samplePlan ?: params.reads ?: null,
  'Genome' : params.genome,
  'Max Resources': "${params.maxMemory} memory, ${params.maxCpus} cpus, ${params.maxTime} time per job",
  'Container': workflow.containerEngine && workflow.container ? "${workflow.containerEngine} - ${workflow.container}" : null,
  'Profile' : workflow.profile,
  'OutDir' : params.outDir,
  'WorkDir': workflow.workDir,
  'CommandLine': workflow.commandLine
].findAll{ it.value != null }

workflowSummaryCh = NFTools.summarize(summary, workflow, params)

/*
==============================
  LOAD INPUT DATA
==============================
*/

// Load raw reads
rawReadsCh = NFTools.getInputData(params.samplePlan, params.reads, params.readPaths, params.singleEnd, params)
rawReadsCh.view()

// Make samplePlan if not available
sPlanCh = NFTools.getSamplePlan(params.samplePlan, params.reads, params.readPaths, params.singleEnd)

/*
==================================
           INCLUDE
==================================
*/ 

// Workflows

// Processes
include { getSoftwareVersions } from './nf-modules/common/process/utils/getSoftwareVersions'
include { outputDocumentation } from './nf-modules/common/process/utils/outputDocumentation'
include { umiExtraction } from './nf-modules/common/process/umitools/umiExtraction'
include { umiExtractionSummary } from './nf-modules/common/process/umitools/umiExtractionSummary'
include { multiqc } from './nf-modules/local/process/multiqc'

/*
=====================================
            WORKFLOW 
=====================================
*/

workflow {
  versionsCh = Channel.empty()

  main:

    // subroutines
    outputDocumentation(
      outputDocsCh,
      outputDocsImagesCh
    )

    // extract UMIs in forward reads
    stdin_R1 = Channel.of('R1')

    stdin_R1.view()
    
    umiExtraction(
      rawReadsCh,
      stdin_R1
    )
    umiExtraction_fastqR1Ch = umiExtraction.out.fastq_umi
    umiExtraction_fastqNoUmiR1Ch = umiExtraction.out.fastq_noumi
    umiExtraction_logR1Ch = umiExtraction.out.log
    versionsCh = versionsCh.mix(umiExtraction.out.versions)

    // extract UMIs in reverse reads
    stdin_R2 = Channel.of('R2')
    umiExtraction_fastqR1Ch
      .map() {item -> [item[1], item[0]] }
      .set{umiExtraction_fastqR1_changedCh}
    
    umiExtraction(
      umiExtraction_fastqR1_changedCh,
      stdin_R2
    )
    umiExtraction_fastqR2Ch = umiExtraction.out.fastq_umi
    umiExtraction_fastqNoUmiR2Ch = umiExtraction.out.fastq_noumi
    umiExtraction_logR2Ch = umiExtraction.out.log
    versionsCh = versionsCh.mix(umiExtraction.out.versions)
    
    // summarize UMI extraction
    umiExtractionSummary(
      rawReadsCh.join(umiExtraction_fastqR1Ch).join(umiExtraction_fastqR2Ch).join(umiExtraction_fastqNoUmiR2Ch)
    )
    umiExtractionSummary_fastqCh = umiExtractionSummary.out.fastq
    umiExtractionSummary_nonUmiReadIdCh = umiExtractionSummary.out.nonUmiReadId
    umiExtractionSummary_percentUmiCh = umiExtractionSummary.out.percentUmi
    umiExtractionSummary_nbTotFragCh = umiExtractionSummary.out.nbTotFrag

    //*******************************************
    // MULTIQC
  
    // Warnings that will be printed in the mqc report
    warnCh = Channel.empty()

    if (!params.skipMultiQC){

      getSoftwareVersions(
        versionsCh.unique().collectFile()
      )

      multiqc(
        customRunName,
        sPlanCh.collect(),
        metadataCh.ifEmpty([]),
        multiqcConfigCh.ifEmpty([]),
        getSoftwareVersions.out.versionsYaml.collect().ifEmpty([]),
        workflowSummaryCh.collectFile(name: "workflow_summary_mqc.yaml"),
        warnCh.collect().ifEmpty([])
      )
      mqcReport = multiqc.out.report.toList()
    }
}

workflow.onComplete {
  NFTools.makeReports(workflow, params, summary, customRunName, mqcReport)
}
