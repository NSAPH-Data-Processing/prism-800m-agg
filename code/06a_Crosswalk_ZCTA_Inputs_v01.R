# =========================================================================== #
# 06a_Crosswalk_ZCTA_Inputs_v01.R
# Download/cache national ZCTA geometry and ZCTA population inputs for the
# block-to-ZCTA crosswalk steps.
#
# Usage:
#   Rscript code/06a_Crosswalk_ZCTA_Inputs_v01.R DECYEAR config.yaml
# =========================================================================== #

suppressPackageStartupMessages({
  library(yaml)
  library(sf)
  library(tigris)
  library(tidycensus)
})

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  stop("Usage: Rscript code/06a_Crosswalk_ZCTA_Inputs_v01.R DECYEAR [config.yaml]")
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

pop_var_zcta <- function(year) {
  if (year %in% 2000:2019) return("P001001")
  if (year %in% 2020:2029) return("P1_001N")
  stop("Unsupported ZCTA population year: ", year)
}

crosswalk_dir <- resolve_path(config$paths$crosswalk_dir, config$working_dir)
zcta_dir <- file.path(crosswalk_dir, "zcta")
pop_dir <- file.path(crosswalk_dir, "population")
dir.create(zcta_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(pop_dir, recursive = TRUE, showWarnings = FALSE)

zcta_gpkg <- file.path(zcta_dir, paste0("ZCTA_", decyear, "_US.gpkg"))
zcta_pop_rds <- file.path(pop_dir, paste0("zcta_population_", decyear, "_US.Rds"))

options(tigris_use_cache = TRUE, tigris_class = "sf")
sf::sf_use_s2(FALSE)

if (!file.exists(zcta_gpkg)) {
  cat("Downloading ZCTA geometry for", decyear, "\n")
  zctas <- tigris::zctas(year = decyear)
  sf::st_write(zctas, zcta_gpkg, delete_dsn = TRUE, quiet = TRUE)
} else {
  cat("Reusing", zcta_gpkg, "\n")
}

if (!file.exists(zcta_pop_rds)) {
  cat("Downloading ZCTA population for", decyear, "\n")
  pop_var <- pop_var_zcta(decyear)
  sumfile <- ifelse(decyear == 2020, "dhc", "sf1")
  zcta_pop <- tidycensus::get_decennial(
    geography = "zcta",
    variables = pop_var,
    year = decyear,
    sumfile = sumfile,
    key = Sys.getenv("CENSUS_API_KEY")
  )
  saveRDS(zcta_pop, zcta_pop_rds)
} else {
  cat("Reusing", zcta_pop_rds, "\n")
}

cat("Done.\n")
