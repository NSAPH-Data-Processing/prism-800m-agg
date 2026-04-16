#!/bin/bash
#SBATCH -J extract_prism       # Job name
#SBATCH -p hsph                # Partition / queue
#SBATCH --array=198101-198149,198201-198249,198301-198349,198401-198449,198501-198549,198601-198649,198701-198749,198801-198849,198901-198949,199001-199049,199101-199149,199201-199249,199301-199349,199401-199449,199501-199549,199601-199649,199701-199749,199801-199849,199901-199949,200001-200049,200101-200149,200201-200249,200301-200349,200401-200449,200501-200549,200601-200649,200701-200749,200801-200849,200901-200949,201001-201049,201101-201149,201201-201249,201301-201349,201401-201449,201501-201549,201601-201649,201701-201749,201801-201849,201901-201949,202001-202049,202101-202149,202201-202249,202301-202349
#SBATCH -c 16                  # Cores per array task
#SBATCH --mem 64GB             # Memory per array task
#SBATCH -t 0-12:00             # Time limit (D-HH:MM)
#SBATCH -o extract_prism_%a.out  # Log file (%a = array task index)

## The array task ID encodes year and state as YYYYSS (e.g. 201001 = year 2010,
## state index 01). Specify --array at submission time via 02c (recommended) or
## directly, e.g. for year 2010 across all 49 states:
##   sbatch --array=201001-201049 code/02b_PRISM_Raster_Extract_v03.sh

## ---- Edit these two lines before submitting --------------------------------
PROJECT_DIR="/n/dominici_lab/Lab/data_processing/shreya_prism_800m/prism-800m-agg"   # must match working_dir in config.yaml
R_VERSION="4.4.1"                        # must match r_version in config.yaml
## ---------------------------------------------------------------------------

CONFIG="${PROJECT_DIR}/config.yaml"

: "${SLURM_ARRAY_TASK_ID:?This script must be submitted as a Slurm array job. Use: sbatch code/02b_PRISM_Raster_Extract_v03.sh or code/02c_PRISM_Raster_Extract_Exe_v03.sh}"

year=$(echo $SLURM_ARRAY_TASK_ID | cut -c 1-4)
state=$(echo $SLURM_ARRAY_TASK_ID | cut -c 5-6)

cd $PROJECT_DIR

source code/slurm_runtime_env.sh
Rscript code/02a_PRISM_Raster_Extract_v03.R $year $state $CONFIG
