CI artifacts contract
=====================

Purpose
-------
This document specifies the CI artifact layout the repository expects and the aggregator inputs.

Artifact locations
------------------
- Per-job test results: `artifacts/test-results/` — workflows must write VSTest TRX files here.
- Per-job TRX filename: any name, but workflows should include a `.trx` file per `dotnet test` invocation.
- Per-job skip info: `artifacts/test-results/skip-info.json` (optional) — contains counts for skipped tests and reasons.

Uploader behavior
-----------------
- Workflows running `dotnet test` should pass: `--logger "trx;LogFileName=<name>.trx" --results-directory ./artifacts/test-results`.
- Always upload the `artifacts/test-results` folder (use `if: always()` in upload steps) so failures still produce diagnostics.

Aggregator
----------
- The aggregator merges all TRX files found under `artifacts/test-results` into `artifacts/test-results/all-tests.trx`.
- The aggregator also sums `<Counters>` and merges any `skip-info.json` counters into the merged output.

Opt-in logs
-----------
- When `collect_ci_logs` is enabled, workflows may write additional logs under `artifacts/ci-logs/<job-name>/` and upload that folder.

Notes
-----
- Use consistent results-directory usage across workflows to ensure the aggregator finds all per-job TRX files.
- The canonical merged TRX is `artifacts/test-results/all-tests.trx` and should be produced by a dedicated merge job before publishing artifacts for reviewers.
