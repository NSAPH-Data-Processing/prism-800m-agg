# ************************************************************** #
# ~~~~~  ACRES-PRISM Processing Daily Raster to Blocks       ~~~~~ #
# ************************************************************** #
#   Date created: 2025-02-26 (v01)
#   Last modified:  
#   Created by:     Zach P. (zpopp@bu.edu)
#   Modified from:  Keith Spangler, Muskaan Khemani
#   Modifications:  

##Purpose: Process daily temperature rasters to census blocks nationwide
##Overall Processing Steps:
## 1) Create Fishnet that can be used to extract PRISM data from raster stack
##    00a_Create_Fishnet_PRISMv2_800m_v02.R 
## 2) Load block geographies including decennial and year-specific IDs, and 
##    conduct union of block geometries with fishnet developed in step 1 (01a_Extraction_Pts).
## 3) Create extraction points from the union of the block and fishnet. These 
##    are what we can use to extract values from the raster that overlaps with
##    with the points aligning to each block (01a_Extraction_Pts).
## 4) Estimate the block-level exposure to PRISM, accounting for the availability
##    of data within the block (this file).

# Overview: Now that we have our points representing the block - grid 
#     intersection, we will proceed with bringing in all of the 365 rasters per
#     year per variable and extracting the data for each point. We will then 
#     use the spatial weights assigned in script 01a_Extraction_Pts to calculate
#     a block value for each day. As with previous scripts, this is set to 
#     run for a user-indicated decennial census geography, and for a user-
#     specified state or series of states (or all states in CONUS). 
#
#   The script includes 3 sections:
#       User-Defined Parameters, where the file paths are indicated as are the
#       desired geographies and states of interest.
#       Building Functions, where a function is set up to process based on 
#       state and decennial census inputs
#       Running Functions by Year, where a for loop is set to run separately
#       for each decennial census indicated in the User-Defined Parameters

########################## USER-DEFINED PARAMETERS #############################
# Load configuration from config.yaml.
# The config path can be passed as the third command-line argument (after year
# and state index); if omitted, the script looks for config.yaml in the
# current directory then one level up.
#
library("yaml")
args <- commandArgs(trailingOnly = TRUE)
.config_path <- if (length(args) >= 3 && grepl("\\.ya?ml$", args[length(args)])) {
  args[length(args)]
} else if (file.exists("config.yaml")) {
  "config.yaml"
} else if (file.exists("../config.yaml")) {
  "../config.yaml"
} else {
  stop("config.yaml not found. Pass its path as the last command-line argument.")
}
config <- yaml::read_yaml(.config_path)

setwd(config$working_dir)

# This directory is used just to read in the state FIPS codes.
#
fipsdir <- config$paths$fips_dir

# This directory should include the raw PRISM 800m raster files.
# The structure below assumes the raw data have been stored as
#       RawData --> variable directories --> year directories
prismdir <- config$paths$rawdata_dir

# This directory is where the linked points will be written to
points_dir <- config$paths$extraction_pts_dir

# This directory is where the block data with daily PRISM variables will be
# saved to. Note that the output is written with the expectation of nested
# directories within this outdir for decennial census geography and year of
# PRISM data, ie:
#       outdir/blocks/blocks_10/2000/
# Please edit the output line at the end of the script as needed based on your
# data structure
block_outdir <- config$paths$block_outdir

# Variables to process
#
exp_list <- as.character(unlist(config$processing$exp_list))

# If running for a subset of states, list below. If running nationwide:
#   state_fips: "Nationwide"
state_fips <- as.character(unlist(config$processing$state_fips))

# Set decennial years to process output extraction points
#
decyear <- as.numeric(unlist(config$processing$decyear))

valid_decyears <- c(2000, 2010, 2020)

map_decyear_by_year <- function(year, decyear_config) {
  decyear_config <- as.numeric(decyear_config)
  decyear_config <- decyear_config[!is.na(decyear_config)]

  if (length(decyear_config) == 1 && decyear_config %in% valid_decyears) {
    return(decyear_config)
  }

  auto_map <- length(decyear_config) == 0 || any(!decyear_config %in% valid_decyears)
  if (auto_map) {
    if (year < 2010) {
      return(2000)
    }
    if (year < 2020) {
      return(2010)
    }
    return(2020)
  }

  if (year < 2010 && 2000 %in% decyear_config) {
    return(2000)
  }
  if (year >= 2010 && year < 2020 && 2010 %in% decyear_config) {
    return(2010)
  }
  if (year >= 2020 && 2020 %in% decyear_config) {
    return(2020)
  }

  decyear_config <- sort(unique(decyear_config))
  decyear_prior <- decyear_config[decyear_config <= year]
  if (length(decyear_prior) > 0) {
    return(max(decyear_prior))
  }

  return(min(decyear_config))
}

# Temperature variable column names get a "_C" suffix; others keep their name
temp_vars <- c("tmax", "tmin", "tmean", "tdmean")
exp_list_zcta <- ifelse(exp_list %in% temp_vars, paste0(exp_list, "_C"), exp_list)

library("terra")  # For raster data
library("sf")     # For vector data
library("plyr")
library("dplyr")
library("tigris") # For downloading census shapefiles
library("doBy")
library("tidyverse")
library("tidycensus")
library("lwgeom")
library("data.table")
sf_use_s2(FALSE)  # S2 is for computing distances, areas, etc. on a SPHERE (using
# geographic coordinates, i.e., lat/lon in decimal-degrees); no need for this
# extra computational processing time if using PROJECTED coordinates,
# since these are already mapped to a flat surface. Here, pm25
# is indeed in geographic coordinates, but the scale of areas we are 
# interested in is very small, and hence the error introduced by 
# ignoring the Earth's curvature over these tiny areas is negligible and
# a reasonable trade off given the dramatic reduction in processing time. Moreover,
# the areas we calculate are not an integral part of the process
# and any error in that step would not materially impact the final output
options(tigris_use_cache = TRUE)

# Check package version numbers
#
if (packageVersion("terra") < "1.5.34"   | packageVersion("sf") < "1.0.7" | 
    packageVersion("plyr")  < "1.8.7"    | packageVersion("tigris") < "2.0.4" |
    packageVersion("doBy")  < "4.6.19"   | packageVersion("tidyverse") < "1.3.1" |
    packageVersion("tidycensus") < "1.5" | packageVersion("lwgeom") < "0.2.8" |
    R.version$minor < "4.0") {
  cat("WARNING: packages are outdated and may result in errors.") }

# The following variables come from the command line when running as bash
# If running for a single year/state, replace this code and skip past where
# the stateFIPS is indexed using stateFIPS$StFIPS[b] below
#     year <- 2010
#     stateFIPS <- 11
year <- as.numeric(args[1])
b <- as.numeric(args[2]) # state FIPS index

# %%%%%%%%%%%%%%%%%%%% IDENTIFY STATE FIPS OF INTEREST %%%%%%%%%%%%%%%%%%%%%%% #
# Reading in stateFIPS to allow for filtering by state in bash script
#
stateFIPS <- read.csv(config$paths$fips_csv, stringsAsFactors = FALSE)
stateFIPS$StFIPS <- formatC(stateFIPS$StFIPS, width = 2, format = "fg", flag = "0")
stateFIPS <- stateFIPS %>% filter(!StFIPS %in% c("02", "15"))

# Use NE subset for initial run
#
# Restrict to subset as needed
#
if (!isTRUE(grepl("Nationwide", state_fips))) {
  stateFIPS <- stateFIPS %>% filter(StFIPS %in% c(state_fips))
} else {
  stateFIPS <- stateFIPS
}

# Get subset from bash input
#
stateFIPS <- stateFIPS$StFIPS[b]   

########################## BUILDING FUNCTIONS  #################################

# Define a function to calculate sums such that if all values are NA then it returns
# NA rather than 0.
#
sumfun <- function(x) { return(ifelse(all(is.na(x)), as.double(NA), sum(x, na.rm = TRUE))) }

# In this step, we will use the extraction points to extract the temperature grid cell
# underlying each portion of a census block across the entire raster stack of values.
#
# Built as function to run for different exposures, areas, years, and decennial geos
#
process_prism_blocks <- function(exp_in, state_in, year, decyear) {
  
  var_stack <- paste0(exp_in, "/")
  decyear_abr <- substr(decyear, 3, 4)
    
  # Read in extraction points
  #
  extraction_pts <- readRDS(paste0(points_dir, "PRISM_extraction_points_tl", decyear_abr, "_block_", state_in, ".rds"))
  
  cat("----------------------------------------------------------------\n")
  cat("Beginning variable", exp_in, "\n")
  
  newvarname <- ifelse(exp_in %in% temp_vars, paste0(exp_in, "_C"), exp_in)
  
  # List raster files for variable and year
  #
  var_files <- list.files(paste0(prismdir, var_stack, "/", year, "/"), pattern=paste0('\\.tif$'))
  
  prism <- terra::rast(paste0(prismdir, var_stack, "/", year,  "/", var_files))
  
  # Extract data based on block extraction points
  #
  # Auto QC: confirm same CRS
  #
  if (isTRUE(all.equal(st_crs(prism), st_crs(extraction_pts)))) {
    prismpts <- terra::extract(prism, extraction_pts) # prism = rasterlayer or rasterstack; pts = points shapefile
    prismpts <- as_tibble(prismpts)
  } else { cat("ERROR: CRS mismatch between prism and extraction_pts \n"); break }
  
  # Extract GEOID
  #
  GEOID <- names(extraction_pts)[grep("GEOID|BLKIDFP", names(extraction_pts))]
  
  # Merge with data including spatial weight
  #
  prismpts <- bind_cols(as_tibble(extraction_pts[,c(GEOID, "SpatWt")]), prismpts) # The extraction is in the same order as the input pts
  prismpts$geometry <- NULL
  
  # Extract dates
  #
  dates <- substr(sapply(strsplit(names(prismpts)[grep("prism_", names(prismpts))], "_30s_"), "[", 2), 1, 8)
  names(prismpts)[grep("prism_", names(prismpts))] <- dates
  
  prismpts <- pivot_longer(prismpts, cols = all_of(dates), names_to = "PRISM_Date")
  names(prismpts)[which(names(prismpts) == "value")] <- newvarname
  
  # Convert your data frame to a data.table (if it's not already one)
  #
  prismpts <- as.data.table(prismpts)
  
  # Filter the rows based on no missing variable and summarize using data.table
  #
  avail <- prismpts[!is.na(get(newvarname)), 
                    lapply(.SD, sumfun), 
                    by = c(GEOID, "PRISM_Date"), 
                    .SDcols = "SpatWt"]
  
  # Merge this value back into the prismpts
  #
  prismpts <- merge(prismpts, avail, by = c(GEOID, "PRISM_Date"), all.x = TRUE)
  
  # Re-weight the area weight by dividing by total available weight
  #
  prismpts$SpatWt <- prismpts$SpatWt.x / prismpts$SpatWt.y
  
  # QC: check that the weights of *available data* all add to 1
  #
  check <- prismpts[!is.na(get(newvarname)), 
                    lapply(.SD, sumfun), 
                    by = c(GEOID, "PRISM_Date"), 
                    .SDcols = "SpatWt"]
  
  if (length(which(round(check$SpatWt, 4) != 1)) > 0) {
    cat("ERROR: weights do not sum to 1", "\n"); break 
  } else {
    cat(":) weights sum to 1", "\n")
    prismpts$SpatWt.y <- NULL
  }
  
  # Multiply the variable of interest (here "newvarname") by the weighting value and then
  # sum up the resultant values within census blocks. This is an area-weighted average;
  # we will use the same algorithm with population to get the population-weighted average
  # at tracts, counties, etc. later on in the code
  #
  tempvar <- paste0(newvarname, "_Wt")
  prismpts[[tempvar]] <- prismpts[[newvarname]] * prismpts[["SpatWt"]]
  prismpts[[tempvar]] <- as.numeric( prismpts[[tempvar]])
  
  # Summarize using data.table
  #
  final <- prismpts[, 
                    lapply(.SD, sumfun), 
                    by = c(GEOID, "PRISM_Date"), 
                    .SDcols = tempvar]
  
  # Automated QC to confirm that the dimensions are correct
  #
  if (length(unique(extraction_pts[[GEOID]][[GEOID]])) * length(unique(prismpts$PRISM_Date)) != dim(final)[1]) {
    cat("ERROR: incorrect dimensions of final df", "\n"); break
  } else { cat(":) dimensions of final df are as expected", "\n") }
  
  # Revise name
  if (exp_in %in% temp_vars) {
    newvarname <- paste0(exp_in, "_C")
  } else {
    newvarname <- exp_in
  }
  
  names(final)[grep(paste0("^", exp_in), names(final))] <- newvarname
  
  final <- as.data.frame(final)
  
  # Round to four digits (saves space)
  #
  final[[newvarname]] <- round(final[[newvarname]], 3)
  
  final <- final[c(GEOID, "PRISM_Date", newvarname)]
  
  # There is at least one year (2019) with an undated observation, which we 
  # will remove
  #
  final <- filter(final, nchar(PRISM_Date) > 4)

}

########################## RUNNING FUNCTIONS  #################################

# Select decennial geography based on PRISM year, then loop exposures
decyear_in <- map_decyear_by_year(year, decyear)

for (exp_in in exp_list) {
  cat("Running function for ", stateFIPS, " ", decyear_in, "\n")
  
  # Get decennial year marker
  #
  decyear_abr <- substr(decyear_in, 3, 4)
  
  # Run function for exposure input, state, year, and decennial year
  #
  output <- process_prism_blocks(exp_in = exp_in, 
                                 state_in = stateFIPS, 
                                 year = year, 
                                 decyear = decyear_in)
  
  # Grab GEOID to be used in building data with all exposures
  #
  GEO_ID <- names(output)[grepl("GEOID|BLKID", names(output))]
  
  if (exp_in == exp_list[1]) {
    all_data <- output
  } else {
    all_data <- left_join(all_data, output, by = c(GEO_ID, "PRISM_Date"))
  }
}

# Check output for decennial input:
#
cat("The final output has", dim(all_data)[1], "rows. \n")
cat("The first few lines of the output are: \n")
print(head(all_data))

# Automated QC: missing data
#
missing_counts <- sapply(exp_list_zcta, function(v) length(which(is.na(all_data[[v]]))))
if (any(missing_counts > 0)) {
  cat("WARNING: Note the number of missing block-days by variable: \n")
  for (v in names(missing_counts)[missing_counts > 0]) {
    cat(v, ":", missing_counts[[v]], "\n")
    cat("The first few lines of missing", v, "(if any) are printed below: \n")
    print(head(all_data[which(is.na(all_data[[v]])), ]))
  }
} else { cat(":) No missing PRISM values! \n") }

# Automated QC: impossible temperature values
#
temp_check_cols <- c("tmax_C", "tmean_C", "tmin_C")
if (all(temp_check_cols %in% names(all_data))) {
  num_temp_errors <- length(which(all_data$tmax_C < all_data$tmean_C |
                                    all_data$tmax_C < all_data$tmin_C |
                                    all_data$tmin_C > all_data$tmean_C |
                                    all_data$tmin_C > all_data$tmax_C))
} else {
  num_temp_errors <- 0
  cat("Skipping relative temperature QC because one or more temperature columns are absent.\n")
}

options(scipen = 999)
if (num_temp_errors > 0) { 
  cat("ERROR: impossible temperature values.\n")
  cat(paste0(round((num_temp_errors / dim(all_data)[1]) * 100, 4), "%"), "of block-days are incorrect. \n")
  cat("Applicable rows printed below: \n")
  print(all_data[which(all_data$tmax_C < all_data$tmean_C |
                            all_data$tmax_C < all_data$tmin_C |
                            all_data$tmin_C > all_data$tmean_C |
                            all_data$tmin_C > all_data$tmax_C),])
} else { print(":) all temperature values are of correct *relative* magnitude") }

# Save result 
#
saveRDS(all_data, paste0(paste0(block_outdir, "blocks_", decyear_abr, "/", year, "/tl", decyear_abr, "_prism_daily_", year, "_", stateFIPS, ".rds")))

