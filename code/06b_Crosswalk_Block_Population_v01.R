# =========================================================================== #
# 06b_Crosswalk_Block_Population_v01.R
# Download/cache decennial block population for one configured state.
#
# Usage:
#   Rscript code/06b_Crosswalk_Block_Population_v01.R STATE_INDEX DECYEAR config.yaml
# =========================================================================== #

suppressPackageStartupMessages({
  library(yaml)
  library(dplyr)
  library(tigris)
  library(tidycensus)
})

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript code/06b_Crosswalk_Block_Population_v01.R STATE_INDEX DECYEAR [config.yaml]")
}

state_index <- as.integer(args[1])
decyear <- as.integer(args[2])
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

pop_var_block <- function(year) {
  if (year %in% 2000:2009) return("PL001001")
  if (year %in% 2010:2019) return("P001001")
  if (year %in% 2020:2029) return("P1_001N")
  stop("Unsupported block population year: ", year)
}

states <- normalize_state_fips(config$processing$state_fips)
if (is.na(state_index) || state_index < 1 || state_index > length(states)) {
  stop("STATE_INDEX must be between 1 and ", length(states), ".")
}
state_fips <- states[state_index]

crosswalk_dir <- resolve_path(config$paths$crosswalk_dir, config$working_dir)
pop_dir <- file.path(crosswalk_dir, "population")
dir.create(pop_dir, recursive = TRUE, showWarnings = FALSE)

out_file <- file.path(pop_dir, paste0("block_population_", decyear, "_", state_fips, ".Rds"))
if (file.exists(out_file)) {
  cat("Reusing", out_file, "\n")
  quit(status = 0)
}

options(tigris_use_cache = TRUE, tigris_class = "sf")

cat("Downloading block population for", decyear, "state", state_fips, "\n")
counties <- tigris::counties(state = state_fips, year = decyear, cb = TRUE)
county_col <- names(counties)[grep("^COUNTYFP", names(counties), ignore.case = TRUE)[1]]
county_fips <- unique(counties[[county_col]])

block_pop <- tidycensus::get_decennial(
  geography = "block",
  variables = pop_var_block(decyear),
  year = decyear,
  state = state_fips,
  county = county_fips,
  sumfile = "pl",
  key = Sys.getenv("CENSUS_API_KEY")
)

saveRDS(block_pop, out_file)
cat("Wrote", out_file, "\n")
