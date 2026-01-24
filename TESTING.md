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
- There is a long-term plan to centralize artifact helpers and add a CI job that runs the gated repro automatically on failures; see the repository TODO for details.
- There is a long-term plan to centralize artifact helpers and add a CI job that runs the gated repro automatically on failures; see `docs/TODOs-actionable.md` for details.

- If you want me to also add a short validation unit test to assert the factory-created DB is valid, I can add that next.
