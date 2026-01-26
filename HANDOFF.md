Handoff: Reproducing FOREIGN KEY failure (snapshot)

Summary
Summary
- Current focus: reproduce a SQLite FOREIGN KEY constraint failure observed in CI run `21323958834`.
- Status: diagnostic work done; `artifacts/ci-local-simracing-on-failure.db` contains a DB snapshot from a run where TRX was missing. Server was stopped and background process cleared.

Important files / artifacts
- Failure DB snapshot: artifacts/ci-local-simracing-on-failure.db
- Local DB copy: artifacts/ci-local-simracing.db
- Latest integration TRX (if present): artifacts/integration.trx
- Temp server logs and pid: scripts/tmp/server.log, scripts/tmp/server.err.log, scripts/tmp/server.pid

Scripts changed
- Non-interactive runner: scripts/run-integration-noninteractive.ps1
- Prompt helper (auto defaults): scripts/interactive/PromptHelper.ps1
- Start-server health fallback: scripts/start-server-and-wait.ps1 (pwsh -> powershell fallback)
- Stop helper: scripts/tmp/stop-server.ps1

Quick resume commands
1) Start CI-like run (non-interactive) using the failure DB (recommended):

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\run-integration-noninteractive.ps1 -DbPath artifacts/ci-local-simracing-on-failure.db -Port 5010
```

2) OR manual start + test run:

```powershell
# copy snapshot into server folder (optional if you want server to use it)
Copy-Item -Path artifacts/ci-local-simracing-on-failure.db -Destination server/USBDeviceManager/simracing.db -Force

# start server and wait for health
.\scripts\start-server-and-wait.ps1 -Port 5010

# run integration tests
dotnet test USBDeviceManager.sln --filter Category=Integration --logger "trx;LogFileName=artifacts/integration.trx"
```

3) Stop server (if needed):

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/tmp/stop-server.ps1
```

Next recommended tasks (short):
- Run the concurrent POST repro harness (200 concurrent `POST /api/logs`) against a server using the failure DB and capture logs + TRX.
- If repro occurs, save `server/USBDeviceManager/simracing.db` to `artifacts/ci-local-simracing-on-failure.db` and attach logs to CI artifacts.
- Add CI step to upload `simracing.db` and EF debug log on job failure.
- Implement a deterministic integration test that simulates the race.

Session closure notes (2026-01-27):
- Today's CI remediation: root workflow sanitized, minimal `dotnet` path fixes applied, `.worktrees` removed from index and ignored.
- Branch with changes: `ci/enrich-aggregator-stabilize` (ready for smoke run).
- I will dispatch the `CI` workflow to run on that branch now.

If you want the run scheduled at a specific future time, tell me the desired UTC time and I will create a scheduling PR or add a short workflow to dispatch at that time; otherwise the dispatched run will start immediately on GitHub's runners.

Notes
- Server process was stopped and PID file cleared before this handoff; it's safe to power off the machine.
- If you resume later, ensure `pwsh` is available in PATH. `start-server-and-wait.ps1` will fall back to `powershell` if not.

Logged state
- Centralized TODOs: actionable steps moved into `docs/TODOs-collected.md`.

Contact
- Resume with these steps or ping me if you want me to run the repro now before you power off.
