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
library(yaml)
library(dplyr)
library(sf)

# Load configuration from config.yaml.
# The config path can be passed as a command-line argument; if omitted, the
# script looks for config.yaml in the current directory then one level up.
#
args <- commandArgs(trailingOnly = TRUE)
.config_path <- if (length(args) > 0 && grepl("\\.ya?ml$", args[length(args)])) {
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

# Set decennial years available for processing. Each PRISM year is mapped to the
# matching decennial ZCTA folder and state-weight crosswalk.
#
decyear <- as.numeric(unlist(config$processing$decyear))

valid_decyears <- c(2000, 2010, 2020)
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

# Set years to process. This script can handle listing many years, so long
# as ZCTA outputs have been generated
#
years_to_process <- as.numeric(unlist(config$processing$years_to_process))
state_fips <- normalize_state_fips(config$processing$state_fips)
if (length(state_fips) == 0) {
  stop("No valid CONUS state_fips configured.")
}
state_pattern <- paste(state_fips, collapse = "|")

# Variables to process. Temperature variables (tmax, tmin, tmean, tdmean)
# carry a "_C" suffix in ZCTA outputs; all others keep their original name.
temp_vars <- c("tmax", "tmin", "tmean", "tdmean")
exp_list_raw <- as.character(unlist(config$processing$exp_list))
exp_list <- ifelse(exp_list_raw %in% temp_vars, paste0(exp_list_raw, "_C"), exp_list_raw)

# This is where the weights by state should be stored:
# See https://github.com/Climate-CAFE/block2zcta_xwalk for details
cross_dir <- config$paths$crosswalk_dir

# This is where the nationwide output will be written
nation_dir <- config$paths$nation_dir
dir.create(nation_dir, recursive = TRUE, showWarnings = FALSE)

################### Set functions ##############################################

# User-defined function for summing values; returns NA if all values are NA
#
sumfun <- function(x) { ifelse(all(is.na(x)), return(NA), return(sum(x, na.rm = TRUE))) }

state_weight <- function(input_data, decyear_in, varnames) {

  # Read in state weights
  state_wts <- readRDS(paste0(cross_dir, "ZCTA_StateWt_", decyear_in, "_US.Rds"))

  # Assign ZCTA name
  zc_name <- paste0("ZCTA5CE", substr(decyear_in, 3, 4))

  # Join state weights to result
  input_data <- left_join(input_data, state_wts, by = c("ST", zc_name))

  # Restrict to rows with available PRISM data for all variables and re-estimate State_Wt
  input_data <- input_data %>%
    group_by(!!sym(zc_name), PRISM_Date) %>%
    filter(if_all(all_of(varnames), ~ !is.na(.x))) %>%
    mutate(sum_State_Wt = sumfun(State_Wt),
           State_Wt = State_Wt / sum_State_Wt)

  # Multiply each variable by State_Wt and then sum across the ZCTA/Date
  input_data <- input_data %>%
    mutate(across(all_of(varnames), ~ .x * State_Wt))

  input_data <- input_data %>%
    group_by(!!sym(zc_name), PRISM_Date) %>%
    dplyr::summarise(across(all_of(varnames), ~ sumfun(.x)),
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

# Read in and add state from processing for each file, by year
#
for (yr in c(years_to_process)) {
  
  cat(yr, "\n")

  decyear_in <- map_decyear_by_year(yr, decyear)
  deyr_abr <- substr(decyear_in, 3, 4)
  zct_state_dir <- paste0(config$paths$zcta_outdir, "zcta_", deyr_abr, "/")
  
  # Subset to files for year
  #
  files_yr <- list.files(
    zct_state_dir,
    pattern = paste0("^PRISM_ZCTA", deyr_abr, "_", yr, "_(", state_pattern, ")\\.Rds$"),
    full.names = TRUE
  )

  if (length(files_yr) == 0) {
    stop("No state-level ZCTA files found for year ", yr, " in ", zct_state_dir)
  }
  
  for (i in seq_along(files_yr)) {
    
    cat("Now processing ", i, "\n")
    
    # Read in files
    #
    file_in <- readRDS(files_yr[i])
    
    # Add state as variable
    #
    state_match <- regmatches(
      basename(files_yr[i]),
      regexec("^PRISM_ZCTA[0-9]{2}_[0-9]{4}_([0-9]{2})\\.Rds$", basename(files_yr[i]))
    )[[1]]
    if (length(state_match) < 2) {
      stop("Could not parse state FIPS from ZCTA file name: ", files_yr[i])
    }
    file_in$ST <- state_match[2]
    
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

  for (v in exp_list) print(summary(all_files[[v]]))

  # Set ZCTA name
  #
  ZCTA_geoid <- paste0("ZCTA5CE", deyr_abr)

  # Rearrange
  #
  all_exp <- all_files[c(ZCTA_geoid, "PRISM_Date", "ST", exp_list)]

  # Remove NA ZCTA (this will occur where there is a block not linked to a
  # ZCTA, which can happen if the block does not nest within a ZCTA and is more
  # than 1km from the nearest)
  #
  all_exp <- filter(all_exp, !is.na(!!sym(ZCTA_geoid)))

  # Apply state weights
  #
  all_exp <- state_weight(input_data = all_exp, decyear_in = decyear_in, varnames = exp_list)

  # Rearrange
  #
  all_exp <- all_exp[c(ZCTA_geoid, "PRISM_Date", exp_list)]
  
  all_exp2 <- all_exp
  all_exp2$PRISM_Date <- as.Date(all_exp2$PRISM_Date, format = "%Y%m%d")
  
  saveRDS(all_exp2, paste0(nation_dir, "PRISM_ZCTA", deyr_abr, "_", yr, "_nation.rds"))
  
  # Clean up
  rm(all_files, all_exp2, all_exp)
  invisible(gc())
}
