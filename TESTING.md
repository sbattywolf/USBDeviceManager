TESTING — Repro and artifact triage

Purpose
- Document how to run the gated DB-delete/lock repro locally and where artifacts are written for triage.

Environment toggles
- `RUN_DB_REPRO=1`
  - Enables the gated repro behavior in tests and causes `SimRacingTestFactory` to prefer repo-local artifacts and preserve DB files.
- `SIMRACING_DEBUG_DBPATH`
  - Optional override for the DB path used by the tests. When set, the factory will use this path for the DB file.

Repro: run the single gated test (Windows PowerShell)

```powershell
set "RUN_DB_REPRO=1"
# optional: set "SIMRACING_DEBUG_DBPATH=server/USBDeviceManager.Tests/TestResults/artifacts/SimRacingTest_debug.db"
dotnet test server/USBDeviceManager.Tests/USBDeviceManager.Tests.csproj --filter DisplayName~Repro_DbDeleteLock_Local -v minimal
```

Local cleanup (recommended)

Before running the repro ensure no prior test hosts are running and stop them after the run completes:

```powershell
# Stop any running dotnet test hosts
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\stop-dotnet.ps1

# Run the repro (example below)
set "RUN_DB_REPRO=1"
dotnet test server/USBDeviceManager.Tests/USBDeviceManager.Tests.csproj --filter DisplayName~Repro_DbDeleteLock_Local -v minimal

# Ensure cleanup after the test
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\stop-dotnet.ps1
```

Expected artifacts (local runs)
- Repo-level artifacts directory (already created by `SimRacingTestFactory`):
  - `server/USBDeviceManager.Tests/TestResults/artifacts/`
    - `* -dbpath.txt` : recorded DB path seen by the factory
    - `* -db-sample.bin` : small sample copy of the DB file produced during the run
    - `* -server-console.log` : captured console output from the test host (when present)
    - `* -delete-diagnostics.txt` : delete diagnostics if a delete attempt failed
- Runtime/bin artifacts (when tests run in a different working directory):
  - `server/**/bin/**/TestResults/artifacts/**`

CI behavior
- The CI workflow now uploads the test DB artifacts under the artifact name `test-db-artifacts-<run>-<job>-<os>`.
  - This includes `server/USBDeviceManager.Tests/TestResults/artifacts/**` and `server/**/bin/**/TestResults/artifacts/**` so triage artifacts should be available from failed runs.

Quick triage steps
1. Re-run the repro locally (see commands above).
2. Inspect the repo artifacts folder: `server/USBDeviceManager.Tests/TestResults/artifacts/`.
3. If present, run the helper `scripts/inspect-repro-artifacts.ps1` to show headers and log excerpts (if present).
4. Upload artifacts from CI run and inspect the `* -db-sample.bin` and `* -delete-diagnostics.txt` files to determine lock sources or partial-write symptoms.

Notes and next steps
- There is a long-term plan to centralize artifact helpers and add a CI job that runs the gated repro automatically on failures; see `docs/TODOs-actionable.md` for details.

- If you want me to also add a short validation unit test to assert the factory-created DB is valid, I can add that next.

Integration tests (non-interactive)

To run the integration test harness locally (this starts the server, waits for readiness, runs integration tests, and preserves DB on failure):

```powershell
# Stop any stray dotnet processes first to avoid port or file-lock issues
pwsh ./scripts/stop-dotnet.ps1

# Run the integration test wrapper (non-interactive). Adjust Port/DbPath as needed.
pwsh ./scripts/run-integration-noninteractive.ps1 -Port 5010 -NonInteractive

# Check artifacts and logs:
# - scripts/tmp/server.log
# - scripts/tmp/server.err.log
# - artifacts/integration.trx


Cleanup behavior

- The integration wrapper now guarantees cleanup: `scripts/run-integration-noninteractive.ps1` calls `scripts/ensure-server-stopped.ps1` in a `finally` block so the server process is stopped at the end of the run (unless you pass `-NoStop`).
- To explicitly skip automatic stop (for manual post-run inspection), pass `-NoStop` to the wrapper. When `-NoStop` is used you must stop the server manually, for example:

```powershell
# Manually stop the recorded server pid
Stop-Process -Id <pid> -ErrorAction SilentlyContinue

# Or use the helper (preferred)
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ensure-server-stopped.ps1
```

DB preservation on failures

- When tests fail the wrapper attempts to preserve the test DB into `artifacts/ci-local-simracing-on-failure.*.db`. If a strict copy fails due to locks, it will attempt a best-effort fallback copy. To force preservation even when tests pass, run the wrapper and then copy the DB path in `SIMRACING_DEBUG_DBPATH` yourself.
CI job naming
- The integration workflow now includes a final analysis job named `Integration Test & Analysis` (workflow job id `integration-test-analysis`). This job downloads integration artifacts, generates the HTML/text reports, and uploads them as `integration-report` artifacts. Use that job name when looking for the report in the GitHub Actions UI.
  
  The analysis job now produces a small, triage-focused bundle by default named `artifacts/integration-report-triage.zip` to avoid creating large full archives every run. This triage bundle contains test TRX, preserved DB snapshots, key logs, and the `publish-sentinel` capture when present.

  When a full forensic bundle is explicitly required (for offline deep-dive), set the environment variable `FULL_INTEGRATION_ARCHIVE=1` in the CI analysis job; this will produce `artifacts/integration-report-full.zip` containing the full artifacts tree.

  Note: the previous automatic trimming workflow (`TRIM_INTEGRATION_LOGS`) is deprecated for CI runs. `scripts/trim-integration-logs.ps1` remains available for manual, local trimming, but it is not run by default in CI.

Test dispatch & job naming
- **Recommended job id:** `test-runner` — a concise, clear identifier for the CI job that dispatches selected test suites.
- **Display name used in CI:** `Test Suite Runner (dispatch)` (this job calls the reusable `test-runner-dispatch.yml`).
- **Run via GitHub UI:** Use the `CI` workflow's run view and select the `Test Suite Runner (dispatch)` job when triggering `workflow_dispatch`.
- **Run via gh CLI (example):**

```bash
# Run unit + integration (same as CI defaults)
gh workflow run CI --ref main --field run_unit=true --field run_integration=true

# Run only unit tests
gh workflow run CI --ref main --field run_unit=true --field run_integration=false --field run_e2e=false

# Run full (all suites)
gh workflow run CI --ref main --field full=true
```
```

Troubleshooting notes

- If you see "A parameter cannot be found that matches parameter name 'or'" when the CI invokes `start-server-and-wait.ps1`, ensure the called script accepts the switches passed by CI (for example `-NonInteractive`) and that the invocation uses `-File` or `-Command` consistently. A missing parameter in the script signature is a common cause.
- Use the new integration-only GitHub Action to reproduce CI behavior locally: see [/.github/workflows/integration-only.yml](.github/workflows/integration-only.yml).

## CI Forensics & Cleanup (added 2026-01-25)

- **When to run cleanup:** Before large local CI runs or when disk space drops below ~30% on the artifacts drive. Run `scripts/cleanup-old-artifacts.ps1` or remove old `artifacts/publish-*` snapshots.
- **Where preserved DBs are stored:** `artifacts/ci-local-dbs-on-failure/` (also fallback: `D:\temp-preserve-dbs` when E: is full).
- **If server fails to start with runtime errors:** check `artifacts/server.err.log` and `artifacts/publish-sentinel.txt` for publish layout and runtime-missing captures.
- **Recording investigations:** Add a short forensic note to `docs/diagnostics/ci-forensics-YYYY-MM-DD.md` with run-IDs and preserved artifact paths.

I will keep these diagnostic notes updated after each investigation.

## Interactive menu tests (mock-mode)

We added a CI-safe harness for the interactive `scripts/process-menu.ps1` menu that runs in `mock` mode
and emits marker files so automated runners can assert behavior without launching real processes.

Quick run (mock-mode, CI-safe):

```powershell
# Run server auto-action then agent auto-action, generate pid files from marker, and assert both
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ci\run_process_menu_once.ps1 -Action 2
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ci\run_process_menu_once.ps1 -Action 6
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ci\make_pids_from_marker.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ci\assert_process_menu_mock_results.ps1 -Role both
```

Useful files:
- `scripts/ci/run_process_menu_mock_capture.ps1` — wrapper that runs `process-menu` once and prints escaped markers; useful for log capture.
- `scripts/ci/run_process_menu_once.ps1` — run `process-menu` with a single auto-action (`-Action 2`=server, `-Action 6`=agent).
- `scripts/ci/make_pids_from_marker.ps1` — parse the marker file and produce `scripts/ci/mock_server.pid` and `scripts/ci/mock_agent.pid`.
- `scripts/ci/assert_process_menu_mock_results.ps1` — CI assertion script; exits non-zero if expected marker/pid files are missing or malformed.

CI integration suggestion:
- Add a job step that runs the above sequence and uploads `scripts/ci/process-menu-mock-run.log` and `scripts/ci/process-menu-run.marker` as artifacts.

