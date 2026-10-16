library(testthat)

test_that("Verbose run writes a standard-schema results.json and a separate row-level file", {
  outputFolder <- tempfile("dqd_")
  on.exit(unlink(outputFolder, recursive = TRUE))

  withCallingHandlers(
    results <- executeDqChecks(
      connectionDetails = connectionDetailsEunomia,
      cdmDatabaseSchema = cdmDatabaseSchemaEunomia,
      resultsDatabaseSchema = resultsDatabaseSchemaEunomia,
      cdmSourceName = "Eunomia",
      checkNames = "measureValueCompleteness",
      outputFolder = outputFolder,
      writeToTable = FALSE,
      verboseOutput = TRUE
    ),
    warning = function(w) {
      if (grepl("^Missing check names", w$message)) {
        invokeRestart("muffleWarning")
      }
    }
  )

  jsonFiles <- list.files(outputFolder, "\\.json$", full.names = TRUE)
  standardPath <- jsonFiles[!grepl("_rowLevelViolations\\.json$", jsonFiles)]
  violationsPath <- jsonFiles[grepl("_rowLevelViolations\\.json$", jsonFiles)]

  expect_length(standardPath, 1)
  expect_length(violationsPath, 1)

  # Paired filenames, same folder
  expect_equal(dirname(standardPath), dirname(violationsPath))
  expect_equal(
    sub("\\.json$", "_rowLevelViolations.json", basename(standardPath)),
    basename(violationsPath)
  )

  # Standard schema: CheckResults is a flat array of rows, no violatingRows anywhere
  standardJson <- jsonlite::read_json(standardPath, simplifyVector = FALSE)
  expect_true(all(sapply(standardJson$CheckResults, function(cr) is.null(cr$violatingRows))))
  expect_true(all(sapply(standardJson$CheckResults, function(cr) is.null(cr$summary))))
  expect_true(all(sapply(standardJson$CheckResults, function(cr) !is.null(cr$checkId))))

  # results.json stays consumable by the existing CSV/table writers
  csvPath <- file.path(outputFolder, "results.csv")
  writeJsonResultsToCsv(jsonPath = standardPath, csvPath = csvPath)
  expect_true(file.exists(csvPath))
  csvData <- read.csv(csvPath)
  expect_true(nrow(csvData) > 0)
  expect_true("checkId" %in% colnames(csvData))

  # Row-level file: nested {summary, violatingRows}, summary matches results.json rows
  violationsJson <- jsonlite::read_json(violationsPath, simplifyVector = FALSE)
  expect_true(all(sapply(violationsJson$CheckResults, function(cr) !is.null(cr$summary))))

  failedEntries <- Filter(function(cr) isTRUE(cr$summary[[1]]$failed == 1), violationsJson$CheckResults)
  if (length(failedEntries) > 0) {
    expect_true(!is.null(failedEntries[[1]]$violatingRows))
  }
})

test_that("writeDqdJsonToCustomTables works against the row-level file and against results.json", {
  skip_if_not(
    identical(connectionDetailsEunomia$dbms, "postgresql"),
    "writeDqdJsonToCustomTables uses Postgres-specific DDL (CREATE SCHEMA IF NOT EXISTS); run against a Postgres connection to exercise this test"
  )

  outputFolder <- tempfile("dqd_")
  on.exit(unlink(outputFolder, recursive = TRUE))

  withCallingHandlers(
    results <- executeDqChecks(
      connectionDetails = connectionDetailsEunomia,
      cdmDatabaseSchema = cdmDatabaseSchemaEunomia,
      resultsDatabaseSchema = resultsDatabaseSchemaEunomia,
      cdmSourceName = "Eunomia",
      checkNames = "measureValueCompleteness",
      outputFolder = outputFolder,
      writeToTable = FALSE,
      verboseOutput = TRUE
    ),
    warning = function(w) {
      if (grepl("^Missing check names", w$message)) {
        invokeRestart("muffleWarning")
      }
    }
  )

  jsonFiles <- list.files(outputFolder, "\\.json$", full.names = TRUE)
  standardPath <- jsonFiles[!grepl("_rowLevelViolations\\.json$", jsonFiles)]
  violationsPath <- jsonFiles[grepl("_rowLevelViolations\\.json$", jsonFiles)]

  connection <- DatabaseConnector::connect(connectionDetailsEunomia)
  on.exit(DatabaseConnector::disconnect(connection), add = TRUE)

  # Against the row-level file: populates both dim_dqd_tests and fact_dqd_violations
  out1 <- writeDqdJsonToCustomTables(
    connection = connection,
    jsonFilePath = violationsPath,
    resultsDatabaseSchema = resultsDatabaseSchemaEunomia
  )
  expect_true(nrow(out1$tests) > 0)

  # Against the standard file: does not error, populates check metadata, but
  # finds no violating rows (results.json never carries them)
  out2 <- writeDqdJsonToCustomTables(
    connection = connection,
    jsonFilePath = standardPath,
    resultsDatabaseSchema = resultsDatabaseSchemaEunomia
  )
  expect_true(nrow(out2$tests) > 0)
  expect_equal(nrow(out2$violations), 0)
})