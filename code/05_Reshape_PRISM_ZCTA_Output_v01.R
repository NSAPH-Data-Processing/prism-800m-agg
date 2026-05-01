# =========================================================================== #
# 05_Reshape_PRISM_ZCTA_Output_v01.R
# Standardize final PRISM ZCTA outputs into daily and yearly parquet files.
#
# Output structure (inside repo):
#   outputdata/meteorology__prism/population_weighted/zcta_daily/
#   outputdata/meteorology__prism/population_weighted/zcta_yearly/
#
# Daily file naming:
#   meteorology__prism__zcta_daily__YYYY.parquet
#
# Yearly file naming:
#   meteorology__prism__zcta_yearly__YYYY.parquet
#
# Usage:
#   Rscript code/05_Reshape_PRISM_ZCTA_Output_v01.R [config_path]
# =========================================================================== #

suppressPackageStartupMessages({
  library(yaml)
  library(dplyr)
})

if (!requireNamespace("arrow", quietly = TRUE)) {
  stop("Package 'arrow' is required. Install it (e.g., install.packages('arrow')) and rerun.")
}

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

resolve_path <- function(path_in, base_dir) {
  if (grepl("^/", path_in)) return(path_in)
  file.path(base_dir, path_in)
}

mean_or_na <- function(x) {
  if (all(is.na(x))) return(NA_real_)
  mean(x, na.rm = TRUE)
}

working_dir <- config$working_dir
nation_dir <- resolve_path(config$paths$nation_dir, working_dir)

output_root <- file.path(working_dir, "outputdata", "meteorology__prism", "population_weighted")
out_daily <- file.path(output_root, "zcta_daily")
out_yearly <- file.path(output_root, "zcta_yearly")

dir.create(out_daily, recursive = TRUE, showWarnings = FALSE)
dir.create(out_yearly, recursive = TRUE, showWarnings = FALSE)

input_files <- list.files(
  nation_dir,
  pattern = "^PRISM_ZCTA[0-9]{2}_[0-9]{4}_nation\\.rds$",
  full.names = TRUE
)

if (length(input_files) == 0) {
  stop("No nationwide ZCTA files found in ", nation_dir,
       ". Expected files like PRISM_ZCTA10_2010_nation.rds")
}

cat("Found", length(input_files), "nationwide yearly RDS files.\n")

daily_by_year <- list()

for (f in input_files) {
  fname <- basename(f)
  year_match <- regmatches(fname, regexec("_([0-9]{4})_nation\\.rds$", fname))[[1]]
  if (length(year_match) < 2) {
    warning("Skipping unrecognized filename: ", fname)
    next
  }
  file_year <- as.integer(year_match[2])

  dat <- readRDS(f)

  zcta_col <- grep("^ZCTA", names(dat), value = TRUE)[1]
  if (is.na(zcta_col)) {
    stop("Could not identify ZCTA column in file: ", f)
  }

  day_col <- if ("PRISM_Date" %in% names(dat)) "PRISM_Date" else grep("date|day", names(dat), value = TRUE, ignore.case = TRUE)[1]
  if (is.na(day_col)) {
    stop("Could not identify day/date column in file: ", f)
  }

  names(dat)[names(dat) == zcta_col] <- "zcta"
  names(dat)[names(dat) == day_col] <- "day"

  # Normalize day to Date, supporting either YYYYMMDD integer/character or Date.
  if (!inherits(dat$day, "Date")) {
    day_chr <- as.character(dat$day)
    if (all(grepl("^[0-9]{8}$", day_chr))) {
      dat$day <- as.Date(day_chr, format = "%Y%m%d")
    } else {
      dat$day <- as.Date(dat$day)
    }
  }

  dat$zcta <- as.character(dat$zcta)
  dat$year <- as.integer(format(dat$day, "%Y"))

  value_cols <- setdiff(names(dat), c("zcta", "day", "year"))
  if (length(value_cols) == 0) {
    stop("No PRISM value columns found in file: ", f)
  }

  dat <- dat %>% select(zcta, day, year, all_of(value_cols))

  key <- as.character(file_year)
  if (!key %in% names(daily_by_year)) {
    daily_by_year[[key]] <- dat
  } else {
    daily_by_year[[key]] <- bind_rows(daily_by_year[[key]], dat)
  }
}

if (length(daily_by_year) == 0) {
  stop("No valid input files were processed.")
}

for (yr in sort(as.integer(names(daily_by_year)))) {
  dat <- daily_by_year[[as.character(yr)]]

  value_cols <- setdiff(names(dat), c("zcta", "day", "year"))

  # If duplicate zcta-day rows exist, collapse by mean across duplicates.
  dat_daily <- dat %>%
    group_by(zcta, day) %>%
    summarise(across(all_of(value_cols), mean_or_na), .groups = "drop") %>%
    mutate(year = as.integer(format(day, "%Y"))) %>%
    select(zcta, day, all_of(value_cols), year)

  daily_path <- file.path(out_daily, sprintf("meteorology__prism__zcta_daily__%d.parquet", yr))
  arrow::write_parquet(dat_daily, sink = daily_path)

  dat_yearly <- dat_daily %>%
    group_by(zcta, year) %>%
    summarise(across(all_of(value_cols), mean_or_na), .groups = "drop") %>%
    select(zcta, year, all_of(value_cols))

  yearly_path <- file.path(out_yearly, sprintf("meteorology__prism__zcta_yearly__%d.parquet", yr))
  arrow::write_parquet(dat_yearly, sink = yearly_path)

  cat("Wrote:\n")
  cat("  ", daily_path, "\n", sep = "")
  cat("  ", yearly_path, "\n", sep = "")
}

cat("Done.\n")
