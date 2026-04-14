#!/bin/bash
#SBATCH -J prism_fishnet       # Job name
#SBATCH -p hsph                # Partition / queue
#SBATCH -c 16                  # Cores
#SBATCH --mem 64GB             # Memory
#SBATCH -t 0-04:00             # Time limit (D-HH:MM)
#SBATCH -o prism_fishnet_%j.out  # Log file (%j = job ID)

## Absolute path to config.yaml (edit before submitting)
CONFIG="/pathtoscript/config.yaml"

module load R/4.2.1
Rscript /pathtoscript/00a_Create_Fishnet_PRISMv2_800m_v03.R $CONFIG

## Submit with:
##   sbatch 00b_Create_Fishnet_PRISMv2_800m_v03.sh
