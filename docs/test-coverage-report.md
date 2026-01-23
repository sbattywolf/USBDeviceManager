# Test Coverage Report & Prioritized Roadmap

Summary
- Overall Cobertura line coverage: ~24.8% (artifacts/coverage-dotnet/.../coverage.cobertura.xml).
- Coverage run shows many server-side controllers, SignalR hubs and Blazor components with 0% coverage.

Top 10 high-impact low-coverage files (prioritized)
1. `server/USBDeviceManager/Controllers/ServicesController.cs` — 0.0% (0/90)
   - Action: Add unit tests for controller endpoints and service-layer calls.
   - Estimated effort: 8–16 hours.
2. `server/USBDeviceManager/Controllers/AgentController.cs` — 0.0% (0/6)
   - Action: Add unit tests for agent endpoints and input validation paths.
   - Estimated effort: 2–4 hours.
3. `server/USBDeviceManager/Hubs/MonitoringHub.cs` — 0.0% (0/40)
   - Action: Add SignalR hub unit/integration tests (use TestServer/HubConnectionFactory or integration harness).
   - Estimated effort: 4–8 hours.
4. `server/USBDeviceManager/Pages/ServerStatus.razor` — 0.0% (0/514)
   - Action: Add `bUnit` component tests to exercise rendering and state transitions; cover lifecycle and injected services.
   - Estimated effort: 8–24 hours.
5. `server/USBDeviceManager/Components/Pages/Home.razor` — 0.0% (0/438)
   - Action: Add `bUnit` tests for rendering and event handling; add small integration GUI tests if needed.
   - Estimated effort: 8–16 hours.
6. `server/USBDeviceManager/Pages/Devices.razor` — 0.0% (0/108)
   - Action: Component tests + mock service responses.
   - Estimated effort: 4–8 hours.
7. `server/USBDeviceManager/Pages/SettingsAgentControls.razor` — 0.0% (0/142)
   - Action: Component tests for settings flows and API interaction.
   - Estimated effort: 4–8 hours.
8. `server/USBDeviceManager/Pages/Software.razor` — 0.0% (0/126)
   - Action: Component tests plus API mock coverage.
   - Estimated effort: 4–8 hours.
9. `server/USBDeviceManager/Components/LogViewer.razor` — 0.0% (0/54)
   - Action: Render and paging tests using `bUnit`.
   - Estimated effort: 2–4 hours.
10. `server/USBDeviceManager/DTOs/ConfigCreateDto.cs` — 0.0% (0/20)
   - Action: Add validation/mapping unit tests (AutoMapper or manual tests).
   - Estimated effort: 1–2 hours.

Immediate Roadmap (prioritized tasks)
- Priority A — Unblock CI and get reliable test feedback
  1. Fix CI GUI native deps: ensure runner installs `libegl1-mesa`, `libgl1-mesa-dri` and required GL libs (or switch to a prebuilt container), and run GUI tests under Xvfb. (1–2 hours)
  2. Add minimal controller unit tests for `ServicesController` covering the most-used endpoints and error paths. (8–16 hours)
  3. Add unit tests for `AgentController` and include authorization/validation cases. (2–4 hours)

- Priority B — Address SignalR, components and helpers
  4. Add SignalR hub tests for `MonitoringHub` (connect/disconnect, broadcasting). (4–8 hours)
  5. Add `bUnit` tests for `ServerStatus` and `Home` components. Start with rendering and injected-service mock flows. (8–24 hours)

- Priority C — Cleanups and quick wins
  6. Add small tests for DTOs and mappers (`ConfigCreateDto`). (1–2 hours)
  7. Add smoke/integration tests that exercise a small set of pages using headless browser or PyQt GUI harness where appropriate. (4–12 hours)
  8. Enable/standardize coverage collection on CI (XPlat coverage for .NET -> Cobertura; pytest-cov for GUI; consider Pester upgrade for PowerShell coverage). (2–4 hours)

Running coverage locally
- .NET (example):
```powershell
dotnet test /p:CollectCoverage=true /p:CoverletOutputFormat=cobertura
```
- Python GUI (example):
```bash
python -m pytest --cov=gui --cov-report=xml:artifacts/coverage-gui.xml gui/tests
```

Deliverables I'll create if you want me to continue
- `docs/test-coverage-report.md` (this file) — created.
- PRs that add unit tests and CI workflow changes (I can implement the smallest high-priority items first).
- A CSV or full ranked file list exported from the Cobertura XML for tracking.

Next recommended immediate action
- Update `.github/workflows/ci.yml` to install Mesa EGL/GL packages and re-run the CI GUI job; while CI runs, add a small unit test for `ServicesController` exercising one endpoint to demonstrate coverage increases.

If you want, I will now:
1. Add the top-5 missing test TODOs to the project TODOs (I will do that now). 
2. Open a PR that updates CI packages and adds a minimal `ServicesController` unit test.
# Test Coverage Report (automated run)

Summary of coverage artifacts produced by the local verification run (generated on 2026-01-23):

- **.NET (server)**: coverage collected via `dotnet test --collect:"XPlat Code Coverage"`.
  - Artifact: `artifacts/coverage-dotnet/*/coverage.cobertura.xml`
  - Tests run: 75 unit tests passed.

- **Agent (PowerShell / Pester)**: agent tests executed via `TestRunner.ps1` (or `Invoke-Pester` fallback).
  - Tests: executed successfully locally; no failing tests reported in this run.
  - Coverage: not produced — the locally installed `Pester` does not accept `-EnableCodeCoverage` in this environment. See "Next actions" below.

- **GUI (Python / pytest + pytest-cov)**: pytest run with `--cov=gui`.
  - Artifact: `artifacts/coverage-gui.xml`
  - Result: 6 tests passed; coverage XML written to `artifacts/coverage-gui.xml`.

Notes and issues discovered:

- The .NET coverage file is in Cobertura XML format and can be consumed by coverage tools (report generators or CI coverage viewers).
- Pester coverage collection failed because `Invoke-Pester` on the current environment rejected `-EnableCodeCoverage`. Options: upgrade Pester to a version that supports `-EnableCodeCoverage`, or collect coverage with `PSCodeCoverage`/`Coverlet`-style tooling and post-process the results.

Next actions (recommended, prioritized):

1. Generate readable coverage reports (HTML) from the Cobertura / pytest XML files and attach them to CI artifacts.
   - Tools: `reportgenerator` (for .NET Cobertura -> HTML) or online viewers.

2. Produce PowerShell coverage:
   - Option A: Upgrade `Pester` in CI and locally to a version that supports `-EnableCodeCoverage`, then re-run `Invoke-Pester -EnableCodeCoverage` to produce a coverage artifact (JSON/XML).
   - Option B: Use `PSCodeCoverage` or a custom script to instrument and collect coverage for PowerShell modules, then convert to a common format.

3. Parse `artifacts/coverage-dotnet/*/coverage.cobertura.xml` and `artifacts/coverage-gui.xml` to locate low-coverage modules and generate a prioritized list of missing tests.

Follow-up TODOs (created automatically):

- Identify top 5 low-coverage source files in the server project and add explicit test tasks.
- Add CI steps to publish HTML coverage reports for both .NET and GUI runs.
- Fix Pester coverage collection (choose Option A or B above) and re-run coverage collection for agent tests.

Artifacts produced by the run (local paths):

- `artifacts/coverage-dotnet/<guid>/coverage.cobertura.xml`
- `artifacts/coverage-gui.xml`
- `artifacts/agent-pester-results.xml` (Pester test results)

If you want I can now:

- Parse the Cobertura file and produce a ranked list of low-coverage files (requires adding a small parser step), or
- Patch CI to publish HTML coverage reports and to install/upgrade Pester so agent coverage can be collected automatically.

— Automated run on branch `chore/stabilize-tests` (local workspace)
