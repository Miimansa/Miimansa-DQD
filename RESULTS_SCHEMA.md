# DQD Results Output Schema

This documents the schema decisions made for `executeDqChecks()` output, applicable
whether `verboseOutput` is `FALSE` (default) or `TRUE`.

## `results.json` — standard schema (always, regardless of `verboseOutput`)

This is the single, stable, public contract. It is unchanged from the
long-standing non-verbose DQD schema and is what the Shiny viewer
(`inst/shinyApps`, `loadResults.js`), `writeJsonResultsToCsv()`, and
`writeJsonResultsToTable()` all assume.

```
{
  "startTimestamp": ...,
  "endTimestamp": ...,
  "executionTime": ...,
  "executionTimeSeconds": ...,
  "CheckResults": [
    {
      "checkId": ...,
      "checkName": ...,
      "checkLevel": ...,
      "checkDescription": ...,
      "cdmTableName": ...,
      "cdmFieldName": ...,
      "conceptId": ...,
      "unitConceptId": ...,
      "numViolatedRows": ...,
      "pctViolatedRows": ...,
      "numDenominatorRows": ...,
      "failed": ...,
      "passed": ...,
      "isError": ...,
      "notApplicable": ...,
      "notApplicableReason": ...,
      "thresholdValue": ...,
      "notesValue": ...,
      "executionTime": ...,
      "queryText": ...,
      "error": ...,
      "warning": ...,
      ...
    },
    ...
  ],
  "Metadata": [...],
  "Overview": {...}
}
```

`CheckResults` is a **flat array** — every element is a check result row
directly (no nesting). It **never** contains a `violatingRows` field, in
verbose mode or otherwise. Row-level data is not part of this file, by
design (see below).

## `<outputFile>_rowLevelViolations.json` — verbose-only, row-level detail

Written only when `verboseOutput = TRUE`, in the same `outputFolder` as
`results.json`, named after it (e.g. `synthea-20260922103000.json` ->
`synthea-20260922103000_rowLevelViolations.json`).

```
{
  "startTimestamp": ...,
  "endTimestamp": ...,
  "executionTime": ...,
  "executionTimeSeconds": ...,
  "CheckResults": [
    {
      "summary": [ { <same fields as a results.json row> } ],
      "violatingRows": [ { <row-level CDM data> }, ... ]   // present only for failed checks
    },
    ...
  ],
  "Metadata": [...],
  "Overview": {...}
}
```

This is the **only** artifact that ever carries row-level (patient-level)
data, and it is only intended to be consumed by
`writeDqdJsonToCustomTables()` to populate the `dim_dqd_tests` /
`fact_dqd_violations` database tables. It is not consumed by the Shiny
viewer, `writeJsonResultsToCsv()`, or `writeJsonResultsToTable()`.

## Rationale

- **One stable public schema.** `results.json` keeps the exact shape every
  existing consumer (viewer, CSV export, table export) already expects,
  regardless of whether the run was verbose. No new schema variants, no new
  parameters to learn.
- **Row-level data never leaves the row-level file.** Patient-level data is
  never written into the standard, more freely shared `results.json`. It
  only exists in `_rowLevelViolations.json` and, ultimately, the database
  tables written by `writeDqdJsonToCustomTables()`.
- **`writeDqdJsonToCustomTables()` works against either file.** It has been
  made tolerant of both shapes: pointed at `_rowLevelViolations.json` it
  behaves exactly as before (populates both `dim_dqd_tests` and
  `fact_dqd_violations`); pointed at the standard `results.json` it still
  populates `dim_dqd_tests` (check metadata) but finds no violating rows to
  write, which is correct since `results.json` never carries them.
