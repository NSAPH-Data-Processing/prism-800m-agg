# =========================================================================== #
# 06d_Merge_Block_to_ZCTA_Crosswalk_v01.R
# Merge state-level block-to-ZCTA files and create state weights for ZCTAs that
# cross state boundaries.
#
# Usage:
#   Rscript code/06d_Merge_Block_to_ZCTA_Crosswalk_v01.R DECYEAR config.yaml
# =========================================================================== #

suppressPackageStartupMessages({
  library(yaml)
  library(dplyr)
})

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  stop("Usage: Rscript code/06d_Merge_Block_to_ZCTA_Crosswalk_v01.R DECYEAR [config.yaml]")
}

decyear <- as.integer(args[1])
config_path <- if (length(args) > 1 && grepl("\\.ya?ml$", args[length(args)])) {
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

conus_state_fips <- c(
  "01", "04", "05", "06", "08", "09", "10", "11", "12", "13",
  "16", "17", "18", "19", "20", "21", "22", "23", "24", "25",
  "26", "27", "28", "29", "30", "31", "32", "33", "34", "35",
  "36", "37", "38", "39", "40", "41", "42", "44", "45", "46",
  "47", "48", "49", "50", "51", "53", "54", "55", "56"
)

normalize_state_fips <- function(raw_state_fips) {
  if (is.character(raw_state_fips) && length(raw_state_fips) == 1 &&
      tolower(raw_state_fips) == "nationwide") {
    return(conus_state_fips)
  }
  supplied <- sprintf("%02s", as.character(unlist(raw_state_fips)))
  conus_state_fips[conus_state_fips %in% supplied]
}

crosswalk_dir <- resolve_path(config$paths$crosswalk_dir, config$working_dir)
states <- normalize_state_fips(config$processing$state_fips)
state_files <- file.path(crosswalk_dir, paste0("Block_to_ZCTA_", decyear, "_", states, ".Rds"))
missing_files <- state_files[!file.exists(state_files)]
if (length(missing_files) > 0) {
  stop("Missing state crosswalk files:\n", paste(missing_files, collapse = "\n"))
}

national_xwalk <- dplyr::bind_rows(lapply(state_files, readRDS))
block_geoid <- names(national_xwalk)[grep("^GEOID|^BLKID", names(national_xwalk), ignore.case = TRUE)[1]]
zcta_id <- names(national_xwalk)[grep("^ZCTA5", names(national_xwalk), ignore.case = TRUE)[1]]
blockpopvar <- names(national_xwalk)[grep(paste0("^Pop_", decyear, "$"), names(national_xwalk), ignore.case = TRUE)[1]]

if (is.na(block_geoid) || is.na(zcta_id) || is.na(blockpopvar)) {
  stop("Could not identify required columns in state crosswalks.")
}

if (length(unique(national_xwalk[[block_geoid]])) != nrow(national_xwalk)) {
  cat("WARNING: duplicate block GEOIDs detected in national crosswalk\n")
}

national_xwalk$ST <- substr(national_xwalk[[block_geoid]], 1, 2)

zcta_state_pop <- national_xwalk %>%
  group_by(!!sym(zcta_id), ST) %>%
  summarise(Pop_ZCTA = dplyr::first(Pop_ZCTA), .groups = "drop")

zcta_state_weight <- zcta_state_pop %>%
  group_by(!!sym(zcta_id)) %>%
  mutate(
    Pop_ZCTA_Total = sum(Pop_ZCTA, na.rm = TRUE),
    State_Wt = ifelse(Pop_ZCTA_Total > 0, Pop_ZCTA / Pop_ZCTA_Total, NA_real_)
  ) %>%
  ungroup() %>%
  select(!!sym(zcta_id), Pop_ZCTA, Pop_ZCTA_Total, State_Wt, ST)

national_xwalk <- national_xwalk %>%
  left_join(
    zcta_state_weight %>% select(!!sym(zcta_id), ST, Pop_ZCTA_Total),
    by = c(zcta_id, "ST")
  ) %>%
  mutate(
    Pop_ZCTA = Pop_ZCTA_Total,
    Spatial_Weight = ifelse(Pop_ZCTA_Total > 0, .data[[blockpopvar]] / Pop_ZCTA_Total, NA_real_)
  ) %>%
  select(-Pop_ZCTA_Total)

state_wt_file <- file.path(crosswalk_dir, paste0("ZCTA_StateWt_", decyear, "_US.Rds"))
national_file <- file.path(crosswalk_dir, paste0("Block_to_ZCTA_", decyear, "_US.Rds"))
saveRDS(zcta_state_weight, state_wt_file)
saveRDS(national_xwalk, national_file)

cat("Wrote", state_wt_file, "\n")
cat("Wrote", national_file, "\n")
