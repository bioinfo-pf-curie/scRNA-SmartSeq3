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
chChunkSize     = params.chunkSize     ? Channel.value(params.chunkSize)                                    : Channel.value([])
chSampleDescitpion = params.sampleDescription  ? Channel.fromPath(params.sampleDescription, checkIfExists: true).collect()    : Channel.value([])

/*
===========================
   SUMMARY
===========================
*/

def branch = null
def commit = null
try {
    branch = "git rev-parse --abbrev-ref HEAD".execute().text.trim()
    commit = "git rev-parse HEAD".execute().text.trim()
} catch (ignored) {}

summary = [
  'Pipeline' : workflow.manifest.name ?: null,
  'Version': workflow.manifest.version ?: null,
  'DOI': workflow.manifest.doi ?: null,
  'Run Name': customRunName,
  'Inputs' : params.samplePlan ?: params.reads ?: null,
  'Genome' : params.genome,
  'Remove singleton' : params.rmSingleton ,
  'Remove Duplicates' : params.keepDups ,
  'Max Resources': "${params.maxMemory} memory, ${params.maxCpus} cpus, ${params.maxTime} time per job",
  'Container': workflow.containerEngine && workflow.container ? "${workflow.containerEngine} - ${workflow.container}" : null,
  'Profile' : workflow.profile,
  'Date Started': workflow.start,
  'OutDir' : params.outDir,
  'WorkDir': workflow.workDir,
  'CommandLine': workflow.commandLine,
  'Pipeline Git URL': workflow.repository ?: null,
  'Pipeline Git Commit': commit ?: '@git_commit@',
  'Pipeline Git branch': branch ?: null,
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
include { createBatchFlow } from './modules/common/subworkflow/createBatchFlow'
include { markdupFlow } from './modules/common/subworkflow/markdupFlow'

// Process
include { getSoftwareVersions } from './modules/common/process/utils/getSoftwareVersions'
include { outputDocumentation } from './modules/common/process/utils/outputDocumentation'
include { umitoolsExtract } from './modules/common/process/umitools/umitoolsExtract'
//include { seqkitSeq } from './modules/common/process/seqkit/seqkitSeq'
include { concatFastq } from './modules/common/process/concatFastq/concatFastq'
include { cutadapt } from './modules/common/process/cutadapt/cutadapt'
include { starAlign } from './modules/common/process/star/starAlign'

include { barcode2tag as bc2tag} from './modules/local/process/barcode2tag'
include { barcode2tag as umi2tag} from './modules/local/process/barcode2tag'

include { barcodeListPerBatch} from './modules/local/process/barcodeListPerBatch'
//include { nbCells} from './modules/local/process/nbCells'
include { seqkitFx2tab} from './modules/local/process/seqkitFx2tab'
include {calculMT}  from './modules/local/process/calculMT'

include { samtoolsMerge as samtoolsMergeChunk } from './modules/common/process/samtools/samtoolsMerge'
include { samtoolsMerge as samtoolsMergeFinal } from './modules/common/process/samtools/samtoolsMerge'

//include { samtoolsStats } from './modules/common/process/samtools/samtoolsStats'
include { samtoolsFilter as filterUnaligned } from './modules/common/process/samtools/samtoolsFilter'
include { samtoolsFilter as filterMarkdup } from './modules/common/process/samtools/samtoolsFilter'

include { samtoolsIndex as samtoolsIndexUmiAligned } from './modules/common/process/samtools/samtoolsIndex'
include { samtoolsIndex as samtoolsIndexAllAligned } from './modules/common/process/samtools/samtoolsIndex'
include { samtoolsIndex as samtoolsIndexMarkdup } from './modules/common/process/samtools/samtoolsIndex'
include { samtoolsIndex as samtoolsIndexUmis} from './modules/common/process/samtools/samtoolsIndex'
include { samtoolsIndex as samtoolsIndexAllFinal} from './modules/common/process/samtools/samtoolsIndex'

include { samtoolsSort as samtoolsSortAllStar} from './modules/common/process/samtools/samtoolsSort'
include { samtoolsSort as samtoolsSortUmis} from './modules/common/process/samtools/samtoolsSort'
include { samtoolsSort as samtoolsSortAll} from './modules/common/process/samtools/samtoolsSort'

include { extractUmiReads } from './modules/local/process/extractUmiReads'

//include { umitoolsGroup} from './modules/common/process/umitools/umitoolsGroup'
include { umitoolsCount} from './modules/common/process/umitools/umitoolsCount'
include { umitoolsDedup } from './modules/common/process/umitools/umitoolsDedup'
include { featureCountsMatrix} from './modules/local/process/featureCountsMatrix'

include { featureCounts as featureCountsUmis} from './modules/common/process/featureCounts/featureCounts'
include { featureCounts as featureCountsAll} from './modules/common/process/featureCounts/featureCounts'
include { samtoolsFilter as filterAllUnassigned } from './modules/common/process/samtools/samtoolsFilter'
include { like10xMatrix as like10xMatrixUmis } from './modules/local/process/like10xMatrix'
include { like10xMatrix as like10xMatrixAll } from './modules/local/process/like10xMatrix'

// multiqc modules
//include { preseq } from './modules/common/process/preseq/preseq'
//include { rseqcReadQuality } from './modules/common/process/rseqc/rseqcReadQuality'
include { rseqcBamStat } from './modules/common/process/rseqc/rseqcBamStat'
include { rseqcInnerDistance } from './modules/common/process/rseqc/rseqcInnerDistance'
//include { rseqcReadDistribution } from './modules/common/process/rseqc/rseqcReadDistribution'
include { rseqcJunctionAnnotation } from './modules/common/process/rseqc/rseqcJunctionAnnotation'
include { rseqcJunctionSaturation } from './modules/common/process/rseqc/rseqcJunctionSaturation'
include { qualimapRNAseq } from './modules/common/process/qualimap/qualimapRNAseq'
include { fastqc } from './modules/common/process/fastqc/fastqc'

include { multiqc } from './modules/local/process/multiqc'
include {checkStarLog} from './lib/functions'
include { saturationCurve } from './modules/local/process/saturationCurve'

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
  createBatchFlow(
    chRawReads,
    chChunkSize,
    chSampleDescitpion
  )
  chTaggedReads = createBatchFlow.out.reads
  chVersions = createBatchFlow.out.versions

  seqkitFx2tab(
    chTaggedReads
  )
  chFastqNbCells=seqkitFx2tab.out.count
  chVersions = chVersions.mix(seqkitFx2tab.out.versions)

  //********************************************************
  // Extract UMIs info 

  // extract UMIs in forward reads (R1)
  umitoolsExtract(
    chTaggedReads
  )
  chUmi=umitoolsExtract.out.fastq
  chNoUmi = umitoolsExtract.out.noumi
  chUmiExtractLogs=umitoolsExtract.out.log
  ChVersionsCh = chVersions.mix(umitoolsExtract.out.versions)

  // Reconcatenate umi and no umis fastqs (R1umi + R1noumis et R2umi + R2noumis)
  chUmiAndNoUmi = chUmi
    .join(chNoUmi)
    .map{meta,umi,noumi -> [meta, [umi[0], umi[1], noumi[0], noumi[1]]]}

  // concatenate R1 together and R2 together 
  concatFastq(
    chUmiAndNoUmi, 
    Channel.value(2)
  )
  chConcat = concatFastq.out.reads 
  chVersions = chVersions.mix(concatFastq.out.versions)

  //********************************************************
  // trim polyA/T linker 
  cutadapt(
    chConcat
  )
  chCutadaptLogs=cutadapt.out.logs
  chVersions = chVersions.mix(cutadapt.out.versions)

  //********************************************************
  // Sequence alignement of all reads
  starAlign(
    cutadapt.out.fastq,
    chStarIndex,
    chGtf
  )
  chVersions = chVersions.mix(starAlign.out.versions)

  // Filter removes all 'aligned' channels that fail the check
  starAlign.out.finallog.join(starAlign.out.bam)
    .filter { meta, logs, bam -> checkStarLog(meta, logs, params.minStarReads) }
    .map { meta, logs, bam -> [ meta, bam ] }
    .set { chBams }

  //-------- Add barcodes as read tag
  barcodeListPerBatch(
    chBams
  )
  
  bc2tag(
    chBams.join(barcodeListPerBatch.out.barcodes)
  )
  chVersions = chVersions.mix(bc2tag.out.versions)
  //-----

  // info meta.chunk is deleted to merge all chunks
  if (params.generateBatch == true && params.sampleDescription!=null){
    // if several chunks within a batch 
    chTaggedBams = bc2tag.out.bam
      .map{meta, bam ->
        def newMeta = [ id: "${meta.id}_${meta.batch}", name: meta.name, protocol: meta.protocol, totchunk:meta.totchunk, batch:meta.batch]
        [ newMeta, bam ]
      }.groupTuple()
      .branch {
        single: it[0].totchunk == null
        multiple: it[0].totchunk != null
      }
  }else{
    // 1 batch==1 id per row in the SP
    chTaggedBams = bc2tag.out.bam
      .map{meta, bam ->
        def newMeta = [ id: meta.id, name: meta.name, protocol: meta.protocol, totchunk:meta.totchunk]
        [ newMeta, bam ]
      }.groupTuple()
      .branch {
        single: it[0].totchunk <= 1 
        multiple: it[0].totchunk > 1
      }
  }

  samtoolsMergeChunk(
    chTaggedBams.multiple
  )
  chBams = samtoolsMergeChunk.out.bam.mix(chTaggedBams.single)

  filterUnaligned(
    chBams
  )
  chVersions = chVersions.mix(filterUnaligned.out.versions)

  //********************************************************
  // UMI reads
  extractUmiReads(
    filterUnaligned.out.bam
  )
  chExtractUmiReads=extractUmiReads.out.bam

  samtoolsIndexUmiAligned(
    chExtractUmiReads
  )

  featureCountsUmis( 
    chExtractUmiReads.join(samtoolsIndexUmiAligned.out.bai).combine(chGtf)
  )
  chVersions = chVersions.mix(featureCountsUmis.out.versions)

  samtoolsSortUmis(
    featureCountsUmis.out.bam
  )

  umi2tag(
    samtoolsSortUmis.out.bam.map{meta, bam -> [meta, bam, []]}
  )
  umiInTags=umi2tag.out.bam

  samtoolsIndexUmis(
    umiInTags
  )

  /*umitoolsGroup(
    samtoolsSortUmis.out.bam.join(samtoolsIndexUmis.out.bai)
  )
  umiInTags=umitoolsGroup.out.bam
  umitoolsGroupLogs=umitoolsGroup.out.log*/

  // generate matrix
  umitoolsCount(
    umiInTags.join(samtoolsIndexUmis.out.bai)
  )
  matrixUmis=umitoolsCount.out.matrix
  chVersions = chVersions.mix(umitoolsCount.out.versions)

  like10xMatrixUmis(
    matrixUmis.map{it->[it[1]]}.collect(),
    Channel.value("umis")
  )
  chVersions = chVersions.mix(like10xMatrixUmis.out.versions)

  // generate dedup bam
  umitoolsDedup(
    umiInTags.join(samtoolsIndexUmis.out.bai)
  )
  chFinalBamUmi=umitoolsDedup.out.bam
  chVersions = chVersions.mix(umitoolsDedup.out.versions)

  // umitools counts = umi + gene unique 
  // umitools dedup = umi + start + end SAUF si option --per-gene

  //********************************************************
  // All reads

  samtoolsIndexAllAligned(
    filterUnaligned.out.bam
  )

  // Mark duplicated reads
  markdupFlow(
    filterUnaligned.out.bam.join(samtoolsIndexAllAligned.out.bai)
  )

  // Filter out pcr duplicates
  filterMarkdup(
    markdupFlow.out.bam
  )
                                                                                                                                                                                
  samtoolsIndexMarkdup(
    filterMarkdup.out.bam
  )

  // Assign 
  featureCountsAll( // IF gene_name exists in gtf !!!! add if not -> gene_id
    filterMarkdup.out.bam.join(samtoolsIndexMarkdup.out.bai).combine(chGtf)
  )
  chVersions = chVersions.mix(featureCountsAll.out.versions)

  // Matrix all umis
  featureCountsMatrix(
    featureCountsAll.out.counts.join(filterMarkdup.out.bam)
  )
  matrixAll=featureCountsMatrix.out.matrix

  like10xMatrixAll(
    matrixAll.map{it->[it[1]]}.collect(),
    Channel.value("reads")
  )
  chVersions = chVersions.mix(like10xMatrixAll.out.versions)

  filterAllUnassigned(
    featureCountsAll.out.bam
  )
  chFinalBamAll=filterAllUnassigned.out.bam

  samtoolsSortAll(
      chFinalBamAll
  )
  chFinalSortedBamAll=samtoolsSortAll.out.bam

  //*******************************************
  // MULTIQC
  //*******************************************

  //subroutines
  outputDocumentation(
    outputDocsCh,
    outputDocsImagesCh
  )

  //-----------%MT genes---------------------------

  if (params.genome in ["hg38", "hg19", "mm10", "mm9"]){
    calculMT(
      matrixAll.map{it->[it[1]]}.collect()
    )
    chMt=calculMT.out.results
  } else {
    chMt=Channel.empty()
  }

  saturationCurve(
      matrixAll.map{it->[it[1]]}.collect(),
      chConcat.map{it->[it[1][0]]}.collect()
  )
  chSaturationCurve=saturationCurve.out.results

  //-----------FastQC------------------------------
  fastqc(
    cutadapt.out.fastq
  )
  chFastqc=fastqc.out.results
  chVersions = chVersions.mix(fastqc.out.versions)

  //-----------preseq------------------------------
  //  ne marche plus
  /*if (!params.skipSatCurvePlot){
    samtoolsSortAllStar(
      chBams
    )

    preseq(
      samtoolsSortAllStar.out.bam
    )
    chPreseq = preseq.out.curves
    chVersions = chVersions.mix(preseq.out.versions)
  }else {
    chPreseq=Channel.empty()
  }*/

  //-----------RSeqC------------------------------

  rseqcBamStat(
    chBams
  )
  chRseqcBamStat=rseqcBamStat.out.results

  rseqcInnerDistance(
    chFinalSortedBamAll,
    chBed12
  )
  chRseqcInnerDistance=rseqcInnerDistance.out.results

  rseqcJunctionAnnotation(
    chFinalSortedBamAll,
    chBed12
  )
  chRseqcJunctionAnnot=rseqcJunctionAnnotation.out.results

  rseqcJunctionSaturation(
    chFinalSortedBamAll,
    chBed12
  )
  chRseqcJunctionSat=rseqcJunctionSaturation.out.results

  //-----------Qualimap------------------------------

  samtoolsIndexAllFinal(
    chFinalSortedBamAll
  )
  
  qualimapRNAseq(
    chFinalSortedBamAll.join(samtoolsIndexAllFinal.out.bai),
    chGtf.collect()
  )
	chQualimapMqc = qualimapRNAseq.out.results.collect()
  chVersions = chVersions.mix(qualimapRNAseq.out.versions)


  //-----------MultiQC------------------------------
  if (!params.skipMultiQC){

    getSoftwareVersions(
      chVersions.unique().collectFile()
    )
    chGetSoftwareVersions=getSoftwareVersions.out.versionsYaml

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
      //chPreseq.collect().ifEmpty([]),
      //chRseqcBamStat.collect().ifEmpty([]),
      chRseqcInnerDistance.collect().ifEmpty([]),
      chRseqcJunctionAnnot.collect().ifEmpty([]),
      chRseqcJunctionSat.collect().ifEmpty([]),
      chQualimapMqc.ifEmpty([]),
      //chRseqcReadQuality.collect().ifEmpty([]), // not a module
      //chRseqcReadDist.collect().ifEmpty([]), // fait buguer
      //stat2mqc
      chUmiExtractLogs.map{it->[it[1]]}.collect().ifEmpty([]),
      umitoolsDedup.out.log.map{it->[it[1]]}.collect().ifEmpty([]),
      chFastqNbCells.map{it->[it[1]]}.collect().ifEmpty([]), // Nb cells 
      starAlign.out.logs.collect().ifEmpty([]),
      chFastqc.collect().ifEmpty([]),
      chMt,
      chSaturationCurve,
      featureCountsAll.out.summary.collect(),
      featureCountsAll.out.log.collect(),
      featureCountsUmis.out.summary.collect(),
      featureCountsUmis.out.log.collect(),
      matrixUmis.map{it->[it[1]]}.collect().ifEmpty([]),
      matrixAll.map{it->[it[1]]}.collect().ifEmpty([]),
      barcodeListPerBatch.out.barcodes.map{it->[it[1]]}.collect().ifEmpty([])
    )

    mqcReport = multiqc.out.report.toList()
  }

}

workflow.onComplete {
  NFTools.makeReports(workflow, params, summary, customRunName, mqcReport)
}
