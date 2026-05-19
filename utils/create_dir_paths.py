import logging
import os

import hydra
from omegaconf import DictConfig

try:
    from src.prism_paths import local_base_path
except ModuleNotFoundError:
    from prism_paths import local_base_path

LOGGER = logging.getLogger(__name__)


def init_folder(datapath: str = "data", folder_cfg: DictConfig | None = None) -> None:
    folder_dict = folder_cfg.dirs

    datapath = local_base_path(folder_cfg, data_dir=datapath)
    os.makedirs(datapath, exist_ok=True)
    LOGGER.info("Using base path: %s", datapath)

    create_subfolders_and_links(datapath=datapath, folder_dict=folder_dict)


def create_subfolders_and_links(datapath: str = "data", folder_dict: DictConfig | None = None) -> None:
    """Recursively create subfolders and symbolic links."""
    if not os.path.exists(datapath):
        LOGGER.info("Error: %s does not exist.", datapath)
        return

    if isinstance(folder_dict, DictConfig):
        for path, subfolder_dict in folder_dict.items():
            sub_datapath = os.path.join(datapath, path)
            if isinstance(subfolder_dict, str):
                if os.path.islink(sub_datapath):
                    link_target = os.readlink(sub_datapath)
                    if os.path.abspath(link_target) == os.path.abspath(subfolder_dict):
                        LOGGER.info(
                            "There is a symbolic link to %s at %s already",
                            subfolder_dict,
                            sub_datapath,
                        )
                    else:
                        LOGGER.info(
                            "Error: %s is a symbolic link to %s, not %s",
                            sub_datapath,
                            link_target,
                            subfolder_dict,
                        )
                        return
                else:
                    if os.path.exists(sub_datapath):
                        LOGGER.info(
                            "Error: Path %s already exists, cannot create symlink",
                            sub_datapath,
                        )
                        return
                    os.makedirs(os.path.abspath(subfolder_dict), exist_ok=True)
                    os.symlink(os.path.abspath(subfolder_dict), sub_datapath)
                    LOGGER.info(
                        "Created symlink %s -> %s",
                        sub_datapath,
                        subfolder_dict,
                    )
            else:
                if os.path.exists(sub_datapath):
                    LOGGER.info("Path %s already exists", sub_datapath)
                else:
                    os.mkdir(sub_datapath)
                    LOGGER.info("Created data path %s", sub_datapath)
                if subfolder_dict is not None:
                    create_subfolders_and_links(sub_datapath, subfolder_dict)


@hydra.main(config_path="../conf", config_name="config", version_base=None)
def main(cfg: DictConfig) -> None:
    """Create data subfolders and symbolic links as indicated in config file."""
    init_folder(folder_cfg=cfg.datapaths)


if __name__ == "__main__":
    main()
