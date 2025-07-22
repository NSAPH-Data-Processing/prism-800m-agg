#!/bin/bash -l

#$ -N prism10  ## Name the job
#$ -j y         ## Merge error & output files
#$ -pe omp 16    ## Request between 16 GB and 32 GB of RAM (may require more - see below)

## This script is based on a university computing cluster and is likely to
## vary based on your computing environment
## Learn more about high performance computing:
##		https://github.com/Climate-CAFE/hpc_batch_jobs_micro_tutorial

module load R/4.2.1
Rscript /pathtoscript/00a_Create_Fishnet_PRISMv2_800m_v03.R 

## In Terminal, cd to the directory in which this bash script is located. Then,
## submit the job using the below:
##
## qsub -P acres 00b_Create_Fishnet_PRISMv2_800m_v03.sh
