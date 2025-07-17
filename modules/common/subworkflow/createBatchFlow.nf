include { seqkitReplace } from '../../local/process/seqkitReplace'
include { createBatches } from '../../local/process/createBatches'
include { createChunk } from '../../local/process/createChunk'

// Create batches of paired-end data
def splitByPairsAndChunk(row){
  def map = []
  int chunk_nb = 1
  int totchunk = row[1].size()/2
  for (i=0; i<row[1].size(); i+=2) { 
    meta = row[0].clone()
    meta.chunk = chunk_nb
    meta.totchunk = totchunk
    r1 = row[1][i]
    r2 = row[1][i+1]
    map += [meta, [r1,r2]]
    chunk_nb+=1
  }
  return map
}

def splitByPairs(row){
  def map = []
  for (i=0; i<row[1].size(); i+=2) { 
    meta = row[0].clone()
    r1 = row[1][i]
    r2 = row[1][i+1]
    map += [meta, [r1,r2]]
  }
  return map
}

workflow createBatchFlow{

  take:
  reads
  chunkSize
  sampleDescitpion

  main:
  chVersions = Channel.empty()

  seqkitReplace(
    reads,
    sampleDescitpion
  )
  chVersions = chVersions.mix(seqkitReplace.out.versions)

  if ( params.generateBatch == true && params.sampleDescription != null){
    createBatches(
      seqkitReplace.out.reads,
      sampleDescitpion
    )

    chPairedFastq = createBatches.out.reads
      .flatMap { it -> splitByPairs(it) }
      .collate(2)
      .map { meta, fastqs ->
        def batchName = (fastqs[0] =~ /batch(.*?)\.R1/)[0][1]  // Extrait le mot entre "batch" et .R1
        meta.put('batch', batchName)  // Ajoute le champ 'batch' avec la valeur extraite
        return [meta, fastqs]  // Retourne le meta modifié et les fichiers
    }

  }else{
    createChunk(
      seqkitReplace.out.reads,
      chunkSize
    )

    // group by read pairs
    chPairedFastq = createChunk.out.reads
      .flatMap { it -> splitByPairsAndChunk(it) }
      .collate(2)    
  }


  emit:
  versions = chVersions 
  reads = chPairedFastq
}