#!/bin/bash
#SBATCH -J prism_bl_zcta       # Job name
#SBATCH -p hsph                # Partition / queue
#SBATCH -c 28                  # Cores per array task
#SBATCH --mem 128GB            # Memory per array task
#SBATCH -t 0-08:00             # Time limit (D-HH:MM)
#SBATCH -o prism_bl_zcta_%a.out  # Log file (%a = array task index)

## The array task ID encodes year and state as YYYYSS (e.g. 201001 = year 2010,
## state index 01). Specify --array at submission time via 03c (recommended) or
## directly, e.g. for year 2010 across all 49 states:
##   sbatch --array=201001-201049 03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh

year=$(echo $SLURM_ARRAY_TASK_ID | cut -c 1-4)
state=$(echo $SLURM_ARRAY_TASK_ID | cut -c 5-6)

## Absolute path to config.yaml (edit before submitting)
CONFIG="/pathtoscript/config.yaml"

module load R/4.3.1
Rscript /pathtoscript/03a_BlockPop_Wt_ZCTA_PRISM_800m_v03.R $year $state $CONFIG
