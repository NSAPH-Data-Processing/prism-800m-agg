configfile: "config.yaml"

shell.executable("/bin/bash")

import os

PROJECT_DIR = workflow.basedir
CONFIG_PATH = os.path.join(PROJECT_DIR, "config.yaml")

# Keep the state ordering aligned with the FIPS CSV produced by the download step.
CONUS_STATE_FIPS = [
    "01", "04", "05", "06", "08", "09", "10", "11", "12", "13",
    "16", "17", "18", "19", "20", "21", "22", "23", "24", "25",
    "26", "27", "28", "29", "30", "31", "32", "33", "34", "35",
    "36", "37", "38", "39", "40", "41", "42", "44", "45", "46",
    "47", "48", "49", "50", "51", "53", "54", "55", "56",
]


def normalize_state_fips(raw_state_fips):
    if isinstance(raw_state_fips, str):
        if raw_state_fips == "Nationwide":
            return CONUS_STATE_FIPS
        return [str(raw_state_fips).zfill(2)]

    supplied = [str(state).zfill(2) for state in raw_state_fips]
    return [state for state in CONUS_STATE_FIPS if state in supplied]


STATE_FIPS = normalize_state_fips(config["processing"]["state_fips"])
STATE_INDEX = {state: index + 1 for index, state in enumerate(STATE_FIPS)}
YEARS = [int(year) for year in config["processing"]["years_to_process"]]
DECYEARS = [int(year) for year in config["processing"]["decyear"]]
DECYEAR_ABRS = [str(year)[2:4] for year in DECYEARS]
FIRST_DECYEAR_ABR = DECYEAR_ABRS[0]
R_VERSION = config["r_version"]
FISHNET_YEAR = int(config["fishnet"]["year"])
FISHNET_VAR = str(config["fishnet"]["variable"])

DOWNLOAD_DONE = ".workflow/download.done"
FISHNET_OUTPUT = os.path.join("intermediate", "fishnet", f"prism_fishnet_{FISHNET_VAR}_800m.gpkg")


def state_index(wildcards):
    return STATE_INDEX[wildcards.state]


rule all:
    input:
        DOWNLOAD_DONE,
        FISHNET_OUTPUT,
        expand(
            os.path.join(
                "outputdata",
                "zcta",
                "nationwide",
                "PRISM_ZCTA{decyear_abr}_{year}_nation.rds",
            ),
            decyear_abr=[FIRST_DECYEAR_ABR],
            year=YEARS,
        )


rule download_inputs:
    output:
        stamp=DOWNLOAD_DONE,
        fips_csv="rawdata/fips/US_States_FIPS_Codes.csv",
    input:
        config=CONFIG_PATH,
    params:
        mkdir="mkdir -p .workflow",
        r_version=R_VERSION,
    threads: 4
    shell:
        """
        set -euo pipefail
        {params.mkdir}
        export R_VERSION={params.r_version}
        source code/slurm_runtime_env.sh
        Rscript code/X_Download_PRISM800m_v01.R {input.config}
        touch {output.stamp}
        """


rule fishnet:
    input:
        config=CONFIG_PATH,
        download=DOWNLOAD_DONE,
    output:
        FISHNET_OUTPUT,
    params:
        mkdir="mkdir -p intermediate/fishnet",
        r_version=R_VERSION,
    threads: 16
    shell:
        """
        set -euo pipefail
        {params.mkdir}
        export R_VERSION={params.r_version}
        source code/slurm_runtime_env.sh
        Rscript code/00a_Create_Fishnet_PRISMv2_800m_v03.R {input.config}
        """


rule extraction_points:
    input:
        config=CONFIG_PATH,
        download=DOWNLOAD_DONE,
        fishnet=FISHNET_OUTPUT,
    output:
        expand(
            os.path.join(
                "intermediate",
                "extraction_pts",
                "PRISM_extraction_points_tl{decyear_abr}_block_{state}.rds",
            ),
            decyear_abr=DECYEAR_ABRS,
            state="{state}",
        ),
    params:
        mkdir="mkdir -p intermediate/extraction_pts",
        state_idx=state_index,
        r_version=R_VERSION,
    threads: 4
    shell:
        """
        set -euo pipefail
        {params.mkdir}
        export R_VERSION={params.r_version}
        source code/slurm_runtime_env.sh
        Rscript code/01a_Extraction_Pts_v03.R {params.state_idx} {input.config}
        """


rule raster_extract:
    input:
        config=CONFIG_PATH,
        download=DOWNLOAD_DONE,
        extraction_points=expand(
            os.path.join(
                "intermediate",
                "extraction_pts",
                "PRISM_extraction_points_tl{decyear_abr}_block_{state}.rds",
            ),
            decyear_abr=DECYEAR_ABRS,
            state="{state}",
        ),
    output:
        expand(
            os.path.join(
                "outputdata",
                "blocks",
                "blocks_{decyear_abr}",
                "{year}",
                "tl{decyear_abr}_prism_daily_{year}_{state}.rds",
            ),
            decyear_abr=DECYEAR_ABRS,
            year="{year}",
            state="{state}",
        ),
    params:
        mkdir=lambda wildcards: "mkdir -p " + " ".join(
            os.path.join("outputdata", "blocks", f"blocks_{decyear_abr}", wildcards.year)
            for decyear_abr in DECYEAR_ABRS
        ),
        state_idx=state_index,
        r_version=R_VERSION,
    threads: 16
    shell:
        """
        set -euo pipefail
        {params.mkdir}
        export R_VERSION={params.r_version}
        source code/slurm_runtime_env.sh
        Rscript code/02a_PRISM_Raster_Extract_v03.R {wildcards.year} {params.state_idx} {input.config}
        """


rule zcta_state:
    input:
        config=CONFIG_PATH,
        download=DOWNLOAD_DONE,
        blocks=expand(
            os.path.join(
                "outputdata",
                "blocks",
                "blocks_{decyear_abr}",
                "{year}",
                "tl{decyear_abr}_prism_daily_{year}_{state}.rds",
            ),
            decyear_abr=DECYEAR_ABRS,
            year="{year}",
            state="{state}",
        ),
        crosswalk=expand(
            os.path.join("rawdata", "crosswalk", "Block_to_ZCTA_{decyear}_{state}.Rds"),
            decyear=DECYEARS,
            state="{state}",
        ),
    output:
        expand(
            os.path.join(
                "outputdata",
                "zcta",
                "zcta_{decyear_abr}",
                "PRISM_ZCTA{decyear_abr}_{year}_{state}.Rds",
            ),
            decyear_abr=DECYEAR_ABRS,
            year="{year}",
            state="{state}",
        ),
    params:
        mkdir=lambda wildcards: "mkdir -p " + " ".join(
            os.path.join("outputdata", "zcta", f"zcta_{decyear_abr}")
            for decyear_abr in DECYEAR_ABRS
        ),
        state_idx=state_index,
        r_version=R_VERSION,
    threads: 28
    shell:
        """
        set -euo pipefail
        {params.mkdir}
        export R_VERSION={params.r_version}
        source code/slurm_runtime_env.sh
        Rscript code/03a_BlockPop_Wt_ZCTA_PRISM_800m_v03.R {wildcards.year} {params.state_idx} {input.config}
        """


rule nationwide_zcta:
    input:
        config=CONFIG_PATH,
        download=DOWNLOAD_DONE,
        state_files=expand(
            os.path.join(
                "outputdata",
                "zcta",
                "zcta_{decyear_abr}",
                "PRISM_ZCTA{decyear_abr}_{year}_{state}.Rds",
            ),
            decyear_abr=FIRST_DECYEAR_ABR,
            year=YEARS,
            state=STATE_FIPS,
        ),
        weights=expand(
            os.path.join("rawdata", "crosswalk", "ZCTA_StateWt_{year}_US.Rds"),
            year=YEARS,
        ),
    output:
        expand(
            os.path.join(
                "outputdata",
                "zcta",
                "nationwide",
                "PRISM_ZCTA{decyear_abr}_{year}_nation.rds",
            ),
            decyear_abr=[FIRST_DECYEAR_ABR],
            year=YEARS,
        ),
    params:
        mkdir="mkdir -p outputdata/zcta/nationwide",
        r_version=R_VERSION,
    threads: 16
    shell:
        """
        set -euo pipefail
        {params.mkdir}
        export R_VERSION={params.r_version}
        source code/slurm_runtime_env.sh
        Rscript code/04_Zip2Zcta_Cleaning_PRISM_allyrs_v01.R {input.config}
        """