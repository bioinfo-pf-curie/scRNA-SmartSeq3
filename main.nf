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
SmartSeq3
========================================================================================
#### Homepage / Documentation
https://gitlab.curie.fr/sc-platform/smartseq3
----------------------------------------------------------------------------------------
*/

// File with text to display when a developement version is used
devMessageFile = file("$baseDir/assets/devMessage.txt")

def helpMessage() {
  if ("${workflow.manifest.version}" =~ /dev/ ){
    devMess = file("$baseDir/assets/devMessage.txt")
    log.info devMessageFile.text
  }

  log.info """
  SmartSeq3 v${workflow.manifest.version}
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
    --starIndex [dir]             Index for STAR aligner
    --singleEnd [bool]            Specifies that the input is single-end reads

  Skip options: All are false by default
    --skipSoftVersion [bool]      Do not report software version
    --skipMultiQC [bool]          Skips MultiQC
    --skipGeneCov [bool]          Skips calculating genebody coverage
  
  Genomes: If not specified in the configuration file or if you wish to overwrite any of the references given by the --genome field
  --genomeAnnotationPath [file]      Path  to genome annotation folder

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

// Configurable reference genomes
genomeRef = params.genome

params.starIndex = genomeRef ? params.genomes[ genomeRef ].starIndex ?: false : false
if (params.starIndex){
  Channel
    .fromPath(params.starIndex, checkIfExists: true)
    .ifEmpty {exit 1, "STAR index file not found: ${params.starIndex}"}
    .set { chStar }
} else {
  exit 1, "STAR index file not found: ${params.starIndex}"
}

params.gtf = genomeRef ? params.genomes[ genomeRef ].gtf ?: false : false
if (params.gtf) {
  Channel
    .fromPath(params.gtf, checkIfExists: true)
    .into { chGtfSTAR; chGtfFC }
}else {
  exit 1, "GTF annotation file not not found: ${params.gtf}"
}

params.bed12 = genomeRef ? params.genomes[ genomeRef ].bed12 ?: false : false
if (params.bed12) {
  Channel  
    .fromPath(params.bed12)
    .ifEmpty { exit 1, "BED12 annotation file not found: ${params.bed12}" }
    .set { chBedGeneCov } 
}else {
  exit 1, "GTF annotation file not not found: ${params.bed12}"
}

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
summary['Pipeline Name']  = 'SmartSeq3'
summary['Pipeline Version'] = workflow.manifest.version
summary['Run Name']     = customRunName ?: workflow.runName
summary['Command Line'] = workflow.commandLine
if (params.samplePlan) {
   summary['SamplePlan']   = params.samplePlan
}else{
   summary['Reads']        = params.reads
}
summary['Genome']       = params.genome
summary['Annotation']   = params.genomeAnnotationPath
summary['Max Memory']     = params.maxMemory
summary['Max CPUs']       = params.maxCpus
summary['Max Time']       = params.maxTime
summary['Current home']   = "$HOME"
summary['Current user']   = "$USER"
summary['Current path']   = "$PWD"
summary['Working dir']    = workflow.workDir
summary['Output dir']     = params.outDir
summary['Config Profile'] = workflow.profile
log.info summary.collect { k,v -> "${k.padRight(15)}: $v" }.join("\n")
log.info "========================================="


/*
 * Reads Mapping
 */

process getTaggedSeq{
  tag "${prefix}"
  label 'seqkit'
  label 'medCpu'
  label 'medMem'

  publishDir "${params.outDir}/getTaggedSeq", mode: 'copy'

  input: 
  set val(prefix), file(reads) from rawReadsFastqc

  output:
  set val(prefix), file("*_tagged.R1.fastq"), file("*_tagged.R2.fastq") into chTaggedFastq
  set val(prefix), file("*_taggedReadIDs.txt") into chTaggedIDs

  script:
  """
  # 1st: get tags in R1 == umi sequences
  # 2nd: get left reads
  # 3rd: get tags in R2 of lefted reads 
  # 4thy: merge 1st and 3rd fastqs 

  getTaggedSeq.sh ${reads[0]} ${reads[1]} ${prefix}_tagged_inR1.R1.fastq ${prefix}_taggedReadIDs_inR1.txt ${prefix}_tagged_inR1.R2.fastq
  seqkit grep -v -f ${prefix}_taggedReadIDs_inR1.txt ${reads[1]} -o ${prefix}_rest.R2.fastq
  getTaggedSeq.sh ${prefix}_rest.R2.fastq ${reads[0]} ${prefix}_tagged_inR2.R2.fastq ${prefix}_taggedReadIDs_inR2.txt ${prefix}_tagged_inR2.R1.fastq

  # 4th: Merge all files 
  cat ${prefix}_taggedReadIDs_inR1.txt > ${prefix}_taggedReadIDs.txt
  cat ${prefix}_taggedReadIDs_inR2.txt >> ${prefix}_taggedReadIDs.txt
  cat ${prefix}_tagged_inR1.R1.fastq > ${prefix}_tagged.R1.fastq
  cat ${prefix}_tagged_inR2.R1.fastq >> ${prefix}_tagged.R1.fastq
  cat ${prefix}_tagged_inR1.R2.fastq > ${prefix}_tagged.R2.fastq
  cat ${prefix}_tagged_inR2.R2.fastq >> ${prefix}_tagged.R2.fastq
  """
}

process umiExtraction {
  tag "${prefix}"
  label 'umiTools'
  label 'highCpu'
  label 'highMem'

  publishDir "${params.outDir}/umiExtraction", mode: 'copy'

  input: 
  set val(prefix), file(taggedR1), file(taggedR2) from chTaggedFastq

  output:
  set val(prefix), file("*_UMIsExtracted.R1.fastq"), file("*_UMIsExtracted.R2.fastq") into chUmiExtracted
  set val(prefix), file("*_umiExtract.log") into chUmiExtractedLog
  file("v_umi_tools.txt") into chUmiToolsVersion

  script:
  """
  # Extract sequences that have tag+UMI+GGG and add UMI to read names (NB: other sequences are deleted)
  # following command bugs cause write incorrect ids for R2 output (write 1:N:0 and not 2:N:0)
  umi_tools extract --either-read --extract-method=regex \\
                    --bc-pattern='(?P<discard_1>.*ATTGCGCAATG)(?P<umi_1>.{$params.umi_size})(?P<discard_2>GGG).*' \\
                    --bc-pattern2='(?P<discard_1>.*ATTGCGCAATG)(?P<umi_1>.{$params.umi_size})(?P<discard_2>GGG).*' \\
                    --stdin=${taggedR1} --stdout=${prefix}_UMIsExtracted.R1.fastq \\
                    --read2-in=${taggedR2} --read2-out=${prefix}_UMIsExtracted_falseIds.R2.fastq \\
                    --log=${prefix}_umiExtract.log 
  # correct bug
  sed 's/1:N:0:/2:N:0/g' ${prefix}_UMIsExtracted_falseIds.R2.fastq > ${prefix}_UMIsExtracted.R2.fastq
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
  set val(prefix), file(reads), file(umiReads_R1), file(umiReads_R2), file(taggedReadIDs) from chMergeReadsFastq.join(chUmiExtracted).join(chTaggedIDs)

  output:
  set val(prefix), file("*_totReads.R1.fastq"), file("*_totReads.R2.fastq") into chMergeReads
  set val(prefix), file("*_umisReadsIDs.txt") into chUmiReadsIDs
  set val(prefix), file("*_pUMIs.txt") into chCountSummaryExtUMI
  set val(prefix), file("*_totReads.txt") into chTotReads
  file("v_seqkit.txt") into chSeqkitVersion

  script:
  """
  # Get UMI read IDs (with UMIs in names for separateReads process)
  seqkit seq -n -i ${umiReads_R1}  > ${prefix}_umisReadsIDs.txt

  # Extract non UMI reads
  seqkit grep -v -f ${taggedReadIDs} ${reads[0]} -o ${prefix}_nonUMIs.R1.fastq
  seqkit grep -v -f ${taggedReadIDs} ${reads[1]} -o ${prefix}_nonUMIs.R2.fastq

  # Merge non umis reads + correct umi reads (with umi sequence in read names) (reads without the exact pattern: tag+UMI+GGG are through out)
  cat ${umiReads_R1} > ${prefix}_totReads.R1.fastq
  cat ${prefix}_nonUMIs.R1.fastq >> ${prefix}_totReads.R1.fastq

  cat ${umiReads_R2} > ${prefix}_totReads.R2.fastq
  cat ${prefix}_nonUMIs.R2.fastq >> ${prefix}_totReads.R2.fastq

  ## Save % of correct UMIs reads (do not take into account all tagged sequences but only tag+UMI+GGG)
  nb_lines=`wc -l < <(gzip -cd ${reads[0]})`
  nb_totreads=\$(( \$nb_lines / 4 ))
  nb_umis=`wc -l < ${prefix}_umisReadsIDs.txt`
  echo "percentUMI:\$(( \$nb_umis * 100 / \$nb_totreads ))" > ${prefix}_pUMIs.txt
  echo "totReads: \$nb_totreads" > ${prefix}_totReads.txt
  seqkit --help | grep Version > v_seqkit.txt
  """
}

process trimReads{
  tag "${prefix}"
  label 'cutadapt'
  label 'medCpu'
  label 'medMem'

  publishDir "${params.outDir}/trimReads", mode: 'copy'

  input:
  set val(prefix), file(totReadsR1), file(totReadsR2) from chMergeReads

  output:
  set val(prefix), file("*_trimmed.R1.fastq"), file("*_trimmed.R2.fastq") into chTrimmedReads
  set val(prefix), file("*_trimmed.log") into chtrimmedReadsLog
  file("v_cutadapt.txt") into chCutadaptVersion

  script:
  """
  # delete linker + polyA queue
  cutadapt -G GCATACGAT{30} --minimum-length=15 --cores=0 -o ${prefix}_trimmed.R1.fastq -p ${prefix}_trimmed.R2.fastq ${totReadsR1} ${totReadsR2} > ${prefix}_trimmed.log
  cutadapt --version &> v_cutadapt.txt
  """
}

process readAlignment {
  tag "${prefix}"
  label 'star'
  label 'extraCpu'
  label 'extraMem'

  publishDir "${params.outDir}/readAlignment", mode: 'copy'

  input :
  file genomeIndex from chStar.collect()
  file genomeGtf from chGtfSTAR.collect()
  set val(prefix), file(trimmedR1) , file(trimmedR2) from chTrimmedReads
	
  output :
  set val(prefix), file("*Aligned.sortedByCoord.out.bam") into chAlignedBam
  file "*.out" into chAlignmentLogs
  file("v_star.txt") into chStarVersion

  script:  
  """
  STAR \
    --genomeDir $genomeIndex \
    --readFilesIn ${trimmedR1} ${trimmedR2} \
    --runThreadN ${task.cpus} \
    --outFilterMultimapNmax 1 \
    --outFileNamePrefix ${prefix} \
    --outSAMtype BAM SortedByCoordinate \
    --clip3pAdapterSeq CTGTCTCTTATACACATCT \
    --limitSjdbInsertNsj 2000000 \
    --sjdbGTFfile $genomeGtf --outFilterIntronMotifs RemoveNoncanonicalUnannotated 

    # outFilterMultimapNmax = max nb of loci the read is allowed to map to. If more, the read is concidered "map to too many loci". 
    # clip3pAdapterSeq = cut 3' remaining illumina adaptater (~1-2%) 
    # limitSjdbInsertNsj = max number of junctions to be insterted to the genome (those known (annotated) + those not annot. but found in many reads). 
    # Default is 1 000 000. By increasing it, more new junctions can be discovered. 
    # outFilterIntronMotifs = delete non annotated (not in genomeGtf) + non-canonical junctions.
    # Non-canonical but annot. or canonical but not annot. will be kept.
    # NB: Canonical <=> juctions describe as having GT/AG, GC/AG or AT/AC (donor/acceptor) dinucleotide combination. 
    # Non-canonical are all other dinucleotide combinations. 

  STAR --version &> v_star.txt
  """
}

process readAssignment {
  tag "${prefix}"
  label 'featureCounts'
  label 'medCpu'
  label 'medMem'

  publishDir "${params.outDir}/readAssignment", mode: 'copy'

  input :
  set val(prefix), file(alignedBam) from chAlignedBam
  file(genome) from chGtfFC.collect()

  output : 
  set val(prefix), file("*featureCounts.bam") into chAssignBam
  file "*.summary" into chAssignmentLogs
  file("v_featurecounts.txt") into chFCversion

  script:
  """	
  featureCounts  -p \
    -a ${genome} \
    -o ${prefix}_counts \
    -T ${task.cpus} \
    -R BAM \
    -g gene_name \
    ${alignedBam}

  featureCounts -v &> v_featurecounts.txt
  """
}

process sortBam {
  tag "${prefix}"
  label 'samtools'
  label 'medCpu'
  label 'medMem'

  publishDir "${params.outDir}/sortBam", mode: 'copy'

  input:
  set val(prefix), file(assignBam) from chAssignBam
	
  output:
  set val(prefix), file("*_Sorted.bam") into chSortedBAM_bigWig, chSortedBAM_sepReads, chSortedBAM_readCounts
  file("v_samtools.txt") into chSamtoolsVersion

  script :
  """
  samtools sort -@ ${task.cpus} ${assignBam} -o ${prefix}_Sorted.bam

  samtools --version &> v_samtools.txt
  """
}

process separateReads {
  tag "${prefix}"
  label 'samtools'
  label 'medCpu'
  label 'medMem'

  publishDir "${params.outDir}/separateReads", mode: 'copy'

  input :
  set val(prefix), file(sortedBam), file(umisReadsIDs) from chSortedBAM_sepReads.join(chUmiReadsIDs)

  output:
  set val("${prefix}_umi"), file("*_assignedUMIs.bam") into chUmiBam, chUmiBam_countMtx
  set val("${prefix}_NonUmi"), file("*_assignedNonUMIs.bam") into chNonUmiBam

  script:  
  """
  # Separate umi and non umi reads
  samtools view ${sortedBam} > ${prefix}assignedAll.sam

  # save header and extract umi reads 
  samtools view -H ${sortedBam} > ${prefix}_assignedUMIs.sam
  fgrep -f ${umisReadsIDs} ${prefix}assignedAll.sam >> ${prefix}_assignedUMIs.sam
  # sam to bam
  samtools view -bh ${prefix}_assignedUMIs.sam > ${prefix}_assignedUMIs.bam

  # save header and extract non umi reads 
  samtools view -H ${sortedBam} > ${prefix}_assignedNonUMIs.sam
  # get reads that do not match umi read IDs
  fgrep -v -f ${umisReadsIDs} ${prefix}assignedAll.sam >> ${prefix}_assignedNonUMIs.sam
  # sam to bam
  samtools view -bh ${prefix}_assignedNonUMIs.sam > ${prefix}_assignedNonUMIs.bam
  """
}

process countMatrices {
  tag "${prefix}"
  label 'umiTools'
  label 'medCpu'
  label 'medMem'

  publishDir "${params.outDir}/countMatrices", mode: 'copy'

  input:
  set val(prefix), file(umiBam) from chUmiBam_countMtx

  output:
  set val(prefix), file("*_Counts.tsv.gz") into chMatrices, chMatrices_dist, chMatrices_counts
  set val(prefix), file("*_UmiCounts.log") into chMatricesLog

  script:
  """
  # Count UMIs per gene per cell
  samtools index ${umiBam}
  umi_tools count --method=cluster --per-gene --gene-tag=XT --assigned-status-tag=XS -I ${umiBam} -S ${prefix}_Counts.tsv.gz > ${prefix}_UmiCounts.log
  """
}

process bigWig {
  tag "${prefix}"
  label 'deeptools'
  label 'extraCpu'
  label 'extraMem'

  publishDir "${params.outDir}/bigWig", mode: 'copy'

  input:
  set val(prefix), file(bam) from chSortedBAM_bigWig

  output:
  set val(prefix), file("*_coverage.bw") into chBigWig 
  set val(prefix), file("*_coverage.log") into chBigWigLog
  file("v_deeptools.txt") into chBamCoverageVersion

  script:
  """
  ## Create bigWig files
  samtools index ${bam}
  bamCoverage --normalizeUsing CPM -b ${bam} -of bigwig -o ${prefix}_coverage.bw --numberOfProcessors=${task.cpus}  > ${prefix}_coverage.log
  bamCoverage --version &> v_deeptools.txt
  """
}

/*
 * Gene body Coverage
 */

process genebody_coverage {
  tag "${prefix}"
  label 'rseqc'
  label 'extraCpu'
  label 'extraMem'
  publishDir "${params.outDir}/genebody_coverage" , mode: 'copy',
  saveAs: {filename ->
      if (filename.indexOf("geneBodyCoverage.curves.pdf") > 0)       "geneBodyCoverage/$filename"
      else if (filename.indexOf("geneBodyCoverage.r") > 0)           "geneBodyCoverage/rscripts/$filename"
      else if (filename.indexOf("geneBodyCoverage.txt") > 0)         "geneBodyCoverage/data/$filename"
      else if (filename.indexOf("log.txt") > -1) false
      else filename
  }

  when:
  !params.skipGeneCov

  input:
  file bed12 from chBedGeneCov.collect()
  set val(prefix), file(bm) from chUmiBam.concat(chNonUmiBam) 

  output:
  file "*.{txt,pdf,r}" into chGeneCov_res
  file ("v_rseqc") into chRseqcVersion

  script:
  """
  samtools index ${bm}
  geneBody_coverage.py \\
      -i ${bm} \\
      -o ${prefix}.rseqc \\
      -r $bed12
  mv log.txt ${prefix}.rseqc.log.txt

  geneBody_coverage.py --version &> v_rseqc
  """
}

/*
 * Cell Viability
 */

process umiPerGeneDist{
  tag "${prefix}"
  label 'R'
  label 'lowCpu'
  label 'lowMem'

  publishDir "${params.outDir}/umiPerGeneDist", mode: 'copy'

  input:
  set val(prefix), file(matrix) from chMatrices_dist

  output:
  set val(prefix), file ("*_HistUMIperGene_mqc.csv") into chUMIperGene

  script:
  """
  # Get matrix one by one
  umiPerGene_dist.r ${matrix} ${prefix}
  """ 
}

// si MiSeq ~ 20 cells
process countUMIGenePerCell{
  tag "${prefix}"
  label 'R'
  label 'lowCpu'
  label 'lowMem'

  publishDir "${params.outDir}/countUMIGenePerCell", mode: 'copy'

  input:
  file(matrices) from chMatrices_counts.collect()

  output:
  file ("nbGenePerCell.csv") into chGenePerCell
  file ("nbUMIPerCell.csv") into chUmiPerCell

  script:
  """
  umiGenePerCell.r
  """ 
} 

// Si NovaSeq (~1500 cells): 1 histogram de distribution du nb d'umis par cell 
// == matrice de 2 columns, 1st avec nb cells, 2nd avec nb UMIs per cell
// TODO

process cellAnalysis{
  tag "${prefix}"
  label 'R'
  label 'highCpu'
  label 'highMem'

  publishDir "${params.outDir}/cellAnalysis", mode: 'copy'

  input:
  file (matrices) from chMatrices.collect()

  output:
  file ("10Xoutput/") into ch10X
  file ("resume.txt") into chResume
  file ("RatioPerCell.csv") into chUmiGeneRatio
  file ("MtGenePerCell.csv") into chMT
  file ("v_R.txt") into chRversion

  script:
  """
  cellViability.r 10Xoutput/
  R --version &> v_R.txt  
  """ 
}

/*
 * MultiQC 
 */

process getSoftwareVersions{
  label 'python'
  label 'lowCpu'
  label 'lowMem'
  publishDir path: "${params.outDir}/software_versions", mode: "copy"

  when:
  !params.skipSoftVersions

  input:
  file("v_umi_tools.txt") from chUmiToolsVersion.first().ifEmpty([])
  file("v_seqkit.txt") from chSeqkitVersion.first().ifEmpty([])
  file("v_cutadapt.txt") from chCutadaptVersion.first().ifEmpty([])
  file("v_star.txt") from chStarVersion.first().ifEmpty([])
  file("v_featurecounts.txt") from chFCversion.first().ifEmpty([])
  file("v_samtools.txt") from chSamtoolsVersion.first().ifEmpty([])
  file("v_deeptools.txt") from chBamCoverageVersion.first().ifEmpty([])
  file ("v_R.txt") from chRversion.ifEmpty([])
  file ("v_rseqc") from chRseqcVersion.ifEmpty([])

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
  label 'medCpu'
  label 'medMem'
  publishDir "${params.outDir}/MultiQC", mode: 'copy'

  when:
  !params.skipMultiQC

  input:
  file splan from chSplan.collect()
  file multiqcConfig from chMultiqcConfig
  file metadata from chMetadata.ifEmpty([])
  file ('software_versions/*') from softwareVersionsYaml.collect().ifEmpty([])
  file ('workflow_summary/*') from workflowSummaryYaml.collect()
  //Modules
  file ('trimming/*') from chtrimmedReadsLog.collect().ifEmpty([])
  file ('star/*') from chAlignmentLogs.collect().ifEmpty([])
  file ('FC/*') from chAssignmentLogs.collect().ifEmpty([])
  file ('coverage/*') from chGeneCov_res.collect().ifEmpty([])
  //LOGS
  file ('umiExtract/*') from chUmiExtractedLog.collect()
  file('pUMIs/*') from chCountSummaryExtUMI.collect()
  file('totReads/*') from chTotReads.collect()
  file ('bigwig/*') from chBigWigLog.collect()
  file (resume) from chResume // general stats 
  //PLOTS
  file ("umiPerGene/*") from chUMIperGene.collect() // linegraph == histogram
  file ("nbUMI/*") from chUmiPerCell.collect()  // bargraph
  file ("nbGene/*") from chGenePerCell.collect() // bargraph 
  file ("ratio/*") from chUmiGeneRatio.collect() // UmiGenePerCell_mqc.csv
  file ("mt/*") from chMT.collect() // MtGenePerCell_mqc.csv

  output: 
  file splan
  file "*report.html" into multiqc_report
  file "*_data"

  script:
  rtitle = customRunName ? "--title \"$customRunName\"" : ''
  rfilename = customRunName ? "--filename " + customRunName + "_report" : "--filename report"
  metadataOpts = params.metadata ? "--metadata ${metadata}" : ""
  modules_list = "-m custom_content -m cutadapt -m samtools -m star -m featureCounts -m deeptools  -m rseqc"

  """
  stat2mqc.sh ${splan} 
  #mean_calculation.r 
  mqc_header.py --splan ${splan} --name "SmartSeq3 scRNA-seq" --version ${workflow.manifest.version} ${metadataOpts} > multiqc-config-header.yaml
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

  publishDir "${params.outDir}/summary", mode: 'copy'

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
