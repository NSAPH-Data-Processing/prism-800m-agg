#!/bin/bash
#SBATCH -J prism_bl_zcta       # Job name
#SBATCH -p hsph                # Partition / queue
#SBATCH --array=198001-198043,198101-198143,198201-198243,198301-198343,198401-198443,198501-198543,198601-198643,198701-198743,198801-198843,198901-198943,199001-199043,199101-199143,199201-199243,199301-199343,199401-199443,199501-199543,199601-199643,199701-199743,199801-199843,199901-199943,200001-200043,200101-200143,200201-200243
#SBATCH -c 28                  # Cores per array task
#SBATCH --mem 128GB            # Memory per array task
#SBATCH -t 0-08:00             # Time limit (D-HH:MM)
#SBATCH -o prism_bl_zcta_%a.out  # Log file (%a = array task index)

## The array task ID encodes year and state as YYYYSS (e.g. 201001 = year 2010,
## state index 01). Specify --array at submission time via 03c (recommended) or
## directly, e.g. for year 2010 across all 49 states:
##   sbatch --array=201001-201049 code/03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh

## ---- Edit these two lines before submitting --------------------------------
PROJECT_DIR="/n/dominici_lab/Lab/data_processing/shreya_prism_800m/prism-800m-agg"   # must match working_dir in config.yaml
R_VERSION="4.4.1"                        # must match r_version in config.yaml
## ---------------------------------------------------------------------------

CONFIG="${PROJECT_DIR}/config.yaml"

: "${SLURM_ARRAY_TASK_ID:?This script must be submitted as a Slurm array job. Use: sbatch code/03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh or code/03c_BlockPop_Wt_ZCTA_PRISM_800m_Exe_v03.sh}"

year=$(echo $SLURM_ARRAY_TASK_ID | cut -c 1-4)
state=$(echo $SLURM_ARRAY_TASK_ID | cut -c 5-6)

cd $PROJECT_DIR

source code/slurm_runtime_env.sh
Rscript code/03a_BlockPop_Wt_ZCTA_PRISM_800m_v03.R $year $state $CONFIG
