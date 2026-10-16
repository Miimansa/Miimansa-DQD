# Security Policy

## Reporting a vulnerability

Please do not report security vulnerabilities through public GitHub issues.

Email **ribhu.lahiri@miimansa.com** instead, with:

- a description of the issue and its impact
- steps to reproduce it, or a proof of concept
- the version or commit you tested against

We will acknowledge your report and keep you updated while we work on a fix.

## Patient data and credentials

This package runs against clinical databases, and with `verboseOutput = TRUE` it
writes row-level (patient-level) records to `<name>_rowLevelViolations.json`.

- Never attach `results.json`, `_rowLevelViolations.json`, logs, screenshots or
  database dumps containing real patient data to an issue, pull request or email.
  Use synthetic data (for example [Eunomia](https://github.com/OHDSI/Eunomia))
  to reproduce problems.
- Never commit `runner/dqd_config.R` or any file containing database credentials.
  It is gitignored for that reason; pass credentials through the environment
  variables described in the README.

If you think patient data or credentials have been published in this repository,
email the address above straight away.
