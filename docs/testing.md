# Testing guide

This project uses xUnit and integration tests via `WebApplicationFactory<Program>`.

Key points about the test infrastructure:

- Tests use a temporary file-based SQLite database per test run to exercise EF Core relational behavior.
- Test DB files are created under the system temp directory with names like `USBDeviceManagerTest_YYYYMMDDHHMMSS_<pid>.db`.
- Startup cleanup removes old `SimRacingTest_*.db` files older than `SIMRACING_TEST_DB_EXPIRATION_HOURS` (default 6).
- The test factory applies `PRAGMA journal_mode=WAL` and `PRAGMA busy_timeout=10000` to help with concurrency.
- xUnit parallelization is disabled at the assembly level to avoid SQLite concurrency races.

Running tests locally:

```powershell
# run all tests
dotnet test

# run only server tests
dotnet test server\USBDeviceManager.Tests\USBDeviceManager.Tests.csproj
```

Troubleshooting:
- If you see SQLite native registration errors, ensure the tests are not running in parallel and retry.
- If you see duplicate key / tracking errors, check that test data generators do not preassign `Id` values for entities persisted by EF.

Environment variables:
- `SIMRACING_TEST_DB_EXPIRATION_HOURS` - number of hours after which old temp DB files are deleted (integer). Set to `0` to skip deletion.

For more details, see the test factory at `server/USBDeviceManager.Tests/Fixtures/SimRacingTestFactory.cs`.

PowerShell/Agent tests
----------------------

The repository contains a PowerShell-based agent test harness located under `agent/SimRacingAgent.Tests`.

- Use the TestRunner to orchestrate the full suite or selected categories:

```powershell
Import-Module agent/SimRacingAgent.Tests/TestRunner.ps1 -Force
Invoke-CICDTestSuite -GenerateReport -ReportPath scripts/tmp/reports
```

- For CI-like transcripts and child-process isolation run the wrapper:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File agent/SimRacingAgent.Tests/run_startproc_wrapper.ps1
# transcript saved to agent/SimRacingAgent.Tests/run_tests_transcript_<timestamp>.txt
```

CI helper script
-----------------

Use `ci/run-tests.ps1` to run server (`dotnet test`) and agent (PowerShell) tests locally in a CI-like manner:

```powershell
.\ci\run-tests.ps1
```

Notes:
- `ci/run-tests.ps1` will run the solution `dotnet test` if `dotnet` is on PATH; it will run agent tests via the PowerShell harness.
- If you need to skip server or agent tests, use `-RunServerTests:$false` or `-RunAgentTests:$false`.

Reports and artifacts
---------------------

- PowerShell test reports (when `-GenerateReport` is used) are written to the `ReportPath` argument (default `scripts/tmp/reports`).
- Runner transcripts are written to `agent/SimRacingAgent.Tests/run_tests_transcript_<timestamp>.txt`.

If you make changes to the test harness or tests
---------------------------------------------

1. Run the full harness locally via the wrapper to capture a transcript and reports.
2. Fix failing tests or flaky diagnostics; prefer small, surgical fixes in the test harness rather than modifying production code only to satisfy tests.
3. Commit changes and push; CI will run `ci/run-tests.ps1` on the CI host.
