# PRISM 800-meter Aggregation to Population-Weighted Zip Code Tabulation Areas
Aggregation of PRISM 800m temperature and precipitation data to census blocks, and population weighting from blocks to zip code tabulation areas and counties

## Project Overview
PRISM (Parameter-elevation Regressions on Independent Slopes Model) provides daily time-series data back to 1980 for several health-relevant meteorological variables, including temperature, precipitation, and humidity. This repository provides a pipeline that can be used to aggregate the daily raster time series to administrative boundaries (census block, zip code tabulation area). Data query code is provided for the 800-meter model which presents a substantial increase in spatial resolution to the previously public PRISM 4km data. For processing of the 4km data product, please see https://github.com/Climate-CAFE/population_weighting_raster_data which follows the same census block and larger geography aggregation applied here.

## Usage
Required libraries include: 
library("terra")  # For raster data
library("sf")     # For vector data
library("plyr")   # For data management
library("tigris") # For downloading census shapefiles
library("doBy")   # For data management
library("tidyverse") # For data management
library("tidycensus")# For census population query
library("lwgeom")  # For data management

## Data Sources
PRISM Group, Oregon State University, https://prism.oregonstate.edu, data created 1 December 2023. accessed 13 December 2024

From the PRISM website (https://prism.oregonstate.edu/):

"The PRISM Group gathers weather observations from a wide range of monitoring networks, applies sophisticated quality control measures, and develops spatial datasets to reveal short- and long-term weather patterns. The resulting datasets incorporate a variety of modeling techniques and are available at multiple spatial/temporal resolutions, covering the period from 1895 to the present. Whenever possible, we offer these datasets to the public, either free of charge or for a fee (depending on dataset size/complexity and funding available for the activity)."

U.S. Census Bureau, “tl_2020_us_blocks”, TIGER/Line Shapefiles, 2020, [https://www2.census.gov/geo/tiger/TIGER2020](https://www2.census.gov/geo/tiger/TIGER2020/TABBLOCK20/)/.

## Workflow
### Snakemake orchestration
The pipeline can be run end-to-end through Snakemake and submitted to Slurm as
a single batch job:

```bash
sbatch code/run_snakemake.sbatch
```

The `Snakefile` reads `config.yaml`, maps each PRISM year to the configured
decennial census geography, and orchestrates download, fishnet creation,
block-to-ZCTA crosswalk construction, extraction points, raster extraction,
ZCTA aggregation, nationwide ZCTA cleaning, and final parquet reshaping. The
download stage is split into concrete outputs: PRISM variable/year directories,
state block shapefile components, and the FIPS CSV. This lets downstream rules
start as soon as their required downloaded inputs are present instead of waiting
for every configured input to finish downloading.

The crosswalk rules follow the workflow from
[`Climate-CAFE/block2zcta_xwalk`](https://github.com/Climate-CAFE/block2zcta_xwalk)
and write the expected files to `rawdata/crosswalk/`. The Census population
queries use `tidycensus`, so set `CENSUS_API_KEY` in your Slurm environment if
your cluster does not already provide one.

To inspect the DAG without running jobs:

```bash
sbatch code/run_snakemake.sbatch --dry-run
```

Script X: X_Download_PRISM800m_v01.R
1) Download PRISM 800m rasters and census geographies (block) for use in pipeline.

Script 0:   00a_Create_Fishnet_PRISMv2_800m_v01.R
1) Create Fishnet that can be used to extract PRISM data from raster stack including Tmax daily data (this file).This will allow for extraction from raster stack to block-level estimates without the large computational burden of a terra::zonal loop (as below)
2) Note: This script is set to run in bash because it is time and resource intensive. Running in an interactive R session will be time consuming.

Script 1: 	01a_Extraction_Pts_v03.R
1) Load block geographies including decennial and year-specific IDs, and conduct union of block geometries with fishnet developed in step 1 
2) Create extraction points from the union of the block and fishnet. These are what we can use to extract values from the raster that overlaps with with the points aligning to each block
3) Note: This script is set to run in bash with parallel processing by state. Separate outputs for each state will be created so that the following steps in the pipeline can also be processed by state.

Script 2: 	02a_PRISM_Raster_Extract_v03.R
1) Estimate the block-level exposure to PRISM, accounting for the availability of data within the block (this file).
2) Note: This script is set to run in bash with parallel processing by state and year. The process for a single year can take multiple hours (depending on the size of the state and census geographies therein). There are multiple shell scripts accompanying this R script, as the process of running by state and year entails separate terminal submissions for each year being processed. Script C uses an executable script to submit all of these jobs at once.

Script 3: 	03a_BlockPop_Wt_ZCTA_PRISM_800m_v03.R
1) Read in block PRISM measures and state-level block - ZCTA crosswalk
2) For each variable (Tmax, Tmean, Tmin, Ppt) weight the block-level exposure based on the state-level ZCTA block aggregate population. This will provide a block population-weighted ZCTA mean for each ZCTA in the state
3) Note: This script is set to run in bash with parallel processing by state and year. The process for a single year can take multiple hours (depending on the size of the state and census geographies therein). There are multiple shell scripts accompanying this R script, as the process of running by state and year entails separate terminal submissions for each year being processed. Script C uses an executable script to submit all of these jobs at once.

Script 4:  	04_Zip2Zcta_Cleaning_PRISM_allyrs_v01.R
1) Takes ZCTA output, and combines across years.
2) Then a weight can be applied to each state ZCTA based on the proportion of the ZCTA population within the state, and the ZCTA exposure weighted on population across states can be assessed.
2) Note: This script is set to run in bash because it is time and resource intensive. Running in an interactive R session will be time consuming.

## Contact Information: 
Please open an issue or contact Zach Popp (zpopp@bu.edu) with questions or issues.
