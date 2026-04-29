#!/bin/bash
# Submits 01b as one array job per decennial census year, covering all 49 CONUS states.
# Each submission uses task IDs 1-49 (state indices) with the census year passed as an argument.
#
# Usage:
#   (1) chmod +x 01c_Extraction_Pts_Exe_v03.sh
#   (2) ./01c_Extraction_Pts_Exe_v03.sh

sbatch --array=1-49 -J prism_pts_2000 -o prism_pts_2000_%a.out ./01b_Extraction_Pts_v03.sh 2000
sbatch --array=1-49 -J prism_pts_2010 -o prism_pts_2010_%a.out ./01b_Extraction_Pts_v03.sh 2010
sbatch --array=1-49 -J prism_pts_2020 -o prism_pts_2020_%a.out ./01b_Extraction_Pts_v03.sh 2020
