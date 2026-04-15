#!/bin/bash
#SBATCH -J extract_prism       # Job name
#SBATCH -p hsph                # Partition / queue
#SBATCH -c 16                  # Cores per array task
#SBATCH --mem 64GB             # Memory per array task
#SBATCH -t 0-12:00             # Time limit (D-HH:MM)
#SBATCH -o extract_prism_%a.out  # Log file (%a = array task index)

## The array task ID encodes year and state as YYYYSS (e.g. 201001 = year 2010,
## state index 01). Specify --array at submission time via 02c (recommended) or
## directly, e.g. for year 2010 across all 49 states:
##   sbatch --array=201001-201049 code/02b_PRISM_Raster_Extract_v03.sh

## ---- Edit these two lines before submitting --------------------------------
PROJECT_DIR="/n/dominici_lab/Lab/data_processing/shreya_prism_800m/prism-800m-agg"   # must match working_dir in config.yaml
R_VERSION="4.4.1"                        # must match r_version in config.yaml
## ---------------------------------------------------------------------------

CONFIG="${PROJECT_DIR}/config.yaml"

year=$(echo $SLURM_ARRAY_TASK_ID | cut -c 1-4)
state=$(echo $SLURM_ARRAY_TASK_ID | cut -c 5-6)

cd $PROJECT_DIR

source code/slurm_runtime_env.sh
Rscript code/02a_PRISM_Raster_Extract_v03.R $year $state $CONFIG
