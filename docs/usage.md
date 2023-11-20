# Usage

<!-- TODO - Update with the usage of your pipeline -->

## Table of contents

* [Introduction](#general-nextflow-info)
* [Running the pipeline](#running-the-pipeline)
* [Main arguments](#main-arguments)
    * [`-profile`](#-profile)
    * [`--reads`](#-reads)
    * [`--samplePlan`](#-sampleplan)
	* [`--design`](#--design) 
* [Inputs](#inputs)
    * [`--singleEnd`](#--singleend)
* [Reference genomes](#reference-genomes)
    * [`--genome`](#-genome)
* [Annotations](#annotations)
    * [`--genomeAnnotationPath`](#-genomeannotationpath)
* [Nextflow profiles](#nextflow-profiles)
* [Job resources](#job-resources)
* [Other command line parameters](#other-command-line-parameters)
    * [`--skip*`](#-skip)
    * [`--metadata`](#-metadata)
    * [`--outDir`](#-outdir)
    * [`-name`](#-name)
    * [`-resume`](#-resume)
    * [`-c`](#-c)
    * [`--maxMemory`](#-maxmemory)
    * [`--maxTime`](#-maxtime)
    * [`--maxCpus`](#-maxcpus)
    * [`--multiqcConfig`](#-multiqcconfig)
* [Profile parameters](#profile-parameters)
    * [`--condaCacheDir`](#-condacachedir)
    * [`--globalPath`](#-globalpath)
    * [`--queue`](#-queue)
    * [`--singularityImagePath`](#-singularityimagepath)

## General Nextflow info

Nextflow handles job submissions on SLURM or other environments, and supervises the job execution. Thus the Nextflow process must run until the pipeline is finished. We recommend that you put the process running in the background through `screen` / `tmux` or similar tool. Alternatively you can run nextflow within a cluster job submitted your job scheduler.

It is recommended to limit the Nextflow Java virtual machines memory. We recommend adding the following line to your environment (typically in `~/.bashrc` or `~./bash_profile`):

```bash
NXF_OPTS='-Xms1g -Xmx4g'
```

## Running the pipeline

The typical command for running the pipeline is as follows:
```bash
nextflow run main.nf --reads '*_R{1,2}.fastq.gz' -profile 'singularity'
```

This will launch the pipeline with the `singularity` configuration profile. See below for more information about profiles.

Note that the pipeline will create the following files in your working directory:

```bash
work            # Directory containing the nextflow working files
results         # Finished results (configurable, see below)
.nextflow_log   # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```

You can change the output director using the `--outDir/-w` options.

## Main arguments

### `-profile`

Use this option to set the [Nextflow profiles](profiles.md). For example:

```bash
-profile singularity,cluster
```

### `--reads`
Use this to specify the location of your input FastQ files. For example:

```bash
--reads 'path/to/data/sample_*_{1,2}.fastq'
```

Please note the following requirements:

1. The path must be enclosed in quotes
2. The path must have at least one `*` wildcard character
3. When using the pipeline with paired end data, the path must use `{1,2}` notation to specify read pairs

If left unspecified, a default pattern is used: `data/*{1,2}.fastq.gz`


### `--samplePlan`

Use this to specify a `sample plan` file instead of a regular expression to find fastq files. For example :

```bash
--samplePlan 'path/to/data/samplePlan.csv
```

The `sample plan` is a csv file with the following information (and no header) :

```
Sample ID | Sample Name | /path/to/R1/fastq/file | /path/to/R2/fastq/file (for paired-end only)
```

### `--design`

Specify a `design` file for extended analysis.

```bash
--design 'path/to/data/design.csv'
```

The `design` is a custom csv file that list all experimental samples, their IDs, the associated control as well as any other useful metadata. It can contain any information you need during the analysis.
The design is expected to be created with the following header :

```bash
SAMPLE_ID | VARIABLE1 | VARIABLE2
```

Importantly, defining a custom `design` file implies that you modify the variable `designHeader` in the `bin/apCheckDesign.py` script accordingly. For example: set `designHeader=['SAMPLE_ID', 'VARIABLE1', 'VARIABLE2']`. Modify also the `designCh` channel in the `main.nf` to use the custom information.



The `--samplePlan` and the `--design` will be checked by the pipeline and have to be rigorously defined in order to make the pipeline work.
If the `design` file is not specified, the pipeline will run over the first steps but the downstream analysis will be ignored.

## Inputs

### `--singleEnd`

By default, the pipeline expects paired-end data. If you have single-end data, you need to specify `--singleEnd` on the command line when you launch the pipeline. A normal glob pattern, enclosed 
in quotation marks, can then be used for `--reads`. For example:

```bash
--singleEnd --reads '*.fastq.gz'
```

## Reference Genomes

All information about genomes and annotation are available in [ReferenceGenome](referenceGenome.md).

### `-genome`

There are different species supported in the genomes references file. To run the pipeline, you must specify which to use with the `--genome` flag.

You can find the keys to specify the genomes in the [genomes config file](../conf/genomes.config). Common genomes that are supported are:

* Human
  * `--genome hg38`
* Mouse
   * `--genome mm10`
	
> There are numerous others - check the config file for more.

## Annotations

### `--genomeAnnotationPath`

The path where the genome annotations are available (and organized as specified in the ``conf/genomes.config`` file) can be changed at runtine with the ``--genomeAnnotationPath`` option.

## Nextflow profiles

Different Nextflow profiles can be used. See [Profiles](profiles.md) for details.

## Job resources

Each step in the pipeline has a default set of requirements for number of CPUs, memory and time (see the [`conf/process.conf`](../conf/process.config) file). 
For most of the steps in the pipeline, if the job exits with an error code of `143` (exceeded requested resources) it will automatically resubmit with higher requests (2 x original, then 3 x original). If it still fails after three times then the pipeline is stopped.

## Other command line parameters

### `--skip*`

The pipeline is made with a few *skip* options that allow to skip optional steps in the workflow.
The following options can be used:
* `--skipFastqc`
* `--skipMultiqc`
				
### `--metadata`
Specify a two-columns (tab-delimited) metadata file to diplay in the final Multiqc report.

### `--outDir`
The output directory where the results will be saved.

### `-name`
Name for the pipeline run. If not specified, Nextflow will automatically generate a random mnemonic.

This is used in the MultiQC report (if not default) and in the summary HTML.

**NB:** Single hyphen (core Nextflow option)

### `-resume`
Specify this when restarting a pipeline. Nextflow will used cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously.

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

**NB:** Single hyphen (core Nextflow option)

### `-c`
Specify the path to a specific config file (this is a core NextFlow command).

**NB:** Single hyphen (core Nextflow option)

Note - you can use this to override pipeline defaults.

### `--maxMemory`
Use to set a top-limit for the default memory requirement for each process.
Should be a string in the format integer-unit. eg. `--maxMemory '8.GB'`

### `--maxTime`
Use to set a top-limit for the default time requirement for each process.
Should be a string in the format integer-unit. eg. `--maxTime '2.h'`

### `--maxCpus`
Use to set a top-limit for the default CPU requirement for each process.
Should be a string in the format integer-unit. eg. `--maxCpus 1`

### `--multiqcConfig`
Specify a path to a custom MultiQC configuration file.

## Profile parameters


### `--condaCacheDir`

Whenever you use the `conda` or `multiconda` profiles, the conda environments are created in the ``${HOME}/conda-cache-nextflow`` folder by default. This folder can be changed using the `--condaCacheDir` option.


### `--globalPath`

When you use `path` or `multipath` profiles, the ``path`` and ``multipath`` folders where are installed the tools can be changed at runtime with the ``--globalPath`` option.


### `--queue`

If you want your job to be submitted on a specific ``queue`` when you use the `cluster` profile, use the option ``--queue`` with the name of the queue in the command line.


### `--singularityImagePath`

When you use the `singularity` profile, the path to the singularity containers can be changed at runtime with the ``--singularityImagePath`` option.


