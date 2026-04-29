# ****************************************** #
# ~~~~~ ACRES-POPULATION WEIGHTED MEAN ~~~~~ #
# ****************************************** #
#   Date created: 2025-02-26 (v01)
#   Last modified:  
#   Created by:     Zach P. (zpopp@bu.edu)
#   Modified from:  Keith Spangler, Muskaan Khemani
#   Modifications:  
#
##Purpose: Population weighting of blocks to ZCTAs
##
##Overall Processing Steps:
## 1) Create Fishnet that can be used to extract PRISM data from raster stack
##    00a_Create_Fishnet_PRISMv2_800m_v02.R 
## 2) Load block geographies including decennial and year-specific IDs, and 
##    conduct union of block geometries with fishnet developed in step 1 (01a_Extraction_Pts).
## 3) Create extraction points from the union of the block and fishnet. These 
##    are what we can use to extract values from the raster that overlaps with
##    with the points aligning to each block (01a_Extraction_Pts).
## 4) Estimate the block-level exposure to PRISM, accounting for the availability
##    of data within the block 02a_PRISM_Raster_Extract_v03.R)
## 5) Link blocks with population and crosswalk to ZCTA. Aggregate from block
##    to ZCTA based on population weights
##
## Overview:
## 1) Read in block PRISM measures and state-level block - ZCTA crosswalk
## 2) For each variable (Tmax, Tmean, Tmin) weight the block-level exposure
##    based on the state-level ZCTA block aggregate population. This will 
##    provide a block population-weighted ZCTA mean for each ZCTA in the 
##    state
## 3) This is output and then a weight can be applied to each state ZCTA based
##    on the proportion of the ZCTA population within the state, and the 
##    ZCTA exposure weighted on population across states can be assessed.
##
##  NOTE: 
##      This file relies on a block to ZCTA crosswalk being built for linkage
##      with the meteorological block variables that have already been created.
##      Code demonstrating this process can be found at:
##            https://github.com/Climate-CAFE/block2zcta_xwalk
##      Within the code, the output from this process are expected to be stored
##      in rawdata/crosswalk/

# This script population-weights block-level data up to ZCTA values
#
library("yaml")
library("terra")  # For raster data
library("sf")     # For vector data
library("plyr")
library("dplyr")
library("tigris") # For downloading census shapefiles
library("doBy")
library("tidyverse")
library("tidycensus")
library("lwgeom")
sf_use_s2(FALSE)  # S2 is for computing distances, areas, etc. on a SPHERE (using
# geographic coordinates, i.e., lat/lon in decimal-degrees); no need for this
# extra computational processing time if using PROJECTED coordinates,
# since these are already mapped to a flat surface. Here, PRISM
# is indeed in geographic coordinates, but the scale of areas we are 
# interested in is very small, and hence the error introduced by 
# ignoring the Earth's curvature over these tiny areas is negligible and
# a reasonable trade off given the dramatic reduction in processing time. Moreover,
# the areas we calculate are not an integral part of the process
# and any error in that step would not materially impact the final output
options(tigris_use_cache = TRUE)

# %%%%%%%%%%%%%%%%%%%%%%% USER-DEFINED PARAMETERS %%%%%%%%%%%%%%%%%%%%%%%%%%%% #
# Load configuration from config.yaml.
# The config path can be passed as the third command-line argument (after year
# and state index); if omitted, the script looks for config.yaml in the
# current directory then one level up.
#
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

# Variables to aggregate to ZCTA.
# Temperature variables (tmax, tmin, tmean, tdmean) get a "_C" suffix;
# all others (e.g. ppt) keep their original name.
temp_vars <- c("tmax", "tmin", "tmean", "tdmean")
exp_list_raw <- as.character(unlist(config$processing$exp_list))
exp_list <- ifelse(exp_list_raw %in% temp_vars, paste0(exp_list_raw, "_C"), exp_list_raw)

# Create decennial period indicator. Block data is only available from the decennial
# census
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

# If running for a subset of states, list below. If running nationwide:
#   state_fips: "Nationwide"
state_fips <- as.character(unlist(config$processing$state_fips))

# This directory is where the block data with daily PRISM variables will be
# saved to. Note that the output is written with the expectation of nested
# directories within this outdir for decennial census geography and year of
# PRISM data, ie:
#       outdir/blocks/blocks_10/2000/
# Please edit the output line at the end of the script as needed based on your
# data structure
block_outdir <- config$paths$block_outdir

# This directory is where the ZCTA-level data will be saved to, with nested
# directories for decennial census geography, ie:
#       outdir/zcta/zcta_10/
zcta_outdir <- config$paths$zcta_outdir

# This is where the block to ZCTA crosswalk should be stored.
# See https://github.com/Climate-CAFE/block2zcta_xwalk for details
cross_dir <- config$paths$crosswalk_dir

# Check package version numbers
#
if (packageVersion("terra") < "1.5.34"   | packageVersion("sf") < "1.0.7" | 
    packageVersion("plyr")  < "1.8.7"    | packageVersion("tigris") < "2.0.4" |
    packageVersion("doBy")  < "4.6.19"   | packageVersion("tidyverse") < "1.3.1" |
    packageVersion("tidycensus") < "1.5" | packageVersion("lwgeom") < "0.2.8") {
  cat("WARNING: packages are outdated and may result in errors. \n") }

# User-defined function for summing values; returns NA if all values are NA
#
sumfun <- function(x) { ifelse(all(is.na(x)), return(NA), return(sum(x, na.rm = TRUE))) }

# Read in command line arguments
#
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

# Crosswalk block up to ZCTA for a list of variable inputs, a given state,
# year and decennial census
#
block2zcta_walk <- function(varnames, state_in, year, decyear) {
  
  decyear_abr <- substr(decyear, 3,4)
  
  # Update directories based on year/decennial year
  #
  blockoutdir <- paste0(block_outdir, "blocks_", decyear_abr, "/", year, "/")
  output_data_dir <- zcta_outdir # Enter the full pathway of the directory where your output data will be stored.
  block_zcta_dir <- paste0(cross_dir)
  
  # %%%%%%%%%%%%%% STEP 1. READ IN BLOCK - ZCTA CROSSWALK %%%%%%%%%%%%%%%%%%%%%% #
  # Read in Census block crosswalk
  #
  block_zctas <- readRDS(paste0(block_zcta_dir, "Block_to_ZCTA_", decyear, "_", state_in, ".Rds"))
  
  # Remove the extraneous columns; we only need block GEOID, ZCTA GEOID, and population (if available)
  # n.b., some census block shapefiles include populations but not others. The code
  # here assumes that the shapefile does not include population. The name of the GEOID
  # will change depending on the census year; confirm that block_geoid correctly
  # identifies it. Modify as needed. Both the blocks and ZCTA shapefiles may have
  # variables called GEOID; the block one will come first if intersection is done
  # with block first.
  #
  block_geoid <- names(block_zctas)[grep("^GEOID|BLKIDFP", names(block_zctas), ignore.case = TRUE)[1]]
  zcta_geoid <- names(block_zctas)[grep("^ZCTA", names(block_zctas), ignore.case = TRUE)[1]]
  
  # Get the GEOID for the block shapefile and for the block populations file, which may 
  # change depending on the year of Census data
  #
  GEOID_shapefile <- names(block_zctas)[grep("^GEOID|BLKIDFP", names(block_zctas), ignore.case = TRUE)[1]]
  
  # %%%%%%%%%%%% STEP 2. READ IN PRISM BLOCKS THEN WEIGHT TO ZCTA %%%%%%%%%%%% #
  #
  # Read in the block-level PRISM values
  #
  prism_block <- readRDS(paste0(blockoutdir, "/tl", decyear_abr, "_prism_daily_", year, "_", state_in, ".rds"))
  
  # Grab the GEOID that is in the PRISM dataset
  #
  GEOID_prism <- names(prism_block)[grep("^GEOID|BLKIDFP", names(prism_block), ignore.case = TRUE)]
  
  # Merge exposure dataset with block:ZCTA crosswalk
  #
  bl_zcta_prism <- merge(block_zctas, prism_block, by.x = GEOID_shapefile, by.y = GEOID_prism, all.x = TRUE)
  
  # Track non-linked blocks
  #
  missing_zcta <- is.na(bl_zcta_prism[[zcta_geoid]])
  if (any(missing_zcta)) {
    cat("WARNING: Not all blocks linked to ZCTA. Missing blocks listed below: \n")
    cat(unique(bl_zcta_prism[[GEOID_shapefile]][missing_zcta]))
  }
  
  # Function to check for leap year so that it will work for any year
  #
  leap_year <- function(year) { return(ifelse((year %% 4 == 0 & year %% 100 != 0) | year %% 400 == 0, TRUE, FALSE)) }
  isleap <- leap_year(year)
  numdays <- ifelse(isleap, 366, 365)
  
  popvar <- paste0("Pop_", decyear)
  subgeowt <- "Spatial_Weight"
  availwt <- "Spatial_Weight.sumfun"
  
  # For loop is used to calculate for each variable
  #
  for (i in 1:length(varnames)) {
    
    cat("..........Processing variable", varnames[i], "\n")
    
    # Calculate available weights which accounts for missingness in eventual output
    #
    avail <- summaryBy(as.formula(paste0("Spatial_Weight  ~ PRISM_Date +", zcta_geoid)),
                       data = bl_zcta_prism[which( !(is.na(bl_zcta_prism[varnames[i]])) ),],
                       FUN = sumfun)
    
    # Merge available weight with raw weight
    #
    bl_zcta_prism_merge <- merge(bl_zcta_prism, avail, by = c(zcta_geoid, "PRISM_Date"), all.x = TRUE)
    
    # Mark as NA any ZCTA-day in which <50% of data are available
    #
    bl_zcta_prism_merge[[availwt]][which(bl_zcta_prism_merge[[availwt]] < 0.50)] <- NA
    
    # Adjust weight based on availability of data
    #
    bl_zcta_prism_merge[[subgeowt]] <- bl_zcta_prism_merge[[subgeowt]] / bl_zcta_prism_merge[[paste0(subgeowt, ".sumfun")]]
    
    varwt <- paste0(varnames[i], "_Wt")
    bl_zcta_prism_merge[[varwt]] <- bl_zcta_prism_merge[[varnames[i]]] * bl_zcta_prism_merge[[subgeowt]]
    
    # Automated QC: Check to see if appropriate sum of weights
    #
    check1 <- summaryBy(as.formula(paste0(subgeowt, " ~ ", zcta_geoid, " + PRISM_Date")),
                        data = bl_zcta_prism_merge[which( !(is.na(bl_zcta_prism_merge[varnames[i]])) ),],
                        FUN = sumfun)
    
    if (length(which(round(check1[[paste0(subgeowt, ".sumfun")]], 4) != numdays)) > 0) {
      cat("WARNING: weights do not all sum to 1 \n") 
      cat("...... total number of rows marked as NA:", length(which(is.na(bl_zcta_prism_merge[[varwt]]))), "\n")
      allNA <- check1[[zcta_geoid]][which(is.na(check1[[paste0(subgeowt, ".sumfun")]]))]
      cat("...... number of geographies with NA on all days:", length(allNA), "\n")
      missingNon0 <- length(which(bl_zcta_prism_merge[[popvar]][which(bl_zcta_prism_merge[[zcta_geoid]] %in% allNA)] != 0))
      if (missingNon0 > 0) { cat("...... ERROR: some non-zero pop blocks are missing ALL days"); break }
      cat("............ >> among these,", missingNon0, "have non-zero populations \n")
      cat("...... among non-zero pop. geos, total number of geo-days missing:", sumfun(numdays - check1[[paste0(subgeowt, ".sumfun")]]), "\n")
    } else { cat(":) all weights sum to 1 \n") }
    
    # Sum the partial weights of the variable to get the final population-weighted value
    #
    final_wt <- summaryBy(as.formula(paste0(varwt, " ~ PRISM_Date + ", zcta_geoid)),
                          data = bl_zcta_prism_merge, FUN = sumfun)
    
    names(final_wt)[grep(varnames[i], names(final_wt))] <- varnames[i]
    
    final_wt[[varnames[i]]] <- round(final_wt[[varnames[i]]], 4)
    
    if (i == 1) { final <- final_wt; next }
    
    if (all.equal(final[[zcta_geoid]], final_wt[[zcta_geoid]])) {
      final <- cbind(final, final_wt[varnames[i]])
    } else { cat("ERROR: GEOID mismatch \n") }
    
  }
  
  # Save resulting dataset
  #
  cat("The final output has", dim(final)[1], "rows. \n")
  cat("The first few lines of the output are: \n")
  print(head(final))
  
  # ZCTAs that are less than 10m in area will not be included due to removal in
  # the fishnet formation process. Remove them from the output
  #
  final <- final[!is.na(final$PRISM_Date), ]
  
  # Automated QC: missing data
  #
  missing_counts <- sapply(exp_list, function(v) length(which(is.na(final[[v]]))))
  if (any(missing_counts > 0)) {
    cat("WARNING: Note the number of missing ZCTA-days by variable: \n")
    for (v in names(missing_counts)[missing_counts > 0]) {
      cat(v, ":", missing_counts[[v]], "\n")
      cat("The first few lines of missing", v, "(if any) are printed below: \n")
      print(head(final[which(is.na(final[[v]])), ]))
    }
  } else { cat(":) No missing PRISM values! \n") }

  # Check if all of the missing vars are in ZCTAs with no population.
  # Uses the first variable in exp_list as the missingness indicator.
  #
  first_var <- exp_list[1]
  ZCTA_missing <- filter(final, !is.na(PRISM_Date) & is.na(!!sym(first_var)))
  
  # Subset block-ZCTA cross to missing data
  #
  check_population <- filter(block_zctas, !!sym(zcta_geoid) %in% ZCTA_missing[[zcta_geoid]])
  
  # Assess if all population is Zero
  #
  if (dim(check_population)[1] == 0) {
    print(":) No missingness")
  } else if (all(check_population$Pop_ZCTA == 0)) { 
    print(":) Missingness attributable to zero population.")
  } else {
    print("ERROR: Missingness NOT attributable to zero population. Assess output further.")
    break
  }
  
  # Automated QC: impossible temperature values
  #
  num_temp_errors <- length(which(final$tmax_C < final$tmean_C |
                                    final$tmax_C < final$tmin_C |
                                    final$tmin_C > final$tmean_C |
                                    final$tmin_C > final$tmax_C))
  
  if (num_temp_errors > 0) { 
    print("ERROR: impossible temperature values. Applicable rows printed below:")
    print(final[which(final$tmax_C < final$tmean_C |
                        final$tmax_C < final$tmin_C |
                        final$tmin_C > final$tmean_C |
                        final$tmin_C > final$tmax_C),])
  } else { print(":) all temperature values are of correct *relative* magnitude") }
  
  
  return(final)
}

# Select decennial geography based on PRISM year
decyear_in <- map_decyear_by_year(year, decyear)

cat("Running function for ", decyear_in, "\n")

# Get marker of decennial year
#
decyear_abr <- substr(decyear_in, 3, 4)

# Run function
#
output <- block2zcta_walk(varnames = exp_list, state_in = stateFIPS,
                          year = year, decyear = decyear_in)

# Set output directory based on decennial year
#
outdir <- paste0(zcta_outdir, "zcta_", decyear_abr, "/")
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

# Save output
#
saveRDS(output, paste0(outdir, "PRISM_ZCTA", decyear_abr, "_",year ,"_", stateFIPS,".Rds"))
