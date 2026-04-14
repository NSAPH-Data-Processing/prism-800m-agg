#!/bin/bash
# Submits 03b as one array job per year, covering all 43 CONUS states
# included in the original run (NE states already processed separately).
# The task ID is YYYYSS (year + 2-digit state index).
#
# Usage:
#   (1) chmod +x 03c_BlockPop_Wt_ZCTA_PRISM_800m_Exe_v03.sh
#   (2) ./03c_BlockPop_Wt_ZCTA_PRISM_800m_Exe_v03.sh

sbatch --array=198001-198043 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
sbatch --array=198101-198143 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
sbatch --array=198201-198243 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
sbatch --array=198301-198343 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
sbatch --array=198401-198443 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
sbatch --array=198501-198543 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
sbatch --array=198601-198643 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
sbatch --array=198701-198743 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
sbatch --array=198801-198843 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
sbatch --array=198901-198943 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
sbatch --array=199001-199043 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
sbatch --array=199101-199143 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
sbatch --array=199201-199243 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
sbatch --array=199301-199343 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
sbatch --array=199401-199443 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
sbatch --array=199501-199543 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
sbatch --array=199601-199643 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
sbatch --array=199701-199743 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
sbatch --array=199801-199843 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
sbatch --array=199901-199943 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
sbatch --array=200001-200043 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
sbatch --array=200101-200143 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
sbatch --array=200201-200243 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
