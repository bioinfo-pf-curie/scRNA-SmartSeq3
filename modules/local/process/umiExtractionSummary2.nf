
// one line = one batch
grep "Input Reads:" results/preprocessing/umitoolsExtract/fastq_chunk*R1* | awk '{print $6}' >> totFragChunk
grep "Reads output: " results/preprocessing/umitoolsExtract/fastq_chunk* | awk '{print $6}' >> nbumireads

