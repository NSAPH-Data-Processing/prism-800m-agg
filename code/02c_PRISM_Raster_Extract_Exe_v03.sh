#!/bin/bash
# Submits 02b as one array job per year, covering all 49 CONUS states.
# The task ID is YYYYSS (year + 2-digit state index, e.g. 202001-202049).
#
# Usage:
#   (1) chmod +x 02c_PRISM_Raster_Extract_Exe_v03.sh
#   (2) ./02c_PRISM_Raster_Extract_Exe_v03.sh

sbatch --array=198101-198149 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=198201-198249 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=198301-198349 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=198401-198449 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=198501-198549 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=198601-198649 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=198701-198749 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=198801-198849 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=198901-198949 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=199001-199049 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=199101-199149 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=199201-199249 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=199301-199349 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=199401-199449 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=199501-199549 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=199601-199649 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=199701-199749 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=199801-199849 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=199901-199949 ./02b_PRISM_Raster_Extract_v03.sh
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
sbatch --array=201701-201749 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=201801-201849 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=201901-201949 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=202001-202049 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=202101-202149 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=202201-202249 ./02b_PRISM_Raster_Extract_v03.sh
sbatch --array=202301-202349 ./02b_PRISM_Raster_Extract_v03.sh
