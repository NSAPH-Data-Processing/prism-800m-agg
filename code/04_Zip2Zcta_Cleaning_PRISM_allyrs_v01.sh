#!/bin/bash
#SBATCH -J prism_zcta_clean    # Job name
#SBATCH -p hsph                # Partition / queue
#SBATCH -c 16                  # Cores
#SBATCH --mem 64GB             # Memory
#SBATCH -t 0-06:00             # Time limit (D-HH:MM)
#SBATCH -o prism_zcta_clean_%j.out  # Log file (%j = job ID)

## ---- Edit these two lines before submitting --------------------------------
PROJECT_DIR="/n/dominici_lab/Lab/data_processing/shreya_prism_800m/prism-800m-agg"   # must match working_dir in config.yaml
R_VERSION="4.4.1"                        # must match r_version in config.yaml
## ---------------------------------------------------------------------------

CONFIG="${PROJECT_DIR}/config.yaml"

cd $PROJECT_DIR

source code/slurm_runtime_env.sh
Rscript code/04_Zip2Zcta_Cleaning_PRISM_allyrs_v01.R $CONFIG

## Submit with:
##   sbatch code/04_Zip2Zcta_Cleaning_PRISM_allyrs_v01.sh
