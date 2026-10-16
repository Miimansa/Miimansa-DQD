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
# Local DQD runner
#
# Runtime values such as database, schema, output folder, excluded tables, and
# excluded fields live in dqd_config.R. Edit that file for each environment.
#
# This script does not install packages. Run runner/setup.R first on a new
# machine/session, then run this script after setup succeeds.
# =============================================================================

requiredPackages <- c(
  "DatabaseConnector",
  "SqlRender",
  "DataQualityDashboard",
  "jsonlite",
  "dplyr",
  "DBI",
  "magrittr"
)

missingPackages <- requiredPackages[!vapply(requiredPackages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missingPackages) > 0) {
  stop(
    "Missing required R package(s): ",
    paste(missingPackages, collapse = ", "),
    ". Run `Rscript runner/setup.R` first, then rerun this runner.",
    call. = FALSE
  )
}

suppressPackageStartupMessages({
  library(DatabaseConnector)
  library(SqlRender)
})

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
packageDir <- normalizePath(file.path(runnerDir, ".."), winslash = "/", mustWork = TRUE)
configPath <- file.path(runnerDir, "dqd_config.R")

if (!file.exists(configPath)) {
  stop("Config file not found: ", configPath)
}

cfg <- source(configPath, local = TRUE)$value

suppressPackageStartupMessages(library(DataQualityDashboard))
source(file.path(packageDir, "R", "writeDqdJsonToDb.R"))

connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = cfg$connection$dbms,
  user = cfg$connection$user,
  password = cfg$connection$password,
  server = cfg$connection$server,
  port = cfg$connection$port,
  pathToDriver = cfg$connection$pathToDriver
)

cdmDatabaseSchema <- cfg$schemas$cdm
resultsDatabaseSchema <- cfg$schemas$results
vocabDatabaseSchema <- cfg$schemas$vocab
cdmSourceName <- cfg$cdmSourceName
cdmVersion <- cfg$cdmVersion

numThreads <- cfg$execution$numThreads
sqlOnly <- cfg$execution$sqlOnly
sqlOnlyIncrementalInsert <- cfg$execution$sqlOnlyIncrementalInsert
sqlOnlyUnionCount <- cfg$execution$sqlOnlyUnionCount
outputFolder <- cfg$execution$outputFolder
outputFile <- cfg$execution$outputFile
verboseMode <- cfg$execution$verboseMode
writeToTable <- cfg$execution$writeToTable
writeTableName <- cfg$execution$writeTableName
writeToCsv <- cfg$execution$writeToCsv
csvFile <- cfg$execution$csvFile
verboseOutput <- cfg$execution$verboseOutput
checkLevels <- cfg$execution$checkLevels

checkNames <- cfg$checkNames
tablesToExclude <- cfg$tablesToExclude
fieldsToExclude <- cfg$fieldsToExclude

if (!dir.exists(outputFolder)) {
  dir.create(outputFolder, recursive = TRUE)
}

cat("Testing database connection...\n")
tryCatch({
  conn <- DatabaseConnector::connect(connectionDetails)
  on.exit(DatabaseConnector::disconnect(conn), add = TRUE)
  cat("Connected to database\n")

  testSql <- SqlRender::render(
    sql = "SELECT COUNT(*) AS person_count FROM @cdmDatabaseSchema.PERSON;",
    cdmDatabaseSchema = cdmDatabaseSchema
  )
  testResult <- DatabaseConnector::querySql(conn, testSql)
  cat(sprintf("Found %d persons in %s.PERSON\n", testResult$PERSON_COUNT, cdmDatabaseSchema))
  cat("Connection test successful\n\n")
}, error = function(e) {
  stop(paste("ERROR: Failed to connect or query PERSON table. Details:", conditionMessage(e)))
})

fieldCheckThresholdLoc <- "default"
conceptCheckThresholdLoc <- "default"

if (length(fieldsToExclude) > 0) {
  origFieldCsv <- system.file("csv", sprintf("OMOP_CDMv%s_Field_Level.csv", cdmVersion), package = "DataQualityDashboard")
  origConceptCsv <- system.file("csv", sprintf("OMOP_CDMv%s_Concept_Level.csv", cdmVersion), package = "DataQualityDashboard")

  origField <- read.csv(origFieldCsv, check.names = FALSE, stringsAsFactors = FALSE)
  origConcept <- read.csv(origConceptCsv, check.names = FALSE, stringsAsFactors = FALSE)

  fieldsLower <- tolower(trimws(fieldsToExclude))
  customField <- origField[!tolower(trimws(origField$cdmFieldName)) %in% fieldsLower, ]
  customConcept <- origConcept[!tolower(trimws(origConcept$cdmFieldName)) %in% fieldsLower, ]

  removedField <- nrow(origField) - nrow(customField)
  removedConcept <- nrow(origConcept) - nrow(customConcept)
  cat(sprintf("Field CSV   : %d rows -> %d rows (%d removed)\n", nrow(origField), nrow(customField), removedField))
  cat(sprintf("Concept CSV : %d rows -> %d rows (%d removed)\n", nrow(origConcept), nrow(customConcept), removedConcept))

  if (removedField == 0 && removedConcept == 0) {
    stop(paste0(
      "Validation failed: none of the requested fields were found in either CSV. ",
      "Check spelling against cdmFieldName values. Provided: ",
      paste(fieldsToExclude, collapse = ", ")
    ))
  }

  foundInField <- fieldsLower %in% tolower(origField$cdmFieldName)
  foundInConcept <- fieldsLower %in% tolower(origConcept$cdmFieldName)
  for (i in seq_along(fieldsToExclude)) {
    if (!foundInField[i] && !foundInConcept[i]) {
      warning(sprintf("fieldsToExclude: '%s' not found in either CSV; no rows removed for it.", fieldsToExclude[i]))
    } else {
      cat(sprintf("  Removed '%s' from: %s\n", fieldsToExclude[i],
                  paste(c(if (foundInField[i]) "Field CSV" else NULL,
                          if (foundInConcept[i]) "Concept CSV" else NULL),
                        collapse = " and ")))
    }
  }

  checkNameColsField <- intersect(checkNames, colnames(origField))
  checkNameColsConcept <- intersect(checkNames, colnames(origConcept))
  for (cn in checkNameColsField) {
    nOrig <- sum(!is.na(origField[[cn]]) & origField[[cn]] != "" & origField[[cn]] != 0, na.rm = TRUE)
    nCustom <- sum(!is.na(customField[[cn]]) & customField[[cn]] != "" & customField[[cn]] != 0, na.rm = TRUE)
    if (nOrig != nCustom) {
      cat(sprintf("  checkName '%s' (Field CSV): %d -> %d active rows\n", cn, nOrig, nCustom))
    }
  }
  for (cn in checkNameColsConcept) {
    nOrig <- sum(!is.na(origConcept[[cn]]) & origConcept[[cn]] != "" & origConcept[[cn]] != 0, na.rm = TRUE)
    nCustom <- sum(!is.na(customConcept[[cn]]) & customConcept[[cn]] != "" & customConcept[[cn]] != 0, na.rm = TRUE)
    if (nOrig != nCustom) {
      cat(sprintf("  checkName '%s' (Concept CSV): %d -> %d active rows\n", cn, nOrig, nCustom))
    }
  }

  customFieldCsvPath <- file.path(outputFolder, "custom_field_level.csv")
  customConceptCsvPath <- file.path(outputFolder, "custom_concept_level.csv")
  write.csv(customField, customFieldCsvPath, row.names = FALSE)
  write.csv(customConcept, customConceptCsvPath, row.names = FALSE)
  cat(sprintf("  Written: %s\n", customFieldCsvPath))
  cat(sprintf("  Written: %s\n", customConceptCsvPath))

  fieldCheckThresholdLoc <- customFieldCsvPath
  conceptCheckThresholdLoc <- customConceptCsvPath
}

cat("========================================\n")
cat("Starting Data Quality Dashboard\n")
cat("========================================\n")
cat(sprintf("CDM Schema: %s\n", cdmDatabaseSchema))
cat(sprintf("Vocab Schema: %s\n", vocabDatabaseSchema))
cat(sprintf("Results Schema: %s\n", resultsDatabaseSchema))
cat(sprintf("Output Folder: %s\n", outputFolder))
cat("\nThis will take 10-60 minutes...\n")
cat("========================================\n\n")

generation_time <- system.time(
  DataQualityDashboard::executeDqChecks(
    connectionDetails = connectionDetails,
    cdmDatabaseSchema = cdmDatabaseSchema,
    resultsDatabaseSchema = resultsDatabaseSchema,
    vocabDatabaseSchema = vocabDatabaseSchema,
    cdmSourceName = cdmSourceName,
    cdmVersion = cdmVersion,
    numThreads = numThreads,
    sqlOnly = sqlOnly,
    sqlOnlyUnionCount = sqlOnlyUnionCount,
    sqlOnlyIncrementalInsert = sqlOnlyIncrementalInsert,
    outputFolder = outputFolder,
    outputFile = outputFile,
    verboseMode = verboseMode,
    writeToTable = writeToTable,
    writeTableName = writeTableName,
    writeToCsv = writeToCsv,
    csvFile = csvFile,
    checkLevels = checkLevels,
    checkNames = checkNames,
    verboseOutput = verboseOutput,
    fieldCheckThresholdLoc = fieldCheckThresholdLoc,
    conceptCheckThresholdLoc = conceptCheckThresholdLoc,
    tablesToExclude = tablesToExclude
  )
)
print(paste("Time spent running DQD:", generation_time["elapsed"], "seconds"))

cat("\n========================================\n")
cat("DQD Complete\n")
cat("========================================\n\n")

if (isTRUE(cfg$persistViolations)) {
  cat("========================================\n")
  cat("Persisting DQD violations to DB...\n")
  cat("========================================\n\n")

  # Row-level violation data only exists in the row-level file (never in
  # outputFile / results.json). Derive its name from outputFile via the same
  # shared rule executeDqChecks() uses, rather than a second config value.
  jsonFilePathPersist <- if (isTRUE(verboseOutput)) {
    file.path(outputFolder, rowLevelViolationsFileName(outputFile))
  } else {
    file.path(outputFolder, outputFile)
  }
  connPersist <- DatabaseConnector::connect(connectionDetails)
  tryCatch({
    writeDqdJsonToCustomTables(
      connection = connPersist,
      jsonFilePath = jsonFilePathPersist,
      resultsDatabaseSchema = resultsDatabaseSchema
    )
    cat("\nViolations persisted to DB\n")
    cat(sprintf("  Schema : %s\n", resultsDatabaseSchema))
    cat("  Tables : dim_dqd_tests, fact_dqd_violations\n")
  }, finally = {
    DatabaseConnector::disconnect(connPersist)
  })
}
