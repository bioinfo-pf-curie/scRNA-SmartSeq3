process calculMT {
  label 'onlyLinux'
  label 'lowCpu'
  label 'medMem'

  input:
  path(matrix)

  output:
  path("percent_mt.txt"), emit: results

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

    for matrix in *gz; do 

        gzip -cd \$matrix > mat

        # Get total des reads par colonne
        total=\$(awk 'NR>1 {for (i=2;i<=NF;i++) sum[i]+=\$i} END {for (i=2;i<=NF;i++) print sum[i]}' mat)

        samples=\$(awk 'NR==1 {for (i=2; i<=NF; i++) print \$i}' mat)

        # Get des reads mitochondriaux
        mt=\$(awk -v prefix="\$gene_prefix" 'NR>1 && \$1 ~ prefix {for (i=2;i<=NF;i++) sum[i]+=\$i} END {for (i=2;i<=NF;i++) print sum[i]}' mat)

        # Get pourcentage
        percent=\$(paste <(echo "\$mt") <(echo "\$total") | awk '{ 
        if (\$2 > 0) 
            print (\$1 / \$2) * 100; 
        else 
            print "0.0" 
        }')

        paste <(echo "\$samples") <(echo "\$total") <(echo "\$percent") -d, >> percent_mt.txt
    done
  """
}




