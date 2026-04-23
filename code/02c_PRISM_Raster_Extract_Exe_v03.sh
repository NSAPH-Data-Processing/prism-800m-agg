#!/bin/bash
# Submits 02b as one array job per year, covering all 49 CONUS states.
# The task ID is YYYYSS (year + 2-digit state index, e.g. 202001-202049).
#
# Usage:
#   (1) chmod +x 02c_PRISM_Raster_Extract_Exe_v03.sh
#   (2) ./02c_PRISM_Raster_Extract_Exe_v03.sh

sbatch --array=200001-200049 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=200101-200149 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=200201-200249 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=200301-200349 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=200401-200449 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=200501-200549 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=200601-200649 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=200701-200749 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=200801-200849 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=200901-200949 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=201001-201049 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=201101-201149 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=201201-201249 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=201301-201349 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=201401-201449 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=201501-201549 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=201601-201649 ./02b_PRISM_Raster_Extract_v03.sh
