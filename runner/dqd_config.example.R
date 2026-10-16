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

# Central runtime configuration for the local DQD runner.
#
# Copy this file to dqd_config.R (same folder) and fill in your own values.
# dqd_config.R is gitignored so real credentials/host/schema names never get
# committed. Edit that copy when moving between databases, schemas, or
# output locations -- the runner scripts read these values instead of
# requiring code edits.

list(
  # Used by runner/setup.R only. Leave NULL to install this repository package.
  packagePath = NULL,

  connection = list(
    dbms = "postgresql",
    user = Sys.getenv("DQD_DB_USER", ""),
    password = Sys.getenv("DQD_DB_PASSWORD", ""),
    server = Sys.getenv("DQD_DB_SERVER", "your_host/your_database"),
    port = as.integer(Sys.getenv("DQD_DB_PORT", "5432")),
    pathToDriver = Sys.getenv("DQD_JDBC_DRIVER_PATH", "~/jdbc_drivers")
  ),

  schemas = list(
    cdm = Sys.getenv("DQD_CDM_SCHEMA", "your_cdm_schema"),
    results = Sys.getenv("DQD_RESULTS_SCHEMA", "your_results_schema"),
    vocab = Sys.getenv("DQD_VOCAB_SCHEMA", "your_vocab_schema")
  ),

  cdmSourceName = Sys.getenv("DQD_CDM_SOURCE_NAME", "your_cdm_source_name"),
  cdmVersion = "5.4",

  execution = list(
    numThreads = 1,
    sqlOnly = FALSE,
    sqlOnlyIncrementalInsert = FALSE,
    sqlOnlyUnionCount = 1,
    verboseMode = TRUE,
    verboseOutput = TRUE,
    writeToTable = TRUE,
    writeTableName = "dqd_whole_results",
    writeToCsv = FALSE,
    csvFile = "",
    outputFolder = "output/dqd_output",
    outputFile = "results.json",
    checkLevels = c("TABLE", "FIELD", "CONCEPT")
  ),

  checkNames = c(
    "plausibleGender",
    "plausibleGenderUseDescendants",
    "plausibleUnitConceptIds",
    "cdmDatatype",
    "standardConceptRecordCompleteness",
    "sourceConceptRecordCompleteness",
    "fkClass",
    "fkDomain",
    "isPrimaryKey",
    "measureValueCompleteness",
    "plausibleAfterBirth",
    "plausibleBeforeDeath",
    "plausibleDuringLife",
    "plausibleStartBeforeEnd",
    "plausibleTemporalAfter",
    "withinVisitDates",
    "isForeignKey"
  ),

  # Standard OMOP vocabulary/reference tables: static reference data, not
  # patient data, so row-level DQ checks generally aren't meaningful against
  # them. Reasonable defaults for most CDM installs -- add to this list for
  # any other tables specific to your own deployment.
  tablesToExclude = c(
    "CONCEPT", "VOCABULARY", "CONCEPT_ANCESTOR", "CONCEPT_RELATIONSHIP",
    "CONCEPT_CLASS", "CONCEPT_SYNONYM", "RELATIONSHIP", "DOMAIN", "DRUG_STRENGTH"
  ),

  # Field-level exclusions tend to be specific to what a given dataset does
  # or doesn't populate. No general defaults are shipped here -- decide
  # this list based on your own CDM's known gaps.
  fieldsToExclude = c(),

  persistViolations = TRUE
)
