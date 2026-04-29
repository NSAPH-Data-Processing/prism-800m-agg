# =========================================================================== #
# setup_env.R — One-time package install for the PRISM 800m pipeline
# =========================================================================== #
# Do not run this directly. Use the companion shell script instead:
#
#   bash setup_env.sh
#
# That script loads the required cluster modules (R, cmake) and sets
# LD_LIBRARY_PATH before calling this file, which is necessary for several
# packages to compile and load correctly on this cluster.
# =========================================================================== #

cat("=== PRISM 800m package setup ===\n\n")

# ---- Ensure a writable user library exists ---------------------------------
user_lib <- Sys.getenv("R_LIBS_USER")
if (!nzchar(user_lib)) {
  user_lib <- file.path(
    path.expand("~"), "R",
    paste0(R.version$platform, "-library"),
    paste0(R.version$major, ".", strsplit(R.version$minor, "\\.")[[1]][1])
  )
}
if (!dir.exists(user_lib)) dir.create(user_lib, recursive = TRUE)
.libPaths(c(user_lib, .libPaths()))
cat("Installing packages to:", user_lib, "\n\n")

# ---- Helper: install from CRAN archive if not already present --------------
install_if_missing <- function(pkgs, repos = "https://cloud.r-project.org") {
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) == 0) {
    cat("Already installed:", paste(pkgs, collapse = ", "), "\n")
    return(invisible(NULL))
  }
  cat("Installing:", paste(missing, collapse = ", "), "\n")
  install.packages(missing, repos = repos, lib = .libPaths()[1])
}

# ---- 1. sf must be pinned to 1.0-19 ----------------------------------------
# sf 1.1-0 has a type-mismatch bug in gdal.cpp (NumericVector vs CharacterVector)
# that causes compilation failure with Rcpp >= 1.0.x on this cluster.
if (!requireNamespace("sf", quietly = TRUE)) {
  cat("Installing sf 1.0-19 from CRAN archive (1.1-0 has a compilation bug on this cluster)...\n")
  install.packages(
    "https://cran.r-project.org/src/contrib/Archive/sf/sf_1.0-19.tar.gz",
    repos = NULL,
    type  = "source",
    lib   = .libPaths()[1]
  )
} else {
  cat("sf already installed (version", as.character(packageVersion("sf")), ")\n")
}

# ---- 2. All other required packages ----------------------------------------
install_if_missing(c(
  "terra",       # >= 1.5.34 — raster data processing
  "plyr",        # >= 1.8.7  — data manipulation
  "dplyr",
  "doBy",        # >= 4.6.19 — summaryBy()
  "tigris",      # >= 2.0.4  — Census shapefiles
  "tidyverse",   # >= 1.3.1
  "tidycensus",  # >= 1.5    — Census data access
  "lwgeom",      # >= 0.2.8  — extended geometry operations
  "data.table",
  "yaml",
  "arrow"        # final parquet output
))

# ---- 3. Verify all packages load -------------------------------------------
cat("\nVerifying all packages load correctly...\n")
required <- c("terra", "sf", "plyr", "dplyr", "doBy",
              "tigris", "tidyverse", "tidycensus", "lwgeom",
              "data.table", "yaml", "arrow")

failed <- character(0)
for (pkg in required) {
  ok <- tryCatch({ library(pkg, character.only = TRUE); TRUE }, error = function(e) FALSE)
  cat(sprintf("  %-15s %s\n", pkg, if (ok) "OK" else "FAILED"))
  if (!ok) failed <- c(failed, pkg)
}

if (length(failed) > 0) {
  cat("\nThe following packages failed to load:", paste(failed, collapse = ", "), "\n")
  cat("Check the error messages above.\n")
  quit(status = 1)
} else {
  cat("\nAll packages installed and loading correctly.\n")
}
