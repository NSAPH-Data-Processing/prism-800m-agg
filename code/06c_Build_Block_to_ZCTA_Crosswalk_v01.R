# =========================================================================== #
# 06c_Build_Block_to_ZCTA_Crosswalk_v01.R
# Build a state-level block-to-ZCTA crosswalk for one decennial year/state.
#
# Usage:
#   Rscript code/06c_Build_Block_to_ZCTA_Crosswalk_v01.R STATE_INDEX DECYEAR config.yaml
# =========================================================================== #

suppressPackageStartupMessages({
  library(yaml)
  library(sf)
  library(dplyr)
  library(doBy)
})

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript code/06c_Build_Block_to_ZCTA_Crosswalk_v01.R STATE_INDEX DECYEAR [config.yaml]")
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

block_id_candidates <- function(year) {
  if (year == 2000) return(c("BLKIDFP00", "GEOID00", "GEOID"))
  if (year == 2010) return(c("GEOID10", "GEOID", "BLKIDFP10"))
  if (year == 2020) return(c("GEOID20", "GEOID", "BLKIDFP20"))
  c("GEOID", "BLKIDFP")
}

pop_var_block <- function(year) {
  paste0("Pop_", year)
}

sumfun <- function(x) {
  ifelse(all(is.na(x)), return(NA), return(sum(x, na.rm = TRUE)))
}

find_block_shapefile <- function(block_root, year, state_fips) {
  year_dir <- file.path(block_root, as.character(year))
  suffix <- substr(year, 3, 4)
  candidates <- list.files(
    year_dir,
    pattern = paste0(state_fips, ".*tabblock", suffix, "\\.shp$"),
    full.names = TRUE,
    ignore.case = TRUE
  )
  if (length(candidates) == 0) {
    stop("No block shapefile found for ", year, " state ", state_fips,
         " under ", year_dir)
  }
  candidates[1]
}

states <- normalize_state_fips(config$processing$state_fips)
if (is.na(state_index) || state_index < 1 || state_index > length(states)) {
  stop("STATE_INDEX must be between 1 and ", length(states), ".")
}
state_fips <- states[state_index]

crosswalk_dir <- resolve_path(config$paths$crosswalk_dir, config$working_dir)
block_root <- resolve_path(config$paths$block_shapefile_dir, config$working_dir)
zcta_gpkg <- file.path(crosswalk_dir, "zcta", paste0("ZCTA_", decyear, "_US.gpkg"))
block_pop_rds <- file.path(crosswalk_dir, "population", paste0("block_population_", decyear, "_", state_fips, ".Rds"))
out_file <- file.path(crosswalk_dir, paste0("Block_to_ZCTA_", decyear, "_", state_fips, ".Rds"))
dir.create(crosswalk_dir, recursive = TRUE, showWarnings = FALSE)

sf::sf_use_s2(FALSE)

cat("Building block-to-ZCTA crosswalk for", decyear, "state", state_fips, "\n")
blocks <- sf::st_read(find_block_shapefile(block_root, decyear, state_fips), quiet = TRUE)

bbox <- sf::st_bbox(blocks)
bbox[["xmin"]] <- bbox[["xmin"]] - 0.0625
bbox[["ymin"]] <- bbox[["ymin"]] - 0.0625
bbox[["xmax"]] <- bbox[["xmax"]] + 0.0625
bbox[["ymax"]] <- bbox[["ymax"]] + 0.0625
extent_poly <- sf::st_as_text(sf::st_as_sfc(bbox, crs = sf::st_crs(blocks)))

zctas <- sf::st_read(zcta_gpkg, wkt_filter = extent_poly, quiet = TRUE)
if (!isTRUE(all.equal(sf::st_crs(blocks), sf::st_crs(zctas)))) {
  blocks <- sf::st_transform(blocks, crs = sf::st_crs(zctas))
}

blocks <- sf::st_make_valid(blocks)
zctas <- sf::st_make_valid(zctas)
if ("POP20" %in% names(blocks)) blocks$POP20 <- NULL

blockpop <- readRDS(block_pop_rds)
pop_col <- pop_var_block(decyear)
names(blockpop)[grep("^value$", names(blockpop), ignore.case = TRUE)] <- pop_col
blockpop[, intersect(c("NAME", "variable"), names(blockpop))] <- NULL

block_geoid <- intersect(block_id_candidates(decyear), names(blocks))[1]
pop_geoid <- names(blockpop)[grep("^GEOID", names(blockpop), ignore.case = TRUE)[1]]
if (is.na(block_geoid) || is.na(pop_geoid)) {
  stop("Could not identify block GEOID columns for ", decyear, " state ", state_fips)
}

blocks <- merge(blocks, blockpop, by.x = block_geoid, by.y = pop_geoid, all.x = TRUE)
num_missing <- sum(is.na(blocks[[pop_col]]))
if (num_missing > 0) {
  cat("WARNING:", num_missing, "blocks with missing population\n")
}

zcta_geoid <- names(zctas)[grep("^ZCTA5", names(zctas))[1]]
land_area_var <- names(blocks)[grep("^ALAND", names(blocks))[1]]
if (is.na(zcta_geoid) || is.na(land_area_var)) {
  stop("Could not identify ZCTA or land-area columns for ", decyear, " state ", state_fips)
}

block_centroids <- sf::st_point_on_surface(blocks)
block_zctas <- sf::st_intersection(block_centroids, zctas[c(zcta_geoid)])

assigned <- sf::st_drop_geometry(block_zctas)[c(block_geoid, zcta_geoid, pop_col)]
unassigned_blocks <- block_centroids[!(block_centroids[[block_geoid]] %in% assigned[[block_geoid]]), ]
populated <- which(unassigned_blocks[[pop_col]] > 10 & unassigned_blocks[[land_area_var]] > 0)

if (length(populated) > 0) {
  cat("Joining", length(populated), "populated unassigned blocks by nearest ZCTA\n")
  unassigned_pop <- unassigned_blocks[populated, ]
  zctas_proj <- sf::st_transform(zctas, 5070)
  unassigned_proj <- sf::st_transform(unassigned_pop, 5070)
  nearest_idx <- sf::st_nearest_feature(unassigned_proj, zctas_proj)
  distance_m <- as.numeric(sf::st_distance(unassigned_proj, zctas_proj[nearest_idx, ], by_element = TRUE))
  nearest_zcta <- zctas[[zcta_geoid]][nearest_idx]
  nearest_zcta[distance_m > 1000] <- NA

  unassigned_df <- sf::st_drop_geometry(unassigned_pop)
  unassigned_df[[zcta_geoid]] <- nearest_zcta
  unassigned_df <- unassigned_df[!is.na(unassigned_df[[zcta_geoid]]), c(block_geoid, zcta_geoid, pop_col)]
  assigned <- dplyr::bind_rows(assigned, unassigned_df)
}

zcta_pop <- doBy::summaryBy(
  as.formula(paste0(pop_col, " ~ ", zcta_geoid)),
  data = assigned,
  FUN = sumfun
)
names(zcta_pop)[grep(paste0("^", pop_col), names(zcta_pop))] <- "Pop_ZCTA"

final <- merge(assigned, zcta_pop, by = zcta_geoid, all.x = TRUE)
final$Spatial_Weight <- ifelse(final$Pop_ZCTA > 0, final[[pop_col]] / final$Pop_ZCTA, NA_real_)
final <- final[c(block_geoid, zcta_geoid, pop_col, "Pop_ZCTA", "Spatial_Weight")]

qc <- doBy::summaryBy(
  as.formula(paste0("Spatial_Weight ~ ", zcta_geoid)),
  data = final[!is.na(final$Spatial_Weight), ],
  FUN = sumfun
)
bad <- which(round(qc$Spatial_Weight.sumfun, 4) != 1)
if (length(bad) > 0) {
  cat("WARNING:", length(bad), "ZCTAs have spatial weights that do not sum to 1\n")
} else {
  cat(":) all nonzero-population spatial weights sum to 1\n")
}

saveRDS(final, out_file)
cat("Wrote", out_file, "\n")
