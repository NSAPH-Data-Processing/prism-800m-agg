#!/bin/bash
#SBATCH -J extract_prism       # Job name
#SBATCH -p hsph                # Partition / queue
#SBATCH -c 16                  # Cores per array task
#SBATCH --mem 64GB             # Memory per array task
#SBATCH -t 0-12:00             # Time limit (D-HH:MM)
#SBATCH -o extract_prism_%a.out  # Log file (%a = array task index)

## The array task ID encodes year and state as YYYYSS (e.g. 201001 = year 2010,
## state index 01). Specify --array at submission time via 02c (recommended) or
## directly, e.g. for year 2010 across all 49 states:
##   sbatch --array=201001-201049 02b_PRISM_Raster_Extract_v03.sh

year=$(echo $SLURM_ARRAY_TASK_ID | cut -c 1-4)
state=$(echo $SLURM_ARRAY_TASK_ID | cut -c 5-6)

## Absolute path to config.yaml (edit before submitting)
CONFIG="/pathtoscript/config.yaml"

module load R/4.3.1
Rscript /pathtoscript/02a_PRISM_Raster_Extract_v03.R $year $state $CONFIG
