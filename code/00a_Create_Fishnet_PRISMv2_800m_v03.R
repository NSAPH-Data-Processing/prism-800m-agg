# ************************************************************** #
# ~~~~~  ACRES-Temperature Processing Daily Raster to Blocks       ~~~~~ #
# ************************************************************** #
#   Date created:   2025-03-14
#   Last modified:  
#   Created by:     Zach P. (zpopp@bu.edu)
#   Modified from:  Keith Spangler, Muskaan Khemani
#   Modifications:  

##Purpose: Process daily temperature rasters to census blocks, then aggregate to 
##          additional geos, nationwide
##Overall Processing Steps:
## 1) Create Fishnet that can be used to extract PRISM data from raster stack
##    including temperature daily data (this file). 
##    This will allow for extraction from raster stack to block-level estimates 
##    without the large computational burden of a terra::zonal loop
##
## 2) Load block geographies (2000 dicennial, then yearly after 2010) and 
##    population (dicennial block), and conduct union of block geometries
##    with fishnet developed in step 1 (next file).
## 3) Create extraction points from the union of the block and fishnet. These 
##    are what we can use to extract values from the raster that overlaps with
##    with the points aligning to each block (next file).
## 4) Estimate the block-level exposure to temperature, accounting for the availability
##    of data within the block (next file).
## 5) Use population-weighting to derive exposure data for block group, tract,
##    and county levels (next file).

library("terra")  # For raster data
library("sf")     # For vector data
library("plyr")
library("tigris") # For downloading census shapefiles
library("doBy")
library("tidyverse")
library("tidycensus")
library("lwgeom")
sf_use_s2(FALSE)  
# S2 is for computing distances, areas, etc. on a SPHERE (using
# geographic coordinates, i.e., lat/lon in decimal-degrees); no need for this
# extra computational processing time if using PROJECTED coordinates,
# since these are already mapped to a flat surface. Here, temperature
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

# Set input year - this can be any year for which PRISM data is available.
# The raster grid will be consistent across all years.
#
year <- 2010

# %%%%%%%%%%%%%%%%%%%%%%% USER-DEFINED PARAMETERS %%%%%%%%%%%%%%%%%%%%%%%%%%%% #
# Set working directory
#
setwd("")

# This directory should include the raw PRISM 800m raster files.
# The structure below assumes the raw data have been stored as
#       RawData --> variable directories --> year directories
prismdir <- paste0("rawdata/tmax/", year, "/")

# The directory below is where the final fishnet will be outputs
outdir <- "intermediate/fishnet/"

# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% #
# %%%%%%%%%%%%%%%%%% CREATE Temperature EXTRACTION POINTS  %%%%%%%%%%%%%%%%%%% #
# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% #
#
# %%%%%%%%%%%%%%%%%%%%% READ IN THE Temperature RASTER DATA %%%%%%%%%%%%%%%%%% #
#
# NOTE: Any given PRISM raster can be used for this process. We read in all 
# rasters and then extract the first in the stack for creation of the fishnet
# below. Any raster works since they have the same grid
#
tmax_files <- list.files(prismdir, pattern=paste0('\\.tif$'), full.names = F)

# Stack all of the daily files by year
#
tmax_files <- paste0(prismdir, tmax_files)
tmax_raster <- rast(tmax_files[1])

# %%%%%%%%%%%%%%%%%%%% CREATE A FISHNET GRID OF THE RASTER EXTENT %%%%%%%%%%%% #
#
# Here, we are making a shapefile that is a fishnet grid of the raster extent.
# It will essentially be a polygon of lines surrounding each temperature cell.
#
# Reference/credit: https://gis.stackexchange.com/a/243585
#
# This process is time and compute-intensive (especially the st_make_grid line)
#
# Example code below is provided to crop the raster to a single state shapefile
# and process
#   state_in <- tigris::counties(state = "DC", year = 2010)
#   tmax_raster <- terra::crop(tmax_raster, ext(state_in))
#
#
tmax_extent <- ext(tmax_raster)
xmin <- tmax_extent[1]
xmax <- tmax_extent[2]
ymin <- tmax_extent[3]
ymax <- tmax_extent[4]

tmax_matrix <- matrix(c(xmin, ymax,
                          xmax, ymax,
                          xmax, ymin,
                          xmin, ymin,
                          xmin, ymax), byrow = TRUE, ncol = 2) %>%
  list() %>% 
  st_polygon() %>% 
  st_sfc(., crs = st_crs(tmax_raster))

tmax_rows <- dim(tmax_raster)[1]
tmax_cols <- dim(tmax_raster)[2]
tmax_fishnet <- st_make_grid(tmax_matrix, n = c(tmax_cols, tmax_rows), 
                               crs = st_crs(tmax_raster), what = 'polygons') %>%
  st_sf('geometry' = ., data.frame('ID' = 1:length(.)))

# Write fishnet to output as gpkg
#
st_write(tmax_fishnet, paste0(outdir, "prism_fishnet_tmax_800m.gpkg"), append=FALSE)

# Automated QC check -- confirm same coordinate reference system (CRS) between
#                       the fishnet and temperature raster
if ( !(all.equal(st_crs(tmax_raster), st_crs(tmax_fishnet))) ) {
  cat("ERROR: CRS's do not match \n") } else { cat(":) CRS's match \n") }
