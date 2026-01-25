````markdown
# Troubleshooting & Testing Log

This document captures all troubleshooting steps, test runs, attempted fixes, and lessons learned for CI and integration test stability. It is updated each time a bug-task is worked on.

Related: docs/diagnostics/ci-integration-audit.md

Principles
- Record the exact command, environment variables, and which script or file was changed.
- Note outcome (pass/fail), logs captured, and next action.
- Avoid repeating approaches that previously failed; reference this file before reattempting.

Recent activity (summary)

1) Initial audit (2026-01-25)
- File: docs/diagnostics/ci-integration-audit.md
- Findings: missing LongRunner on Windows, temp DB locked by other processes, server readiness fragility, EF log config checks.
- Action: prioritize LongRunner publish/assert and DB-handle cleanup.

2) Attempts (multiple) — server startup/readiness
- Files inspected: scripts/start-server-and-wait.ps1, scripts/poll-health.ps1, scripts/run-integration-noninteractive.ps1, .github/workflows/ci.yml
- Actions tried: increased diagnostic logging in start script (printed env vars, out/err tails), ensured readiness marker detection includes multiple markers.
- Outcome: intermittent success; some runs still hit health timeouts and early process exit. Logs saved to scripts/tmp/server.log and server.err.log when available.
- Lesson: readiness markers exist but polling time/window needs tuning per-platform; capture full stdout/stderr on early exit.

3) LongRunner publish failures
- Symptom: Unit tests failing with System.ComponentModel.Win32Exception because LongRunner exe missing under artifacts/longrunner/win-x64
- Action: confirmed publish step in CI exists but sometimes produces dll not exe on non-Windows runners; need explicit publish for Windows runner and assert existence in CI.
- Outcome: identified actionable fix (CI assert + ensure publish for Windows). Marked as P0.

4) DB lock / cleanup failures in test factory
- Symptom: `SimRacingTestFactory: failed to delete temp DB on dispose` with IO exceptions.
- Actions to try: ensure DbContexts disposed, add a small wait-and-retry before file deletion in test teardown, capture list of open handles (Windows SysInternals `handle.exe` not available on CI), and preserve failing DB to artifacts for analysis.
- Outcome: add safe-delete helper to test factory and preserve sample DBs for triage.

Planned guardrails (do before re-running CI)
- Add CI assert step to fail early if LongRunner exe missing and upload build logs.
- Add safe wait-and-retry delete in `SimRacingTestFactory` teardown (short backoff + capture diagnostics) before removing temp DB.
- Harden `start-server-and-wait.ps1` to increase marker wait and always write full stdout/stderr into artifacts for CI upload.
- Add `scripts/local-run-all.ps1` to reproduce CI sequence locally.

How to add entries
- Each bug-task must add an entry here with:
  - Date/time, command(s) run, files modified, result, and next steps.

If you want, I will now:
- Implement the LongRunner CI assert and local publish helper (fast, P0)
- Add a safe-delete retry in test factory teardown (next, P0)

— End of log

2026-01-25  — Implemented LongRunner publish/assert + increased DB-delete retries
- Files changed:
  - `.github/workflows/ci.yml` : added `Assert LongRunner artifact (Windows)` step to fail early when the LongRunner exe is missing on Windows runners.
  - `scripts/ci/publish-longrunner.ps1` : new helper script to publish `test-helpers/LongRunner` for Windows and verify `LongRunner.exe` exists.
  - `server/USBDeviceManager.Tests/Fixtures/SimRacingTestFactory.cs` : increased DB delete retry attempts and initial backoff (to reduce transient IO delete failures).
- Commands run / verification:
  - Ran a local `dotnet publish` using `scripts/ci/publish-longrunner.ps1` (dev machine) to validate that the helper publishes an exe and returns exit code 0 when successful.
  - Verified the CI workflow contains the new assertion step (Windows) which will fail early and surface a clear error message when missing.
- Outcome: Added early fail-fast for missing LongRunner and increased resilience for temp DB deletion during test teardown. Added artifacts and diagnostics writing already present in the test factory will capture failing DB samples when deletion fails.

Next actions:
- If CI still shows missing LongRunner on Windows runners, consider forcing `dotnet publish` in a dedicated Windows-only job, or change publish target/runtime to match runner architecture.
- Monitor test runs for reduced DB deletion failures; if still flaky, extend delay or add active handle detection when available on CI.

## PowerShell parse-check (usage)

We added a small parse-only checker `scripts/ci/ps-parsecheck.ps1` to validate PowerShell scripts in CI and locally. This helps catch syntax and parsing errors (including ambiguous `$var:` tokens) before running the orchestration steps.

Run locally (PowerShell):

```powershell
.\tools\pwsh -NoProfile -ExecutionPolicy Bypass -Command "& { .\scripts\ci\ps-parsecheck.ps1 -Paths 'scripts/run-integration-noninteractive.ps1','scripts/start-server-and-wait.ps1','scripts/poll-health.ps1','scripts/extract-failures.ps1' }"
```

Or, simpler on a dev machine with `pwsh` available:

```powershell
.\scripts\ci\ps-parsecheck.ps1 -Paths 'scripts/run-integration-noninteractive.ps1','scripts/start-server-and-wait.ps1','scripts/poll-health.ps1','scripts/extract-failures.ps1'
```

CI integration: a step was added to `.github/workflows/ci.yml` (pre-server-start) to run the parse-check and fail early if any script does not parse. If the parse-check identifies issues it returns nonzero and the job will stop before starting the server.

Notes:
- The parse-check uses the PowerShell Parser API (`[System.Management.Automation.Language.Parser]::ParseFile`) with `[ref]` parameters to avoid emitting guidance warnings; the helper takes a `-Paths` array and will report `PARSE_OK:` lines for successful files.
- If you add or modify automation scripts, add them to the parse-check invocation list in CI or update the helper call accordingly.

See also: Live troubleshooting notes for rapid edits and temporary observations are in [docs/diagnostics/troubleshooting-testing-live-notes.md](docs/diagnostics/troubleshooting-testing-live-notes.md).

---

### Run 21331804897 — merged trace (2026-01-25)

- **Summary:** CI run for branch `chore/ci-fix-env-check` produced 3090 tests: 3086 passed, 4 failed. Failures returned HTTP 404 NotFound from the test server.
- **Where to find artifacts:** [artifacts/ci-run-21331804897](artifacts/ci-run-21331804897)
- **Key logs examined:** [artifacts/ci-run-21331804897/run.log](artifacts/ci-run-21331804897/run.log) and [artifacts/ci-run-21331804897/final-test-report/final-report.txt](artifacts/ci-run-21331804897/final-test-report/final-report.txt)
- **Root cause (diagnosed):** server binary `SMServer.exe` was not available at the runner-expected path (CI published to `net8.0/win-x64/SMServer.exe` while the tests expect `net8.0/SMServer.exe`), so the test harness received 404 when calling endpoints.
- **Mitigation applied:** patched `.github/workflows/ci.yml` to (a) defensively copy the RID-published exe from `win-x64` into the framework root before test start, and (b) upload a `publish-sentinel.txt` artifact to assert publish success on Windows runners.
- **Follow-up actions:** poller running for run `21332370587` will verify presence of `publish-sentinel.txt` and `SMServer.exe` in the downloaded artifacts; if missing, we'll capture full server stdout/stderr and preserved DBs under `artifacts/enriched/failures/<runId>` for triage.

If you want, I can now archive large run logs (move `artifacts/ci-run-21331804897/run.log` into `artifacts/archive/`) and append the archived filename here; confirm and I'll proceed.

````

