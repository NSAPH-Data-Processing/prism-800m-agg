#!/bin/bash
# =========================================================================== #
# setup_env.sh — Cluster environment setup for the PRISM 800m pipeline
# =========================================================================== #
# Run once from the project root to install all required R packages:
#
#   bash setup_env.sh
#
# This script loads the required modules and sets environment variables that
# several packages need to compile and load correctly on this cluster, then
# calls setup_env.R.
# =========================================================================== #

set -euo pipefail

# ---- 1. Load required modules ----------------------------------------------
module load R/4.4.1
module load cmake          # required by fs and s2 (build libuv / abseil-cpp)

# ---- 2. Fix runtime library path for xml2 ----------------------------------
# xml2's pkg-config picks up libxml2 from the conda installation, which links
# against conda's libiconv. Without this, xml2.so fails to load at runtime
# with "libiconv.so.2: cannot open shared object file".
CONDA_LIB="/n/sw/Miniforge3-24.11.3-0/lib"
if [ -d "$CONDA_LIB" ]; then
  export LD_LIBRARY_PATH="${CONDA_LIB}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

# ---- 3. Run from project root (so .Rprofile, if any, is picked up) ---------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Environment ==="
echo "R:     $(which Rscript) ($(Rscript --version 2>&1))"
echo "cmake: $(which cmake) ($(cmake --version | head -1))"
echo "LD_LIBRARY_PATH: ${LD_LIBRARY_PATH:-<not set>}"
echo ""

Rscript setup_env.R
