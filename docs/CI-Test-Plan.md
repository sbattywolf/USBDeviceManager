# CI Test Plan & Improvements

Summary
- Goal: make CI failures reproducible locally and prevent regressions that cause intermittent 404s and database FK errors.
- Approach: improve tests (add stress + concurrency scenarios), improve diagnostics and test-run reporting, and update CI jobs to always collect server logs and artifacts needed for triage.

Proposed test additions
- Heartbeat stress test: repeated POSTs of legacy heartbeat payloads to exercise logging path and DB writes.
- Concurrent load test: small concurrent request bursts against frequently-used endpoints to reveal race conditions.
- DB-robustness tests: operations that intentionally create optional/missing device entries to verify `DeviceStatus` and FK handling.
- Start/stop lifecycle test: repeatedly start and stop the WebApplicationFactory host to reveal shutdown/Dispose races.

Diagnostics & reporting improvements
- Capture server `stdout`/`stderr` (host logs) for every test run and include in TRX artifact folder.
- Enable more verbose logging in `appsettings.Testing.json` for `Microsoft.EntityFrameworkCore` and `USBDeviceManager.*` during CI runs.
- On test failure, upload the current SQLite DB file (if in-process) and a short DB dump (schema + last 100 rows from key tables).
- Add structured request/response capture for failing tests (small JSON with URL, method, status, response body snippet).
- Ensure `scripts/extract-failures.ps1` (or equivalent) greps logs/artifacts for EF/SQLite exceptions and highlights them in enriched outputs.

CI workflow changes
- Always publish `server-log-<os>.zip` containing `server.log` and `server.err.log` for integration jobs.
- Add an artifact `db-dumps` when tests run with SQLite in-process.
- Add a step to the test job to convert TRX -> HTML summary and upload alongside raw TRX.

Test runner changes
- Modify the test fixture (`SimRacingTestFactory`) to write host logs into a deterministic file under the test results folder when `ASPNETCORE_ENVIRONMENT=Testing`.
- Add a toggle to optionally enable request/response capture for a test via an attribute or test fixture configuration.

Implementation plan (high level)
1. Add `docs/CI-Test-Plan.md` (this document).
2. Update `scripts/extract-failures.ps1` to search server logs and DB dumps for EF/SQLite errors and include excerpts.
3. Modify `SimRacingTestFactory` to write host logs to TestResults/artifacts and include a compact request/response capture.
4. Add a new integration test `HeartbeatStressTests` (short by default) and add CI job matrix entry to run longer stress runs in nightly or gateway jobs.
5. Update CI workflow to upload server logs, DB dumps and TRX->HTML summaries.
6. Run stress tests locally; collect TRX and artifacts; iterate on diagnostics.

Notes and rationale
- The CI artifacts in the previous run showed empty server logs. Ensuring the test host writes logs to disk and CI uploads them will make triage possible.
- Small targeted tests (stress + concurrency) are cheaper than full E2E and help catch race conditions that only appear under concurrency.
- Capturing DB dumps on failure is small overhead but invaluable when diagnosing FK/constraint failures.

Files/places to change (suggested)
- `server/USBDeviceManager.Tests/Fixtures/SimRacingTestFactory.cs` — add file logging and optional request capture.
- `server/USBDeviceManager.Tests/Functional/HeartbeatStressTests.cs` — new test.
- `scripts/extract-failures.ps1` — enrich extraction rules.
- `.github/workflows/ci.yml` (or relevant workflow) — upload `server-log-*.zip` and `db-dumps` artifacts, add TRX->HTML step.
- `appsettings.Testing.json` — increase log level for EF and app namespaces in CI only.

Acceptance criteria
- CI jobs always produce server logs and TRX->HTML artifacts for failed integration jobs.
- New stress/concurrency tests run locally and in CI (short runs in PR, extended in nightly), and reproduce any CI-only race conditions when they exist.
- Diagnostics (server logs + DB dumps + request captures) are attached to artifacts on failure.

Next steps
- I'll update the tracked todo list with concrete implementation items and start by adding a small host-logging change to the test fixture so logs are written to disk during tests.
