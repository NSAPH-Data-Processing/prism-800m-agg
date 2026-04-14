#!/bin/bash
#SBATCH -J prism_zcta_clean    # Job name
#SBATCH -p hsph                # Partition / queue
#SBATCH -c 16                  # Cores
#SBATCH --mem 64GB             # Memory
#SBATCH -t 0-06:00             # Time limit (D-HH:MM)
#SBATCH -o prism_zcta_clean_%j.out  # Log file (%j = job ID)

## Absolute path to config.yaml (edit before submitting)
CONFIG="/pathtoscript/config.yaml"

module load R/4.4.0
Rscript /pathtoscript/04_Zip2Zcta_Cleaning_PRISM_allyrs_v01.R $CONFIG

## Submit with:
##   sbatch 04_Zip2Zcta_Cleaning_PRISM_allyrs_v01.sh
