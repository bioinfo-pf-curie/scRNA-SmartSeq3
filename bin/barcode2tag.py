#!/usr/bin/env python
# coding: utf-8

"""
Nicolas Servant
Add RG tag using barcode information extracted from read name
"""

import os
import sys
import glob
import pysam
import argparse

def get_args():
    '''Parse sys.argv'''
    parser = argparse.ArgumentParser()
    parser.add_argument('-i','--input', required=True,
                        help='The input BAM files.')
    parser.add_argument('-o','--output', required=True,
                        help="Output file name")
    parser.add_argument('-b','--barcodes',
                        help="List of all possible barcodes - required if tag==RG")
    parser.add_argument('-SM', type=str,
                        help="Sample Name")
    parser.add_argument('-t', '--tag', type=str, 
                        help="Tag name")

    args = parser.parse_args()
    return args


def get_BAM_header(bam):
    """Get BAM header"""
    samfile = pysam.Samfile(bam, 'r')
    header = samfile.header.to_dict()
    samfile.close()
    return header

def add_RG_to_header(header, barcodes, sname):
    """Add read group info to a header."""
    # CREATE TEMPLATE
    # Read group. Unordered multiple @RG lines are allowed.
    RG_template = { 'ID': '',           # Read group identifier. e.g., Illumina flowcell + lane name and number
                    'SM': '',           # Sample. Use pool name where a pool is being sequenced.
                    'LB': '1',          # Read group library
                    'PU': '1',          # Platform unit (e.g. flowcell-barcode.lane for Illumina or slide for SOLiD).
                    'PL': 'ILLUMINA'}   # Platform/technology used to produce the reads.

    # ADD BARCODE INFO TO TEMPLATE
    barcode_rg = []
    with open(barcodes) as fhbc:
        while True:
            bcname = fhbc.readline().rstrip()
            if len(bcname) == 0 :
                break
            else:
                RG_template = RG_template.copy()
                RG_template['ID'] = bcname
                RG_template['SM'] = sname
                barcode_rg.append(RG_template)

    header['RG']=barcode_rg
    return header

def add_tag_to_BAM(bam, output, header, tag):
    """Generates the correct @RG header and adds a RG field to a bam file."""

    name, ext = os.path.splitext(bam)
    outfile = pysam.Samfile( output, 'wb', header=header)

    # Process Bam file adding Read Group to Each Read
    bamfile = pysam.Samfile(bam, "rb")
    #bamfile.fetch()
    for count, read in enumerate(bamfile.fetch(until_eof=True)):
        name = read.query_name
        read_group = name.split("_")[-1]
        read.qname = ' '.join(name.split("_")[:-1])
        new_tags = read.get_tags()
        new_tags.append((tag, read_group))
        read.set_tags(new_tags)
        outfile.write(read)
    outfile.close()

    # Make index of read group enabled bamfile
    #pysam.index(output)
    return

if __name__ == '__main__':
    args = get_args()
    
    h=get_BAM_header(args.input)

    if args.tag == 'RG':
        if args.barcodes:
            h=add_RG_to_header(h, args.barcodes, args.SM)
        else:
            sys.exit("--barcodes is mandatory to use RG tag")

    add_tag_to_BAM(args.input, args.output, h, args.tag)
