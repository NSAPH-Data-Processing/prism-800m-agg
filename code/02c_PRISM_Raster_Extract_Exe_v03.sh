#!/bin/bash
# Submits 02b as one array job per year, covering all 49 CONUS states.
# Each submission uses task IDs 1-49 (state indices) with the year passed as an argument.
#
# Usage:
#   (1) chmod +x 02c_PRISM_Raster_Extract_Exe_v03.sh
#   (2) ./02c_PRISM_Raster_Extract_Exe_v03.sh

sbatch --array=1-49 -J extract_prism_2000 -o extract_prism_2000_%a.out ./02b_PRISM_Raster_Extract_v03.sh 2000
sbatch --array=1-49 -J extract_prism_2001 -o extract_prism_2001_%a.out ./02b_PRISM_Raster_Extract_v03.sh 2001
sbatch --array=1-49 -J extract_prism_2002 -o extract_prism_2002_%a.out ./02b_PRISM_Raster_Extract_v03.sh 2002
sbatch --array=1-49 -J extract_prism_2003 -o extract_prism_2003_%a.out ./02b_PRISM_Raster_Extract_v03.sh 2003
sbatch --array=1-49 -J extract_prism_2004 -o extract_prism_2004_%a.out ./02b_PRISM_Raster_Extract_v03.sh 2004
sbatch --array=1-49 -J extract_prism_2005 -o extract_prism_2005_%a.out ./02b_PRISM_Raster_Extract_v03.sh 2005
sbatch --array=1-49 -J extract_prism_2006 -o extract_prism_2006_%a.out ./02b_PRISM_Raster_Extract_v03.sh 2006
sbatch --array=1-49 -J extract_prism_2007 -o extract_prism_2007_%a.out ./02b_PRISM_Raster_Extract_v03.sh 2007
sbatch --array=1-49 -J extract_prism_2008 -o extract_prism_2008_%a.out ./02b_PRISM_Raster_Extract_v03.sh 2008
sbatch --array=1-49 -J extract_prism_2009 -o extract_prism_2009_%a.out ./02b_PRISM_Raster_Extract_v03.sh 2009
sbatch --array=1-49 -J extract_prism_2010 -o extract_prism_2010_%a.out ./02b_PRISM_Raster_Extract_v03.sh 2010
sbatch --array=1-49 -J extract_prism_2011 -o extract_prism_2011_%a.out ./02b_PRISM_Raster_Extract_v03.sh 2011
sbatch --array=1-49 -J extract_prism_2012 -o extract_prism_2012_%a.out ./02b_PRISM_Raster_Extract_v03.sh 2012
sbatch --array=1-49 -J extract_prism_2013 -o extract_prism_2013_%a.out ./02b_PRISM_Raster_Extract_v03.sh 2013
sbatch --array=1-49 -J extract_prism_2014 -o extract_prism_2014_%a.out ./02b_PRISM_Raster_Extract_v03.sh 2014
sbatch --array=1-49 -J extract_prism_2015 -o extract_prism_2015_%a.out ./02b_PRISM_Raster_Extract_v03.sh 2015
sbatch --array=1-49 -J extract_prism_2016 -o extract_prism_2016_%a.out ./02b_PRISM_Raster_Extract_v03.sh 2016


