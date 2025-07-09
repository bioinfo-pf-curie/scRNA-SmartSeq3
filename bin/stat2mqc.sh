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
    all_samples=$(find  nbCells/*initial_nb_barcodes.txt | cut -f2 -d"/" | sed 's/_initial_nb_barcodes.txt//')
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

    nb_cells=0
    for chunk in nbCells/${sample}_*initial_nb_barcodes.txt
    do
        nb_cell_part=$(cat $chunk)
        nb_cells=$(( $nb_cells + $nb_cell_part ))
    done
    header+=",Number_of_cells"
    output+=",${nb_cells}"

    nb_frag=0
    for chunk in star/${sample}*Log.final.out
    do
        echo $chunk
        nb_frag_part=$(grep "Number of input reads" $chunk| awk '{print $NF}')
        nb_frag=$(( $nb_frag + $nb_frag_part ))
    done
    nb_reads=$(echo "${nb_frag}" | awk ' { printf "%.0f",$1*2 } ')
    header+=",Number_of_frag,Number_of_reads"
    output+=",${nb_frag},${nb_reads}"


    if [ $n_header == 0 ]; then
        echo -e $header
        n_header=1
    fi
    
    echo -e $output >> general_stats.mqc
done

