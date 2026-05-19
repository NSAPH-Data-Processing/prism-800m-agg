import logging
import os
import zipfile
from pathlib import Path
from typing import Iterable

import hydra
import requests
from omegaconf import DictConfig

LOGGER = logging.getLogger(__name__)

CONUS_STATE_FIPS = [
    "01", "04", "05", "06", "08", "09", "10", "11", "12", "13",
    "16", "17", "18", "19", "20", "21", "22", "23", "24", "25",
    "26", "27", "28", "29", "30", "31", "32", "33", "34", "35",
    "36", "37", "38", "39", "40", "41", "42", "44", "45", "46",
    "47", "48", "49", "50", "51", "53", "54", "55", "56",
]
NON_CONUS_FIPS = {"02", "15", "60", "66", "69", "72", "78"}
NON_CONUS_ABBR = {"AK", "HI", "PR", "GU", "VI", "MP", "AS"}

DECYEAR_CONFIG = {
    2000: {"tiger": "2010", "suffix": "00", "folder": "TIGER2010/TABBLOCK/2000"},
    2010: {"tiger": "2010", "suffix": "10", "folder": "TIGER2010/TABBLOCK/2010"},
    2020: {"tiger": "2020", "suffix": "20", "folder": "TIGER2020/TABBLOCK20"},
}


def resolve_fips_xwalk_path(path_value: str | Path) -> Path | None:
    path = Path(path_value)
    if path.is_dir():
        candidates = sorted(path.glob("*.parquet"))
        return candidates[0] if candidates else None
    if path.exists():
        return path
    return None


def load_state_fips_from_xwalk(path_value: str | Path) -> list[str]:
    xwalk_path = resolve_fips_xwalk_path(path_value)
    if not xwalk_path:
        LOGGER.warning("No FIPS parquet found at %s", path_value)
        return []

    import pandas as pd

    df = pd.read_parquet(xwalk_path)
    columns = {str(col).lower(): col for col in df.columns}
    fips_col = (
        columns.get("state_fips")
        or columns.get("stfips")
        or columns.get("statefp")
        or columns.get("state")
    )
    if not fips_col:
        LOGGER.warning("No state FIPS column found in %s", xwalk_path)
        return []

    stusps_col = columns.get("stusps") or columns.get("state_abbr") or columns.get("abbr")

    fips_series = df[fips_col].astype(str).str.zfill(2)
    if stusps_col:
        stusps = df[stusps_col].astype(str).str.upper()
        mask = ~stusps.isin(NON_CONUS_ABBR)
        fips_series = fips_series[mask]

    fips = [value for value in fips_series.tolist() if value not in NON_CONUS_FIPS]
    # Preserve order while removing duplicates.
    seen = set()
    ordered = []
    for value in fips:
        if value in seen:
            continue
        seen.add(value)
        ordered.append(value)
    return ordered


def normalize_state_fips(raw_state_fips: object, fallback: Iterable[str]) -> list[str]:
    if isinstance(raw_state_fips, str):
        if raw_state_fips.lower() == "nationwide":
            return list(fallback)
        if "," in raw_state_fips:
            return [token.strip().zfill(2) for token in raw_state_fips.split(",") if token.strip()]
        return [raw_state_fips.zfill(2)]

    try:
        return [str(value).zfill(2) for value in raw_state_fips]
    except TypeError:
        return list(fallback)


def block_shapefile_stem(target_dir: Path, tiger_year: str, state: str, suffix: str) -> Path:
    return target_dir / f"tl_{tiger_year}_{state}_tabblock{suffix}"


def block_shapefile_exists(target_dir: Path, tiger_year: str, state: str, suffix: str) -> bool:
    stem = block_shapefile_stem(target_dir, tiger_year, state, suffix)
    for ext in [".shp", ".dbf", ".shx", ".prj"]:
        if not stem.with_suffix(ext).exists():
            return False
    return True


def download_zip(url: str, dest: Path, dry_run: bool) -> None:
    if dest.exists():
        LOGGER.info("Exists: %s", dest)
        return
    if dry_run:
        LOGGER.info("Dry-run: %s -> %s", url, dest)
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    with requests.get(url, stream=True, timeout=120) as response:
        response.raise_for_status()
        tmp_path = dest.with_suffix(dest.suffix + ".download")
        with open(tmp_path, "wb") as handle:
            for chunk in response.iter_content(chunk_size=1024 * 1024):
                if chunk:
                    handle.write(chunk)
        os.replace(tmp_path, dest)


def extract_zip(zip_path: Path, target_dir: Path, dry_run: bool) -> None:
    if dry_run:
        LOGGER.info("Dry-run: extract %s -> %s", zip_path, target_dir)
        return
    target_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zip_path, "r") as archive:
        archive.extractall(target_dir)


def download_decyear(
    decyear: int,
    state_fips: Iterable[str],
    target_dir: Path,
    dry_run: bool,
    limit_states: int | None,
) -> None:
    config = DECYEAR_CONFIG.get(decyear)
    if not config:
        raise ValueError(f"Unsupported decennial year: {decyear}")

    base_url = f"https://www2.census.gov/geo/tiger/{config['folder'].rstrip('/')}/"
    tiger_year = config["tiger"]
    suffix = config["suffix"]

    states = list(state_fips)
    if limit_states is not None:
        states = states[:limit_states]

    for state in states:
        if block_shapefile_exists(target_dir, tiger_year, state, suffix):
            LOGGER.info("Exists: %s", block_shapefile_stem(target_dir, tiger_year, state, suffix))
            continue
        filename = f"tl_{tiger_year}_{state}_tabblock{suffix}.zip"
        url = f"{base_url}{filename}"
        zip_path = target_dir / filename
        download_zip(url, zip_path, dry_run)
        extract_zip(zip_path, target_dir, dry_run)


@hydra.main(config_path="../conf", config_name="config", version_base=None)
def main(cfg: DictConfig) -> None:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")

    datapaths = cfg.datapaths
    prism_cfg = cfg.prism
    dry_run = bool(cfg.get("dry_run", False))
    limit_states = cfg.get("limit_states")
    if limit_states is not None:
        limit_states = int(limit_states)

    fips_from_xwalk = load_state_fips_from_xwalk(datapaths.dirs.input.fips_xwalk)
    state_fips = normalize_state_fips(prism_cfg.state_fips, fips_from_xwalk or CONUS_STATE_FIPS)

    decyears = [int(value) for value in prism_cfg.decyears]
    for decyear in decyears:
        target_key = f"block_{decyear}_state"
        target_dir = Path(datapaths.dirs.input.shapefiles[target_key])
        download_decyear(decyear, state_fips, target_dir, dry_run, limit_states)


if __name__ == "__main__":
    main()
