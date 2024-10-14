include { samtoolsMarkdup } from './nf-modules/common/process/samtools/samtoolsMarkdup'
include { samtoolsFlagstat as markdupStat } from './nf-modules/common/process/samtools/samtoolsFlagstat'
include { samtoolsFixmate } from './nf-modules/common/process/samtools/samtoolsFixmate'

workflow createBatchesFlow {

  take:
  bam

  main:
  chVersions = Channel.empty()

  samtoolsFixmate(
    
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
  samtoolsFlagstat(
    samtoolsMarkdup.out.bam
  )
  chVersions = chVersions.mix(samtoolsFlagstat.out.versions)

  emit:
  versions = chVersions 
  bam = samtoolsMarkdup.out.bam
  logs = samtoolsMarkdup.out.logs
  stats = samtoolsFlagstat.out.stats

}