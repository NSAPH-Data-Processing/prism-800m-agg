# ************************************************************** #
# ~~~~~  ACRES-PRISM Build Extraction Points       ~~~~~ #
# ************************************************************** #
#   Date created:  2025-02-26
#   Last modified:  
#   Created by:     Zach P. (zpopp@bu.edu)
#   Modified from:  Keith Spangler, Muskaan Khemani
#   Modifications:  
#
# Purpose: Process daily temperature rasters to census blocks nationwide
# Overall Processing Steps:
#  1) Create Fishnet that can be used to extract PRISM data from raster stack
#     00a_Create_Fishnet_PRISMv2_800m_v01.R (previous file)
#  2) Load block geographies including decennial and year-specific IDs, and 
#     conduct union of block geometries with fishnet developed in step 1 (this file).
#  3) Create extraction points from the union of the block and fishnet. These 
#     are what we can use to extract values from the raster that overlaps with
#     with the points aligning to each block (this file).
#  4) Estimate the block-level exposure to PRISM, accounting for the availability
#     of data within the block (next file).
#
# Overview:
#   We are creating a system of points that represent the unique intersection
#   of our raster grid and block polygon data. Creating this system of points
#   will help us to more quickly link the raster temperature and precipitation
#   data with block geographies, and to compute area-weighted estimates that 
#   cover the census block. We use this instead of zonal statistics because we
#   are trying to process 350+ rasters per year. This file takes the previously
#   created grid polygon for a state, links it to the block polygons of that 
#   state, and then converts the linked grids into points with a spatial weight
#   representing the portion of the block the point should represent. 
#
#   This script is set to run as a batch script by state, because both the 
#   fishnet and block polygon data are quite large. User parameters can be input
#   to adjust the decennial census geography used and which states to process.
#   Selection of an appropriate census geography will depend on the planned use
#   of the data. The end product of this repository is population-weighted
#   estimates (at the ZCTA or county, tract, block group). If the goal is to 
#   link ZCTA estimates with health data, consult the health data dictionary
#   to verify what years were used to define the area-level health outcomes.
#
#   If the data runs from 2000 to 2025 at the Zip code level, then separate
#   geographies may be needed for 2000 to 2009, from 2010 to 2019, and 2020
#   to 2025 given that the block geographies and population have changed over
#   time. If you are aiming to have a longitudinal analysis at the ZCTA or county
#   level, then using a single decennial census geography may be most advantageous
#   to ensure that observed changes are reflective of changing climate variables
#   as opposed to changes in the population distribution. 
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
# The config path can be passed as the second command-line argument (after the
# state FIPS index); if omitted, the script looks for config.yaml in the
# current directory then one level up.
#
library("yaml")
args <- commandArgs(trailingOnly = TRUE)
.config_path <- if (length(args) >= 2 && grepl("\\.ya?ml$", args[length(args)])) {
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

# If running for a subset of states, list below. If running nationwide:
#   state_fips: "Nationwide"
state_fips <- as.character(unlist(config$processing$state_fips))

# Set decennial years to process output extraction points
#
decyear <- as.numeric(unlist(config$processing$decyear))

# This directory is used just to read in the state FIPS codes which are then
# subset based on a bash input. This file can be built by using tigris::states
# and restricting to CONUS as below:
#         fips <- tigris::states(year = 2020)
#         fips <- fips[fips$REGION %in% c(1:4) & !fips$STATEFP %in% c("02", "15"),]
fipsdir <- config$paths$fips_dir

# This directory should include the output from script 00a_Create_Fishnet
fishdir <- config$paths$fishnet_dir

# This directory should include the block census geographies, divided by
# decennual census as needed (The script expects a subfolder labeled
# as 2000, 2010 or 2020).
block_geo <- config$paths$block_shapefile_dir

# This directory should include the raw PRISM 800m raster files.
# The structure below assumes the raw data have been stored as
#       RawData --> variable directories --> year directories
prismdir <- config$paths$rawdata_dir

# This directory is where the linked points will be written to
points_dir <- config$paths$extraction_pts_dir


# Read in all packages 
#
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
# since these are already mapped to a flat surface. Here, PRISM
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
    packageVersion("tidycensus") < "1.5" | packageVersion("lwgeom") < "0.2.8") {
  cat("WARNING: packages are outdated and may result in errors.") }

# The following variables come from the command line when running as bash.
# If you want to run for a single state/county/area, remove these lines and
# update the stateFIPS below
#
b <- as.numeric(args[1]) # state FIPS index

# %%%%%%%%%%%%%%%%%%%% IDENTIFY STATE FIPS OF INTEREST %%%%%%%%%%%%%%%%%%%%%%% #
# Reading in stateFIPS to allow for filtering by state in bash script
#
stateFIPS <- read.csv(paste0(fipsdir, "US_States_FIPS_Codes.csv"), stringsAsFactors = FALSE)
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
# If running for a single state, update below
#         stateFIPS <- "11"
stateFIPS <- stateFIPS$StFIPS[b]   

########################## BUILDING FUNCTIONS ##################################
# Reference/credit: https://stackoverflow.com/a/68713743
#
my_union <- function(a,b) {
  st_agr(a) = "constant"
  st_agr(b) = "constant"
  op1 <- st_difference(a, st_union(b))
  op2 <- st_difference(b, st_union(a))
  op3 <- st_intersection(b, a)
  union <- rbind.fill(op1, op2, op3)
  return(st_as_sf(union))
}

# Build function so it is easy to run across different decennial censuses
#
build_prism_ext_points <- function(decyear, state_in) {
  
  # Get abbreviated decennial year
  #
  decyear_abr <- substr(decyear, 3,4)
  
  # Set directories
  #
  shpdir <- paste0(block_geo, decyear, "/")
 
  # Read in Census blocks
  #
  blocks <- st_read(paste0(shpdir, 
                           ifelse(decyear == 2000, paste0("tl_2010_", stateFIPS, "_tabblock00.shp"),
                                  ifelse(decyear == 2010, paste0("tl_2010_", stateFIPS, "_tabblock10.shp"),
                                         ifelse(decyear == 2020, paste0("tl_2020_", stateFIPS, "_tabblock20.shp"), NA)))))
  
  # Establish block extent
  #
  extent <- st_bbox(blocks)
  
  # Add approx. 1-kilometer buffer around the extent
  #
  extent[["xmin"]] <- extent[["xmin"]] - 0.01
  extent[["ymin"]] <- extent[["ymin"]] - 0.01
  extent[["xmax"]] <- extent[["xmax"]] + 0.01
  extent[["ymax"]] <- extent[["ymax"]] + 0.01
  
  # Create a polygon representing the bounding box
  #
  extent_poly <- st_as_sfc(extent, crs=4326)
  
  # We can create a SQL query filter to only load tracts associated with a FIPS code
  # convert the state extent polygon into WKT text
  #
  wkt <- st_as_text(extent_poly)
  
  # Read in the fishnet created previously
  #
  fishnet_name <- paste0("prism_fishnet_", config$fishnet$variable, "_800m")
  fishnet <- st_read(paste0(fishdir, fishnet_name, ".gpkg"), layer=fishnet_name, wkt_filter=wkt)
  
  # Does not matter which PRISM grid we bring in -- it will be the same grid regardless of date
  #
  prism_files <- list.files(prismdir, pattern = ".tif", recursive = TRUE, full.names = TRUE)
  prism <- terra::rast(prism_files[1])
  
  # Match CRS to PRISM data
  #
  blocks <- st_transform(blocks, crs = st_crs(prism))
  fishnet <- st_transform(fishnet, crs = st_crs(prism))
  
  if (!isTRUE(all.equal(st_crs(blocks), st_crs(fishnet)))) {
    cat("ERROR: CRS's don't match \n")  } else { cat(":) CRS's match \n") }
  
  # Ensure geometries are valid
  #
  blocks <- st_make_valid(blocks) 
  fishnet <- st_make_valid(fishnet)
  
  # Rename fishnet to geom to geometry for union
  #
  fishnet <- fishnet %>%
    dplyr::rename(geometry = geom)
  
  # Create the union between the fishnet and blocks layers
  #
  fishnetblock <- my_union(fishnet, blocks)
  fishnetblock$UniqueID <- 1:dim(fishnetblock)[1]
  
  # Automated QC -- Check to see if the union has introduced any geometry errors
  #                 and fix as appropriate
  #
  check <- try(st_make_valid(fishnetblock), silent = TRUE)
  
  if (class(check)[1] == "try-error") {
    
    cat("There is an issue with the sf object \n")
    cat("..... Attempting fix \n")
    
    geo_types <- unique(as.character(st_geometry_type(fishnetblock, by_geometry = TRUE)))
    
    cat("..... Geometry types in sf object 'fishnetblock':", geo_types, "\n")
    
    for (j in 1:length(geo_types)) {
      
      fishnetblock_subset <- fishnetblock[which(st_geometry_type(fishnetblock, by_geometry = TRUE) == geo_types[j]),]
      if (j == 1) { updated_fishnetblock <- fishnetblock_subset; next }
      updated_fishnetblock <- rbind(updated_fishnetblock, fishnetblock_subset)
      
    }
    
    check2 <- try(st_make_valid(updated_fishnetblock), silent = TRUE)
    
    if (class(check2)[1] == "try-error") {
      cat("..... ERROR NOT RESOLVED \n") } else {
        cat("..... :) issue has been fixed! \n")
        
        updated_fishnetblock <- updated_fishnetblock[order(updated_fishnetblock$UniqueID),]
        if ( !(all.equal(updated_fishnetblock$UniqueID, fishnetblock$UniqueID)) ) {
          cat("ERROR: Unique IDs do not match \n") } else {
            cat(":) unique ID's match. Reassigning 'updated_fishnetblock' to 'fishnetblock' \n")
            fishnetblock <- updated_fishnetblock    
          }
      }
  }
  
  
  # Automated QC check -- ensure that there is a variable identifying the census
  #                       geographies. Note that these variable names may change
  #                       depending on the year of the census data. For years where
  #                       multiple census geography indicators are available, one
  #                       will be selected
  #
  state_id_var <- names(fishnetblock)[grep("^STATEFP", names(fishnetblock), ignore.case = TRUE)]
  
  if (length(state_id_var) != 1) {
    cat("ERROR: missing variable name or multiple matches \n") 
    state_id_var <- state_id_var[1]  # ZP added this line to select a state ID if multiple are present
    if (length(state_id_var) == 1) {
      cat("Selected ",state_id_var[1], " as state ID" ) 
    } else {
      cat("Error remains")}
  } else {
    cat(":) variable name present. It is called", state_id_var, "\n") }
  
  # Identify the polygons of the fishnet that do not intersect with the census
  # data; drop them.
  #
  before_dim <- dim(fishnetblock)[1]
  fishnetblock <- fishnetblock[which( !(is.na(fishnetblock[[state_id_var]])) ),]
  after_dim <- dim(fishnetblock)[1]
  
  cat("Dropped", before_dim - after_dim, "polygons that do not intersect with census data \n")
  
  # Some polygons formed in the union are incredibly small -- this adds unnecessary
  # computation time without materially reducing error. Drop the small polygons.
  # NOTE: Typically, when calculating areas of polygons, you would want to convert to
  #       a projected CRS appropriate for your study domain. For the purpose of identifying
  #       negligibly small areas to drop here, the error introduced by using geographic
  #       coordinates for calculating area at this scale is negligible.
  #
  fishnetblock$Area_m2 <- as.numeric(st_area(fishnetblock))
  
  fishnetblock <- fishnetblock[which(fishnetblock$Area_m2 > 10),]
  
  # %%%%%%%%%%%%%%%%%%%%%%%%%%%% CONVERT POLYGON TO POINTS %%%%%%%%%%%%%%%%%%%%% #
  #
  # The final step is to create the extraction points. This is a point shapefile
  # that will enable us to extract prism data from an entire stack of rasters rather
  # than individually processing zonal statistics on each raster layer. 
  #
  # NOTE: This step throws a warning message related to using geographic coordinates 
  #       rather than a projected CRS. This step is only placing a point inside the 
  #       polygon to identify which prism grid cell we need to extract from; as all
  #       of the input data are on the same CRS and the spatial scale of the polygons
  #       is extremely small, this does not introduce substantive error.
  #
  extraction_pts <- st_point_on_surface(fishnetblock)
  
  # %%%%%%%%%%%%%%%%%%%%% CALCULATE LAND-AREA WEIGHTED AVG BY BLOCK %%%%%%%%%%%% #
  #
  #
  # Set the unique geographic identifier (GEOID) from the extraction_pts sf object
  #
  GEOID <- names(blocks)[grep("GEOID|BLKIDFP", names(blocks))]
  
  # Get the total area by block to calculate the spatial weight value (typically 1.0)
  #
  eqn <- as.formula(paste0("Area_m2 ~ ", GEOID))
  
  # Define a function to calculate sums such that if all values are NA then it returns
  # NA rather than 0.
  #
  sumfun <- function(x) { return(ifelse(all(is.na(x)), as.double(NA), sum(x, na.rm = TRUE))) }
  
  # Calculate the sum area by block
  #
  ptstotal <- summaryBy(eqn, data = as.data.frame(extraction_pts), FUN = sumfun)
  
  # Merge area and calculate spatial weight of points
  #
  extraction_pts <- merge(extraction_pts, ptstotal, by = GEOID, all.x = TRUE)
  extraction_pts$SpatWt <- extraction_pts$Area_m2 / extraction_pts$Area_m2.sumfun
  
  # Convert the extraction_pts to a SpatVector object
  #
  extraction_pts <- terra::vect(extraction_pts)
  
  # Return 
  #
  return(extraction_pts)
}

########################## RUNNING FUNCTIONS BY YEAR ###########################

# Loop through decennial censes to process PRISM grid against blocks
#
for (decyear_in in decyear) {
  
  cat("Running function for ", stateFIPS, " ", decyear_in, "\n")
  
  # Get shortened decennial year marker
  #
  decyear_abr <- substr(decyear_in, 3, 4)
  
  # Run function
  #
  output <- build_prism_ext_points(decyear = decyear_in, state_in = stateFIPS)
  
  # Save result
  #
  saveRDS(output, paste0(points_dir, "PRISM_extraction_points_tl", decyear_abr, "_block_", stateFIPS, ".rds"))
}
