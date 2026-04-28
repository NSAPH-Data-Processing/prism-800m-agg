#!/bin/bash
#SBATCH -J prism_download      # Job name
#SBATCH -p hsph                # Partition / queue
#SBATCH -c 4                   # Cores (mostly network I/O, not CPU-bound)
#SBATCH --mem 32GB             # Memory (for handling downloaded files)
#SBATCH -t 0-24:00             # Time limit (D-HH:MM) — 8 hours for network downloads
#SBATCH -o X_Download_PRISM800m_%j.out  # Log file (%j = job ID)

## ---- Edit these two lines before submitting --------------------------------
PROJECT_DIR="/n/dominici_lab/Lab/data_processing/shreya_prism_800m/prism-800m-agg"   # must match working_dir in config.yaml
R_VERSION="4.4.1"                        # must match r_version in config.yaml
## ---------------------------------------------------------------------------

CONFIG="${PROJECT_DIR}/config.yaml"

cd $PROJECT_DIR

source code/slurm_runtime_env.sh
Rscript code/X_Download_PRISM800m_v01.R $CONFIG

## Submit with:
##   sbatch code/X_Download_PRISM800m.sh
