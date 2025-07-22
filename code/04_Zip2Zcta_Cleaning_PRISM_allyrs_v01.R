# ***************************************************** #
# ~~~~~ ACRES-ZCTA Cleaning and Zip Merge  ~~~~~~~~~~~~ #
# ***************************************************** #
#  Date created:  2025-02-28 (v01)
#   Last modified:  
#   Created by:     Zach P. (zpopp@bu.edu)
#   Modified from:  Keith Spangler, Muskaan Khemani
#   Modifications:  

##Purpose: Apply state weighting corrections to all ZCTA PRISM data and merge
##  across years and states for overall region-level data in all years.
##  Merge ZCTA time series with zip codes for use in health analyses
##
##  Because ZCTA's can cross state lines, there will be ZCTAs with 
##  the same ZCTA ID in multiple states based on population weighting for the
##  block population in each state. This script brings in the population of
##  each ZCTA within each state and uses it to harmonize an overall
##  ZCTA cross-state weighted exposure measure
##
##Overall Processing Steps:
## 1) Takes ZCTA output, and combines across years.
## 2) Then a weight can be applied to each state ZCTA based
##    on the proportion of the ZCTA population within the state, and the 
##    ZCTA exposure weighted on population across states can be assessed.
##
##  NOTE: 
##      This file relies on having a file that includes the population in 
##      all US ZCTAs by state. This can be created using code from:
##            https://github.com/Climate-CAFE/block2zcta_xwalk
##      Within the code, the output from this process are expected to be stored
##      in rawdata/crosswalk/

# Set up libraries
#
library(dplyr)
library(sf)

# Set decennial year to process
#
decyear <- 2010
deyr_abr <- substr(decyear, 3, 4)

# Set years to process. This script can handle listing many years, so long
# as ZCTA outputs have been generated
#
years_to_process <- c(2010:2010)

# Set directories
#
setwd("")

# This is where the weights by state should be stored:
# See https://github.com/Climate-CAFE/block2zcta_xwalk for details
cross_dir <- paste0("rawdata/crosswalk/")

# This is where the nationwide output will be written
nation_dir <- paste0("outputdata/zcta/nationwide/")

# This is where output at the state/ZCTA level is expected
zct_state_dir <- paste0("outputdata/zcta/zcta_", deyr_abr, "/")

################### Set functions ##############################################

# User-defined function for summing values; returns NA if all values are NA
#
sumfun <- function(x) { ifelse(all(is.na(x)), return(NA), return(sum(x, na.rm = TRUE))) }

state_weight <- function(input_data, year) {
  
  # Read in state weights
  state_wts <- readRDS(paste0(cross_dir, "ZCTA_StateWt_", year, "_US.Rds"))
  
  # Assign ZCTA name
  zc_name <- paste0("ZCTA5CE", substr(year, 3, 4))
  
  # Join state weights to result
  input_data <- left_join(input_data, state_wts, by = c("ST", zc_name))
  
  # Restrict to data with available PRISM data and re-estimate State_WT
  input_data <- input_data %>%
    group_by(!!sym(zc_name), PRISM_Date) %>%
    filter(!is.na(tmax_C) & !is.na(tmin_C) & !is.na(tmean_C) & !is.na(ppt)) %>%
    mutate(sum_State_Wt = sumfun(State_Wt),
           State_Wt = State_Wt / sum_State_Wt)
  
  # We want to multiply each of the Temperature measures by the State_WT and then 
  # sum across the ZCTA/Date
  input_data <- input_data %>%
    mutate(across(c(tmax_C, tmin_C, tmean_C, ppt), ~ .x * State_Wt))
  
  input_data <- input_data %>%
    group_by(!!sym(zc_name), PRISM_Date) %>%
    dplyr::summarise(across(c(tmax_C, tmin_C, tmean_C, ppt), ~ sumfun(.x)),
                     sum_WT = sumfun(State_Wt))
  
  # QA check. The state weights should add up to 1. If not, there is an error in 
  # the code to form the state-level outputs, or to produce the ZCTA-level exposure
  if (length(which(input_data$sum_WT != 1))) {
    cat("ERROR: Weights do not add up! \n")
  } else {
    cat(":) Weights add up! \n")
  }
  
  return(input_data)
  
}


################### Read in exposure data ######################################

# List all ZCTAs
#
files_all <- list.files(zct_state_dir, full.names = TRUE)

# Read in and add state from processing for each file, by year
#
for (yr in c(years_to_process)) {
  
  cat(yr, "\n")
  
  # Subset to files for year
  #
  files_yr <- files_all[grepl(yr, files_all)]
  
  for (i in 1:length(files_yr)) {
    
    cat("Now processing ", i, "\n")
    
    # Read in files
    #
    file_in <- readRDS(files_yr[i])
    
    # Add state as variable
    #
    file_in$ST <- substr(files_yr[i], nchar(files_yr[i]) - 8, nchar(files_yr[i])- 7)
    
    # Bind files
    #
    if (i == 1) {
      all_files <- file_in
    } else if (i > 1) {
      all_files <- rbind(all_files, file_in)
    } 
    
    # Clean up
    rm(file_in)
    invisible(gc())
    
  }
  
  
  # Check output
  #
  head(all_files)
  
  summary(all_files$tmax_C  )
  summary(all_files$tmin_C )
  summary(all_files$tmean_C )
  summary(all_files$ppt)
  
  # Set ZCTA name
  #
  ZCTA_geoid <- paste0("ZCTA5CE", deyr_abr)
  
  # Rearrange
  #
  all_exp <- all_files[c(ZCTA_geoid, "PRISM_Date", "ST", "tmax_C", "tmin_C", "tmean_C", "ppt")]
  
  # Remove NA ZCTA (this will occur where there is a block not linked to a
  # ZCTA, which can happen if the block does not nest within a ZCTA and is more
  # than 1km from the nearest)
  #
  all_exp <- filter(all_exp, !is.na(!!sym(ZCTA_geoid)))
  
  # Apply state weights
  #
  all_exp <- state_weight(input_data = all_exp, year = decyear)
  
  # Rearrange
  #
  all_exp <- all_exp[c(ZCTA_geoid, "PRISM_Date", "tmax_C", "tmin_C", "tmean_C", "ppt")]
  
  all_exp2 <- all_exp
  all_exp2$PRISM_Date <- as.Date(all_exp2$PRISM_Date, format = "%Y%m%d")
  
  saveRDS(all_exp2, paste0(nation_dir, "PRISM_ZCTA", deyr_abr, "_", yr, "_nation.rds"))
  
  # Clean up
  rm(all_files, all_exp2, all_exp)
  invisible(gc())
}


