#!/usr/bin/env bash

# =========================================================================== #
# X_Download_Census_Block_Shapefiles.sh
# Download Census TIGER/Line tabblock shapefiles expected by this pipeline.
#
# Usage:
#   bash code/X_Download_Census_Block_Shapefiles.sh [config_path]
#
# If config_path is omitted, the script looks for config.yaml in cwd then ../.
# =========================================================================== #

set -euo pipefail

# ---- Resolve config path ----------------------------------------------------
if [[ $# -ge 1 ]]; then
  CONFIG_PATH="$1"
elif [[ -f "config.yaml" ]]; then
  CONFIG_PATH="config.yaml"
elif [[ -f "../config.yaml" ]]; then
  CONFIG_PATH="../config.yaml"
else
  echo "ERROR: config.yaml not found. Pass it as the first argument." >&2
  exit 1
fi

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "ERROR: Config file not found at $CONFIG_PATH" >&2
  exit 1
fi

# ---- Check required tools ---------------------------------------------------
if ! command -v Rscript >/dev/null 2>&1; then
  echo "ERROR: Rscript is required to parse config.yaml." >&2
  exit 1
fi

HAS_CURL=0
HAS_WGET=0

if command -v curl >/dev/null 2>&1; then
  HAS_CURL=1
fi

if command -v wget >/dev/null 2>&1; then
  HAS_WGET=1
fi

if [[ "$HAS_CURL" -eq 1 ]]; then
  DL_CMD="curl"
elif [[ "$HAS_WGET" -eq 1 ]]; then
  DL_CMD="wget"
else
  echo "ERROR: curl or wget is required to download shapefiles." >&2
  exit 1
fi

# Optional override: DOWNLOADER=curl or DOWNLOADER=wget
if [[ -n "${DOWNLOADER:-}" ]]; then
  case "$DOWNLOADER" in
    curl)
      if [[ "$HAS_CURL" -ne 1 ]]; then
        echo "ERROR: DOWNLOADER=curl requested but curl is not installed." >&2
        exit 1
      fi
      DL_CMD="curl"
      ;;
    wget)
      if [[ "$HAS_WGET" -ne 1 ]]; then
        echo "ERROR: DOWNLOADER=wget requested but wget is not installed." >&2
        exit 1
      fi
      DL_CMD="wget"
      ;;
    *)
      echo "ERROR: DOWNLOADER must be 'curl' or 'wget'." >&2
      exit 1
      ;;
  esac
fi

if ! command -v unzip >/dev/null 2>&1; then
  echo "ERROR: unzip is required to extract shapefile archives." >&2
  exit 1
fi

# ---- Parse config with R (robust YAML parsing) ------------------------------
readarray -t CFG < <(Rscript - "$CONFIG_PATH" <<'RSCRIPT'
suppressPackageStartupMessages(library(yaml))

args <- commandArgs(trailingOnly = TRUE)
config_path <- args[1]
cfg <- yaml::read_yaml(config_path)

stopifnot(!is.null(cfg$working_dir))
stopifnot(!is.null(cfg$paths$block_shapefile_dir))
stopifnot(!is.null(cfg$processing$decyear))

working_dir <- cfg$working_dir
block_dir <- cfg$paths$block_shapefile_dir

if (!grepl("^/", block_dir)) {
  block_dir <- file.path(working_dir, block_dir)
}

# CONUS + DC. Excludes AK (02), HI (15), and territories.
conus_dc <- c(
  "01","04","05","06","08","09","10","11","12","13","16","17","18","19",
  "20","21","22","23","24","25","26","27","28","29","30","31","32","33",
  "34","35","36","37","38","39","40","41","42","44","45","46","47","48",
  "49","50","51","53","54","55","56"
)

state_fips_cfg <- cfg$processing$state_fips
if (is.character(state_fips_cfg) && length(state_fips_cfg) == 1 && state_fips_cfg == "Nationwide") {
  state_fips <- conus_dc
} else {
  state_fips <- sprintf("%02s", as.character(unlist(state_fips_cfg)))
}

decyears <- as.character(as.integer(unlist(cfg$processing$decyear)))

cat(working_dir, "\n", sep = "")
cat(block_dir, "\n", sep = "")
cat(paste(decyears, collapse = ","), "\n", sep = "")
cat(paste(state_fips, collapse = ","), "\n", sep = "")
RSCRIPT
)

if [[ ${#CFG[@]} -lt 4 ]]; then
  echo "ERROR: Failed to parse config values." >&2
  exit 1
fi

WORKING_DIR="${CFG[0]}"
BLOCK_DIR="${CFG[1]}"
DECYEARS_CSV="${CFG[2]}"
STATE_FIPS_CSV="${CFG[3]}"

IFS=',' read -r -a DECYEARS <<< "$DECYEARS_CSV"
IFS=',' read -r -a STATE_FIPS <<< "$STATE_FIPS_CSV"

mkdir -p "$BLOCK_DIR"
cd "$WORKING_DIR"

# ---- URL helper -------------------------------------------------------------
year_settings() {
  local decyear="$1"
  case "$decyear" in
    2020)
      echo "https://www2.census.gov/geo/tiger/TIGER2020/TABBLOCK20 tabblock20 tl_2020"
      ;;
    2010)
      echo "https://www2.census.gov/geo/tiger/TIGER2010/TABBLOCK/2010 tabblock10 tl_2010"
      ;;
    2000)
      echo "https://www2.census.gov/geo/tiger/TIGER2010/TABBLOCK/2000 tabblock00 tl_2010"
      ;;
    *)
      return 1
      ;;
  esac
}

download_zip() {
  local url="$1"
  local dest="$2"

  if [[ "$DL_CMD" == "curl" ]]; then
    # Census servers can intermittently fail HTTP/2 streams; force HTTP/1.1.
    if curl -fL \
      --http1.1 \
      --retry 8 \
      --retry-delay 5 \
      --retry-all-errors \
      --connect-timeout 30 \
      --max-time 900 \
      -H "Connection: close" \
      -A "Mozilla/5.0" \
      -o "$dest" "$url"; then
      return 0
    fi

    if [[ "$HAS_WGET" -eq 1 ]]; then
      echo "WARN: curl failed for $url; retrying with wget..."
      wget --tries=8 --waitretry=5 -O "$dest" "$url"
      return $?
    fi

    return 1
  else
    wget --tries=8 --waitretry=5 -O "$dest" "$url"
  fi
}

echo "=== Downloading census block shapefiles ==="
echo "Config: $CONFIG_PATH"
echo "Block output directory: $BLOCK_DIR"

tmp_zip_dir="$BLOCK_DIR/.zip_tmp"
mkdir -p "$tmp_zip_dir"

failures=()

for decyear in "${DECYEARS[@]}"; do
  if ! yset="$(year_settings "$decyear")"; then
    echo "WARNING: Unsupported decennial year '$decyear'; skipping. Supported: 2000, 2010, 2020."
    continue
  fi

  # shellcheck disable=SC2086
  read -r base_url suffix prefix <<< "$yset"

  year_dir="$BLOCK_DIR/$decyear"
  mkdir -p "$year_dir"

  echo "--- Year $decyear ---"

  for st in "${STATE_FIPS[@]}"; do
    zip_name="${prefix}_${st}_${suffix}.zip"
    shp_name="${prefix}_${st}_${suffix}.shp"
    shp_path="$year_dir/$shp_name"
    zip_path="$tmp_zip_dir/$zip_name"
    url="$base_url/$zip_name"

    if [[ -f "$shp_path" ]]; then
      echo "skip: $shp_name already present"
      continue
    fi

    echo "download: $zip_name"
    if ! download_zip "$url" "$zip_path"; then
      echo "ERROR: failed download $url"
      failures+=("$decyear:$st")
      rm -f "$zip_path"
      continue
    fi

    if ! unzip -o -q "$zip_path" -d "$year_dir"; then
      echo "ERROR: failed unzip $zip_name"
      failures+=("$decyear:$st")
      rm -f "$zip_path"
      continue
    fi

    rm -f "$zip_path"
  done
done

rmdir "$tmp_zip_dir" 2>/dev/null || true

if [[ ${#failures[@]} -gt 0 ]]; then
  echo ""
  echo "Completed with failures (${#failures[@]}):"
  for f in "${failures[@]}"; do
    echo "  - $f"
  done
  exit 2
fi

echo ""
echo "Done. Census block shapefiles are available under: $BLOCK_DIR"
