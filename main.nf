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
include { markdupFlow } from './nf-modules/common/subworkflow/markdupFlow'

// Process
include { getSoftwareVersions } from './nf-modules/common/process/utils/getSoftwareVersions'
include { outputDocumentation } from './nf-modules/common/process/utils/outputDocumentation'
include { umitoolsExtract as umiExtractR1 } from './nf-modules/common/process/umitools/umitoolsExtract'
include { umitoolsExtract as umiExtractR2 } from './nf-modules/common/process/umitools/umitoolsExtract'
//include { seqkitSeq } from './nf-modules/common/process/seqkit/seqkitSeq'
include { concatFastq } from './nf-modules/common/process/concatFastq/concatFastq'
include { cutadapt } from './nf-modules/common/process/cutadapt/cutadapt'
include { starAlign } from './nf-modules/common/process/star/starAlign'

include { barcode2tag} from './nf-modules/local/process/barcode2tag'
include { barcodeListPerBatch} from './nf-modules/local/process/barcodeListPerBatch'
include { nbCells} from './nf-modules/local/process/nbCells'

include { samtoolsMerge as samtoolsMergeBatch } from './nf-modules/common/process/samtools/samtoolsMerge'
include { samtoolsMerge as samtoolsMergeStar } from './nf-modules/common/process/samtools/samtoolsMerge'
include { samtoolsMerge as samtoolsMergeFinal } from './nf-modules/common/process/samtools/samtoolsMerge'

include { samtoolsStats } from './nf-modules/common/process/samtools/samtoolsStats'
include { samtoolsFilter as filterUnaligned } from './nf-modules/common/process/samtools/samtoolsFilter'
include { samtoolsFilter as filterMarkdup } from './nf-modules/common/process/samtools/samtoolsFilter'
include { samtoolsIndex as samtoolsIndexStar } from './nf-modules/common/process/samtools/samtoolsIndex'
include { samtoolsIndex as samtoolsIndexAligned } from './nf-modules/common/process/samtools/samtoolsIndex'
include { samtoolsIndex as samtoolsIndexMarkdup } from './nf-modules/common/process/samtools/samtoolsIndex'
include { samtoolsIndex as samtoolsIndexUmis} from './nf-modules/common/process/samtools/samtoolsIndex'
include { samtoolsIndex as samtoolsIndexFinalBam} from './nf-modules/common/process/samtools/samtoolsIndex'

include { samtoolsSort as samtoolsSortUmis} from './nf-modules/common/process/samtools/samtoolsSort'
include { samtoolsSort as samtoolsSortNoUmis} from './nf-modules/common/process/samtools/samtoolsSort'
include { samtoolsSort as samtoolsSortFinalBam} from './nf-modules/common/process/samtools/samtoolsSort'

include { featureCounts as featureCountsUmis} from './nf-modules/common/process/featureCounts/featureCounts'
include { umitoolsCount as umitoolsCountUmis} from './nf-modules/common/process/umitools/umitoolsCount'
include { umitoolsDedup } from './nf-modules/common/process/umitools/umitoolsDedup'

include { featureCounts as featureCountsNoUmis} from './nf-modules/common/process/featureCounts/featureCounts'
include { samtoolsFilter as filterNoUmisUnassigned } from './nf-modules/common/process/samtools/samtoolsFilter'
include { featureCountsMatrix} from './nf-modules/local/process/featureCountsMatrix'

// multiqc modules
include { preseq } from './nf-modules/common/process/preseq/preseq'
include { rseqcGeneBodyCoverage } from './nf-modules/common/process/rseqc/rseqcGeneBodyCoverage'
include { rseqcReadQuality } from './nf-modules/common/process/rseqc/rseqcReadQuality'
include { rseqcBamStat } from './nf-modules/common/process/rseqc/rseqcBamStat'
include { rseqcInnerDistance } from './nf-modules/common/process/rseqc/rseqcInnerDistance'
include { rseqcReadDistribution } from './nf-modules/common/process/rseqc/rseqcReadDistribution'
include { rseqcJunctionAnnotation } from './nf-modules/common/process/rseqc/rseqcJunctionAnnotation'
include { rseqcJunctionSaturation } from './nf-modules/common/process/rseqc/rseqcJunctionSaturation'
include { qualimapRNAseq } from './nf-modules/common/process/qualimap/qualimapRNAseq'


include { multiqc } from './nf-modules/local/process/multiqc'

/*
=====================================
            WORKFLOW 
=====================================
*/

workflow {
  chVersions = Channel.empty()

  main:

  nbCells(
    chRawReads
  )
  chNbCells = nbCells.out.count

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


  chUmiExtractLogs=umiExtractR1.out.log.join(umiExtractR2.out.log)
  chUmiExtractLogs.view()

  /*umiReadsLog(
    umiExtractR1.out.log.join(umiExtractR2.out.log).collect()
  )
  chTotFrag=
  chPercentUmis=*/

  // Reconcatenate umi fastqs (R1umi + R2umis)
  chUmi = umiExtractR1.out.fastq
    .join(umiExtractR2.out.fastq)
    .map{meta,umi1,umi2 -> [meta, [umi1[0], umi1[1], umi2[0], umi2[1]]]}

  // concatenate R1 together and R2 together 
  concatFastq(
    chUmi, 
    Channel.value(2)
  )
  chUmiReadsConcat = concatFastq.out.reads 
  chVersions = chVersions.mix(concatFastq.out.versions)

  // add umi info into meta
  chUmiReads=chUmiReadsConcat
  .map{meta, fastqs ->
    newMeta = [ id: meta.id, name: meta.name, protocol: meta.protocol, chunk:meta.chunk ,totchunk:meta.totchunk, umi:"umi"]
    [newMeta, fastqs]
    }
  chNoUmiReads=chNoUmi
  .map{meta, fastqs ->
    newMeta = [ id: meta.id, name: meta.name, protocol: meta.protocol, chunk:meta.chunk ,totchunk:meta.totchunk, umi:"noUmi"]
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
  chCutadaptLogs=cutadapt.out.logs
  chVersions = chVersions.mix(cutadapt.out.versions)

  //********************************************************
  // Sequence alignement

  starAlign(
    cutadapt.out.fastq,
    chStarIndex,
    chGtf
  )
  chVersions = chVersions.mix(starAlign.out.versions)

  samtoolsIndexStar(
    starAlign.out.bam
  )
  chVersions = chVersions.mix(samtoolsIndexStar.out.versions)

  barcodeListPerBatch(
    starAlign.out.bam
  )

  // Add barcodes as read tag
  barcode2tag(
    starAlign.out.bam.join(samtoolsIndexStar.out.bai).join(barcodeListPerBatch.out.barcodes)
  )
  chVersions = chVersions.mix(barcode2tag.out.versions)

  // Merge BAM of batchs but still keep the number of total number of batchs info in meta.totchunk
  // meta.chunk (==batch number) info is deleted
  chStar = barcode2tag.out.bam
    .map{meta, bam ->
       def newMeta = [ id: meta.id, name: meta.name, protocol: meta.protocol, totchunk:meta.totchunk, umi:meta.umi]
       [ groupKey(newMeta, meta.totchunk), bam ]
     }.groupTuple()
     .branch {
       single: it[0].totchunk <= 1 // if only one batch
       multiple: it[0].totchunk > 1 // if several batchs
     }

  samtoolsMergeBatch(
    chStar.multiple
  )
  chBams = samtoolsMergeBatch.out.bam.mix(chStar.single)
  chVersions = chVersions.mix(samtoolsMergeBatch.out.versions)

  samtoolsStats(
    chBams, // umi et non umi seperat
    Channel.value([])
  )
  chVersions = chVersions.mix(samtoolsStats.out.versions)

  filterUnaligned(
    chBams
  )
  chVersions = chVersions.mix(filterUnaligned.out.versions)
                                                                                                                                                                                                       
  samtoolsIndexAligned(
    filterUnaligned.out.bam
  )
  chVersions = chVersions.mix(samtoolsIndexAligned.out.versions)

  filterUnaligned.out.bam.join(samtoolsIndexAligned.out.bai)
  .branch {
        umi: it[0].umi == "umi"
        noUmi: it[0].umi == "noUmi"
    }
    .set { chAlignedBams }

  //********************************************************
  // UMI reads

  featureCountsUmis( 
    chAlignedBams.umi.combine(chGtf)
  )
  chVersions = chVersions.mix(featureCountsUmis.out.versions)

  samtoolsSortUmis(
    featureCountsUmis.out.bam
  )
  chVersions = chVersions.mix( samtoolsSortUmis.out.versions)

  samtoolsIndexUmis(
    samtoolsSortUmis.out.bam
  )
  chVersions = chVersions.mix(samtoolsIndexUmis.out.versions)
  
  // generate matrix
  umitoolsCountUmis(
    samtoolsSortUmis.out.bam.join(samtoolsIndexUmis.out.bai)
  )
  chVersions = chVersions.mix(umitoolsCountUmis.out.versions)

  // generate dedup bam
  umitoolsDedup(
    samtoolsSortUmis.out.bam.join(samtoolsIndexUmis.out.bai)
  )
  chUmiFilt=umitoolsDedup.out.bam
  chVersions = chVersions.mix(umitoolsDedup.out.versions)

  //********************************************************
  // Non Umi reads

  // Mark PCR reads duplicates non UMI reads
  markdupFlow(
    chAlignedBams.noUmi
  )
  chVersions = chVersions.mix(markdupFlow.out.versions)

  // Filter out pcr duplicates
  filterMarkdup(
    markdupFlow.out.bam
  )
  chVersions = chVersions.mix(filterMarkdup.out.versions)
                                                                                                                                                                                                       
  samtoolsIndexMarkdup(
    filterMarkdup.out.bam
  )
  chVersions = chVersions.mix(samtoolsIndexMarkdup.out.versions)

  // Assign 
  featureCountsNoUmis( // IF gene_name exists in gtf !!!! add if not -> gene_id
    filterMarkdup.out.bam.join(samtoolsIndexMarkdup.out.bai).combine(chGtf)
  )
  chVersions = chVersions.mix(featureCountsNoUmis.out.versions)

  filterNoUmisUnassigned(
    featureCountsNoUmis.out.bam
  )
  chNoUmiFilt=filterNoUmisUnassigned.out.bam
  chVersions = chVersions.mix(featureCountsNoUmis.out.versions)

  // Matrix 
  featureCountsMatrix(
    featureCountsNoUmis.out.counts,
    filterMarkdup.out.bam
  )

  //********************************************************
  // final BAM

  chFiltBams = chNoUmiFilt.concat(chUmiFilt)
    .map{meta, bam ->
       def newMeta = [ id: meta.id, name: meta.name, protocol: meta.protocol, totchunk:meta.totchunk]
       [ newMeta, bam ]
     }.groupTuple()

  chFiltBams.view()

  samtoolsMergeFinal(
    chFiltBams
  )
  chFinalBam = samtoolsMergeFinal.out.bam
  chVersions = chVersions.mix(samtoolsMergeFinal.out.versions)

  samtoolsSortFinalBam(
    chFinalBam
  )
  chFinalBamSorted = samtoolsSortFinalBam.out.bam
  chVersions = chVersions.mix(samtoolsMergeFinal.out.versions)

  samtoolsIndexFinalBam(
    chFinalBamSorted
  )
  chFinalBai = samtoolsIndexFinalBam.out.bai
  chVersions = chVersions.mix(samtoolsMergeFinal.out.versions)

  //*******************************************
  // MULTIQC

  //subroutines
  outputDocumentation(
    outputDocsCh,
    outputDocsImagesCh
  )
  
  //-----------umitools------------------------------
  //umiExtractionSummary

  //-----------preseq------------------------------
  chStarBams = starAlign.out.bam
    .map{meta, bam ->
       def newMeta = [ id: meta.id, name: meta.name, protocol: meta.protocol, totchunk:meta.totchunk]
       [ newMeta, bam ]
     }.groupTuple()

  samtoolsMergeStar(
    chStarBams
  )
  chStarBam = samtoolsMergeStar.out.bam
  chVersions = chVersions.mix(samtoolsMergeStar.out.versions)

  preseq(
    samtoolsMergeStar.out.bam
  )
  chPreseq = preseq.out.curves
  chVersions = chVersions.mix(preseq.out.versions)

  //-----------RSeqC------------------------------
  if (!params.skipGeneCov){

    samtoolsSortNoUmis(
      chNoUmiFilt
    )
    chVersions = chVersions.mix( samtoolsSortUmis.out.versions)

    rseqcGeneBodyCoverage(
      samtoolsSortNoUmis.out.bam.concat(chUmiFilt), 
      chBed12 
    )
    chRseqcGeneCov=rseqcGeneBodyCoverage.out.results
  } else {
    chRseqcGeneCov=Channel.empty()
  }

  rseqcReadQuality(
    samtoolsMergeStar.out.bam
  )
  chRseqcReadQuality=rseqcReadQuality.out.results

  rseqcBamStat(
    samtoolsMergeStar.out.bam
  )
  chRseqcBamStat=rseqcBamStat.out.results

  rseqcInnerDistance(
    chFinalBamSorted,
    chBed12
  )
  chRseqcInnerDistance=rseqcInnerDistance.out.results

  rseqcReadDistribution(
    chFinalBamSorted,
    chBed12
  )
  chRseqcReadDist=rseqcReadDistribution.out.results

  rseqcJunctionAnnotation(
    chFinalBamSorted,
    chBed12
  )
  chRseqcJunctionAnnot=rseqcJunctionAnnotation.out.results

  rseqcJunctionSaturation(
    chFinalBamSorted,
    chBed12
  )
  chRseqcJunctionSat=rseqcJunctionSaturation.out.results

  //-----------Qualimap------------------------------
  qualimapRNAseq(
          chFinalBamSorted.join(chFinalBai),
          chGtf.collect()
        )
	chQualimapMqc = qualimapRNAseq.out.results.collect()
  chVersions = chVersions.mix(qualimapRNAseq.out.versions)


  //-----------MultiQC------------------------------
  if (!params.skipMultiQC){
    chGetSoftwareVersions = Channel.empty()
    if (!params.skipSoftVersions){
      getSoftwareVersions(
        chVersions.unique().collectFile()
      )
      chGetSoftwareVersions=getSoftwareVersions.out.versionsYaml
    }

    warnCh = Channel.empty()

    multiqc(
      customRunName,
      sPlanCh.collect(),
      metadataCh.ifEmpty([]),
      multiqcConfigCh.ifEmpty([]),
      chGetSoftwareVersions.collect().ifEmpty([]),
      workflowSummaryCh.collectFile(name: "workflow_summary_mqc.yaml"),
      warnCh.collect().ifEmpty([]),
      //modules
      chCutadaptLogs.collect().ifEmpty([]),
      chPreseq.collect().ifEmpty([]),
      chRseqcGeneCov.collect().ifEmpty([]),
      chRseqcBamStat.collect().ifEmpty([]),
      chRseqcInnerDistance.collect().ifEmpty([]),
      chRseqcJunctionAnnot.collect().ifEmpty([]),
      chRseqcJunctionSat.collect().ifEmpty([]),
      chQualimapMqc.ifEmpty([]),
      //chRseqcReadQuality.collect().ifEmpty([]), // not a module
      //chRseqcReadDist.collect().ifEmpty([]) // fait buguer
      //stat2mqc
      //chUmiExtractLogs.collect().ifEmpty([])

    )

    mqcReport = multiqc.out.report.toList()
  }

}

workflow.onComplete {
  NFTools.makeReports(workflow, params, summary, customRunName, mqcReport)
}
