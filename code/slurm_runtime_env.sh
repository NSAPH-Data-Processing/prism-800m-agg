#!/bin/bash
# Shared runtime environment for SLURM jobs in this pipeline.
# Ensures R runs with the same dynamic library settings used during package install.

set -euo pipefail

# Require caller to pass R version in env var.
: "${R_VERSION:?R_VERSION is required}"

module load R/${R_VERSION}

# xml2 (used by tidycensus) may link against libiconv from Miniforge.
CONDA_LIB="/n/sw/Miniforge3-24.11.3-0/lib"
if [ -d "$CONDA_LIB" ]; then
  export LD_LIBRARY_PATH="${CONDA_LIB}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi
