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

CI job naming
- The integration workflow now includes a final analysis job named `Integration Test & Analysis` (workflow job id `integration-test-analysis`). This job downloads integration artifacts, generates the HTML/text reports, and uploads them as `integration-report` artifacts. Use that job name when looking for the report in the GitHub Actions UI.
```

Troubleshooting notes

- If you see "A parameter cannot be found that matches parameter name 'or'" when the CI invokes `start-server-and-wait.ps1`, ensure the called script accepts the switches passed by CI (for example `-NonInteractive`) and that the invocation uses `-File` or `-Command` consistently. A missing parameter in the script signature is a common cause.
- Use the new integration-only GitHub Action to reproduce CI behavior locally: see [/.github/workflows/integration-only.yml](.github/workflows/integration-only.yml).
