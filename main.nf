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

if ((params.reads && params.samplePlan) || (params.readDir && params.samplePlan)){
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
chBatchSize     = params.batchSize     ? Channel.value(params.batchSize)                                    : Channel.value([])

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
  'Remove singleton' : params.rmSingleton ? "Yes" : "No",
  'Remove Duplicates' : params.keepDups ? "No" : "Yes",
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
chRawReads = NFTools.getInputData(params.samplePlan, params.reads, params.readDir, params)

// Make samplePlan if not available
sPlanCh = NFTools.getSamplePlan(params.samplePlan, params.reads, params.readDir)

/*
==================================
           INCLUDE
==================================
*/ 

// Workflows
include { createBatchesFlow } from './nf-modules/common/subworkflow/createBatchesFlow'

// Process
include { getSoftwareVersions } from './nf-modules/common/process/utils/getSoftwareVersions'
include { outputDocumentation } from './nf-modules/common/process/utils/outputDocumentation'
include { umiExtract as umiExtractR1 } from './nf-modules/common/process/umitools/umiExtract'
include { umiExtract as umiExtractR2 } from './nf-modules/common/process/umitools/umiExtract'
//include { seqkitSeq } from './nf-modules/common/process/seqkit/seqkitSeq'
include { concatFastq } from './nf-modules/common/process/concatFastq/concatFastq'
include { cutadapt } from './nf-modules/common/process/cutadapt/cutadapt'
include { starAlign } from './nf-modules/common/process/star/starAlign'
include { samtoolsMerge } from './nf-modules/common/process/samtools/samtoolsMerge'
include { samtoolsStats } from './nf-modules/common/process/samtools/samtoolsStats'
include { samtoolsFixmate } from './nf-modules/common/process/samtools/samtoolsFixmate'
include { samtoolsSort } from './nf-modules/common/process/samtools/samtoolsSort'
include { samtoolsMarkdup } from './nf-modules/common/process/samtools/samtoolsMarkdup'
include { samtoolsFlagstat as markdupStat } from './nf-modules/common/process/samtools/samtoolsFlagstat'
include { samtoolsFilter as filterUnaligned } from './nf-modules/common/process/samtools/samtoolsFilter'
include { samtoolsFilter as filterMarkdup } from './nf-modules/common/process/samtools/samtoolsFilter'
include { samtoolsIndex as samtoolsIndexFilterUnaligned } from './nf-modules/common/process/samtools/samtoolsIndex'
include { samtoolsIndex as samtoolsIndexFilterMarkdup } from './nf-modules/common/process/samtools/samtoolsIndex'
include { featureCounts as featureCountsUmis} from './nf-modules/common/process/featureCounts/featureCounts'
include { featureCounts as featureCountsNonUmis} from './nf-modules/common/process/featureCounts/featureCounts'

include { multiqc } from './nf-modules/local/process/multiqc'

/*
=====================================
            WORKFLOW 
=====================================
*/

workflow {
  chVersions = Channel.empty()

  main:

  //********************************************************
  // Merge cell fastqs into one 
  createBatchesFlow(
    chRawReads,
    chBatchSize
  )
  chVersions = createBatchesFlow.out.versions

  //********************************************************
  // Extract UMIs info 

  // extract UMIs in forward reads (R1)
  umiExtractR1(
    createBatchesFlow.out.reads,
    Channel.value('R1')
  )
  ChVersionsCh = chVersions.mix(umiExtractR1.out.versions)

  // extract UMIs in reverse reads (R2)
  umiExtractR2(
    umiExtractR1.out.noumi, // reads without umi in R1 (but maybe in R2)
    Channel.value('R2')
  )
  chNoUmi = umiExtractR2.out.noumi
  chVersions = chVersions.mix(umiExtractR2.out.versions)

  // Reconcatenate umi fastqs (R1umi + R2umis)
  chUmi = umiExtractR1.out.fastq
    .join(umiExtractR2.out.fastq)
    .map{meta,umi1,umi2 -> [meta, [umi1[0], umi1[1], umi2[0], umi2[1]]]}

  // concatenate R1 together and R2 together 
  concatFastq(
    chUmi, 
    Channel.value(2)
  )
  chUmiReadsConcat = concatFastq.out.reads //V660_chunk1_R1.concat.fastq.gz, V660_chunk1_R2.concat.fastq.gz
  chVersions = chVersions.mix(concatFastq.out.versions)

  // add umi info into meta
  chUmiReads=chUmiReadsConcat
  .map{meta, fastqs ->
    newMeta = [ id: meta.id, name: meta.name, protocol: meta.protocol, chunk:meta.chunk ,part:meta.part, umi:"umi"]
    [newMeta, fastqs]
    }
  chNoUmiReads=chNoUmi
  .map{meta, fastqs ->
    newMeta = [ id: meta.id, name: meta.name, protocol: meta.protocol, chunk:meta.chunk ,part:meta.part, umi:"noUmi"]
    [newMeta, fastqs]
    }
  chReads = chUmiReads.concat(chNoUmiReads)

  // Get name of reads without UMIs
  /*seqkitSeq(
    chNoUmi // reads without umi in R1 and R2
  )
  chVersions = chVersions.mix(seqkitSeq.out.versions)*/

  //********************************************************
  // trim polyA/T linker 
  cutadapt(
    chReads
  )
  chVersions = chVersions.mix(cutadapt.out.versions)

  //********************************************************
  // Sequence alignement

  starAlign(
    cutadapt.out.fastq,
    chStarIndex,
    chGtf
  )
  chVersions = chVersions.mix(starAlign.out.versions)

  // Merge BAM of batchs but still keep the number of total number of batchs info in meta.part
  // meta.chunk (==batch number) info is deleted
  chStar = starAlign.out.bam
    .map{meta, bam ->
       def newMeta = [ id: meta.id, name: meta.name, protocol: meta.protocol, part:meta.part ]
       [ groupKey(newMeta, meta.part), bam ]
     }.groupTuple()
     .branch {
       single: it[0].part <= 1 // if only one batch
       multiple: it[0].part > 1 // if several batchs
     }


 filterUnaligned(
    chStar
  )
  chVersions = chVersions.mix(filterUnaligned.out.versions)
                                                                                                                                                                                                       
  samtoolsIndexFilterUnaligned(
    filterUnaligned.out.bam
  )
  chVersions = chVersions.mix(samtoolsIndexFilterUnaligned.out.versions)

  filterUnaligned.out.bam.join(samtoolsIndexFilterUnaligned.out.bai).view()

  filterUnaligned.out.bam.join(samtoolsIndexFilterUnaligned.out.bai)
  .branch {
        umi: it[0].umi == "umi"
        noUmi: it[0].umi == "noUmi"
    }
    .set { chAlignedBams }

    chAlignedBams.view()

  //********************************************************
  // Assign UMI reads

  featureCountsUmis(
    chAlignedBams.umi.combine(chGtf)
  )
  chVersions = chVersions.mix(featureCountsUmis.out.versions)


  /***************TODO*************************
  samtools merge umi+nonUMI
  samtools stats 
  preseq

  samtoolsMerge(
    chAlignedBams.multiple
  )
  chBams = samtoolsMerge.out.bam.mix(chAlignedBams.single)
  chVersions = chVersions.mix(samtoolsMerge.out.versions)

  samtoolsStats(
    chBams,
    Channel.value([])
  )
  chVersions = chVersions.mix(samtoolsStats.out.versions)
  *****************************************/

  //********************************************************
  // Mark PCR reads duplicates non Non UMI reads

  /*samtoolsFixmate(
    chBams
  )
  chVersions = chVersions.mix(samtoolsFixmate.out.versions)

  samtoolsSort(
    samtoolsFixmate.out.bam
  )
  chVersions = chVersions.mix(samtoolsSort.out.versions)

  samtoolsMarkdup(
    samtoolsSort.out.bam
  )
  chVersions = chVersions.mix(samtoolsMarkdup.out.versions)

  // Stats on mapped reads including duplicates
  markdupStat(
    samtoolsMarkdup.out.bam
  )
  chVersions = chVersions.mix(markdupStat.out.versions)

  //********************************************************
  // Filter out pcr duplicates
  
  filterMarkdup(
    samtoolsMarkdup.out.bam
  )
  chVersions = chVersions.mix(samtoolsFilter.out.versions)
                                                                                                                                                                                                       
  samtoolsIndexFilter(
    samtoolsFilter.out.bam
  )
  chVersions = chVersions.mix(samtoolsIndexFilter.out.versions)*/

  
  // subroutines
  //outputDocumentation(
  //  outputDocsCh,
  //  outputDocsImagesCh
  //)

  //*******************************************
  // MULTIQC

  // Warnings that will be printed in the mqc report
  warnCh = Channel.empty()

  if (!params.skipMultiQC){

    getSoftwareVersions(
      chVersions.unique().collectFile()
    )

  //  multiqc(
  //    customRunName,
  //    sPlanCh.collect(),
  //    metadataCh.ifEmpty([]),
  //    multiqcConfigCh.ifEmpty([]),
  //    getSoftwareVersions.out.versionsYaml.collect().ifEmpty([]),
  //    workflowSummaryCh.collectFile(name: "workflow_summary_mqc.yaml"),
  //    warnCh.collect().ifEmpty([])
  //  )
  //  mqcReport = multiqc.out.report.toList()
  }
}

workflow.onComplete {
  NFTools.makeReports(workflow, params, summary, customRunName, mqcReport)
}
