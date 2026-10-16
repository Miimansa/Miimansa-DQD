# Copyright 2026 Observational Health Data Sciences and Informatics
# Modified 2026 by Miimansa: runs verbose (row-level) SQL and returns violating rows
# alongside the check summary.
#
# This file is part of DataQualityDashboard
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

#' Internal function to send the fully qualified sql to the database and return the numerical result.
#'
#' @param connection                A connection for connecting to the CDM database using the DatabaseConnector::connect(connectionDetails) function.
#' @param connectionDetails         A connectionDetails object for connecting to the CDM database.
#' @param check                     The data quality check
#' @param checkDescription          The description of the data quality check
#' @param sql                       The fully qualified sql for the data quality check
#' @param outputFolder              The folder to output logs and SQL files to.
#' @param verboseOutput             When TRUE, the sql returns violating rows rather than aggregates.
#'                                  A COUNT denominator query is run separately and the raw rows are
#'                                  attached to the result object alongside the summary stats.
#' @param maxViolatingRows          When verboseOutput=TRUE, cap the number of violating rows stored
#'                                  per check to this limit to keep JSON sizes manageable. Default 1000.
#' @param denomSql                  When verboseOutput=TRUE, the fully rendered/translated SQL that
#'                                  computes the check-specific denominator (eligible row count). If
#'                                  NULL, a naive COUNT(*) over the whole table is used instead as a
#'                                  fallback, and the result is flagged via denominatorMethod =
#'                                  "naive_fallback" so it can be distinguished from a properly scoped
#'                                  denominator ("scoped").
#'
#' @return In normal mode: a one-row dataframe of check results.
#'         In verbose mode: a list with $summary (one-row dataframe) and $violatingRows (dataframe).
#'
#' @keywords internal
#'

.processCheck <- function(connection,
                          connectionDetails,
                          check,
                          checkDescription,
                          sql,
                          outputFolder,
                          verboseOutput = FALSE,
                          maxViolatingRows = 1000L,
                          denomSql = NULL) {
  singleThreaded <- TRUE
  start <- Sys.time()
  if (is.null(connection)) {
    singleThreaded <- FALSE
    connection <- DatabaseConnector::connect(connectionDetails = connectionDetails)
    on.exit(DatabaseConnector::disconnect(connection = connection))
  }

  errorReportFile <- file.path(
    outputFolder, "errors",
    sprintf(
      "%s_%s_%s_%s.txt",
      checkDescription$checkLevel,
      checkDescription$checkName,
      check["cdmTableName"],
      check["cdmFieldName"]
    )
  )
  tryCatch(
    expr = {
      if (singleThreaded) {
        if (.needsAutoCommit(connectionDetails = connectionDetails, connection = connection)) {
          rJava::.jcall(connection@jConnection, "V", "setAutoCommit", TRUE)
        }
      }
      result <- DatabaseConnector::querySql(
        connection = connection, sql = sql,
        errorReportFile = errorReportFile,
        snakeCaseToCamelCase = TRUE
      )

      delta <- difftime(Sys.time(), start, units = "secs")
      executionTime <- sprintf("%f %s", delta, attr(delta, "units"))

      if (verboseOutput) {
        # result contains the actual violating rows.
        numViolatedRows <- nrow(result)

        # Prefer the check-specific, correctly-scoped denominator SQL passed in
        # from .runCheck() (extracted from inst/sql/verbose_denominator/).
        # Only fall back to a naive COUNT(*) over the whole table if no such file
        # exists yet for this check -- and flag that clearly, since a blind
        # COUNT(*) can be wrong for checks whose denominator is a filtered
        # subset (e.g. WHERE field IS NOT NULL, WHERE field = @conceptId, etc.).
        denominatorMethod <- "scoped"
        if (is.null(denomSql)) {
          denominatorMethod <- "naive_fallback"
          ParallelLogger::logWarn(sprintf(
            "[Level: %s] [Check: %s] [CDM Table: %s] [CDM Field: %s] No scoped denominator SQL supplied -- using naive COUNT(*) fallback. numDenominatorRows/pctViolatedRows for this row may be inaccurate.",
            checkDescription$checkLevel,
            checkDescription$checkName,
            check["cdmTableName"],
            check["cdmFieldName"]
          ))
          schema   <- as.character(check["schema"])
          cdmTable <- as.character(check["cdmTableName"])
          if (is.null(schema) || is.na(schema) || schema == "") {
            schema <- cdmTable  # fallback; won't be used
          }
          denomSql <- SqlRender::render(
            sql = "SELECT COUNT_BIG(*) AS num_rows FROM @schema.@cdmTableName;",
            schema = schema,
            cdmTableName = cdmTable
          )
          denomSql <- SqlRender::translate(denomSql, targetDialect = connectionDetails$dbms)
        }

        denomResult <- tryCatch(
          DatabaseConnector::querySql(connection = connection, sql = denomSql,
                                      snakeCaseToCamelCase = TRUE),
          error = function(e) data.frame(numRows = NA_real_)
        )
        numDenominatorRows <- denomResult[[1]][[1]]
        pctViolatedRows <- if (!is.na(numDenominatorRows) && numDenominatorRows > 0) {
          numViolatedRows / numDenominatorRows
        } else {
          # Empty table (denom=0) or failed denom query: treat as 0% violated.
          # evaluateThresholds cannot handle NA pct for non-NA, non-zero thresholds.
          0
        }

        aggregateSummary <- data.frame(
          numViolatedRows    = numViolatedRows,
          pctViolatedRows    = pctViolatedRows,
          numDenominatorRows = numDenominatorRows,
          denominatorMethod  = denominatorMethod
        )

        summaryRow <- .recordResult(
          result = aggregateSummary,
          check = check,
          checkDescription = checkDescription,
          sql = sql,
          executionTime = executionTime
        )

        # Cap violating rows to keep JSON size manageable
        violatingRowsStored <- if (nrow(result) > maxViolatingRows) {
          attr_msg <- sprintf("[Truncated to first %d of %d violating rows]", maxViolatingRows, nrow(result))
          rbind(head(result, maxViolatingRows),
                setNames(as.data.frame(matrix(NA, 1, ncol(result))), names(result)))
          res_trunc <- head(result, maxViolatingRows)
          attr(res_trunc, "truncated") <- attr_msg
          res_trunc
        } else {
          result
        }

        return(list(summary = summaryRow, violatingRows = violatingRowsStored))
      } else {
        return(.recordResult(
          result = result, check = check, checkDescription = checkDescription, sql = sql,
          executionTime = executionTime
        ))
      }
    },
    warning = function(w) {
      ParallelLogger::logWarn(sprintf(
        "[Level: %s] [Check: %s] [CDM Table: %s] [CDM Field: %s] %s",
        checkDescription$checkLevel,
        checkDescription$checkName,
        check["cdmTableName"],
        check["cdmFieldName"], w$message
      ))
      summaryRow <- .recordResult(check = check, checkDescription = checkDescription, sql = sql, warning = w$message)
      if (verboseOutput) return(list(summary = summaryRow, violatingRows = data.frame()))
      return(summaryRow)
    },
    error = function(e) {
      ParallelLogger::logError(sprintf(
        "[Level: %s] [Check: %s] [CDM Table: %s] [CDM Field: %s] %s",
        checkDescription$checkLevel,
        checkDescription$checkName,
        check["cdmTableName"],
        check["cdmFieldName"], e$message
      ))
      summaryRow <- .recordResult(check = check, checkDescription = checkDescription, sql = sql, error = e$message)
      if (verboseOutput) return(list(summary = summaryRow, violatingRows = data.frame()))
      return(summaryRow)
    }
  )
}