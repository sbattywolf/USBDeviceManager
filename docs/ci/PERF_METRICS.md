# CI & Local Performance Metrics (Perf Metrics)

This document describes the methodology used to collect timestamps and durations for test orchestration steps so we can compare local vs CI behavior and track regressions over time.

Goals
- Measure wall-clock times for each major step in the test run: build, server startup/health check, per-suite test execution, E2E wrapper, and TRX merge.
- Produce machine-readable metrics per-run (`metrics.json` and `metrics.csv`) stored alongside TRX artifacts: `artifacts/test-results/<run-id>/`.
- Make metrics collection consistent between local runs and CI (GitHub Actions) so we can compare trends.

What is measured
- Step name: a short identifier (e.g. `Unit tests`, `health_check`, `merge_trx`).
- Start time and end time in ISO-8601 (`Get-Date -Format o`).
- Duration in milliseconds (wall-clock).
- Exit code and an optional note.

Files produced by the instrumentation
- `artifacts/test-results/<run-id>/metrics.csv` — CSV with header: `Step,Start,End,DurationMs,ExitCode,Notes`.
- `artifacts/test-results/<run-id>/metrics.json` — JSON array of objects with fields `Step`, `Start`, `End`, `DurationMs`, `ExitCode`, `Notes`.

How the scripts were instrumented
- `scripts/ci/run_all_tests_sequential.ps1` — now records start/end and durations for each suite (`Unit`, `Integration`, `Functional`, `Regression`), the E2E wrapper invocation and the TRX merge step. It aggregates metrics into `$metrics` and writes `metrics.csv` and `metrics.json` at the end of the run.
- `scripts/ci/run_e2e_selfhost.ps1` — accepts optional `-MetricsFile` parameter and appends metrics for the health check, build and AgentE2E test execution into that CSV.
- `scripts/ci/smoke_health_check.ps1` — accepts optional `-MetricsFile` parameter and appends a `health_check` line when it succeeds or times out.

Example: run locally (recommended)

PowerShell (dry-run):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ci\run_all_tests_sequential.ps1 -RunId manual_run_YYYYMMDD_HHMMSS -DryRun
```

Real run (local or CI):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ci\run_all_tests_sequential.ps1 -RunId manual_run_YYYYMMDD_HHMMSS
```

After a real run, check the run folder:
- `artifacts/test-results/manual_run_YYYYMMDD_HHMMSS/metrics.csv`
- `artifacts/test-results/manual_run_YYYYMMDD_HHMMSS/metrics.json`

CI Integration
- Add steps to the GitHub Actions workflows that run the sequential script and upload `artifacts/test-results/<run-id>/metrics.csv` and `metrics.json` as job artifacts.
- Optionally add a separate GitHub Action job to aggregate metrics across runs and persist them in a simple time-series store or push to an external dashboard.

Next steps / suggestions
- Add more granular instrumentation inside long-running tests or server start code if you want method-level timings.
- Add a small Python or PowerShell aggregator that downloads metrics artifacts from Actions runs and produces trend charts (CSV -> plotly/matplotlib).
- Consider publishing a periodic benchmark job that runs the suites on a stable VM to build a performance baseline.

Contact
- For changes to the metric schema or additional metrics to capture, update the scripts under `scripts/ci/` and this doc.
