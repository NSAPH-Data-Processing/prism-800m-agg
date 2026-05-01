# =========================================================================== #
# X_Build_FIPS_CSV_v01.R
# Build the CONUS + DC FIPS lookup CSV used by state-indexed jobs.
#
# Usage:
#   Rscript code/X_Build_FIPS_CSV_v01.R config.yaml
# =========================================================================== #

suppressPackageStartupMessages({
  library(yaml)
  library(tigris)
})

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

fips_csv <- resolve_path(config$paths$fips_csv, config$working_dir)
dir.create(dirname(fips_csv), recursive = TRUE, showWarnings = FALSE)

options(tigris_use_cache = TRUE)

fallback_fips <- data.frame(
  StFIPS = c(
    "01", "04", "05", "06", "08", "09", "10", "11", "12", "13",
    "16", "17", "18", "19", "20", "21", "22", "23", "24", "25",
    "26", "27", "28", "29", "30", "31", "32", "33", "34", "35",
    "36", "37", "38", "39", "40", "41", "42", "44", "45", "46",
    "47", "48", "49", "50", "51", "53", "54", "55", "56"
  ),
  STUSPS = c(
    "AL", "AZ", "AR", "CA", "CO", "CT", "DE", "DC", "FL", "GA",
    "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD", "MA",
    "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM",
    "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC", "SD",
    "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY"
  ),
  NAME = c(
    "Alabama", "Arizona", "Arkansas", "California", "Colorado",
    "Connecticut", "Delaware", "District of Columbia", "Florida",
    "Georgia", "Idaho", "Illinois", "Indiana", "Iowa", "Kansas",
    "Kentucky", "Louisiana", "Maine", "Maryland", "Massachusetts",
    "Michigan", "Minnesota", "Mississippi", "Missouri", "Montana",
    "Nebraska", "Nevada", "New Hampshire", "New Jersey", "New Mexico",
    "New York", "North Carolina", "North Dakota", "Ohio", "Oklahoma",
    "Oregon", "Pennsylvania", "Rhode Island", "South Carolina",
    "South Dakota", "Tennessee", "Texas", "Utah", "Vermont",
    "Virginia", "Washington", "West Virginia", "Wisconsin", "Wyoming"
  ),
  stringsAsFactors = FALSE
)

fips <- tryCatch(tigris::states(year = 2020, cb = TRUE), error = function(e) NULL)
if (!is.null(fips)) {
  fips <- as.data.frame(fips)
  fips$geometry <- NULL
  region_col <- intersect(c("REGION", "REGIONCE"), names(fips))[1]
  state_col <- intersect(c("STATEFP", "STATEFP20"), names(fips))[1]
  abbr_col <- intersect(c("STUSPS", "STUSPS20"), names(fips))[1]
  name_col <- intersect(c("NAME", "NAME20"), names(fips))[1]

  if (!is.na(region_col)) {
    fips <- fips[as.character(fips[[region_col]]) %in% c("1", "2", "3", "4"), ]
  }
  if (!is.na(state_col)) {
    fips <- fips[!as.character(fips[[state_col]]) %in% c("02", "15"), ]
  }

  if (!any(is.na(c(state_col, abbr_col, name_col))) && nrow(fips) > 0) {
    fips <- data.frame(
      StFIPS = sprintf("%02d", as.integer(fips[[state_col]])),
      STUSPS = fips[[abbr_col]],
      NAME = fips[[name_col]],
      stringsAsFactors = FALSE
    )
  } else {
    fips <- fallback_fips
  }
} else {
  fips <- fallback_fips
}
fips <- fips[match(fallback_fips$StFIPS, fips$StFIPS), ]
fips <- fips[!is.na(fips$StFIPS), ]

utils::write.csv(fips, fips_csv, row.names = FALSE)
cat("Wrote", fips_csv, "\n")
