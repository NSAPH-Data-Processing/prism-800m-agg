#!/bin/bash
#SBATCH -J prism_snakemake
#SBATCH -p hsph
#SBATCH -c 28
#SBATCH --mem=128GB
#SBATCH -t 2-00:00
#SBATCH -o prism_snakemake_%j.out

# Submit the Snakemake-orchestrated pipeline with:
#   sbatch code/run_snakemake.sbatch
#
# Optional examples:
#   sbatch code/run_snakemake.sbatch --dry-run
#   sbatch --export=ALL,SNAKEMAKE_CORES=16 code/run_snakemake.sbatch

set -euo pipefail

PROJECT_DIR="/n/dominici_lab/Lab/data_processing/shreya_prism_800m/prism-800m-agg"
CONFIG="${CONFIG:-${PROJECT_DIR}/config.yaml}"
R_VERSION="${R_VERSION:-4.4.1}"

SNAKEMAKE_CORES="${SNAKEMAKE_CORES:-${SLURM_CPUS_PER_TASK:-1}}"
SNAKEMAKE_MEM_MB="${SNAKEMAKE_MEM_MB:-128000}"
SNAKEMAKE_LATENCY_WAIT="${SNAKEMAKE_LATENCY_WAIT:-60}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-${PROJECT_DIR}/.workflow/cache}"

cd "$PROJECT_DIR"
mkdir -p .workflow "$XDG_CACHE_HOME"
export XDG_CACHE_HOME

export R_VERSION
source code/slurm_runtime_env.sh

if [ -n "${SNAKEMAKE_MODULE:-}" ]; then
  module load "$SNAKEMAKE_MODULE"
fi

if ! command -v snakemake >/dev/null 2>&1; then
  echo "ERROR: snakemake is not available on PATH."
  echo "Load it before submitting, or submit with SNAKEMAKE_MODULE=<module-name>."
  exit 127
fi

snakemake \
  --snakefile Snakefile \
  --configfile "$CONFIG" \
  --config "config_path=${CONFIG}" \
  --cores "$SNAKEMAKE_CORES" \
  --resources "mem_mb=${SNAKEMAKE_MEM_MB}" \
  --rerun-incomplete \
  --printshellcmds \
  --latency-wait "$SNAKEMAKE_LATENCY_WAIT" \
  "$@"
