#!/usr/bin/env bash
# Download one Census TIGER/Line tabblock shapefile archive.
#
# Usage:
#   bash code/X_Download_Census_Block_Shapefile_v01.sh DECYEAR STATE_FIPS OUTPUT_DIR

set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: bash code/X_Download_Census_Block_Shapefile_v01.sh DECYEAR STATE_FIPS OUTPUT_DIR" >&2
  exit 1
fi

DECYEAR="$1"
STATE_FIPS="$2"
OUTPUT_DIR="$3"

case "$DECYEAR" in
  2020)
    BASE_URL="https://www2.census.gov/geo/tiger/TIGER2020/TABBLOCK20"
    SUFFIX="tabblock20"
    PREFIX="tl_2020"
    ;;
  2010)
    BASE_URL="https://www2.census.gov/geo/tiger/TIGER2010/TABBLOCK/2010"
    SUFFIX="tabblock10"
    PREFIX="tl_2010"
    ;;
  2000)
    BASE_URL="https://www2.census.gov/geo/tiger/TIGER2010/TABBLOCK/2000"
    SUFFIX="tabblock00"
    PREFIX="tl_2010"
    ;;
  *)
    echo "Unsupported decennial year: $DECYEAR" >&2
    exit 1
    ;;
esac

if command -v curl >/dev/null 2>&1; then
  DL_CMD="curl"
elif command -v wget >/dev/null 2>&1; then
  DL_CMD="wget"
else
  echo "ERROR: curl or wget is required." >&2
  exit 1
fi

if ! command -v unzip >/dev/null 2>&1; then
  echo "ERROR: unzip is required." >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

ZIP_NAME="${PREFIX}_${STATE_FIPS}_${SUFFIX}.zip"
SHP_NAME="${PREFIX}_${STATE_FIPS}_${SUFFIX}.shp"
ZIP_PATH="${OUTPUT_DIR}/${ZIP_NAME}"
SHP_PATH="${OUTPUT_DIR}/${SHP_NAME}"
STEM="${OUTPUT_DIR}/${PREFIX}_${STATE_FIPS}_${SUFFIX}"
URL="${BASE_URL}/${ZIP_NAME}"
REQUIRED_FILES=("${STEM}.shp" "${STEM}.shx" "${STEM}.dbf" "${STEM}.prj")

all_present=1
for required_file in "${REQUIRED_FILES[@]}"; do
  if [[ ! -s "$required_file" ]]; then
    all_present=0
  fi
done

if [[ "$all_present" -eq 1 ]]; then
  echo "Reusing $SHP_PATH"
  exit 0
fi

echo "Downloading $URL"
if [[ "$DL_CMD" == "curl" ]]; then
  curl -fL \
    --http1.1 \
    --retry 8 \
    --retry-delay 5 \
    --retry-all-errors \
    --connect-timeout 30 \
    --max-time 900 \
    -H "Connection: close" \
    -A "Mozilla/5.0" \
    -o "$ZIP_PATH" "$URL"
else
  wget --tries=8 --waitretry=5 -O "$ZIP_PATH" "$URL"
fi

unzip -o -q "$ZIP_PATH" -d "$OUTPUT_DIR"
rm -f "$ZIP_PATH"

missing_files=()
for required_file in "${REQUIRED_FILES[@]}"; do
  if [[ ! -s "$required_file" ]]; then
    missing_files+=("$required_file")
  fi
done

if [[ "${#missing_files[@]}" -gt 0 ]]; then
  echo "ERROR: shapefile download did not produce all required components:" >&2
  printf '  %s\n' "${missing_files[@]}" >&2
  exit 1
fi

echo "Wrote $SHP_PATH"
