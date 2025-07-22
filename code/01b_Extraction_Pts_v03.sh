#!/bin/bash -l

#$ -N prismpts  ## Name the job
#$ -j y         ## Merge error & output files
#$ -pe omp 4    

## This script is based on a university computing cluster and is likely to
## vary based on your computing environment
## Learn more about high performance computing:
##		https://github.com/Climate-CAFE/hpc_batch_jobs_micro_tutorial

module load R/4.4.0
Rscript /pathtoscript/01a_Extraction_Pts_v03.R $SGE_TASK_ID

## In Terminal, cd to the directory in which this bash script is located. Then,
## submit the job as an array *for each fips* with this command in Terminal:
##
## qsub -P acres -t 1-6 01b_Extraction_Pts_v03.sh
##
## The 'array' job is indicated by the $SGE_TASK_ID and indication in the 
## job submission '-t 1-6'. This will run the script six separate times,
## with a different input passed to the script each time. In this case, the 
## input will be used to select a unique state FIPS code from a list:
##      01a_Extraction_Pts_v03.R $SGE_TASK_ID = 1 (build points for FIPS 01 - Alabama)
##      01a_Extraction_Pts_v03.R $SGE_TASK_ID = 2 (build points for FIPS 04 - Arizona)
##      01a_Extraction_Pts_v03.R $SGE_TASK_ID = 3 (build points for FIPS 05 - Arkansas)
##      01a_Extraction_Pts_v03.R $SGE_TASK_ID = 4 (build points for FIPS 06 - California)
##      01a_Extraction_Pts_v03.R $SGE_TASK_ID = 5 (build points for FIPS 08 - Colorado)
##      01a_Extraction_Pts_v03.R $SGE_TASK_ID = 6 (build points for FIPS 09 - Connecticut)
