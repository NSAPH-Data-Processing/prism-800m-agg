#!/bin/bash
#SBATCH -J prism_pts           # Job name
#SBATCH -p hsph                # Partition / queue
#SBATCH --array=1-49           # One task per CONUS state
#SBATCH -c 4                   # Cores per array task
#SBATCH --mem 64GB             # Memory per array task
#SBATCH -t 0-24:00             # Time limit (D-HH:MM)
#SBATCH -o prism_pts_%a.out    # Log file (%a = array task index)

## The decennial census year is passed as the first argument to this script.
## The array task ID is the state index (1-49).

## ---- Edit these two lines before submitting --------------------------------
PROJECT_DIR="/n/dominici_lab/Lab/data_processing/shreya_prism_800m/prism-800m-agg"   # must match working_dir in config.yaml
R_VERSION="4.4.1"                        # must match r_version in config.yaml
## ---------------------------------------------------------------------------

CONFIG="${PROJECT_DIR}/config.yaml"

: "${SLURM_ARRAY_TASK_ID:?This script must be submitted as a Slurm array job. Use: sbatch code/01c_Extraction_Pts_Exe_v03.sh}"

DECYEAR="${1:?Decennial census year argument required. Usage: sbatch --array=1-49 01b_Extraction_Pts_v03.sh DECYEAR}"
STATE=$SLURM_ARRAY_TASK_ID

cd $PROJECT_DIR

source code/slurm_runtime_env.sh
Rscript code/01a_Extraction_Pts_v03.R $STATE $CONFIG $DECYEAR

