**CI Stability Work — Summary**

- **Branch:** chore/restore-retry
- **Purpose:** Reduce flakiness in CI (integration health polling, port collisions, PowerShell parsing, deterministic ShellRunner), improve diagnostics and artifact reliability.
- **Notable changes (files):**
  - `scripts/start-server-and-wait.ps1` — force IPv4 bind by default via `CI_BIND_ADDRESS`, accept `-Port`, create log placeholders, capture stdout/stderr to `scripts/tmp/`, write `start-server-diagnostics.log` on early exit, poll `/api/health`.
  - `scripts/poll-health.ps1` — try IPv4/IPv6 loopback variants and `/api/health` when callers use `/health`.
  - `scripts/stop-test-environment.ps1` — safer PID handling and no automatic variable clobbering.
  - `server/USBDeviceManager/Program.cs` — tolerate benign Sqlite "table already exists" race during EnsureCreated().
  - `.github/workflows/ci.yml` — global `CI_BIND_ADDRESS=127.0.0.1`, per-job `TEST_PORT` generator (Windows), NuGet restore retry and deterministic LongRunner publishing steps.

- **CI validation:**
  - Triggered repeated CI runs for branch `chore/restore-retry` and iterated until a successful run was observed.
  - Successful run: databaseId 21297513672 (conclusion: success).
  - Artifacts downloaded to: `artifacts/run-21297513672/` (includes `server-log-Windows/server.log` and TRX results).
  - Server log shows: "Now listening on: http://127.0.0.1:<port>" and "Application started." — health endpoint reachable.
  - TRX scan: no failed tests found in downloaded TRX files for that run.

- **Remaining / follow-ups:**
  - Validate stability over several CI runs (monitor for recurrence); temporary diagnostics were removed and consolidated in `chore/cleanup-diagnostics`.
  - Ensure any E2E harness that assumed fixed port 5000 reads `TEST_PORT` env var.
  - Consider consolidating health endpoints in docs and tests to consistently use `/api/health`.

**How to reproduce locally**

1. From project root run `pwsh scripts/start-server-and-wait.ps1 -Port 5000` (optionally set `CI_BIND_ADDRESS=127.0.0.1`).
2. Check logs at `scripts/tmp/server.log` and `scripts/tmp/server.err.log`.

**PR notes**
- This PR contains only CI and orchestration script fixes and a small defensive server change. No functional API changes.

If you'd like, I can: (a) squash or rework commits before merge, (b) remove diagnostics after further validation, or (c) open follow-up issues to track E2E test harness changes.

---
Generated: 2026-01-23
