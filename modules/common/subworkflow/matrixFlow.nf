include { samtoolsIndex as indexForFeatureCounts} from '../process/samtools/samtoolsIndex'
include { featureCounts } from '../process/featureCounts/featureCounts'
include { samtoolsSort } from '../process/samtools/samtoolsSort'
include { samtoolsIndex as indexForUmitools} from '../process/samtools/samtoolsIndex'
include { umitoolsCount } from '../process/umitools/umitoolsCount'


workflow matrixFlow {

  take:
  bam

  main:
  chVersions = Channel.empty()

  indexForFeatureCounts(
    bam
  )
  chVersions = chVersions.mix(indexForFeatureCounts.out.versions)

  featureCounts(
    bam.join(indexForFeatureCounts.out.bai)
  )
  chVersions = chVersions.mix(featureCounts.out.versions)

  samtoolsSort(
    featureCounts.out.bam
  )
  chVersions = chVersions.mix(samtoolsSort.out.versions)

  indexForUmitools(
    samtoolsSort.out.bam
  )
  chVersions = chVersions.mix(indexForUmitools.out.versions)

  // Stats on mapped reads including duplicates
  umitoolsCount(
    samtoolsSort.out.bam.join(indexForUmitools.out.bai)
  )
  chVersions = chVersions.mix(umitoolsCount.out.versions)

  emit:
  versions = chVersions 
  bam = samtoolsSort.out.bam
  logs_FC = featureCounts.out.logs
  logs_umitools = umitoolsCount.out.logs
  matrix = umitoolsCount.out.matrix

}