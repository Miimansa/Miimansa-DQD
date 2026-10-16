# Copyright 2026 Observational Health Data Sciences and Informatics
# Modified 2026 by Miimansa: verbose-mode check execution and per-check progress logging.
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

#' Internal function to run and process each data quality check.
#'
#' @param checkDescription          The description of the data quality check
#' @param tableChecks               A dataframe containing the table checks
#' @param fieldChecks               A dataframe containing the field checks
#' @param conceptChecks             A dataframe containing the concept checks
#' @param connectionDetails         A connectionDetails object for connecting to the CDM database
#' @param connection                A connection for connecting to the CDM database using the DatabaseConnector::connect(connectionDetails) function.
#' @param cdmDatabaseSchema         The fully qualified database name of the CDM schema
#' @param vocabDatabaseSchema       The fully qualified database name of the vocabulary schema (default is to set it as the cdmDatabaseSchema)
#' @param resultsDatabaseSchema     The fully qualified database name of the results schema
#' @param writeTableName            The table tor write DQD results to. Used when sqlOnly or writeToTable is True.
#' @param cohortDatabaseSchema      The schema where the cohort table is located.
#' @param cohortTableName           The name of the cohort table.
#' @param cohortDefinitionId        The cohort definition id for the cohort you wish to run the DQD on. The package assumes a standard OHDSI cohort table called 'Cohort'
#' @param outputFolder              The folder to output logs and SQL files to
#' @param sqlOnlyUnionCount         (OPTIONAL) How many SQL commands to union before inserting them into output table (speeds processing when queries done in parallel). Default is 1.
#' @param sqlOnlyIncrementalInsert  (OPTIONAL) Boolean to determine whether insert check results and associated metadata into output table.  Default is FALSE (for backwards compatability to <= v2.2.0)
#' @param sqlOnly                   Should the SQLs be executed (FALSE) or just returned (TRUE)?
#' @param verboseOutput             When TRUE, load SQL from inst/sql/sql_server_verbose/ and return per-row violating records alongside summary stats.
#'
#' @return A list of per-check result objects (verboseOutput=TRUE) or a dataframe (verboseOutput=FALSE), or SQL queries
#'
#' @import magrittr
#'
#' @keywords internal
#'
.runCheck <- function(checkDescription,
                      tableChecks,
                      fieldChecks,
                      conceptChecks,
                      connectionDetails,
                      connection,
                      cdmDatabaseSchema,
                      vocabDatabaseSchema,
                      resultsDatabaseSchema,
                      writeTableName,
                      cohortDatabaseSchema,
                      cohortTableName,
                      cohortDefinitionId,
                      outputFolder,
                      sqlOnlyUnionCount,
                      sqlOnlyIncrementalInsert,
                      sqlOnly,
                      verboseOutput = FALSE) {
  ParallelLogger::logInfo(sprintf("Processing check description: %s", checkDescription$checkName))

  filterExpression <- sprintf(
    "%sChecks %%>%% dplyr::filter(%s)",
    tolower(checkDescription$checkLevel),
    checkDescription$evaluationFilter
  )
  checks <- eval(parse(text = filterExpression))

  if (length(cohortDefinitionId > 0)) {
    cohort <- TRUE
  } else {
    cohort <- FALSE
  }

  if (nrow(checks) > 0) {
    # ── Verbose path ──────────────────────────────────────────────────────────
    # Must use lapply (not apply) because apply calls simplify2array on the
    # results, which converts a list of list(summary, violatingRows) objects
    # into a 2×N matrix — rendering the structure completely wrong.
    if (verboseOutput) {
      # Convert to matrix first so each row arrives as a named character vector,
      # exactly as apply() would deliver it, preserving param-rendering behaviour.
      checksMat <- as.matrix(checks)

      results <- lapply(seq_len(nrow(checksMat)), function(ri) {
        check <- checksMat[ri, ]

        columns <- lapply(names(check), function(c) {
          setNames(check[c], c)
        })

        verboseSqlFile <- system.file(
          "sql", "sql_server_verbose", checkDescription$sqlFile,
          package = "DataQualityDashboard"
        )
        if (verboseSqlFile == "") {
          ParallelLogger::logWarn(sprintf(
            "No verbose SQL found for %s — skipping check instance for %s.%s",
            checkDescription$checkName,
            check["cdmTableName"], check["cdmFieldName"]
          ))
          return(NULL)
        }

        renderParams <- c(
          list(sql = SqlRender::readSql(verboseSqlFile)),
          list(warnOnMissingParameters = FALSE),
          list(cdmDatabaseSchema = cdmDatabaseSchema),
          list(cohortDatabaseSchema = cohortDatabaseSchema),
          list(cohortTableName = cohortTableName),
          list(cohortDefinitionId = cohortDefinitionId),
          list(vocabDatabaseSchema = vocabDatabaseSchema),
          list(cohort = cohort),
          unlist(columns, recursive = FALSE)
        )

        sql <- SqlRender::translate(
          do.call(SqlRender::render, renderParams),
          targetDialect = connectionDetails$dbms
        )

        # ── Look up the scoped denominator SQL for this check ────────────
        # Lives in a separate folder, one file per check, same filename as
        # the sql_server_verbose file. If it hasn't been added yet for this
        # check, denomSql stays NULL and .processCheck() will fall back to
        # a naive COUNT(*), flagged accordingly.
        denomSqlFile <- system.file(
          "sql", "verbose_denominator", checkDescription$sqlFile,
          package = "DataQualityDashboard"
        )
        denomSql <- if (denomSqlFile != "") {
          denomRenderParams <- renderParams
          denomRenderParams$sql <- SqlRender::readSql(denomSqlFile)
          SqlRender::translate(
            do.call(SqlRender::render, denomRenderParams),
            targetDialect = connectionDetails$dbms
          )
        } else {
          ParallelLogger::logWarn(sprintf(
            "No scoped denominator SQL found for %s — %s.%s will use a naive COUNT(*) fallback.",
            checkDescription$checkName,
            check["cdmTableName"], check["cdmFieldName"]
          ))
          NULL
        }

        instanceLabel <- sprintf("[%s] %s.%s (%d/%d)",
          checkDescription$checkName,
          check["cdmTableName"], check["cdmFieldName"],
          ri, nrow(checksMat))
        ParallelLogger::logInfo(sprintf("START  %s", instanceLabel))
        instanceStart <- proc.time()[["elapsed"]]

        result <- .processCheck(
          connection = connection,
          connectionDetails = connectionDetails,
          check = check,
          checkDescription = checkDescription,
          sql = sql,
          outputFolder = outputFolder,
          verboseOutput = TRUE,
          maxViolatingRows = 1000L,
          denomSql = denomSql
        )

        elapsed <- round(proc.time()[["elapsed"]] - instanceStart, 1)
        ParallelLogger::logInfo(sprintf("DONE   %s  [%.1fs]", instanceLabel, elapsed))
        result
      })

      return(Filter(Negate(is.null), results))
    }

    # ── Non-verbose path (unchanged) ──────────────────────────────────────────
    dfs <- apply(X = checks, MARGIN = 1, function(check) {
      columns <- lapply(names(check), function(c) {
        setNames(check[c], c)
      })

      params <- c(
        list(dbms = connectionDetails$dbms),
        list(sqlFilename = checkDescription$sqlFile),
        list(packageName = "DataQualityDashboard"),
        list(warnOnMissingParameters = FALSE),
        list(cdmDatabaseSchema = cdmDatabaseSchema),
        list(cohortDatabaseSchema = cohortDatabaseSchema),
        list(cohortTableName = cohortTableName),
        list(cohortDefinitionId = cohortDefinitionId),
        list(vocabDatabaseSchema = vocabDatabaseSchema),
        list(cohort = cohort),
        unlist(columns, recursive = FALSE)
      )

      sql <- do.call(SqlRender::loadRenderTranslateSql, params)

      if (sqlOnly && sqlOnlyIncrementalInsert) {
        checkQuery <- .createSqlOnlyQueries(
          params,
          check,
          tableChecks,
          fieldChecks,
          conceptChecks,
          sql,
          connectionDetails,
          checkDescription
        )
        data.frame(query = checkQuery)
      } else if (sqlOnly) {
        write(x = sql, file = file.path(
          outputFolder,
          sprintf("%s.sql", checkDescription$checkName)
        ), append = TRUE)
        data.frame()
      } else {
        .processCheck(
          connection = connection,
          connectionDetails = connectionDetails,
          check = check,
          checkDescription = checkDescription,
          sql = sql,
          outputFolder = outputFolder
        )
      }
    })

    if (sqlOnly && sqlOnlyIncrementalInsert) {
      sqlToUnion <- dfs$query
      if (length(sqlToUnion) > 0) {
        .writeSqlOnlyQueries(sqlToUnion, sqlOnlyUnionCount, resultsDatabaseSchema, writeTableName, connectionDetails$dbms, outputFolder, checkDescription)
        return(NULL)
      }
    } else {
      return(dfs)
    }
  } else {
    ParallelLogger::logWarn(paste0("Warning: Evaluation resulted in no checks: ", filterExpression))
    if (verboseOutput) return(list())
    return(data.frame())
  }
}