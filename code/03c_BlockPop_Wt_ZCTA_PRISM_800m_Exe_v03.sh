#!/bin/bash
# Submits 03b as one array job per year, covering all 49 CONUS states.
# Each submission uses task IDs 1-49 (state indices) with the year passed as an argument.
#
# Usage:
#   (1) chmod +x 03c_BlockPop_Wt_ZCTA_PRISM_800m_Exe_v03.sh
#   (2) ./03c_BlockPop_Wt_ZCTA_PRISM_800m_Exe_v03.sh

sbatch --array=1-49 -J prism_bl_zcta_2000 -o prism_bl_zcta_2000_%a.out ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh 2000
sbatch --array=1-49 -J prism_bl_zcta_2001 -o prism_bl_zcta_2001_%a.out ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh 2001
sbatch --array=1-49 -J prism_bl_zcta_2002 -o prism_bl_zcta_2002_%a.out ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh 2002
sbatch --array=1-49 -J prism_bl_zcta_2003 -o prism_bl_zcta_2003_%a.out ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh 2003
sbatch --array=1-49 -J prism_bl_zcta_2004 -o prism_bl_zcta_2004_%a.out ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh 2004
sbatch --array=1-49 -J prism_bl_zcta_2005 -o prism_bl_zcta_2005_%a.out ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh 2005
sbatch --array=1-49 -J prism_bl_zcta_2006 -o prism_bl_zcta_2006_%a.out ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh 2006
sbatch --array=1-49 -J prism_bl_zcta_2007 -o prism_bl_zcta_2007_%a.out ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh 2007
sbatch --array=1-49 -J prism_bl_zcta_2008 -o prism_bl_zcta_2008_%a.out ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh 2008
sbatch --array=1-49 -J prism_bl_zcta_2009 -o prism_bl_zcta_2009_%a.out ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh 2009
sbatch --array=1-49 -J prism_bl_zcta_2010 -o prism_bl_zcta_2010_%a.out ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh 2010
sbatch --array=1-49 -J prism_bl_zcta_2011 -o prism_bl_zcta_2011_%a.out ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh 2011
sbatch --array=1-49 -J prism_bl_zcta_2012 -o prism_bl_zcta_2012_%a.out ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh 2012
sbatch --array=1-49 -J prism_bl_zcta_2013 -o prism_bl_zcta_2013_%a.out ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh 2013
sbatch --array=1-49 -J prism_bl_zcta_2014 -o prism_bl_zcta_2014_%a.out ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh 2014
sbatch --array=1-49 -J prism_bl_zcta_2015 -o prism_bl_zcta_2015_%a.out ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh 2015
sbatch --array=1-49 -J prism_bl_zcta_2016 -o prism_bl_zcta_2016_%a.out ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh 2016

