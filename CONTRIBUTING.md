# Contributing to Miimansa DQD

Thanks for your interest in contributing. This repository is Miimansa's fork of
[OHDSI DataQualityDashboard](https://github.com/OHDSI/DataQualityDashboard).
It adds row-level traceability for failed checks.

## Where to raise what

- **Bugs or features in the row-level traceability work** (verbose output,
  `_rowLevelViolations.json`, `writeDqdJsonToCustomTables()`, the `runner/`
  scripts): open an issue in this repository.
- **Bugs in the core checks or the dashboard that also happen in upstream
  DataQualityDashboard:** please report them to
  [OHDSI](https://github.com/OHDSI/DataQualityDashboard/issues), so every user
  gets the fix.

## Pull requests

1. Open an issue first for anything beyond a small fix, so we can agree on the
   approach before you spend time on it.
2. Branch from `main` and open your pull request against `main`.
3. Keep the pull request focused on one change.
4. Add or update tests in `tests/testthat/` for new behaviour.
5. Make sure `R CMD check` passes without errors or warnings.
6. Follow the existing code style, which is the
   [OHDSI code style](https://ohdsi.github.io/Hades/codeStyle.html).

## Data and credentials

Never include real patient data or database credentials in issues, pull
requests, tests or fixtures. Use synthetic data such as
[Eunomia](https://github.com/OHDSI/Eunomia). See [SECURITY.md](SECURITY.md).

## Code of conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). By
taking part you agree to follow it.

## License

By contributing, you agree that your contributions will be licensed under the
[Apache License 2.0](LICENSE).
