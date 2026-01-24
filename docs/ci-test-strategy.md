CI Test Strategy and Recent Fixes

Summary
- Fixed CI script errors: prevented TRX self-copy and repaired malformed PowerShell interpolation.
- Published LongRunner as a self-contained Windows `win-x64` exe and prefer exe in `SHELLRUNNER_LONG_CMD`.
- Added job-level artifact uploads so parser errors / logs are always available.
- Fixed `scripts/start-server-and-wait.ps1` PowerShell env lookup to avoid ParserError.
- Fixed `LogsController.Post` to persist `UsbDevice` before inserting `DeviceStatus` to avoid FK race.

Reproduction (local)
1. Run server locally: `dotnet run --project server/USBDeviceManager --urls http://127.0.0.1:5000`
2. Reproduce FK race: send concurrent POSTs to `/api/logs` (payload: `{ deviceId, eventType:"CONNECTED", message }`).
3. Inspect server logs: `server/USBDeviceManager/logs/server.out.log` and `server.err.log`.

CI changes applied
- `.github/workflows/ci.yml` updated to:
  - Publish `LongRunner` as self-contained `win-x64` exe on Windows runners.
  - Prefer the exe path when setting `SHELLRUNNER_LONG_CMD`.
  - Upload job logs and artifacts (TRX/html) on every run.
- `scripts/start-server-and-wait.ps1` parser issue fixed.
- `LogsController` patched to persist devices before statuses (reduces FK races).

Recommended CI hardening (next steps)
- Ensure DB schema present before tests run: add a job step to apply migrations or run `dotnet ef database update` (or `EnsureCreated`) in the test job prior to starting the server.
- Increase EF diagnostics logging and capture parameterized SQL for failing requests.
- Make the long-run helper publishing explicit for all OSes if tests depend on it.
- Keep `job-logs-<run>` artifact naming and include `server_out.txt`/`server_err.txt` for fast triage.

Test strategy
- Keep unit tests in isolated jobs; run integration/regression in separate matrix entries (Windows/Linux) using the published artifacts and the same initialization steps.
- Run e2e in a controlled job that ensures server health before test start and includes retry/backoff.
- After CI run, parse TRX with `scripts/ci-analyze.py` and collect `tests-summary.json` for quick triage.

How I validated
- Ran concurrent POSTs locally to confirm the FK race no longer reproduces after the `LogsController` fix.
- Downloaded CI artifacts for the recent run and verified `tests-summary.json` is generated.

Next actions
- Add CI DB initialization step + EF logging, re-run CI, analyze artifacts, and finalize remaining integration fixes.

