process calculMT {
  label 'unix'
  label 'lowCpu'
  label 'medMem'
  tag "${meta.id}"

  input:
  path(matrix)

  output:
  path("*_percent_mt.txt"), emit: results

  script:
  """
    case "${params.genome}" in
    hg19|hg38)
        gene_prefix="^MT-"
        ;;
    mm9|mm10)
        gene_prefix="^mt-"
        ;;
    *)
        echo "Need : hg19, hg38, mm9 or mm10"
        exit 1
        ;;
    esac

    # Get total des reads par colonne
    total=$(awk 'NR>1 {for (i=2;i<=NF;i++) sum[i]+=\$i} END {for (i=2;i<=NF;i++) print sum[i]}' $matrix)

    samples=$(awk 'NR==1 {for (i=2; i<=NF; i++) print \$i}' $matrix)

    # Get des reads mitochondriaux
    mt=\$(awk -v prefix="\$gene_prefix" 'NR>1 && \$1 ~ prefix {for (i=2;i<=NF;i++) sum[i]+=\$i} END {for (i=2;i<=NF;i++) print sum[i]}' $matrix)

    # Get pourcentage
    percent=\$(paste <(echo "\$mt") <(echo "\$total") | awk '{ 
    if (\$2 > 0) 
        printf "%.1f\n", (\$1 / \$2) * 100; 
    else 
        print "0.00" 
    }')

    paste <(echo "\$samples") <(echo "\$total") <(echo "\$percent") -d, > percent_mt.txt
  """
}




