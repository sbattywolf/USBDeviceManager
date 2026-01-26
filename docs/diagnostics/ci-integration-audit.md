# CI & Local Integration Audit — Summary (2026-01-25)

Scope: collect failures impacting server startup and Windows integration test flakiness. Focus: server readiness, test helpers, and DB locking observed in recent runs.

Key findings

- LongRunner missing on Windows
  - Several unit tests fail when trying to launch `artifacts/longrunner/win-x64/LongRunner.exe` (System.ComponentModel.Win32Exception: file not found). See `tests-summary.txt` and `tests-summary.json` messages reporting missing LongRunner and ShellRunner failures.

- Temporary DB locked by other process
  - Multiple TRX files show `SimRacingTestFactory: failed to delete temp DB on dispose` with `System.IO.IOException: The process cannot access the file ... because it is being used by another process.` This indicates test or server processes still have handles to temp DB files when cleanup runs. Affected files: `test-results/*.trx`, `test-results/integration.trx`.

- Server startup / readiness fragility
  - `scripts/start-server-and-wait.ps1` sometimes reports the server process exited early or timeout waiting for health. Polling reads or readiness marker absence can produce `Server did not become healthy` or `No explicit readiness marker found` messages in CI logs.
  - In test artifacts there are successful "Now listening on" markers, but intermittent runs show health timeouts leading to test failures.

- EF/SQL debug logging partially configured
  - Workflow sets `EF_SQL_LOG_FILE` and logging envs; ensure Windows runners actually write the file path used in CI (`scripts/tmp/ef.log`) and that logs are uploaded on failure.

- CI env/tool differences
  - Windows runners may lack `pwsh` or the published LongRunner exe; scripts fall back to `powershell` or `dotnet` DLL runs. Missing artifacts or different PATHs cause inconsistent behavior.

Representative log excerpts

- Missing LongRunner error (tests-summary.json):

  "Actual:   typeof(System.ComponentModel.Win32Exception)\n---- System.ComponentModel.Win32Exception : An error occurred trying to start process '.\\artifacts\\longrunner\\win-x64\\LongRunner.exe' ... Impossibile trovare il file specificato."

- Temp DB locked (integration.trx):

  "SimRacingTestFactory: failed to delete temp DB on dispose 'C:\\Users\\...\\Temp\\SimRacingTest_20260119111141_28052.db': System.IO.IOException: The process cannot access the file ... because it is being used by another process."

- Server readiness marker present in some artifacts (example):

  "Now listening on: http://localhost:5000"

Immediate recommendations (short-term)

1. Ensure `artifacts/longrunner/win-x64/LongRunner.exe` is produced on Windows runners (fix publish step or provide fallback). Add an assert step that fails early with a clear error if missing.
2. Add safe file-handle wait/retry before deleting temp DBs in test teardown, and audit tests that might keep DB open (ensure proper disposal of DbContext/streams). Consider using unique DB filenames per test and explicit GC/WaitForPendingFinalizers in teardown if necessary.
3. Make `start-server-and-wait.ps1` more defensive: increase readiness marker wait, add alternative markers, and capture full stdout/stderr on early exit. Consider increasing default health timeouts on Windows CI.
4. Confirm EF debug log location is writable on Windows runners and ensure CI uploads `scripts/tmp/ef.log` when tests fail.
5. Add a local helper `scripts/local-run-all.ps1` that reproduces CI sequence so devs can iterate locally.

Next steps I will take (with priority)

- (P0) Add immediate check for LongRunner artifact in CI and local publish step. 
- (P0) Implement safe DB copy/wait before deletion in test teardown or test factory cleanup.
- (P1) Harden server start+poll scripts (`start-server-and-wait.ps1`, `poll-health.ps1`) and increase timeouts for Windows.
- (P1) Verify EF log capture and CI artifact upload on failure.

Files inspected

- `.github/workflows/ci.yml`
- `scripts/start-server-and-wait.ps1`
- `scripts/poll-health.ps1`
- `scripts/run-integration-noninteractive.ps1`
- `tests-summary.txt`, `tests-summary.json`, `test-results/*.trx`
- `run-*.log` files in repo root

If you want, I can: (A) implement the LongRunner publish/assert fix in CI and local publish, (B) add safe DB deletion waits and a failing-fast check for open handles, or (C) harden the server start scripts. Which should I do first?"