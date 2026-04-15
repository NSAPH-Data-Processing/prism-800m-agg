#!/bin/bash
#SBATCH -J prism_fishnet       # Job name
#SBATCH -p hsph                # Partition / queue
#SBATCH -c 16                  # Cores
#SBATCH --mem 64GB             # Memory
#SBATCH -t 0-04:00             # Time limit (D-HH:MM)
#SBATCH -o prism_fishnet_%j.out  # Log file (%j = job ID)

## ---- Edit these two lines before submitting --------------------------------
PROJECT_DIR="/n/dominici_lab/Lab/data_processing/shreya_prism_800m/prism-800m-agg"   # must match working_dir in config.yaml
R_VERSION="4.4.1"                        # must match r_version in config.yaml
## ---------------------------------------------------------------------------

CONFIG="${PROJECT_DIR}/config.yaml"

cd $PROJECT_DIR

source code/slurm_runtime_env.sh
Rscript code/00a_Create_Fishnet_PRISMv2_800m_v03.R $CONFIG

## Submit with:
##   sbatch code/00b_Create_Fishnet_PRISMv2_800m_v03.sh
