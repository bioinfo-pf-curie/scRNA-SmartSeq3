# Pipeline deployment with `geniac`

The [geniac](https://geniac.readthedocs.io) module allows the automatic generation of the [Nextflow](https://www.nextflow.io) configuration files (including profiles) and the container recipes and their creation.


## Quick start

### Prerequisites

* git (>= 2.0) [required]
* cmake (>= 3.0) [required]
* Nextflow (>= 21.10.6) [required]
* Singularity (>= 3.8.5) [optional]
* Docker (>= 18.0) [optional]

Install [conda](https://docs.conda.io):
```bash
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh
```

### Install the geniac conda environment

```bash
# Create the geniac conda environment
export GENIAC_CONDA="https://raw.githubusercontent.com/bioinfo-pf-curie/geniac/release/environment.yml"
wget ${GENIAC_CONDA}
conda env create -f environment.yml
conda activate geniac
```

### Check the code, install and run the pipeline with the multiconda profile

```bash
export WORK_DIR="${HOME}/tmp/myPipeline"
export INSTALL_DIR="${WORK_DIR}/install"
export GIT_URL="https://myPipeline/myPipeline.git"

# Initialization of a working directory
# with the src and build folders
geniac init -w ${WORK_DIR} ${GIT_URL}
cd ${WORK_DIR}

# Check the code
geniac lint

# Install the pipeline
geniac install . ${INSTALL_DIR}

# Test the pipeline with the multiconda profile
geniac test multiconda
```

### Check the code, install and run the pipeline with the singularity profile

Note that you need `sudo` privilege to build the singularity images.

```bash
export WORK_DIR="${HOME}/tmp/myPipeline"
export INSTALL_DIR="${WORK_DIR}/install"
export GIT_URL="https://myPipeline/myPipeline.git"

# Initialization of a working directory
# with the src and build folders
geniac init -w ${WORK_DIR} ${GIT_URL}
cd ${WORK_DIR}

# Install the pipeline with the singularity images
geniac install . ${INSTALL_DIR} -m singularity
sudo chown -R  $(id -gn):$(id -gn) build

# Test the pipeline with the singularity profile
geniac test singularity

# Test the pipeline with the singularity and cluster profiles
geniac test singularity --check-cluster
```

### Advanced users

Note that the geniac command line interface provides a wrapper to `git`, `cmake` and `make` commands. Advanced users familiar with these commands can run the following (see [geniac documentation](https://geniac.readthedocs.io) for more details):

```bash
export WORK_DIR="${HOME}/tmp/myPipeline"
export SRC_DIR="${WORK_DIR}/src"
export INSTALL_DIR="${WORK_DIR}/install"
export BUILD_DIR="${WORK_DIR}/build"
export GIT_URL="https://myPipeline/myPipeline.git"

mkdir -p ${INSTALL_DIR} ${BUILD_DIR}

# clone the repository
# the option --recursive is needed if you use geniac as a submodule
git clone --recursive ${GIT_URL} ${SRC_DIR}

cd ${BUILD_DIR}

# configure the pipeline
cmake ${SRC_DIR}/geniac -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}

# build the files needed by the pipeline
make

# install the pipeline
make install

# run the pipeline
make test_multiconda
```

=========================


## Examples

In the following example, the `singularity` images are available in the `SING_DIR` folder, and will thus be used during the deployment of the pipeline
using the options `ap_singularity_image_path` et `ap_use_singularity_image_link`.

```bash
cmake ${SRC_DIR}/geniac -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} -Dap_singularity_image_path="SING_DIR"
```

## Installation

Note that if the installation of `singularity` or `docker` images has been activated at the previous stage, the `make` command needs to be
run with the `root` rights.

```bash
cd ${BUILD_DIR}
make
make install
```

# Test

## Singularity


```bash
cd ${INSTALL_DIR}/pipeline

nextflow run main.nf --singleEnd 'true' --genome 'hg38' --library 'GW-KO-Sabatini-Human-10' --samplePlan 'test/sample_plan.csv' -profile singularity
```

## Multiconda

The `multiconda` profile generates a `conda` environment for each tool listed in the `conf/geniac.conf` configuration.

```bash
cd ${INSTALL_DIR}/pipeline

nextflow run main.nf --singleEnd 'true' --genome 'hg38' --library 'GW-KO-Sabatini-Human-10' --samplePlan 'test/sample_plan.csv' -profile multiconda
```
