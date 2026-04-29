#!/bin/bash
#SBATCH -J prism_bl_zcta       # Job name
#SBATCH -p hsph                # Partition / queue
#SBATCH --array=1-49           # One task per CONUS state
#SBATCH -c 28                  # Cores per array task
#SBATCH --mem 128GB            # Memory per array task
#SBATCH -t 0-08:00             # Time limit (D-HH:MM)
#SBATCH -o prism_bl_zcta_%a.out  # Log file (%a = array task index)

## The year is passed as the first argument to this script (e.g., sbatch --array=1-49 03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh 2010).
## The array task ID is the state index (1-49).

## ---- Edit these two lines before submitting --------------------------------
PROJECT_DIR="/n/dominici_lab/Lab/data_processing/shreya_prism_800m/prism-800m-agg"   # must match working_dir in config.yaml
R_VERSION="4.4.1"                        # must match r_version in config.yaml
## ---------------------------------------------------------------------------

CONFIG="${PROJECT_DIR}/config.yaml"

: "${SLURM_ARRAY_TASK_ID:?This script must be submitted as a Slurm array job. Use: sbatch code/03c_BlockPop_Wt_ZCTA_PRISM_800m_Exe_v03.sh}"

YEAR="${1:?Year argument required. Usage: sbatch --array=1-49 03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh YEAR}"
STATE=$SLURM_ARRAY_TASK_ID

cd $PROJECT_DIR

source code/slurm_runtime_env.sh
Rscript code/03a_BlockPop_Wt_ZCTA_PRISM_800m_v03.R $YEAR $STATE $CONFIG

