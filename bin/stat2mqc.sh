#!/bin/bash

function usage {
    echo -e "usage : stats2multiqc.sh -s SAMPLE_PLAN -p PROTOCOL [-th]"
    echo -e "Use option -h|--help for more information"
}

function help {
    usage;
    echo
    echo "stat2multiqc.sh"
    echo "---------------"
    echo "OPTIONS"
    echo
    echo "   -s SAMPLE_PLAN"
    echo "   -p PROTOCOL"
    echo "   [-t]: min reads per cell"
    echo "   [-h]: help"
    exit;
}

while getopts "s:p:m:S:b:h" OPT
do
    case $OPT in
        s) splan=$OPTARG;;
        p) protocol=$OPTARG;;
        m) minReads=$OPTARG;;
        S) sampleDes=$OPTARG;;
        b) generatebatch=$OPTARG;;
        h) help ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            usage
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            usage
            exit 1
            ;;
    esac
done

if  [[ -z $splan ]]; then
    usage
    exit
fi

if [[ "$generatebatch" == true && "$sampleDes" != "null" ]]; then
    all_samples=$(find  nbCells/*_initial_nb_barcodes.txt | cut -f2 -d"/" | sed 's/_initial_nb_barcodes.txt//')
else
    all_samples=$(awk -F, '{print $1}' $splan | sort | uniq )
fi

n_header=0

for sample in $all_samples
do                                                                                                                                                                                  
    ## sample name
    if [[ "$generatebatch" == true && "$sampleDes" != "null" ]]; then
        sname=$sample
    else
        sname=$(awk -F, -v sname=$sample '$1==sname{print $2}' $splan | uniq)
    fi
    header="Sample,Sample_id,Sample_name"
    output="${sample},${sample},${sname}"

    cells=0
    for chunk in nbCells/${sample}_*
    do
        cell_part=$(cat $chunk)
        cells=$(( $cells + $cell_part ))
    done
    header+=",Total_cells"
    output+=",${cells}"

    # umitools extract
    frag=0
    umi=0
    for chunk in umitools/${sample}_*umiExtract.log
    do
        frag_part=$(grep "Input Reads:" $chunk| awk '{print $NF}')
        frag=$(( $frag + $frag_part ))
        umi_part=$(grep "Reads output:" $chunk| awk '{print $NF}')
        if [ -z "$umi_part" ]; then
            umi_part=0
        fi
        umi=$(( $umi + $umi_part ))
    done
    mean_frag=$( echo $cells $frag | awk ' { printf "%.0f",$2/$1 }' )
    reads=$(echo "$frag" | awk ' { printf "%.0f",$1*2 } ')
    mean_reads=$( echo $cells $reads | awk ' { printf "%.0f",$2/$1 }' )
    mean_umi=$( echo $cells $umi | awk ' { printf "%.0f",$2/$1 }' )
    mean_percent_umi=$(echo "$mean_reads" "$mean_umi" | awk ' { printf "%.0f",$2/$1*100 } ')
    header+=",Number_of_frag,Number_of_reads,Number_umis,Percent_umis"
    output+=",${mean_frag},${mean_reads},${mean_umi},${mean_percent_umi}"
    
    # star EN FRAG
    aligned=0
    for chunk in star/${sample}_*Log.final.out
    do
        aligned_part=$(grep "Uniquely mapped reads number" $chunk| awk '{print $NF}')
        aligned=$(( $aligned + $aligned_part ))
    done
    aligned_reads=$( echo $aligned | awk ' { printf "%.0f", $1*2 }' )
    mean_aligned=$( echo $cells $aligned_reads | awk ' { printf "%.0f",$2/$1 }' )
    mean_percent_aligned=$(echo "$mean_reads" "$mean_aligned" | awk ' { printf "%.0f",$2/$1*100 } ')
    header+=",Number_aligned,Percent_aligned"
    output+=",${mean_aligned},${mean_percent_aligned}"

    cells_align=0
    for chunk in bcAfterStar/"${sample}"_*barcodes.txt; do
        if [[ -e "$chunk" ]]; then
            echo $chunk
            cells_align_part=$(wc -l < "$chunk")
            cells_align=$(( cells_align + cells_align_part ))
        else
            echo "No corresponding file = no cells : $chunk"
            cells_align_part=0
            cells_align=$(( cells_align + cells_align_part ))
        fi
    done

    # samtools markdup
    reads_dedup=$(grep "Total alignments :" featurecountsAll/${sample}_reads_featureCounts.log |  sed 's/.*Total alignments *: *\([0-9]\+\).*/\1/')
    percent_reads_dedup=$(echo "$reads" "$reads_dedup" | awk ' { printf "%.0f",$2/$1*100 } ')
    # featureCounts
    reads_dedup_assigned=$(grep "Assigned" featurecountsAll/${sample}_reads.csv.summary | tr '\t' '\n' | awk '{sum += $1} END {print sum}') #all reads per cells inline
    percent_reads_dedup_assigned=$(echo "$reads" "$reads_dedup_assigned" | awk ' { printf "%.0f",$2/$1*100 } ')

    # means
    if (( $cells_align == 0 )); then
        mean_reads_dedup=0
        mean_reads_dedup_assigned=0
        mean_percent_reads_dedup=0
        mean_percent_reads_dedup_assigned=0
    else
        mean_reads_dedup=$( echo $cells_align $reads_dedup | awk ' { printf "%.0f",$2/$1 }' )
        mean_reads_dedup_assigned=$( echo $cells_align $reads_dedup_assigned | awk ' { printf "%.0f",$2/$1 }' )
        mean_percent_reads_dedup=$(echo "$mean_reads" "$mean_reads_dedup" | awk ' { printf "%.0f",$2/$1*100 } ')
        mean_percent_reads_dedup_assigned=$(echo "$mean_reads" "$mean_reads_dedup_assigned" | awk ' { printf "%.0f",$2/$1*100 } ')
    fi
    header+=",Number_dedup,Percent_dedup,Final_reads,Percent_assigned"
    output+=",${mean_reads_dedup},${mean_percent_reads_dedup},${mean_reads_dedup_assigned},${mean_percent_reads_dedup_assigned}"

    ##------------Reads
    # Genes (wide format)
    # genes | cell1 | cell2 | ....
    nb_col=$(zcat matrice_reads/${sample}_reads_matrix.tsv.gz | awk 'NR==1 {print NF}')
    if [ $nb_col -gt 2 ]; then
        mean_genes_reads=$(zcat matrice_reads/${sample}_reads_matrix.tsv.gz | tail -n +2 | awk '
                            {
                                for (i=2; i<=NF; i++) {
                                    if ($i > 0) {
                                        count[i]++
                                    }
                                }
                            } END {
                                total = 0
                                n_col = 0
                                for (i in count) {
                                    total += count[i]
                                    n_col++
                                }
                                print total / n_col
                            }')
    else
        mean_genes_reads=$(zcat matrice_reads/${sample}_reads_matrix.tsv.gz | tail -n +2 | wc -l)
    fi
    header+=",Mean_genes_reads"
    output+=",${mean_genes_reads}"

    ##------------UMIs
    #umi_aligned=$(grep "Total alignments :" featurecountsUmis/${sample}_umi_featureCounts.log | awk '{print $NF}')
    #umi_assigned=$(grep "Assigned" featurecountsUmis/${sample}_umi.csv.summary| awk '{print $NF}')
    #umi_dedup_assigned=$(grep "Number of reads out:" umitools/${sample}_umitoolsDedup.log | awk '{print $NF}')
    #umi_dedup_unassigned=$(grep "Read skipped, no tag:" umitools/${sample}_umitoolsDedup.log| cut -f4 -d, | awk '{print $NF}')
    
    # Matrix (long format)
    # genes | cells | counts
    # UMIs
    mean_umi_dedup_assigned=$(zcat matrice_umis/${sample}_matrix.tsv.gz | awk 'NR > 1 {counts[$2] += $3} END {for (cell in counts) {total += counts[cell]; n++} print total/n}')
    header+=",Final_umis"
    output+=",${mean_umi_dedup_assigned}"
    # Genes 
    zcat matrice_umis/${sample}_matrix.tsv.gz | tail -n +2 | cut -f2 | sort | uniq -c > genes_per_cell
    ncells=$(wc -l < genes_per_cell)
    totgenes=$(awk '{sum += $1} END {print sum}' genes_per_cell)
    mean_genes_umis=$( echo $ncells $totgenes | awk '{ printf "%.0f",$2/$1 }' )
    header+=",Mean_genes_umis,Cells"
    output+=",${mean_genes_umis},${ncells}"

    if [ $n_header == 0 ]; then
        echo -e $header > general_stats.mqc
        n_header=1
    fi
    
    echo -e $output >> general_stats.mqc
done

awk -F',' 'BEGIN {OFS=","; print "Sample,Cell,ReadCount"} {print $1","$1","$2}' percent_mt.txt > cell_finalReads.txt
