#!/bin/bash
#SBATCH -J prism_pts           # Job name
#SBATCH -p hsph                # Partition / queue
#SBATCH --array=1-49           # One task per CONUS state
#SBATCH -c 4                   # Cores per array task
#SBATCH --mem 64GB             # Memory per array task
#SBATCH -t 0-08:00             # Time limit (D-HH:MM)
#SBATCH -o prism_pts_%a.out    # Log file (%a = array task index)

## ---- Edit these two lines before submitting --------------------------------
PROJECT_DIR="/n/dominici_lab/Lab/data_processing/shreya_prism_800m/prism-800m-agg"   # must match working_dir in config.yaml
R_VERSION="4.4.1"                        # must match r_version in config.yaml
## ---------------------------------------------------------------------------

CONFIG="${PROJECT_DIR}/config.yaml"

: "${SLURM_ARRAY_TASK_ID:?This script must be submitted as a Slurm array job. Use: sbatch code/01b_Extraction_Pts_v03.sh}"

cd $PROJECT_DIR

source code/slurm_runtime_env.sh
Rscript code/01a_Extraction_Pts_v03.R $SLURM_ARRAY_TASK_ID $CONFIG

## Submit as an array with one task per state (49 CONUS states, excluding AK and HI):
##   sbatch --array=1-49 code/01b_Extraction_Pts_v03.sh
##
## Each task index selects a unique state FIPS code from the list in the R script:
##   task 1 → FIPS 01 (Alabama)
##   task 2 → FIPS 04 (Arizona)
##   task 3 → FIPS 05 (Arkansas)
##   ...and so on
