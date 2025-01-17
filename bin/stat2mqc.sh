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

while getopts "s:p:t:h" OPT
do
    case $OPT in
        s) splan=$OPTARG;;
        d) protocol=$OPTARG;;
        t) minReads=$OPTARG;;
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

all_samples=$(awk -F, '{print $1}' $splan)
n_header=0

for sample in $all_samples
do
                                                                                                                                                                                                          
    ## sample name
    sname=$(awk -F, -v sname=$sample '$1==sname{print $2}' $splan | uniq)
    header="Sample_id,Sample_name"
    output="${sample},${sname}"

    nb_frag=0
    if [[ -e barcodes/${sample}*_addbarcodes.log ]]; then
        for batches in $(ls barcodes/${sample}*_addbarcodes.log)
        do
            #grep "Input Reads:" results/preprocessing/umitoolsExtract/fastq_chunk*R1* | awk '{print $6}' >> totFragChunk
            #grep "Reads output: " results/preprocessing/umitoolsExtract/fastq_chunk* | awk '{print $6}' >> nbumireads
            nb_frag_batch=$(awk  '$0~"Total"{print $NF}' $batches)
            nb_frag=$(( $nb_frag + $nb_frag_batch ))
        done
        nb_reads=$(( $nb_frag * 2 ))
        header+=",Number_of_frag,Number_of_reads"
        output+=",${nb_frag},${nb_reads}"
    else
        nb_reads=$(grep "raw total sequences" stats/${sample}.stats | awk '{print $5}')
        nb_frag=$(( $nb_reads / 2 ))
        nb_reads_barcoded=$nb_reads
        perc_barcoded=$(echo "${nb_reads_barcoded} ${nb_reads}" | awk ' { printf "%.*f",2,$1*100/$2 } ')
        header+=",Number_of_frag,Number_of_reads,Number_barcoded_reads,Percent_barcoded"
        output+=",${nb_frag},${nb_reads},${nb_reads_barcoded},${perc_barcoded}"
    fi


    # Median reads per cell with more than 1000 reads
    countsfiles=$(ls barcodes/${sample}_final_barcodes_counts.txt)
    if [[ -e "${countsfiles[0]}" ]]
    then
	nbCell=$(wc -l ${countsfiles[0]} | awk '{print $1}')
	nbCellminReads=$( awk -v limit=$minReads '$1>=limit{c++} END{print c}' ${countsfiles[0]})
	header+=",Cell_number,Cell_number_minReads"
	output+=",${nbCell},${nbCellminReads}"
	if (( $nbCellminReads>1 ))
	then
	    median=$(sort -k1,1n ${countsfiles[0]} | awk '{ a[i++]=$1; } END { print a[int(i/2)]; }')
	    header+=",Median_reads_per_cell"
	    output+=",${median}"
	fi
    fi

    if [ $n_header == 0 ]; then
        echo -e $header
        n_header=1
    fi
    echo -e $output
done

