library(testthat)

test_that("results.json contains every field loadResults.js reads", {
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

  jsonPath <- list.files(outputFolder, "\\.json$", full.names = TRUE)[1]
  json <- jsonlite::read_json(jsonPath, simplifyVector = FALSE)

  # Fields inst/shinyApps/www/js/loadResults.js reads off each CheckResults row
  requiredRowFields <- c(
    "checkId", "checkName", "checkDescription", "checkLevel",
    "cdmTableName", "cdmFieldName",
    "numViolatedRows", "pctViolatedRows", "numDenominatorRows",
    "executionTime", "queryText"
  )

  expect_true(length(json$CheckResults) > 0)

  for (field in requiredRowFields) {
    present <- vapply(json$CheckResults, function(row) field %in% names(row), logical(1))
    expect_true(all(present), info = sprintf("Missing '%s' on one or more CheckResults rows", field))
  }

  # loadResults.js also reads results.Metadata[0].cdmSourceName
  expect_false(is.null(json$Metadata))
  expect_true(length(json$Metadata) > 0)
  expect_true("cdmSourceName" %in% names(json$Metadata[[1]]))
})
