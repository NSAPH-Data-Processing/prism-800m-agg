import logging
import os
import re
from pathlib import Path
from typing import Iterable

import hydra
import requests
from omegaconf import DictConfig

LOGGER = logging.getLogger(__name__)


def iter_remote_files(index_html: str) -> list[str]:
    matches = re.findall(r'href=["\"]([^"\"]+)["\"]', index_html)
    candidates: list[str] = []
    for name in matches:
        if name.endswith("/"):
            continue
        if name.endswith(".tif") or name.endswith(".zip"):
            candidates.append(name)
    return sorted(set(candidates))


def download_file(url: str, dest: Path, dry_run: bool) -> None:
    if dest.exists():
        LOGGER.info("Exists: %s", dest)
        return
    if dry_run:
        LOGGER.info("Dry-run: %s -> %s", url, dest)
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    with requests.get(url, stream=True, timeout=60) as response:
        response.raise_for_status()
        with open(dest, "wb") as handle:
            for chunk in response.iter_content(chunk_size=1024 * 1024):
                if chunk:
                    handle.write(chunk)


def download_year(
    base_url: str,
    raw_root: Path,
    var: str,
    year: int,
    dry_run: bool,
    limit: int | None,
) -> None:
    year_url = f"{base_url.rstrip('/')}/{var}/daily/{year}/"
    target_dir = raw_root / var / str(year)
    manifest = target_dir / ".download_complete"

    if manifest.exists():
        LOGGER.info("Manifest exists: %s", manifest)
        return

    if dry_run:
        LOGGER.info("Dry-run listing: %s", year_url)
    response = requests.get(year_url, timeout=60)
    response.raise_for_status()
    files = iter_remote_files(response.text)
    if limit is not None:
        files = files[:limit]

    if not files:
        LOGGER.warning("No files found at %s", year_url)
        return

    for name in files:
        download_file(f"{year_url}{name}", target_dir / name, dry_run)

    if dry_run:
        LOGGER.info("Dry-run: would write %s", manifest)
        return

    target_dir.mkdir(parents=True, exist_ok=True)
    manifest.write_text("complete\n", encoding="utf-8")


@hydra.main(config_path="../conf", config_name="config", version_base=None)
def main(cfg: DictConfig) -> None:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")

    prism_cfg = cfg.prism
    datapaths = cfg.datapaths
    raw_root = Path(datapaths.dirs.input.raw)
    dry_run = bool(cfg.get("dry_run", False))
    limit = cfg.get("limit")
    if limit is not None:
        limit = int(limit)

    variables: Iterable[str] = prism_cfg.variables
    years: Iterable[int] = prism_cfg.years

    for var in variables:
        for year in years:
            download_year(prism_cfg.url, raw_root, str(var), int(year), dry_run, limit)


if __name__ == "__main__":
    main()
