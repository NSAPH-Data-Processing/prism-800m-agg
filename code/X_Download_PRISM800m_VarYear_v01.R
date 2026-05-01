# =========================================================================== #
# X_Download_PRISM800m_VarYear_v01.R
# Download and extract PRISM 800m daily rasters for one variable/year.
#
# Usage:
#   Rscript code/X_Download_PRISM800m_VarYear_v01.R VAR YEAR config.yaml
# =========================================================================== #

suppressPackageStartupMessages({
  library(terra)
  library(yaml)
})

options(timeout = 3600)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript code/X_Download_PRISM800m_VarYear_v01.R VAR YEAR [config.yaml]")
}

var <- args[1]
year_data <- as.integer(args[2])
config_path <- if (length(args) > 2 && grepl("\\.ya?ml$", args[length(args)])) {
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

resolve_path <- function(path_in, base_dir) {
  if (grepl("^/", path_in)) return(path_in)
  file.path(base_dir, path_in)
}

rawdata_dir <- sub("/+$", "", resolve_path(config$paths$rawdata_dir, config$working_dir))
target_dir <- file.path(rawdata_dir, var, as.character(year_data))
temp_zip_dir <- file.path(rawdata_dir, "zip_files")
complete_file <- file.path(target_dir, ".download_complete")
dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(temp_zip_dir, recursive = TRUE, showWarnings = FALSE)
if (file.exists(complete_file)) unlink(complete_file)

base_url <- "https://data.prism.oregonstate.edu/time_series/us/an/800m"
prism_user_agent <- "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

is_valid_zipfile <- function(zipfile) {
  if (!file.exists(zipfile) || file.size(zipfile) == 0L) return(FALSE)
  tryCatch({
    members <- utils::unzip(zipfile, list = TRUE)
    is.data.frame(members) && nrow(members) > 0L
  }, error = function(e) FALSE)
}

existing_day_files <- function(day_yyyymmdd) {
  list.files(
    target_dir,
    pattern = paste0(day_yyyymmdd, ".*\\.(tif|tiff|bil|img)$"),
    full.names = TRUE,
    ignore.case = TRUE
  )
}

is_valid_raster_file <- function(path) {
  if (!file.exists(path) || file.size(path) == 0L) return(FALSE)
  tryCatch({
    raster <- terra::rast(path)
    raster_dim <- dim(raster)
    length(raster_dim) >= 2L && all(raster_dim[1:2] > 0L)
  }, error = function(e) FALSE)
}

day_already_extracted <- function(day_yyyymmdd) {
  files <- existing_day_files(day_yyyymmdd)
  if (length(files) == 0L) return(FALSE)

  valid <- vapply(files, is_valid_raster_file, logical(1))
  if (any(!valid)) {
    message("Removing corrupt/incomplete raster(s) for ", day_yyyymmdd)
    unlink(files[!valid])
  }

  any(valid)
}

head_check <- function(url) {
  headers <- tryCatch(
    system2(
      "curl",
      args = c("-sI", "-L", "--max-time", "15", "-A", shQuote(prism_user_agent), url),
      stdout = TRUE,
      stderr = FALSE
    ),
    error = function(e) character(0)
  )
  if (length(headers) == 0L) return(NA)
  if (!any(grepl("^HTTP/.* 200", headers))) return(FALSE)
  if (any(grepl("Content-Type:.*(zip|octet-stream)", headers, ignore.case = TRUE))) return(TRUE)
  NA
}

download_primary <- function(url, destfile) {
  tryCatch(
    utils::download.file(
      url = url,
      destfile = destfile,
      mode = "wb",
      quiet = TRUE,
      method = "libcurl",
      headers = c("User-Agent" = prism_user_agent)
    ),
    error = function(e) -1L
  )
}

curl_available <- tryCatch(
  system2("curl", args = "--version", stdout = FALSE, stderr = FALSE) == 0L,
  error = function(e) FALSE
)

download_curl_fallback <- function(url, destfile) {
  if (!curl_available) return(-1L)
  tryCatch(
    system2(
      "curl",
      args = c("-L", "-f", "--max-time", "600",
               "-A", shQuote(prism_user_agent),
               "-o", destfile, url),
      stdout = FALSE,
      stderr = FALSE
    ),
    error = function(e) -1L
  )
}

download_with_retry <- function(url, destfile, attempts = 5L, base_wait = 10) {
  if (is_valid_zipfile(destfile)) return(TRUE)

  for (attempt in seq_len(attempts)) {
    if (file.exists(destfile)) unlink(destfile)

    head_result <- head_check(url)
    if (isFALSE(head_result)) {
      wait <- base_wait * 2^(attempt - 1L)
      message("WARNING: non-200 response for ", basename(url),
              " (attempt ", attempt, "/", attempts, ").")
      if (attempt < attempts) { Sys.sleep(wait); next } else return(FALSE)
    }

    status <- download_primary(url, destfile)
    if (!is.numeric(status) || status != 0L || !is_valid_zipfile(destfile)) {
      if (file.exists(destfile)) unlink(destfile)
      status <- download_curl_fallback(url, destfile)
    }

    if (is.numeric(status) && status == 0L && is_valid_zipfile(destfile)) {
      return(TRUE)
    }

    if (file.exists(destfile)) unlink(destfile)
    if (attempt < attempts) Sys.sleep(base_wait * 2^(attempt - 1L))
  }

  FALSE
}

extract_tif_member <- function(zipfile) {
  members <- utils::unzip(zipfile, list = TRUE)
  tif_members <- members$Name[grepl("\\.tif$", members$Name, ignore.case = TRUE)]
  if (length(tif_members) == 0L) stop("No .tif member found in zip: ", zipfile)
  utils::unzip(zipfile, files = tif_members, exdir = target_dir, overwrite = FALSE)
  unlink(zipfile)
}

days <- format(
  seq(as.Date(paste0(year_data, "-01-01")),
      as.Date(paste0(year_data, "-12-31")), by = "day"),
  format = "%Y%m%d"
)

message("Downloading PRISM ", var, " ", year_data, " into ", target_dir)
failures <- character(0)

for (day in days) {
  if (day_already_extracted(day)) next

  zip_name <- paste0("prism_", var, "_us_30s_", day, ".zip")
  zip_file <- file.path(temp_zip_dir, zip_name)
  url <- paste0(base_url, "/", var, "/daily/", year_data, "/", zip_name)

  if (file.exists(zip_file) && !is_valid_zipfile(zip_file)) unlink(zip_file)

  if (!file.exists(zip_file)) {
    ok <- download_with_retry(url, zip_file)
    if (!ok) {
      failures <- c(failures, day)
      message("ERROR: failed to download ", url)
      next
    }
  }

  unzip_ok <- tryCatch({
    extract_tif_member(zip_file)
    TRUE
  }, error = function(e) {
    message("ERROR: unzip failed for ", zip_file, " (", conditionMessage(e), ")")
    FALSE
  })

  if (!unzip_ok) failures <- c(failures, day)
}

if (length(failures) > 0L) {
  failure_file <- file.path(rawdata_dir, paste0("failed_downloads_", var, "_", year_data, ".csv"))
  utils::write.csv(data.frame(var = var, year = year_data, day = failures), failure_file, row.names = FALSE)
  stop("Failed downloads for ", var, " ", year_data, ". See ", failure_file)
}

missing_after <- days[!vapply(days, day_already_extracted, logical(1))]
if (length(missing_after) > 0L) {
  failure_file <- file.path(rawdata_dir, paste0("failed_downloads_", var, "_", year_data, ".csv"))
  utils::write.csv(data.frame(var = var, year = year_data, day = missing_after), failure_file, row.names = FALSE)
  stop("Missing or invalid extracted rasters for ", var, " ", year_data, ". See ", failure_file)
}

complete_lines <- c(
  paste0("var=", var),
  paste0("year=", year_data),
  paste0("n_days=", length(days)),
  paste0("completed_at=", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"))
)
complete_tmp <- paste0(complete_file, ".tmp.", Sys.getpid())
writeLines(complete_lines, complete_tmp)
if (!file.rename(complete_tmp, complete_file)) {
  unlink(complete_tmp)
  stop("Failed to write completion marker: ", complete_file)
}

message("Done.")
