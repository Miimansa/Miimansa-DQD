For Developers
==============

This page explains the local changes made around the DQD runner and custom result persistence.

Local Architecture
==================

The local customization has three layers:

* Installation/bootstrap lives in `runner/setup.R`.
* Runtime orchestration lives in `runner/run_dqd.R`.
* Environment-specific values live in `runner/dqd_config.R`.
* Package functionality lives under `R/`, especially `executeDqChecks()` and `writeDqdJsonToCustomTables()`.

Changed Files
=============

* `runner/dqd_config.R`: central config file for package path, database details, schema names, CDM metadata, output location, included checks, excluded tables, excluded fields, and persistence toggle. Gitignored; never committed.
* `runner/dqd_config.example.R`: sanitized template for `runner/dqd_config.R`, with placeholders and environment-variable reads in place of real credentials/host/schema names.
* `runner/setup.R`: first-time setup script. It installs missing R packages, installs the local package, creates the JDBC driver directory, and can download the configured JDBC driver.
* `runner/run_dqd.R`: config-driven runtime script. It checks that dependencies are already installed, performs the connection smoke test, optional custom threshold generation, DQD execution, and optional violation persistence.
* `runner/smoke_test_viewer.R`: manual smoke test that opens a generated `results.json` in the Shiny dashboard.
* `R/executeDqChecks.R`: writes the standard flat `results.json` and, when `verboseOutput = TRUE`, a paired row-level file via the shared `rowLevelViolationsFileName()` helper.
* `R/writeDqdJsonToDb.R`: canonical package function for writing failed checks and violating rows into custom tables; tolerant of both the standard and row-level file shapes.
* `RESULTS_SCHEMA.md`: field-by-field schema for `results.json` and `<name>_rowLevelViolations.json`, and the reasoning behind the split.
* `tests/testthat/test-resultsJsonSchema.R`, `tests/testthat/test-viewerFields.R`: regression coverage for the schema split and viewer-field compatibility.
* `analysis/` and `to_run/`: removed to avoid duplicate/conflicting runner entrypoints.
* `initial.R`: no longer used. The supported entrypoint is `runner/run_dqd.R`.

Execution Flow
==============

`runner/setup.R` is intended for first-time setup:

1. Loads `runner/dqd_config.R`.
2. Installs missing R packages required by the local runner.
3. Installs the local DataQualityDashboard package.
4. Creates the configured JDBC driver directory.
5. Downloads the configured JDBC driver unless `DQD_DOWNLOAD_JDBC` disables it.

Any failure here should be treated as an installation/bootstrap issue. Do not debug database schemas or DQD check logic until setup succeeds.

`runner/run_dqd.R` does the following:

1. Loads `runner/dqd_config.R`.
2. Verifies required packages are already installed.
3. Creates `DatabaseConnector` connection details.
4. Verifies the configured CDM schema by querying `<cdm schema>.PERSON`.
5. Builds custom field/concept threshold CSVs when `fieldsToExclude` is populated.
6. Calls `DataQualityDashboard::executeDqChecks()`.
7. Writes the normal DQD JSON output.
8. Calls `writeDqdJsonToCustomTables()` when `persistViolations = TRUE`.

The runner intentionally does not install or update packages. Any failure here after setup succeeds should be treated as a runtime issue: config, credentials, schemas, source tables, DQD execution, JSON writing, or DB persistence.

Custom Result Tables
====================

`writeDqdJsonToCustomTables()` reads `CheckResults` from a results JSON file and writes two tables:

* `dim_dqd_tests`: one row per check summary.
* `fact_dqd_violations`: one row per violating CDM row for failed checks.

Point it at `<name>_rowLevelViolations.json` (written alongside `results.json` when `verboseOutput = TRUE`) to populate both tables. It also tolerates being pointed at the standard `results.json` -- `dim_dqd_tests` still gets populated, but `fact_dqd_violations` will have zero rows, since `results.json` never carries row-level data by design.

For the full shape of both files, see [`RESULTS_SCHEMA.md`](RESULTS_SCHEMA.md).

Important implementation details:

* Check summaries are flattened first so each result has a stable `check_id`.
* Violating rows are joined back to tests by `check_id`, not just table and column. This avoids cross-linking checks that share the same table and field.
* `person_id` and `visit_occurrence_id` are copied when present in the violating rows.
* `domain_occurrence_id` is derived from the OMOP table primary key when that primary key is present in the violating row.
* The package implementation truncates `fact_dqd_violations` and `dim_dqd_tests` before inserting fresh results, so reruns replace the custom result tables.

Operational Notes
=================

* `tablesToExclude` replaces the package default, so vocabulary tables must remain in the vector if they should not be checked.
* `fieldsToExclude` removes every threshold row matching those field names from both field-level and concept-level CSVs.
* `verboseOutput = TRUE` is required for row-level violating rows to be captured at all; they are written only to the paired `<name>_rowLevelViolations.json` file, never to `results.json`.
* `pathToDriver` must point to the JDBC driver directory used by `DatabaseConnector`.
* Passwords should come from `DQD_DB_PASSWORD`; avoid committing credentials in `runner/dqd_config.R`.
