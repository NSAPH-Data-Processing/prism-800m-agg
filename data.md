================================================================================
Documentation: PRISM 800-meter ZCTA Pipeline Outputs
================================================================================

PRISM (Parameter-elevation Regressions on Independent Slopes Model) provides
daily time-series raster data for health-relevant meteorological variables,
including temperature, precipitation, humidity, vapor pressure deficit, and solar
irradiance. This repository provides a Snakemake pipeline to download PRISM
800-meter daily rasters, aggregate raster values to census blocks using
area-weighted extraction points, and population-weight block estimates to ZIP
Code Tabulation Areas (ZCTAs). The same framework can be configured for one or
more CONUS states or for all CONUS states.


---------- FILE METADATA -------------------------------------------------------
File name:              outputdata/blocks/blocks_<YY>/<YYYY>/
                        tl<YY>_prism_daily_<YYYY>_<STATEFIPS>.rds
File created by:        PRISM 800m aggregation pipeline
Date added:             1 May 2026 (v01)
Date last modified:
Modifications:
Description:            State-level daily census block RDS files. Values are
                        area-weighted from PRISM 800m raster cells to decennial
                        census blocks. The <YY> suffix indicates the decennial
                        census geography: 00, 10, or 20.

File name:              outputdata/zcta/zcta_<YY>/
                        PRISM_ZCTA<YY>_<YYYY>_<STATEFIPS>.Rds
File created by:        PRISM 800m aggregation pipeline
Date added:             1 May 2026 (v01)
Date last modified:
Modifications:
Description:            State-level daily ZCTA RDS files. Values are population
                        weighted from block-level PRISM estimates to ZCTAs using
                        the state block-to-ZCTA crosswalk.

File name:              outputdata/zcta/nationwide/
                        PRISM_ZCTA<YY>_<YYYY>_nation.rds
File created by:        PRISM 800m aggregation pipeline
Date added:             1 May 2026 (v01)
Date last modified:
Modifications:
Description:            Annual daily ZCTA RDS files after applying state weights
                        for ZCTAs crossing state borders. When the pipeline is
                        configured for all CONUS states, these are national
                        files. When the pipeline is configured for a state subset,
                        these files cover the configured state subset.

File name:              outputdata/meteorology__prism/population_weighted/
                        zcta_daily/meteorology__prism__zcta_daily__<YYYY>.parquet
File created by:        PRISM 800m aggregation pipeline
Date added:             1 May 2026 (v01)
Date last modified:
Modifications:
Description:            Standardized daily parquet files derived from the annual
                        ZCTA RDS files.

File name:              outputdata/meteorology__prism/population_weighted/
                        zcta_yearly/meteorology__prism__zcta_yearly__<YYYY>.parquet
File created by:        PRISM 800m aggregation pipeline
Date added:             1 May 2026 (v01)
Date last modified:
Modifications:
Description:            Standardized yearly parquet files derived from the daily
                        ZCTA parquet files. Values are the mean of daily values
                        within each ZCTA-year; precipitation is therefore mean
                        daily precipitation, not annual cumulative precipitation.


---------- DATA EXTENT/RESOLUTION ----------------------------------------------

Current configured time extent:     2000 - 2016
Supported time extent:              Any configured year with available PRISM
                                    800m daily source rasters
Time resolution:                    Daily time series; optional yearly summaries
                                    are ZCTA-year means of daily values
Current configured spatial extent:  Massachusetts, state FIPS 25
Supported spatial extent:           CONUS states, excluding AK and HI
Spatial resolution:                 Source: PRISM 30 arc-second / 800m raster
                                    Intermediate: census block
                                    Derived: ZCTA
Census geography mapping:           PRISM years before 2010 use 2000 census
                                    geographies; years 2010-2019 use 2010
                                    census geographies; years 2020 and later use
                                    2020 census geographies when configured.


---------- CHANGES BY VERSION NUMBER -------------------------------------------
v01     No changes; this is the original data documentation for this pipeline.


---------- VARIABLES -----------------------------------------------------------
Block RDS files:
tl<YY>_prism_daily_<YYYY>_<STATEFIPS>.rds

GEOID00/GEOID10/GEOID20 or
BLKIDFP*        Unique census block identifier; name depends on census year
PRISM_Date      Date for PRISM measures, stored as YYYYMMDD
tmax_C          Area-weighted daily maximum temperature, Celsius
tmin_C          Area-weighted daily minimum temperature, Celsius
tmean_C         Area-weighted daily mean temperature, Celsius
tdmean_C        Area-weighted daily mean dew point temperature, Celsius
ppt             Area-weighted daily total precipitation, millimeters
vpdmax          Area-weighted daily maximum vapor pressure deficit, hPa
vpdmin          Area-weighted daily minimum vapor pressure deficit, hPa
solslope        Area-weighted total daily global shortwave solar irradiance
                received on a sloped surface, MJ m-2 day-1
soltotal        Area-weighted total daily global shortwave solar irradiance
                received on a horizontal surface, MJ m-2 day-1

State and nationwide ZCTA RDS files:
PRISM_ZCTA<YY>_<YYYY>_<STATEFIPS>.Rds
PRISM_ZCTA<YY>_<YYYY>_nation.rds

ZCTA5CE00/ZCTA5CE10/ZCTA5CE20
                Unique ZIP Code Tabulation Area identifier; name depends on
                census year
PRISM_Date      Date for PRISM measures; state files use YYYYMMDD, nationwide
                files are converted to Date
tmax_C          Block population-weighted daily maximum temperature, Celsius
tmin_C          Block population-weighted daily minimum temperature, Celsius
tmean_C         Block population-weighted daily mean temperature, Celsius
tdmean_C        Block population-weighted daily mean dew point temperature,
                Celsius
ppt             Block population-weighted daily total precipitation,
                millimeters
vpdmax          Block population-weighted daily maximum vapor pressure deficit,
                hPa
vpdmin          Block population-weighted daily minimum vapor pressure deficit,
                hPa
solslope        Block population-weighted total daily global shortwave solar
                irradiance received on a sloped surface, MJ m-2 day-1
soltotal        Block population-weighted total daily global shortwave solar
                irradiance received on a horizontal surface, MJ m-2 day-1

Standardized daily parquet files:
meteorology__prism__zcta_daily__<YYYY>.parquet

zcta            Unique ZIP Code Tabulation Area identifier
day             Date for PRISM measures
year            Calendar year
tmax_C          Block population-weighted daily maximum temperature, Celsius
tmin_C          Block population-weighted daily minimum temperature, Celsius
tmean_C         Block population-weighted daily mean temperature, Celsius
tdmean_C        Block population-weighted daily mean dew point temperature,
                Celsius
ppt             Block population-weighted daily total precipitation,
                millimeters
vpdmax          Block population-weighted daily maximum vapor pressure deficit,
                hPa
vpdmin          Block population-weighted daily minimum vapor pressure deficit,
                hPa
solslope        Block population-weighted total daily global shortwave solar
                irradiance received on a sloped surface, MJ m-2 day-1
soltotal        Block population-weighted total daily global shortwave solar
                irradiance received on a horizontal surface, MJ m-2 day-1

Standardized yearly parquet files:
meteorology__prism__zcta_yearly__<YYYY>.parquet

zcta            Unique ZIP Code Tabulation Area identifier
year            Calendar year
tmax_C          Mean of daily ZCTA maximum temperature values within the year
tmin_C          Mean of daily ZCTA minimum temperature values within the year
tmean_C         Mean of daily ZCTA mean temperature values within the year
tdmean_C        Mean of daily ZCTA mean dew point temperature values within the
                year
ppt             Mean of daily ZCTA total precipitation values within the year
vpdmax          Mean of daily ZCTA maximum vapor pressure deficit values within
                the year
vpdmin          Mean of daily ZCTA minimum vapor pressure deficit values within
                the year
solslope        Mean of daily ZCTA sloped-surface solar irradiance values within
                the year
soltotal        Mean of daily ZCTA horizontal-surface solar irradiance values
                within the year


---------- RAW SOURCE DATA -----------------------------------------------------
Data Source 1:  PRISM Group, Oregon State University,
                https://prism.oregonstate.edu and
                https://data.prism.oregonstate.edu/time_series/us/an/800m/
                PRISM all-networks daily 800m time-series rasters.
                * Configured variables downloaded by this pipeline:
                  tmax, tmin, tmean, tdmean, ppt, vpdmax, vpdmin, solslope,
                  soltotal.
                * Downloaded/accessed for the configured run on 30 April 2026
                  according to local .download_complete markers.

Data Source 2:  U.S. Census Bureau, TIGER/Line block and ZCTA geographies.
                * 2000 and 2010 block shapefiles:
                  https://www2.census.gov/geo/tiger/TIGER2010/TABBLOCK/
                * 2020 block shapefiles:
                  https://www2.census.gov/geo/tiger/TIGER2020/TABBLOCK20/
                * ZCTA geographies are queried by tigris for the configured
                  decennial census years.

Data Source 3:  U.S. Census Bureau decennial population counts queried through
                tidycensus.
                * Block population variables used by the pipeline:
                  PL001001 for 2000, P001001 for 2010, and P1_001N for 2020.
                * ZCTA population variables used by the pipeline:
                  P001001 for 2000/2010 and P1_001N for 2020.
                * Local population crosswalk inputs were generated on
                  29-30 April 2026 according to output timestamps.


---------- DESCRIPTION OF DATA SET DERIVATION ----------------------------------
The pipeline downloads daily PRISM 800m GeoTIFF rasters named like
prism_<var>_us_30s_<YYYYMMDD>.zip, extracts the .tif files, and builds a
reference fishnet from the PRISM grid. Census block geometries are intersected
with the fishnet, and point-on-surface extraction points are created for each
block-grid intersection. Each point carries a spatial weight representing the
area of the block-grid intersection within the block.

For each configured PRISM variable, year, and state, raster values are extracted
at the weighted points and collapsed to daily block estimates. If only a subset
of a block has available PRISM data for a variable-day, available spatial weights
are rescaled before aggregation. Block outputs are rounded to three decimals.

The pipeline then builds state-level block-to-ZCTA crosswalks from decennial
block and ZCTA geographies and decennial population counts. Blocks are assigned
to ZCTAs using block point-on-surface intersections; populated unassigned blocks
may be linked to the nearest ZCTA within 1000 meters. Block population weights
within each ZCTA are used to aggregate daily block PRISM values to state-level
ZCTA estimates. ZCTA-day values are set to missing for a variable when less than
50 percent of the source weight is available. State-level ZCTA outputs are
rounded to four decimals.

For ZCTAs crossing state borders, the pipeline creates state weights based on
the proportion of ZCTA population in each state and applies those weights to
create the annual ZCTA files in outputdata/zcta/nationwide/. The reshape script
standardizes these RDS files into daily and yearly parquet datasets.

Please see https://github.com/acresmysticriver/prism-800m-agg for all scripts
and a description of the processing pipeline.


---------- REFERENCES ----------------------------------------------------------
PRISM Group, Oregon State University:
https://prism.oregonstate.edu

PRISM 800m daily source directory:
https://data.prism.oregonstate.edu/time_series/us/an/800m/

PRISM dataset descriptions and units:
https://prism.oregonstate.edu/documents/PRISM_datasets.pdf

PRISM data formats and naming:
https://www.prism.oregonstate.edu/formats/

U.S. Census Bureau TIGER/Line files:
https://www2.census.gov/geo/tiger/

Block-to-ZCTA crosswalk workflow:
https://github.com/Climate-CAFE/block2zcta_xwalk
