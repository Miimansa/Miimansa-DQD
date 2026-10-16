# Copyright 2026 Miimansa
#
# This file is part of Miimansa DQD, a modified version of DataQualityDashboard
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# =============================================================================
# First-time setup for the local DQD runner
#
# Run once on a new machine/session:
#   Rscript runner/setup.R
#
# Then edit runner/dqd_config.R and run:
#   Rscript runner/run_dqd.R
# =============================================================================

script_dir <- function() {
  frames <- sys.frames()
  for (frame in rev(frames)) {
    if (!is.null(frame$ofile)) {
      return(dirname(normalizePath(frame$ofile, winslash = "/", mustWork = FALSE)))
    }
  }

  cmd_args <- commandArgs(trailingOnly = FALSE)
  file_arg <- "--file="
  match <- grep(file_arg, cmd_args, fixed = TRUE, value = TRUE)
  if (length(match) > 0) {
    return(dirname(normalizePath(sub(file_arg, "", match[[1]]), winslash = "/", mustWork = FALSE)))
  }
  normalizePath(getwd(), winslash = "/", mustWork = FALSE)
}

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

install_if_missing <- function(packages) {
  missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) == 0) {
    return(invisible(TRUE))
  }

  repos <- getOption("repos")
  if (is.null(repos) || identical(unname(repos["CRAN"]), "@CRAN@")) {
    options(repos = c(CRAN = "https://cloud.r-project.org"))
  }

  install.packages(missing)
}

runnerDir <- script_dir()
packageDir <- normalizePath(file.path(runnerDir, ".."), winslash = "/", mustWork = TRUE)
configPath <- file.path(runnerDir, "dqd_config.R")

if (!file.exists(configPath)) {
  stop("Config file not found: ", configPath)
}

cfg <- source(configPath, local = TRUE)$value

requiredPackages <- c(
  "devtools",
  "DatabaseConnector",
  "SqlRender",
  "jsonlite",
  "dplyr",
  "DBI",
  "magrittr"
)

cat("Installing missing R packages...\n")
install_if_missing(requiredPackages)

packagePath <- normalizePath(cfg$packagePath %||% packageDir, winslash = "/", mustWork = FALSE)
cat(sprintf("Installing local DataQualityDashboard package from: %s\n", packagePath))
tryCatch({
  devtools::install(packagePath, quiet = TRUE, upgrade = FALSE, dependencies = TRUE)
}, error = function(e) {
  stop(
    "Setup failed while installing the local DataQualityDashboard package. ",
    "Fix the installation error, then rerun `Rscript runner/setup.R`. Details: ",
    conditionMessage(e),
    call. = FALSE
  )
})

driverPath <- path.expand(cfg$connection$pathToDriver)
if (!dir.exists(driverPath)) {
  dir.create(driverPath, recursive = TRUE)
}

cat(sprintf("JDBC driver directory: %s\n", driverPath))
cat(sprintf("Configured DBMS: %s\n", cfg$connection$dbms))

downloadDrivers <- Sys.getenv("DQD_DOWNLOAD_JDBC", "TRUE")
if (toupper(downloadDrivers) %in% c("TRUE", "1", "YES", "Y")) {
  cat("Downloading JDBC driver if needed...\n")
  DatabaseConnector::downloadJdbcDrivers(
    dbms = cfg$connection$dbms,
    pathToDriver = driverPath
  )
} else {
  cat("Skipping JDBC driver download because DQD_DOWNLOAD_JDBC is not TRUE.\n")
}

cat("\nSetup complete.\n")
cat("Next steps:\n")
cat("1. Edit runner/dqd_config.R for your database, schemas, and checks.\n")
cat("2. Export DQD_DB_PASSWORD if your database requires a password.\n")
cat("3. Run: Rscript runner/run_dqd.R\n")
