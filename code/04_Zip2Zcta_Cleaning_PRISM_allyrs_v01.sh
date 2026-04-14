#!/bin/bash -l

#$ -N zct_wt  ## Name the job
#$ -j y         ## Merge error & output files
#$ -pe omp 16  ## Request between 16 GB and 32 GB of RAM (may require more - see below)


## This script is based on a university computing cluster and is likely to
## vary based on your computing environment
## Learn more about high performance computing:
##		https://github.com/Climate-CAFE/hpc_batch_jobs_micro_tutorial

## Absolute path to config.yaml (edit before submitting)
CONFIG="/pathtoscript/config.yaml"

module load R/4.4.0
Rscript /pathtoscript/04_Zip2Zcta_Cleaning_PRISM_allyrs_v01.R $CONFIG

## In Terminal, cd to the directory in which this bash script is located. 
##
## qsub -P acres 05_Zip2Zcta_Cleaning_PRISM_allyrs_v01.sh
