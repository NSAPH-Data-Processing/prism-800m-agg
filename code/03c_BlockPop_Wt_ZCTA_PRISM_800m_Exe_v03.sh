# This script is set up to pass the call from script 02b to the command line
# forty separate times, once for each year and all states. This script can be
# run only after it has been converted to an executable using the process below:
# 
# To run the .sh file, do the following:
#
# (1) Open Terminal window on SCC and cd to the directory containing the .sh file
# (2) chmod +x 03c_BlockPop_Wt_ZCTA_PRISM_800m_Exe_v03.sh
# (3) Run the file with the following command in Terminal:
#     ./03c_BlockPop_Wt_ZCTA_PRISM_800m_Exe_v03.sh

qsub -P acres -t 198001-198043 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
qsub -P acres -t 198101-198143 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
qsub -P acres -t 198201-198243 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
qsub -P acres -t 198301-198343 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
qsub -P acres -t 198401-198443 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
qsub -P acres -t 198501-198543 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
qsub -P acres -t 198601-198643 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
qsub -P acres -t 198701-198743 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
qsub -P acres -t 198801-198843 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
qsub -P acres -t 198901-198943 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
qsub -P acres -t 199001-199043 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
qsub -P acres -t 199101-199143 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
qsub -P acres -t 199201-199243 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
qsub -P acres -t 199301-199343 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
qsub -P acres -t 199401-199443 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
qsub -P acres -t 199501-199543 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
qsub -P acres -t 199601-199643 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
qsub -P acres -t 199701-199743 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
qsub -P acres -t 199801-199843 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
qsub -P acres -t 199901-199943 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
qsub -P acres -t 200001-200043 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
qsub -P acres -t 200101-200143 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
qsub -P acres -t 200201-200243 ./03b_BlockPop_Wt_ZCTA_PRISM_800m_v03.sh
