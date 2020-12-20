#!/usr/bin/env python
# coding: utf-8
#
#  This file is part of multiQC software. Using a metadata file, it writes part of the multiQC config file
#
#  Copyright (c) 2018 - Institut Curie
#
#  File author(s):
#      Dimitri Desvillechabrol <dimitri.desvillechabrol@curie.fr>,
#      Nicolas Servant <nicolas.servant@curie.fr>
#
#  Distributed under the terms of the CeCILL-B license.
#  The full license is in the LICENSE file, distributed with this software.
#
##############################################################################

import os
import re
import argparse
from collections import OrderedDict

parser = argparse.ArgumentParser()
parser.add_argument("-n", "--name", help="Pipeline name")
parser.add_argument("-v", "--version", help="Pipeline version", default='')
parser.add_argument("-m", "--metadata", help="Metatdata file", default=None)
parser.add_argument("-s", "--splan", help="Sample plan", default=None)
parser.add_argument("-x", "--nbreads", help="Number of reads to display on the graph", default=0)

args = parser.parse_args()

##
## Header
##

multiqc_list = ["title: '{}'".format(args.name)]
multiqc_list += ["subtitle: Institut Curie NGS/Bioinformatics core facilities"]

if re.match(r".*dev$", args.version):
    multiqc_list +=["report_comment: >\n This software is currently under active development and the results have been generated with a non stable version. The reliability, reproducibility and the quality of the results are therefore not guaranteed."]

multiqc_list += ["custom_logo: '{}'".format(os.sep.join([
    os.path.dirname(os.path.realpath(__file__)), '../assets/institutCurieLogo.png']))]
multiqc_list += ["custom_logo_title: Institut Curie"]
multiqc_list += ["custom_logo_url: https://science.curie.fr/plateformes/sequencage-adn-haut-debit-ngs/"]


##
## Sample Names
##
if args.splan is not None:
    multiqc_list += ["sample_names_rename_buttons:"]
    multiqc_list += ["    - 'Sample ID'"]
    multiqc_list += ["    - 'Sample Name'"]
    multiqc_list += ["sample_names_rename:"]

    sampledict = dict()
    with open(args.splan, 'r') as fp:
        for line in fp:
            if line not in ['\n', '\r\n']:
                row = line.split(',')
                sampledict[row[0]] = row[1].strip()

    multiqc_list += [
        '    - ["{}","{}"]'.format(key, value)
        for key, value in sampledict.items()]

##
## Preseq
##

if args.nbreads > 0:
    mx="{0:.2f}".format(int(args.nbreads)/1000000)
    multiqc_list += ["custom_plot_config:"]
    multiqc_list += ["   preseq_plot:"]
    multiqc_list += ["      xPlotLines:"]
    multiqc_list += ["         - color: '#a9a9a9'"]
    multiqc_list += ["           value: " + str(mx)]
    multiqc_list += ["           dashStyle: 'LongDash'"]
    multiqc_list += ["           width: 1"]
    multiqc_list += ["           label:"]
    multiqc_list += ["              style: {color: '#a9a9a9'}"]
    multiqc_list += ["              text: 'Median Reads Number'"]
    multiqc_list += ["              verticalAlign: 'top'"]
    multiqc_list += ["              y: 0"]

##
## Metadata
##
multiqc_list += ["report_header_info:"]
if args.metadata is not None:
    # create rims dict
    rims_dict = OrderedDict([
        ('RIMS_ID', "RIMS code"),
        ('project_name', "Project name"),
        ('project_id', "Project ID"),
        ('runs', 'Runs'),
        ('sequencer', "Sequencing setup"),
        ('biological_application', "Application type"),
        ('nature_of_material', 'Material'),
        ('protocol', 'Protocol'),
        ('bed', 'BED of targets'),
        ('technical_contact', "Main contact"),
        ('team_leader|unit', "Team leader"),
        ('ngs_contact', "Contact E-mail")
    ])

    # get data from metadata
    metadict = dict()
    with open(args.metadata, 'r') as fp:
        for line in fp:
            row = line.split('\t')
            metadict[row[0]] = row[1].strip()
            # add ngs mail if no agent was set

    metadict['ngs_contact'] = 'ngs.lab@curie.fr'
    multiqc_list += [
        '    - {}: "{}"'.format(value, metadict[key])
        for key, value in rims_dict.items() if key in metadict]

## Output
custom_content = '\n'.join(multiqc_list)
print(custom_content)



