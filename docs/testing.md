# Testing guide

This document describes the test taxonomy, where tests live, how CI runs them, and how to run tests locally and with the orchestration scripts. The section below consolidates the test strategy, CI mapping, and runbook in a single place for maintainers.

## Test taxonomy
- Unit: fast, pure logic tests. Use `Trait("Category","Unit")`.
- Integration: exercises real application stack (in-memory DB, TestServer). Use `Trait("Category","Integration")`.
- Functional: higher-level server behaviors that exercise multiple components and scripts. Use `Trait("Category","Functional")`.
- E2E: full end-to-end tests that involve the agent binary and real-ish environment. Use `Trait("Category","E2E")`.
- Smoke: short, system-level sanity checks that run quickly (optional, non-blocking).

Canonical categories
- Unit
- Integration
- Functional
- E2E
- Smoke

Note: we normalize on xUnit `Trait("Category","...")` for .NET tests and use the same `Category` string inside Pester test suites for agent tests. Search the repo for existing usages (`Trait("Category",`) — tests are already categorized but new tests should follow this convention.

## Where tests live (convention)
- `server/*Tests` — main .NET test projects for server, integration and E2E.
- `agent/SimRacingAgent.Tests` — agent-focused tests (Pester and .NET tests). Follow the same `Category` trait convention.
- `test/Utilities` — shared test helpers and fixtures (already present for HealthPoller).

## CI mapping (what runs where)
- `build-and-test` job: runs Unit tests only. Example:

```powershell
dotnet test USBDeviceManager.sln --filter "Category=Unit"
```

- `integration-tests` job (windows): starts server via `scripts/start-server-and-wait.ps1`, runs Integration tests, then runs `scripts/stop-test-environment.ps1`. Example:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-server-and-wait.ps1 -ProjectPath server/USBDeviceManager -Port 5000 -TimeoutSec 90
dotnet test USBDeviceManager.sln --filter "Category=Integration"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\stop-test-environment.ps1
```

- `e2e-windows` job: builds and runs Agent E2E tests on Windows; marked `continue-on-error: true` to avoid blocking PRs for flaky hardware-dependent tests. Example run (on self-hosted Windows):

```powershell
dotnet test server/AgentE2E.Tests/AgentE2E.Tests.csproj --filter "Category=E2E"
```

- Agent Pester tests (when present) run on Windows in CI via `ci/run-tests.ps1` or via Pester invocation in the workflow. Example:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\ci\run-tests.ps1 -RunAgentTests -NonInteractive
```

CI artifacts and debugging
- When running integration or build matrix jobs the workflow uploads `scripts/tmp/server.log`, `scripts/tmp/server.err.log`, and `scripts/tmp/ensure-stopped.log` so that flaky server startups and leftover handles are easier to diagnose.
- The `scripts/ensure-server-stopped.ps1` script is invoked before build steps to try to clear any stray server processes that would prevent `dotnet build` from overwriting binaries (file lock errors). It logs actions to `scripts/tmp/ensure-stopped.log`.

## How to run locally

Run unit tests (fast):

```powershell
dotnet test USBDeviceManager.sln --filter "Category=Unit"
```

Run integration tests (start server first):

```powershell
# start server in background (or use scripts/start-server-and-wait.ps1)
pwsh ./scripts/start-server-and-wait.ps1 -NonInteractive
dotnet test USBDeviceManager.sln --filter "Category=Integration"
pwsh ./scripts/stop-test-environment.ps1
```

Run Agent Pester tests (Windows):

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\ci\run-tests.ps1 -RunAgentTests -NonInteractive
```

Run E2E tests (Windows):

```powershell
dotnet test server/AgentE2E.Tests/AgentE2E.Tests.csproj
```

## Orchestration scripts
- `scripts/start-server-and-wait.ps1` — start server and wait for healthy endpoint.
- `scripts/stop-test-environment.ps1` — tear down server and test artifacts.
- `scripts/poll-health.ps1` — helpful for CI to poll service readiness.

Guidance: use these scripts as the canonical way to bring up test dependencies in CI and locally. Avoid ad-hoc background processes in tests; prefer orchestration + health polling to achieve deterministic test runs.

## Folder conventions and guidance
- Keep test helpers in `test/Utilities` for reuse.
- Prefer `*.Tests` suffix for test projects and place them near the code they test (server tests under `server/`, agent tests under `agent/`).
- When adding a new test project, ensure it uses a `Category` trait and that CI filtering in `.github/workflows/ci.yml` will include/exclude it appropriately.

## DI seams and future refactors
To simplify CI and reduce hardware dependency, we recommend adding small DI abstractions in the server and agent code:

- `IProcessLauncher` — abstract starting external processes (agent binary). Replace direct Process.Start.
- `IShellRunner` — run shell scripts and capture output (used by tests that invoke orchestration scripts).
- `IUsbDeviceProvider` — simulate USB device attach/detach for integration/E2E tests.

Actionable refactors (short-term)
- Add `IProcessLauncher` and `IShellRunner` adapters (we've added `ProcessLauncher` and `ShellRunner` implementations in Services/Platform). Register test-friendly fakes in `Program.cs` for CI runs so the orchestration scripts can be used from managed test fixtures.
- Add `InMemoryUsbDeviceProvider` to allow most integration tests to run without physical USB hardware.

Add these gradually behind feature flags/optional adapters so tests can use fakes in CI.

## Troubleshooting & tips
- If tests fail due to ports or DB files, run `scripts/stop-test-environment.ps1` and clean `bin/Debug/*/simracing.db` files under the test project folders.
- For flaky E2E tests, prefer running them on self-hosted Windows runners with access to the required hardware.

## Changelog
- 2026-01-22: Initial testing guide added; documents taxonomy, CI mapping, and run steps.
 - 2026-01-22: Hardened `scripts/ensure-server-stopped.ps1` and added CI artifact uploads for server logs; consolidated testing strategy and runbook.
# Testing strategy and runbook

This document defines the project's testing taxonomy, recommended runtimes, and example commands to run locally and in CI.

Test categories
- Unit: fast, isolated tests that don't touch external services (DB, network). Run on every commit.
- Integration: tests that exercise components together (EF Core, controllers, in-memory DB or sqlite file). Run in CI jobs.
- Functional: higher-level checks that validate a workflow (server + agent registration) and may require starting the server or agent.
- E2E: full end-to-end scenarios with real or simulated agents and devices. Slow and flaky-prone; run optionally on self-hosted Windows runners or nightly.

Principles
- Prefer independent tests. Avoid implicit sequencing inside test suites.
- When ordering or external services are required, use orchestration scripts to start services and poll health endpoints.
- Tag tests by category (xUnit `Trait` or by naming convention) so CI can select subsets.

Orchestration scripts
- `scripts/start-server-and-wait.ps1` — starts the ASP.NET server project and waits for `/health`.
- `scripts/start-agent-and-wait.ps1` — starts a local agent executable and optionally waits for a registration/health URL.
- `scripts/stop-test-environment.ps1` — stops processes started by the scripts (reads PIDs from `scripts/tmp/*.pid`).
- `scripts/run-server-and-gui.ps1` — convenience script to start the server and the WinForms WebView2 PoC.
- `scripts/poll-health.ps1` — HTTP poller used by the other scripts.

Example developer flows

Start server and wait for health:
```powershell
.\scripts\start-server-and-wait.ps1 -ProjectPath server/USBDeviceManager -Port 5000
```

Start an agent and wait for registration (example):
```powershell
.\scripts\start-agent-and-wait.ps1 -AgentExe .\agent\simulated\SimAgent.exe -AgentHealthUrl http://localhost:5000/api/agents -TimeoutSec 60
```

Run integration tests (example uses trait filtering):
```powershell
dotnet test server/AgentE2E.Tests/AgentE2E.Tests.csproj -f "Integration" --logger "trx;LogFileName=Integration.trx"
```

Tear down test environment:
```powershell
.\scripts\stop-test-environment.ps1
```

CI guidance
- Run Unit tests on every push.
- Run Integration tests inside CI using the orchestration scripts to ensure services are started before test execution.
- Keep E2E tests optional/non-blocking; run them on self-hosted Windows runners or nightly pipelines.

Next steps
- Add xUnit traits to categorize existing tests.
- Add a small test utility library that polls `/health` from C# test fixtures (optional; PS scripts are available now).
- Convert fragile sequenced tests to orchestration-based checks using these scripts.
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
