# =========================================================================== #
# X_Download_PRISM800m_v01.R
# Download PRISM 800m daily data and supporting inputs for this pipeline.
#
# Usage:
#   Rscript code/X_Download_PRISM800m_v01.R /abs/path/to/config.yaml
#
# If config path is omitted, script looks for config.yaml in cwd then ../.
# =========================================================================== #

library(yaml)
library(tigris)
library(sf)

options(timeout = 3600)
options(tigris_use_cache = TRUE)

# ---- Load config ------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
config_path <- if (length(args) > 0 && grepl("\\.ya?ml$", args[length(args)])) {
  args[length(args)]
} else if (file.exists("config.yaml")) {
  "config.yaml"
} else if (file.exists("../config.yaml")) {
  "../config.yaml"
} else {
  stop("config.yaml not found. Pass its path as the last command-line argument.")
}

config <- yaml::read_yaml(config_path)
setwd(config$working_dir)

# ---- Config-derived paths and parameters -----------------------------------
rawdata_dir <- sub("/+$", "", config$paths$rawdata_dir)
temp_zip_dir <- file.path(rawdata_dir, "zip_files")
dir.create(temp_zip_dir, recursive = TRUE, showWarnings = FALSE)

vars <- unique(as.character(unlist(config$processing$exp_list)))
years_data <- as.integer(unlist(config$processing$years_to_process))

if (length(vars) == 0 || length(years_data) == 0) {
  stop("No variables or years_to_process found in config.yaml under processing.")
}

base_url <- "https://data.prism.oregonstate.edu/time_series/us/an/800m"

# ---- Helpers ----------------------------------------------------------------
download_with_retry <- function(url, destfile, attempts = 5, wait_seconds = 10) {
  for (attempt in seq_len(attempts)) {
    status <- tryCatch(
      utils::download.file(url = url, destfile = destfile, mode = "wb", quiet = TRUE),
      error = function(e) e
    )

    if (is.numeric(status) && status == 0 && file.exists(destfile)) {
      return(TRUE)
    }

    if (attempt < attempts) {
      message("..... Download failed (attempt ", attempt, "/", attempts,
              "). Retrying in ", wait_seconds, " seconds.")
      Sys.sleep(wait_seconds)
    }
  }

  FALSE
}

day_already_extracted <- function(target_dir, day_yyyymmdd) {
  if (!dir.exists(target_dir)) return(FALSE)
  extracted <- list.files(
    target_dir,
    pattern = paste0(day_yyyymmdd, ".*\\.(tif|tiff|bil|img)$"),
    ignore.case = TRUE
  )
  length(extracted) > 0
}

extract_tif_member <- function(zipfile, exdir) {
  members <- utils::unzip(zipfile, list = TRUE)
  tif_members <- members$Name[grepl("\\.tif$", members$Name, ignore.case = TRUE)]

  if (length(tif_members) == 0) {
    stop("No .tif member found in zip archive: ", zipfile)
  }

  utils::unzip(zipfile, files = tif_members, exdir = exdir, overwrite = FALSE)
  unlink(zipfile)
}

# ---- STEP 1: Download and extract PRISM daily files ------------------------
message("=== STEP 1: Download PRISM 800m daily data ===")

failed_downloads <- character(0)

for (var in vars) {
  message("---------------------------------------------------------------------")
  message("Variable: ", var)

  for (year_data in years_data) {
    message("..... Processing year ", year_data)

    out_dir <- file.path(rawdata_dir, var, as.character(year_data))
    dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

    days <- format(
      seq(as.Date(paste0(year_data, "-01-01")), as.Date(paste0(year_data, "-12-31")), by = "day"),
      format = "%Y%m%d"
    )

    for (day in days) {
      zip_name <- paste0("prism_", var, "_us_30s_", day, ".zip")
      dl_link <- paste0(base_url, "/", var, "/daily/", year_data, "/", zip_name)
      dl_file <- file.path(temp_zip_dir, zip_name)

      if (day_already_extracted(out_dir, day)) {
        next
      }

      if (!file.exists(dl_file)) {
        ok <- download_with_retry(dl_link, dl_file)
        if (!ok) {
          failed_downloads <- c(failed_downloads, paste(var, day, sep = ":"))
          message("..... ERROR: Failed to download ", dl_link)
          next
        }
      }

      unzip_ok <- tryCatch({
        extract_tif_member(dl_file, out_dir)
        TRUE
      }, error = function(e) {
        message("..... ERROR: unzip failed for ", dl_file, " (", conditionMessage(e), ")")
        FALSE
      })

      if (!unzip_ok) {
        failed_downloads <- c(failed_downloads, paste(var, day, sep = ":"))
      }
    }
  }
}

if (length(failed_downloads) > 0) {
  message("\nDownload/unzip failures (", length(failed_downloads), "):")
  message(paste0("  - ", failed_downloads, collapse = "\n"))
} else {
  message("\nAll requested PRISM downloads and extractions completed.")
}

# ---- STEP 2: Download census block shapefiles via tigris -------------------
message("\n=== STEP 2: Download block shapefiles ===")

block_geo_root <- config$paths$block_shapefile_dir
if (!dir.exists(block_geo_root)) {
  dir.create(block_geo_root, recursive = TRUE, showWarnings = FALSE)
}

decyears <- as.integer(unlist(config$processing$decyear))
state_fips_cfg <- config$processing$state_fips

get_state_fips <- function(state_fips_config) {
  if (is.character(state_fips_config) && length(state_fips_config) == 1 && state_fips_config == "Nationwide") {
    st <- tigris::states(year = 2020, cb = TRUE)
    st <- st[st$REGION %in% c("1", "2", "3", "4") & !st$STATEFP %in% c("02", "15"), ]
    return(sort(unique(st$STATEFP)))
  }

  fips <- as.character(unlist(state_fips_config))
  sprintf("%02s", fips)
}

state_fips <- get_state_fips(state_fips_cfg)

for (decyear in decyears) {
  year_dir <- file.path(block_geo_root, as.character(decyear))
  dir.create(year_dir, recursive = TRUE, showWarnings = FALSE)

  for (state in state_fips) {
    shp_stem <- paste0("tl_", decyear, "_", state, "_tabblock", substr(as.character(decyear), 3, 4))
    shp_file <- file.path(year_dir, paste0(shp_stem, ".shp"))

    if (file.exists(shp_file)) {
      next
    }

    blocks_sf <- tryCatch(
      tigris::blocks(year = decyear, state = state),
      error = function(e) {
        message("..... WARNING: Could not download blocks for year ", decyear,
                ", state ", state, " (", conditionMessage(e), ")")
        NULL
      }
    )

    if (!is.null(blocks_sf)) {
      tryCatch(
        sf::st_write(blocks_sf, shp_file, delete_layer = TRUE, quiet = TRUE),
        error = function(e) {
          message("..... WARNING: Could not write shapefile ", shp_file,
                  " (", conditionMessage(e), ")")
        }
      )
    }
  }
}

# ---- STEP 3: Build CONUS FIPS dataset --------------------------------------
message("\n=== STEP 3: Build FIPS CSV ===")

fips_dir <- dirname(config$paths$fips_csv)
dir.create(fips_dir, recursive = TRUE, showWarnings = FALSE)

fips <- tigris::states(year = 2020, cb = TRUE)
fips <- fips[fips$REGION %in% c("1", "2", "3", "4") & !fips$STATEFP %in% c("02", "15"), ]
fips <- as.data.frame(fips)
fips$geometry <- NULL
fips$StFIPS <- fips$STATEFP
fips <- fips[c("StFIPS", "STUSPS", "NAME")]

utils::write.csv(fips, config$paths$fips_csv, row.names = FALSE)

message("Done.")
