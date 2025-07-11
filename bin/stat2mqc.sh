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
    all_samples=$(find  nbCells/*initial_barcodes.txt | cut -f2 -d"/" | sed 's/_initial_barcodes.txt//')
else
    all_samples=$(awk -F, '{print $1}' $splan | uniq )
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
    header="Sample_id,Sample_name"
    output="${sample},${sname}"

    cells=0
    for chunk in nbCells/${sample}_*
    do
        cell_part=$(cat $chunk)
        cells=$(( $cells + $cell_part ))
    done
    header+=",Number_of_cells"
    output+=",${cells}"

    # umitools extract
    frag=0
    umi=0
    for chunk in umitools/${sample}_*umiExtract.log
    do
        frag_part=$(grep "Input Reads:" $chunk| awk '{print $NF}')
        frag=$(( $frag + $frag_part ))
        umi_part=$(grep "Reads output:" $chunk| awk '{print $NF}')
        umi=$(( $umi + $umi_part ))
    done
    reads=$(echo "$frag" | awk ' { printf "%.0f",$1*2 } ')
    percent_umi=$(echo "$frag" "$umi" | awk ' { printf "%.0f",$2/$1*100 } ')
    header+=",Number_of_frag,Number_of_reads,Number_umis,Percent_umis"
    output+=",${frag},${reads},${umi},${percent_umi}"
    
    # star
    aligned=0
    for chunk in star/${sample}*Log.final.out
    do
        echo $chunk
        aligned_part=$(grep "Uniquely mapped reads number" $chunk| awk '{print $NF}')
        aligned=$(( $aligned + $aligned_part ))
    done
    percent_aligned=$(echo "$frag" "$aligned" | awk ' { printf "%.0f",$2/$1*100 } ')
    header+=",Number_aligned,Percent_aligned"
    output+=",${aligned},${percent_aligned}"

    reads_dedup=$(grep "Total alignments :" featurecountsAll/${sample}_reads_featureCounts.log | awk '{print $NF}')
    percent_reads_dedup=$(echo "$frag" "$reads_dedup" | awk ' { printf "%.0f",$2/$1*100 } ')
    reads_dedup_assigned=$(grep "Assigned" featurecountsAll/${sample}_reads.csv.summary | awk '{print $NF}')
    percent_reads_dedup_assigned=$(echo "$frag" "$reads_dedup_assigned" | awk ' { printf "%.0f",$2/$1*100 } ')
    header+=",Number_dedup,Percent_dedup,Number_assigned,Percent_assigned"
    output+=",${reads_dedup},${percent_reads_dedup},${reads_dedup_assigned},${percent_reads_dedup_assigned}"

    umi_aligned=$(grep "Total alignments :" featurecountsUmis/${sample}_umi_featureCounts.log | awk '{print $NF}')
    umi_assigned=$(grep "Assigned" featurecountsUmis/${sample}_umi.csv.summary| awk '{print $NF}')
    umi_dedup_assigned=$(grep "Number of reads out:" umitools/${sample}_umitoolsDedup.log | awk '{print $NF}')
    #umi_dedup_unassigned=$(grep "Read skipped, no tag:" umitools/${sample}_umitoolsDedup.log| cut -f4 -d, | awk '{print $NF}')
    header+=",Final_umi"
    output+=",${umi_dedup_assigned}"

    if [ $n_header == 0 ]; then
        echo -e $header > general_stats.mqc
        n_header=1
    fi
    
    echo -e $output >> general_stats.mqc
done

