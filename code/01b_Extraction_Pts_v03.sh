#!/bin/bash
#SBATCH -J prism_pts           # Job name
#SBATCH -p hsph                # Partition / queue
#SBATCH -c 4                   # Cores per array task
#SBATCH --mem 32GB             # Memory per array task
#SBATCH -t 0-08:00             # Time limit (D-HH:MM)
#SBATCH -o prism_pts_%a.out    # Log file (%a = array task index)

## Absolute path to config.yaml (edit before submitting)
CONFIG="/pathtoscript/config.yaml"

module load R/4.4.0
Rscript /pathtoscript/01a_Extraction_Pts_v03.R $SLURM_ARRAY_TASK_ID $CONFIG

## Submit as an array with one task per state (49 CONUS states, excluding AK and HI):
##   sbatch --array=1-49 01b_Extraction_Pts_v03.sh
##
## Each task index selects a unique state FIPS code from the list in the R script:
##   task 1 → FIPS 01 (Alabama)
##   task 2 → FIPS 04 (Arizona)
##   task 3 → FIPS 05 (Arkansas)
##   ...and so on
