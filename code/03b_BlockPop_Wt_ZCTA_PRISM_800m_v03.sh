#!/bin/bash -l

#$ -N pris_bl_zcta  ## Name the job
#$ -j y         ## Merge error & output files
#$ -pe omp 28  ## Request between 16 GB and 32 GB of RAM (may require more - see below)

## This script is based on a university computing cluster and is likely to
## vary based on your computing environment
## Learn more about high performance computing:
##		https://github.com/Climate-CAFE/hpc_batch_jobs_micro_tutorial

year=$(echo $SGE_TASK_ID | cut -c 1-4)
state=$(echo $SGE_TASK_ID | cut -c 5-6)

module load R/4.3.1
Rscript /pathtoscript/03a_BlockPop_Wt_ZCTA_PRISM_800m_v03.R $year $state

## In Terminal, cd to the directory in which this bash script is located. 
## The task ID will be a concatenation of the year and state index (01-49). For example,
## for Alabama (FIPS = 01) in 2020, the -t ID would be 202001, while for 
## Massachusetts (FIPS = 25) in 2021, it would be 202120 (20 because it is
## 20th in the list of FIPS codes against which the state index is passed. 
## To submit for all states and years, 20 lines are needed, as below:
##
## qsub -P acres -t 200001-200006 03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh