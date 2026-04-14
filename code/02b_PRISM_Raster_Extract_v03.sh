#!/bin/bash -l

#$ -N extract_pris  ## Name the job
#$ -j y         ## Merge error & output files
#$ -pe omp 16

## This script is based on a university computing cluster and is likely to
## vary based on your computing environment
## Learn more about high performance computing:
##		https://github.com/Climate-CAFE/hpc_batch_jobs_micro_tutorial

year=$(echo $SGE_TASK_ID | cut -c 1-4)
state=$(echo $SGE_TASK_ID | cut -c 5-6)

## Absolute path to config.yaml (edit before submitting)
CONFIG="/pathtoscript/config.yaml"

module load R/4.3.1
Rscript /pathtoscript/02a_PRISM_Raster_Extract_v03.R $year $state $CONFIG

## In Terminal, cd to the directory in which this bash script is located. 
## The task ID will be a concatenation of the year and state index (01-49). For example,
## for Alabama (FIPS = 01) in 2020, the -t ID would be 202001, while for 
## Massachusetts (FIPS = 25) in 2021, it would be 202120 (20 because it is
## 20th in the list of FIPS codes against which the state index is passed. 
## To submit for all states and years, 20 lines are needed, as below:
##
## qsub -P acres -t 200001-200006 02b_PRISM_Raster_Extract_v03.sh