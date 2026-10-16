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
# Shiny viewer smoke test (manual)
#
# Launches the DQD Shiny dashboard against a results.json produced by
# runner/run_dqd.R, using the same outputFolder/outputFile from dqd_config.R
# (single source of truth -- not hardcoded here).
#
# This is a MANUAL check: opening/rendering/filtering a Shiny app in a
# browser isn't something we assert on automatically. Run this after any
# change that could affect results.json's shape or the viewer, and confirm:
#   - the dashboard loads with no error
#   - the results table renders rows
#   - expanding a row shows check detail (name, description, counts, etc.)
#   - search/filter on the table works
#   - the CSV export button works
#   - no errors in the browser's JS console
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

runnerDir <- script_dir()
configPath <- file.path(runnerDir, "dqd_config.R")

if (!file.exists(configPath)) {
  stop("Config file not found: ", configPath, ". Copy dqd_config.example.R to dqd_config.R first.")
}

cfg <- source(configPath, local = TRUE)$value

outputFolder <- cfg$execution$outputFolder
outputFile <- cfg$execution$outputFile

cat("Opening DQD Dashboard...\n")

# jsonFilePath <- file.path(outputFolder, outputFile)
jsonFilePath <- normalizePath(file.path(outputFolder, outputFile), mustWork = FALSE)

if (file.exists(jsonFilePath)) {
  DataQualityDashboard::viewDqDashboard(jsonFilePath, launch.browser = FALSE)
} else {
  cat(sprintf("Warning: Results file not found at %s\n", jsonFilePath))
  cat("Run runner/run_dqd.R first to generate results.\n")
}
