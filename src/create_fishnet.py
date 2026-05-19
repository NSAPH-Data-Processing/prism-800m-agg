import logging
import os
import zipfile
from pathlib import Path
from typing import Iterable

import fiona
import hydra
import rasterio
from omegaconf import DictConfig
from shapely.geometry import box, mapping

LOGGER = logging.getLogger(__name__)

RASTER_EXTENSIONS = {".tif", ".tiff", ".bil", ".img", ".zip"}


def find_raster_files(prism_dir: Path) -> list[Path]:
    files = [path for path in prism_dir.iterdir() if path.is_file() and path.suffix.lower() in RASTER_EXTENSIONS]
    return sorted(files)


def resolve_raster_path(candidate: Path) -> str:
    if candidate.suffix.lower() != ".zip":
        return str(candidate)

    with zipfile.ZipFile(candidate, "r") as archive:
        members = [name for name in archive.namelist() if name.lower().endswith((".tif", ".tiff", ".bil", ".img"))]
        if not members:
            raise ValueError(f"No raster files found inside {candidate}")
        member = sorted(members)[0]
        return f"/vsizip/{candidate}/{member}"


def write_fishnet(
    out_path: Path,
    transform,
    width: int,
    height: int,
    crs_wkt: str | None,
    chunk_rows: int,
) -> None:
    schema = {"geometry": "Polygon", "properties": {"ID": "int"}}

    out_path.parent.mkdir(parents=True, exist_ok=True)
    if out_path.exists():
        out_path.unlink()

    with fiona.open(
        out_path,
        "w",
        driver="GPKG",
        crs_wkt=crs_wkt,
        schema=schema,
    ) as sink:
        for row_start in range(0, height, chunk_rows):
            row_end = min(height, row_start + chunk_rows)
            features = []
            for row in range(row_start, row_end):
                row_id_base = row * width + 1
                for col in range(width):
                    x_min, y_max = transform * (col, row)
                    x_max, y_min = transform * (col + 1, row + 1)
                    geom = box(
                        min(x_min, x_max),
                        min(y_min, y_max),
                        max(x_min, x_max),
                        max(y_min, y_max),
                    )
                    features.append(
                        {
                            "geometry": mapping(geom),
                            "properties": {"ID": row_id_base + col},
                        }
                    )
            sink.writerecords(features)
            LOGGER.info("Wrote rows %s-%s", row_start + 1, row_end)


@hydra.main(config_path="../conf", config_name="config", version_base=None)
def main(cfg: DictConfig) -> None:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")

    prism_cfg = cfg.prism
    datapaths = cfg.datapaths
    dry_run = bool(cfg.get("dry_run", False))

    chunk_rows = int(cfg.get("chunk_rows", 100))

    fishnet_year = int(prism_cfg.fishnet.year)
    fishnet_var = str(prism_cfg.fishnet.variable)

    prism_dir = Path(datapaths.dirs.input.raw) / fishnet_var / str(fishnet_year)
    if not prism_dir.exists():
        raise FileNotFoundError(f"PRISM input directory does not exist: {prism_dir}")

    prism_files = find_raster_files(prism_dir)
    if not prism_files:
        raise FileNotFoundError(f"No raster files found in {prism_dir}")

    raster_path = resolve_raster_path(prism_files[0])
    LOGGER.info("Using raster: %s", raster_path)

    with rasterio.open(raster_path) as dataset:
        width = dataset.width
        height = dataset.height
        transform = dataset.transform
        crs_wkt = dataset.crs.to_wkt() if dataset.crs else None

    out_dir = Path(datapaths.dirs.intermediate.fishnet)
    out_name = f"prism_fishnet_{fishnet_var}_800m.gpkg"
    out_path = out_dir / out_name

    if dry_run:
        LOGGER.info("Dry-run output: %s", out_path)
        LOGGER.info("Dry-run grid size: %s rows x %s cols", height, width)
        LOGGER.info("Dry-run chunk rows: %s", chunk_rows)
        return

    write_fishnet(out_path, transform, width, height, crs_wkt, chunk_rows)


if __name__ == "__main__":
    main()
