# =========================================================================== #
# X_Download_PRISM800m_v01.R
# Download PRISM 800m daily data and supporting inputs for this pipeline.
#
# Usage:
#   Rscript code/X_Download_PRISM800m_v01.R /abs/path/to/config.yaml
#   Rscript code/X_Download_PRISM800m_v01.R /abs/path/to/config.yaml --retry-failed
#
# If config path is omitted, script looks for config.yaml in cwd then ../.
# --retry-failed: re-attempt only files listed in failed_downloads.csv
# =========================================================================== #

library(yaml)
library(tigris)
library(sf)

options(timeout = 3600)
options(tigris_use_cache = TRUE)

prism_user_agent <- "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

# ---- Load config ------------------------------------------------------------
args            <- commandArgs(trailingOnly = TRUE)
retry_failed    <- "--retry-failed" %in% args
yaml_args       <- args[grepl("\\.ya?ml$", args)]

config_path <- if (length(yaml_args) > 0) {
  yaml_args[1]
} else if (file.exists("config.yaml")) {
  "config.yaml"
} else if (file.exists("../config.yaml")) {
  "../config.yaml"
} else {
  stop("config.yaml not found. Pass its path as the last command-line argument.")
}

config <- yaml::read_yaml(config_path)
setwd(config$working_dir)

# ---- Config-derived paths and parameters ------------------------------------
rawdata_dir  <- sub("/+$", "", config$paths$rawdata_dir)
temp_zip_dir <- file.path(rawdata_dir, "zip_files")
dir.create(temp_zip_dir, recursive = TRUE, showWarnings = FALSE)

vars       <- unique(as.character(unlist(config$processing$exp_list)))
years_data <- as.integer(unlist(config$processing$years_to_process))

if (length(vars) == 0 || length(years_data) == 0) {
  stop("No variables or years_to_process found in config.yaml under processing.")
}

base_url    <- "https://data.prism.oregonstate.edu/time_series/us/an/800m"
failed_csv  <- file.path(rawdata_dir, "failed_downloads.csv")

# ---- Helpers ----------------------------------------------------------------

# Pure-R zip validity check — no system binary required.
# FIX 1: original tryCatch/return-type mismatch caused inverted results.
is_valid_zipfile <- function(zipfile) {
  if (!file.exists(zipfile) || file.size(zipfile) == 0L) return(FALSE)
  tryCatch({
    members <- utils::unzip(zipfile, list = TRUE)
    is.data.frame(members) && nrow(members) > 0L
  }, error = function(e) FALSE)
}

# Soft HEAD check. Returns TRUE (confirmed zip), FALSE (explicit HTTP error),
# or NA (200 OK but content-type ambiguous — caller should proceed anyway).
# FIX 3: demoted from hard gate; NA no longer blocks downloads.
head_check <- function(url) {
  headers <- tryCatch(
    system2(
      "curl",
      args   = c("-sI", "-L", "--max-time", "15", "-A", shQuote(prism_user_agent), url),
      stdout = TRUE,
      stderr = FALSE
    ),
    error = function(e) character(0)
  )
  if (length(headers) == 0L) return(NA)
  if (!any(grepl("^HTTP/.* 200", headers))) return(FALSE)
  if (any(grepl("Content-Type:.*(zip|octet-stream)", headers, ignore.case = TRUE))) return(TRUE)
  NA  # 200 OK but unknown content-type — proceed with the download attempt
}

# Primary download via download.file with a correctly formatted User-Agent.
# FIX 4: headers must be a *named* character vector for libcurl.
download_primary <- function(url, destfile) {
  tryCatch(
    utils::download.file(
      url      = url,
      destfile = destfile,
      mode     = "wb",
      quiet    = TRUE,
      method   = "libcurl",
      headers  = c("User-Agent" = prism_user_agent)
    ),
    error = function(e) -1L
  )
}

# Fallback: system curl (present on Windows 10+ System32 and most Unix systems).
# FIX 5: checks availability before calling; avoids silent failures on older Windows.
curl_available <- tryCatch(
  system2("curl", args = "--version", stdout = FALSE, stderr = FALSE) == 0L,
  error = function(e) FALSE
)

download_curl_fallback <- function(url, destfile) {
  if (!curl_available) return(-1L)
  tryCatch(
    system2(
      "curl",
      args   = c("-L", "-f", "--max-time", "600",
                 "-A", shQuote(prism_user_agent),
                 "-o", destfile, url),
      stdout = FALSE,
      stderr = FALSE
    ),
    error = function(e) -1L
  )
}

# Download with retry and exponential backoff.
# FIX 3 (continued): HEAD failure → warn and retry, not hard-stop.
# FIX 6: wait doubles each attempt (10s, 20s, 40s, 80s, 160s).
download_with_retry <- function(url, destfile, attempts = 5L, base_wait = 10) {
  if (is_valid_zipfile(destfile)) {
    message("..... Reusing existing download: ", basename(destfile))
    return(TRUE)
  }

  for (attempt in seq_len(attempts)) {
    if (file.exists(destfile)) unlink(destfile)

    head_result <- head_check(url)
    if (isFALSE(head_result)) {
      wait <- base_wait * 2^(attempt - 1L)
      message("..... WARNING: server returned non-200 for ", basename(url),
              " (attempt ", attempt, "/", attempts, "). Waiting ", wait, "s.")
      if (attempt < attempts) { Sys.sleep(wait); next } else return(FALSE)
    }

    status <- download_primary(url, destfile)

    if (!is.numeric(status) || status != 0L || !is_valid_zipfile(destfile)) {
      if (file.exists(destfile)) unlink(destfile)
      status <- download_curl_fallback(url, destfile)
    }

    if (is.numeric(status) && status == 0L && is_valid_zipfile(destfile)) {
      Sys.sleep(0.2)
      return(TRUE)
    }

    if (file.exists(destfile)) unlink(destfile)
    wait <- base_wait * 2^(attempt - 1L)
    if (attempt < attempts) {
      message("..... Download failed (attempt ", attempt, "/", attempts,
              "). Retrying in ", wait, "s.")
      Sys.sleep(wait)
    }
  }
  FALSE
}

day_already_extracted <- function(target_dir, day_yyyymmdd) {
  if (!dir.exists(target_dir)) return(FALSE)
  length(list.files(
    target_dir,
    pattern     = paste0(day_yyyymmdd, ".*\\.(tif|tiff|bil|img)$"),
    ignore.case = TRUE
  )) > 0L
}

extract_tif_member <- function(zipfile, exdir) {
  members     <- utils::unzip(zipfile, list = TRUE)
  tif_members <- members$Name[grepl("\\.tif$", members$Name, ignore.case = TRUE)]
  if (length(tif_members) == 0L) stop("No .tif member found in zip: ", zipfile)
  utils::unzip(zipfile, files = tif_members, exdir = exdir, overwrite = FALSE)
  unlink(zipfile)
}

build_work_list <- function(vars, years_data) {
  work <- vector("list", length(vars) * length(years_data) * 366L)
  idx  <- 0L
  for (var in vars) {
    for (year_data in years_data) {
      days <- format(
        seq(as.Date(paste0(year_data, "-01-01")),
            as.Date(paste0(year_data, "-12-31")), by = "day"),
        format = "%Y%m%d"
      )
      for (day in days) {
        zip_name   <- paste0("prism_", var, "_us_30s_", day, ".zip")
        idx        <- idx + 1L
        work[[idx]] <- list(
          var      = var,
          year     = year_data,
          day      = day,
          key      = paste(var, day, sep = ":"),
          dl_link  = paste0(base_url, "/", var, "/daily/", year_data, "/", zip_name),
          dl_file  = file.path(temp_zip_dir, zip_name),
          out_dir  = file.path(rawdata_dir, var, as.character(year_data))
        )
      }
    }
  }
  work[!vapply(work, is.null, logical(1L))]
}

# ---- STEP 1: Download and extract PRISM daily files ------------------------
message("=== STEP 1: Download PRISM 800m daily data ===")

all_work <- build_work_list(vars, years_data)

# FIX 7 (retry mode): filter work list to previously failed var:day pairs.
if (retry_failed) {
  if (!file.exists(failed_csv)) {
    message("--retry-failed specified but ", failed_csv, " not found. Nothing to retry.")
    all_work <- list()
  } else {
    prev         <- utils::read.csv(failed_csv, stringsAsFactors = FALSE)
    failed_keys  <- paste(prev$var, prev$day, sep = ":")
    all_work     <- Filter(function(x) x$key %in% failed_keys, all_work)
    message("Retrying ", length(all_work), " previously failed file(s).")
  }
}

failed_downloads <- character(0)
current_var      <- ""
current_year     <- ""

for (item in all_work) {
  if (item$var != current_var) {
    message("---------------------------------------------------------------------")
    message("Variable: ", item$var)
    current_var  <- item$var
    current_year <- ""
  }
  if (as.character(item$year) != current_year) {
    message("..... Year: ", item$year)
    current_year <- as.character(item$year)
  }

  dir.create(item$out_dir, recursive = TRUE, showWarnings = FALSE)

  if (day_already_extracted(item$out_dir, item$day)) {
    message(".......... Skipping existing file: ", item$day)
    next
  }

  # FIX 2: validate any pre-existing zip; delete if corrupt so it gets re-fetched.
  if (file.exists(item$dl_file) && !is_valid_zipfile(item$dl_file)) {
    message(".......... Removing corrupt cached zip for ", item$day)
    unlink(item$dl_file)
  }

  if (file.exists(item$dl_file)) {
    message(".......... Reusing cached zip: ", item$day)
  } else {
    message(".......... Downloading: ", item$day)
    ok <- download_with_retry(item$dl_link, item$dl_file)
    if (!ok) {
      failed_downloads <- c(failed_downloads, item$key)
      message(".......... ERROR: Failed to download ", item$dl_link)
      next
    }
  }

  unzip_ok <- tryCatch({
    extract_tif_member(item$dl_file, item$out_dir)
    message(".......... OK: ", item$day)
    TRUE
  }, error = function(e) {
    message(".......... ERROR: unzip failed for ", item$dl_file, " (", conditionMessage(e), ")")
    FALSE
  })

  if (!unzip_ok) failed_downloads <- c(failed_downloads, item$key)
}

# FIX 7: persist failures to CSV for easy reruns.
if (length(failed_downloads) > 0L) {
  message("\nDownload/unzip failures (", length(failed_downloads), "):")
  message(paste0("  - ", failed_downloads, collapse = "\n"))
  utils::write.csv(
    data.frame(
      var = sub(":.*", "", failed_downloads),
      day = sub(".*:", "", failed_downloads),
      stringsAsFactors = FALSE
    ),
    failed_csv, row.names = FALSE
  )
  message("Failures written to: ", failed_csv)
  message("Re-run with --retry-failed to attempt only these files.")
} else {
  message("\nAll requested PRISM downloads and extractions completed.")
  if (file.exists(failed_csv)) unlink(failed_csv)
}

# ---- STEP 2: Download census block shapefiles via tigris -------------------
message("\n=== STEP 2: Download block shapefiles ===")

block_geo_root <- config$paths$block_shapefile_dir
dir.create(block_geo_root, recursive = TRUE, showWarnings = FALSE)

decyears       <- as.integer(unlist(config$processing$decyear))
state_fips_cfg <- config$processing$state_fips

get_state_fips <- function(state_fips_config) {
  if (is.character(state_fips_config) &&
      length(state_fips_config) == 1L &&
      state_fips_config == "Nationwide") {
    st <- tigris::states(year = 2020, cb = TRUE)
    st <- st[st$REGION %in% c("1", "2", "3", "4") & !st$STATEFP %in% c("02", "15"), ]
    return(sort(unique(st$STATEFP)))
  }
  sprintf("%02s", as.character(unlist(state_fips_config)))
}

state_fips <- get_state_fips(state_fips_cfg)

for (decyear in decyears) {
  year_dir <- file.path(block_geo_root, as.character(decyear))
  dir.create(year_dir, recursive = TRUE, showWarnings = FALSE)

  for (state in state_fips) {
    shp_stem <- paste0("tl_", decyear, "_", state, "_tabblock", substr(as.character(decyear), 3L, 4L))
    shp_file <- file.path(year_dir, paste0(shp_stem, ".shp"))
    if (file.exists(shp_file)) next

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

fips            <- tigris::states(year = 2020, cb = TRUE)
fips            <- fips[fips$REGION %in% c("1", "2", "3", "4") & !fips$STATEFP %in% c("02", "15"), ]
fips            <- as.data.frame(fips)
fips$geometry   <- NULL
fips$StFIPS     <- fips$STATEFP
fips            <- fips[c("StFIPS", "STUSPS", "NAME")]

utils::write.csv(fips, config$paths$fips_csv, row.names = FALSE)

message("Done.")
