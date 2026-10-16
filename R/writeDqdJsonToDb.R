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

#' Persist DQD JSON failures to custom DB tables
#'
#' Write failing check summaries and their violating rows into two tables:
#' - dim_dqd_tests (one row per check)
#' - fact_dqd_violations (one row per violating CDM row)
#'
#' @param connection A DBI/DatabaseConnector connection object
#' @param jsonFilePath Path to DQD results JSON file
#' @param resultsDatabaseSchema Schema to write the tables into
#' @export
writeDqdJsonToCustomTables <- function(connection, jsonFilePath, resultsDatabaseSchema) {
  if (missing(connection) || is.null(connection)) stop("connection is required")
  if (missing(jsonFilePath) || !nzchar(jsonFilePath)) stop("jsonFilePath is required")
  if (missing(resultsDatabaseSchema) || !nzchar(resultsDatabaseSchema)) stop("resultsDatabaseSchema is required")
  if (!requireNamespace("magrittr", quietly = TRUE)) stop("magrittr is required")

  `%>%` <- magrittr::`%>%`

  jsonData <- jsonlite::read_json(jsonFilePath, simplifyVector = FALSE)
  if (is.null(jsonData$CheckResults)) stop("JSON must contain 'CheckResults'")

  # Collect summaries. Each element of CheckResults is either the nested
  # verbose shape (list(summary = ..., violatingRows = ...), as written to
  # *_rowLevelViolations.json) or, if pointed at the standard results.json,
  # a check row directly -- in which case there is no violatingRows data to
  # collect below, since results.json never carries it.
  all_summaries <- list()
  for (check_obj in jsonData$CheckResults) {
    summary_obj <- if (!is.null(check_obj$summary)) check_obj$summary else list(check_obj)
    all_summaries <- c(all_summaries, summary_obj)
  }

  if (length(all_summaries) == 0) {
    tests_df <- data.frame()
  } else {
    tests_df <- dplyr::bind_rows(all_summaries) %>%
      dplyr::mutate(
        check_id = as.character(checkId),
        check_name = as.character(checkName),
        check_level = as.character(checkLevel),
        check_description = as.character(checkDescription),
        category = as.character(category),
        context = as.character(context),
        threshold_value = as.numeric(thresholdValue),
        sql_file = as.character(sqlFile),
        query_text = as.character(queryText),
        table_name = toupper(as.character(cdmTableName)),
        column_name = toupper(as.character(cdmFieldName))
      ) %>%
      dplyr::select(
        check_id, check_name, check_level, check_description,
        category, context, threshold_value, sql_file, query_text,
        table_name, column_name
      ) %>%
      dplyr::distinct()
    tests_df$test_id <- seq_len(nrow(tests_df))
  }

  # Collect violating rows only for failed checks, tag with check_id
  viol_list <- list()
  for (check_obj in jsonData$CheckResults) {
    s <- if (!is.null(check_obj$summary)) check_obj$summary[[1]] else check_obj
    if (!is.null(s) && isTRUE(s$failed == 1) && !is.null(check_obj$violatingRows)) {
      rows <- dplyr::bind_rows(check_obj$violatingRows)
      rows$check_id <- as.character(s$checkId)
      viol_list <- c(viol_list, list(rows))
    }
  }

  if (length(viol_list) > 0) {
    viol_df <- dplyr::bind_rows(viol_list)
    # Join to tests_df by check_id (1:1) to get table_name, column_name and test_id
    if (nrow(tests_df) > 0) {
      viol_df <- dplyr::left_join(viol_df, dplyr::select(tests_df, test_id, check_id, table_name, column_name), by = "check_id")
    } else {
      viol_df$test_id <- NA_integer_
      viol_df$table_name <- NA_character_
      viol_df$column_name <- NA_character_
    }

    viol_df <- viol_df %>%
      dplyr::mutate(
        person_id = if ("personId" %in% names(.)) as.integer(personId) else if ("person_id" %in% names(.)) as.integer(person_id) else NA_integer_,
        visit_occurrence_id = if ("visitOccurrenceId" %in% names(.)) as.integer(visitOccurrenceId) else if ("visit_occurrence_id" %in% names(.)) as.integer(visit_occurrence_id) else NA_integer_,
        domain_occurrence_id = NA_integer_
      )

    # Domain PK mapping (camelCase column names as returned by querySql with snakeCaseToCamelCase=TRUE)
    domain_pk_map <- list(
      "CARE_SITE" = "careSiteId",
      "CONDITION_ERA" = "conditionEraId",
      "CONDITION_OCCURRENCE" = "conditionOccurrenceId",
      "COST" = "costId",
      "DEVICE_EXPOSURE" = "deviceExposureId",
      "DOSE_ERA" = "doseEraId",
      "DRUG_ERA" = "drugEraId",
      "DRUG_EXPOSURE" = "drugExposureId",
      "EPISODE" = "episodeId",
      "LOCATION" = "locationId",
      "MEASUREMENT" = "measurementId",
      "METADATA" = "metadataId",
      "NOTE" = "noteId",
      "NOTE_NLP" = "noteNlpId",
      "OBSERVATION" = "observationId",
      "OBSERVATION_PERIOD" = "observationPeriodId",
      "PAYER_PLAN_PERIOD" = "payerPlanPeriodId",
      "PERSON" = "personId",
      "PROCEDURE_OCCURRENCE" = "procedureOccurrenceId",
      "PROVIDER" = "providerId",
      "SPECIMEN" = "specimenId",
      "VISIT_DETAIL" = "visitDetailId",
      "VISIT_OCCURRENCE" = "visitOccurrenceId"
    )

    for (tbl in names(domain_pk_map)) {
      pk_col <- domain_pk_map[[tbl]]
      if (pk_col %in% names(viol_df)) {
        idx <- which(!is.na(viol_df$table_name) & viol_df$table_name == tbl)
        if (length(idx) > 0) {
          viol_df$domain_occurrence_id[idx] <- as.integer(viol_df[[pk_col]][idx])
        }
      }
    }

    viol_df <- viol_df %>% dplyr::filter(!is.na(test_id))
    viol_df$violation_id <- seq_len(nrow(viol_df))
  } else {
    viol_df <- data.frame()
  }

  # Create schema and tables
  DBI::dbExecute(connection, SqlRender::render("CREATE SCHEMA IF NOT EXISTS @schema;", schema = resultsDatabaseSchema))

  DBI::dbExecute(connection, SqlRender::render(
    "CREATE TABLE IF NOT EXISTS @schema.dim_dqd_tests (
       test_id BIGINT PRIMARY KEY,
       check_id VARCHAR(500) NOT NULL,
       check_name VARCHAR(255) NOT NULL,
       check_level VARCHAR(50),
       check_description TEXT,
       category VARCHAR(100),
       context VARCHAR(100),
       threshold_value FLOAT,
       sql_file VARCHAR(255),
       query_text TEXT
     );",
    schema = resultsDatabaseSchema
  ))

  DBI::dbExecute(connection, SqlRender::render(
    "CREATE TABLE IF NOT EXISTS @schema.fact_dqd_violations (
       violation_id BIGINT PRIMARY KEY,
       test_id BIGINT NOT NULL,
       person_id BIGINT,
       visit_occurrence_id BIGINT,
       domain_occurrence_id BIGINT,
       table_name VARCHAR(255),
       column_name VARCHAR(255),
       CONSTRAINT fk_test_id
         FOREIGN KEY (test_id)
         REFERENCES @schema.dim_dqd_tests(test_id)
         ON DELETE CASCADE
     );",
    schema = resultsDatabaseSchema
  ))

  # Truncate both tables on each run so re-runs replace rather than append.
  # PostgreSQL requires parent/child FK tables to be truncated in one statement.
  DBI::dbExecute(connection, SqlRender::render(
    "TRUNCATE @schema.fact_dqd_violations, @schema.dim_dqd_tests;",
    schema = resultsDatabaseSchema
  ))

  # Insert fresh (IDs start from 1 after truncate — no offset needed)
  if (nrow(tests_df) > 0) {
    DBI::dbWriteTable(connection, DBI::Id(schema = resultsDatabaseSchema, table = "dim_dqd_tests"), tests_df %>% dplyr::select(-table_name, -column_name), append = TRUE)
  }
  if (nrow(viol_df) > 0) {
    DBI::dbWriteTable(connection, DBI::Id(schema = resultsDatabaseSchema, table = "fact_dqd_violations"), viol_df %>% dplyr::select(violation_id, test_id, person_id, visit_occurrence_id, domain_occurrence_id, table_name, column_name), append = TRUE)
  }

  invisible(list(tests = tests_df, violations = viol_df))
}
