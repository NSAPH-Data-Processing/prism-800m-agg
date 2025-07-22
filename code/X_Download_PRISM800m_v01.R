
# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% #
# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%% OVERVIEW  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% #
# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% #
#
# Step 1. Bulk-download PRISM data from FTP
# Step 2. Create PRISM extraction points
# Step 3. Calculate land-area weighted PRISM values at the census block level
# Step 4. Calculate *population*-weighted PRISM values at the census block group through county levels 
#
# This code is designed to illustrate the calculation of population-weighted mean
# values in PRISM for a single month in Washington, D.C.
#
# The code can be adapted to multiple times and locations, but requires substantial
# computing time. It is recommended that for nationwide analyses one use distributed 
# processing on a computing cluster, divided between time and space (for example,
# processing one month at a time for individual states).
#
# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% #
# %%%%%%%%%%%%%%%%%% STEP 1: DOWNLOAD PRISM DATA FROM FTP %%%%%%%%%%%%%%%%%%%% #
# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% #
#
# Most applications do not need the enhanced resolution, and one should note
# that the higher-resolution product does not resolve urban heat islands; the modeling
# methodology does not incorporate urbanization characteristics such as LST, albedo,
# or imperviousness of surfaces (which are proxy indicators of UHI).
#
options(timeout=1000) # Set the max timeout (in seconds) for downloading files

# Set working directory
#
setwd("C:/Users/zpopp/OneDrive - Boston University/Desktop/CAFE/PRISM800m/prism-800m-agg/")

# Full pathway of the directory where your input data will be stored.
input_data_dir <- "rawdata/"   

# Set the directory for where the .zip PRISM files
# will be saved. If changing this directory, 
# be sure to keep the final forward slash
zip_file_dir <- "rawdata/zip_files/" 

# Identify the PRISM variables that you want to download using the syntax from
# the PRISM FTP. For the purpose of this tutorial, we are just using "tmax" and "tmin".
# Other options available: c("ppt", "tdmean", "tmean", "tmin", "vpdmax", "vpdmin")
#
vars <- c("ppt", "tdmean", "tmean", "tmin", "tmax")

# The baseline URL for the PRISM FTP directory for daily data. Note that
# other time steps are available as well. Explore the FTP site to find the
# relevant URL and syntax for the data sets that you need.
#
URL <- "https://data.prism.oregonstate.edu/time_series/us/an/800m/"

# Identify the years of data you need. NOTE: data < 6 months old are provisional.
# Use "stable" data whenever possible, and note that the filename will be different
# for provisional data (you will have to modify the code below accordingly).
#
years_data <- c(2010) # If downloading multiple years, enter range here, e.g., 2010:2020

for (i in 1:length(vars)) { 
  
  var <- vars[i]
  
  cat("---------------------------------------------------------------------\n")
  cat("Beginning download of", var, "PRISM data: variable", i, "of", length(vars), "\n")
  
  for (j in 1:length(years_data)) {
    
    year_data <- years_data[j]
    
    cat(".....Processing", year_data, "data \n")
    
    # Identify all of the days in that particular year in the format YYYYMMDD
    # This step is needed to account for Leap Days
    #
    days <- format(seq(as.Date(paste0(year_data, "-01-01")),
                       as.Date(paste0(year_data, "-01-31")), by = "days"),
                   format="%Y%m%d")
    
    for (k in 1:length(days)) {
      
      day <- days[k]
      
      dl_link <- paste0(URL, var, "/daily/", year_data, "/prism_", var, "_us_30s_", days[k], ".zip")
      dl_file <- paste0(zip_file_dir, "PRISM_", var, "_us_30s_", day, ".zip")
      
      # Check to see if the file already exists; download if not
      #
      if (file.exists(dl_file)) {
        
        cat("Zip file for day", day, "already downloaded. Proceeding to next day. \n")
        
      } else {
        
        dl <- try(download.file(dl_link, destfile = dl_file))
        
        # Determine if the download failed
        #
        if (class(dl) == "try-error") {
          
          cat("ERROR! File did not download successfully for", day, "\n")
          cat("..... Pausing for 10 seconds and re-trying. \n")
          
          k <- 10
          while (k > 0) {
            
            cat("..... Attempt", ((10 - k) + 1), "out of 10... \n")
            Sys.sleep(10) # Pause for 10 seconds
            dl <- try(download.file(dl_link, destfile = dl_file))
            
            if (class(dl) != "try-error") { 
              
              cat("..... :) success! Moving on to next file \n"); break 
              
            } else {
              
              cat("..... :( unsuccessful! \n")
              k <- k - 1 
            }
          }
          
          if (k == 0) { cat("..... Error unresolved; file for", day, "has still not been downloaded. \n"); break }
          
        } else { cat(":) file for", day, "downloaded successfully \n") }   
      }
      
      # Unzip the downloaded files
      # Recommended to delete the original zip files manually after downloading is complete
      #
      unzip(dl_file, exdir = paste0(input_data_dir, var, "/", year_data, "/"))
    }
  }
}

# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% #
# %%%%%%%%%%%%%%%%%% STEP 2: DOWNLOAD BLOCK SHAPEFILES (TIGRIS) %%%%%%%%%%%%%% #
# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% #
#
library(tigris)
library(sf)

# Full pathway of the directory where your input data will be stored.
block_geo <- "rawdata/blocks/shapefiles/"

# Set year of census data to download and stateFIPS
decyear <- 2010
stateFIPS <- "11"

# We will download 2010 data for DC
#
dc_blocks <- tigris::blocks(year = decyear, state = stateFIPS)

# Write to file
#
st_write(dc_blocks, paste0(block_geo, decyear, "/tl_", decyear, "_", stateFIPS, "_tabblock10.shp"))

# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% #
# %%%%%%%%%%%%%%%%%% STEP 3: BUILD FIPS DATASET FOR USE IN BASH %%%%%%%%%%%%%% #
# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% #

# Set directory
#
fipsdir <- "rawdata/fips/"

# Download states
#
fips <- tigris::states(year = 2020)

# Subset to CONUS
#
fips <- fips[fips$REGION %in% c(1:4) & !fips$STATEFP %in% c("02", "15"),]

# Save as data.frame
#
fips <- as.data.frame(fips)
fips$geometry <- NULL

# Rename and save columns needed
#
fips$StFIPS <- fips$STATEFP
fips <- fips[c("StFIPS", "STUSPS", "NAME")]

# Save to file
#
write.csv(fips, paste0(fipsdir, "US_States_FIPS_Codes.csv"), 
          row.names = FALSE)
