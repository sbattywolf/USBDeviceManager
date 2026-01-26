Troubleshooting Notes — Testing and CI (2026-01-25)

Purpose
- Capture observed CI failures and remediation steps when running integration tests.

Symptoms
- CI step fails when invoking `scripts/start-server-and-wait.ps1` with: "A parameter cannot be found that matches parameter name 'or'".
- Integration job downloads publish artifacts but server logs are empty or the server process terminates quickly.
- Artifact upload 409 Conflict when the same artifact name is uploaded multiple times in a run without `overwrite: true`.

Immediate Remediations
- Ensure orchestration scripts accept the switches used by CI (eg. add `-NonInteractive` to `start-server-and-wait.ps1`).
- Parenthesize `Join-Path` when building arrays in PowerShell (eg. `$candidates = @((Join-Path ...), (Join-Path ...))`) to avoid `System.Object[]` coercion errors.
- Add `overwrite: true` to `actions/upload-artifact@v4` steps that may re-run in the same workflow to avoid 409 conflicts.

Integration-only CI
- Create and use a minimal integration-only workflow (`.github/workflows/integration-only.yml`) that:
  - Runs on `windows-latest` (host environment that matches the published RID)
  - Downloads `publish-sentinel` and `published-server-win-x64-zip` artifacts
  - Extracts the deterministic publish zip into `server/USBDeviceManager/bin/Release/net8.0`
  - Copies the RID exe to the framework root if necessary
  - Runs `scripts/run-integration-noninteractive.ps1 -Port <port> -NoStop` to start server and run tests

Debugging checklist when the server exits quickly
1. Confirm the chosen executable exists and is runnable: `Test-Path <path>` and attempt a local run.
2. Dump working directory listing immediately before launch (add `Get-ChildItem -Recurse` in `start-server-and-wait.ps1` if failing).
3. Capture stdout/stderr to files and upload them as artifacts; ensure the start script creates placeholder log files before launching so uploads always include them.
4. If stdout is empty and stderr contains nothing, try launching the exe interactively on a matching runner or locally to observe missing runtime dependencies.

Notes for operators
- When reproducing locally, stop stray `dotnet` processes first: `pwsh ./scripts/stop-dotnet.ps1`.
- For out-of-band artifact downloads, use a narrowly-scoped PAT and `gh` or the Actions artifact URLs; revoke the PAT after use.

History
- 2026-01-25: Added notes based on multiple failing runs and fixes (Join-Path parenthesis fix, `start-server-and-wait.ps1` accepts `-NonInteractive`, sentinel verification tolerant to extraction layouts).
# Troubleshooting Notes — PowerShell parse errors (2026-01-25)

Symptom
- CI `ps-parsecheck` reported parse errors: `InvalidVariableReferenceWithDrive Variable reference is not valid. ':' was not followed by a valid variable name`.

Root cause
- Unescaped variable interpolations followed immediately by punctuation (e.g. `$id:`, `$max:`) can be parsed as invalid "variable-with-drive" tokens by PowerShell's parser on non-Windows runners.

Fixes applied
- Replace risky interpolations with either:
  - explicit subexpression: `"$($var): ..."`
  - or format operator: `"... {0}: {1}" -f $var, $val`
- Files patched in this change set:
  - `scripts/poll-pr28.ps1`
  - `workspace_restart.ps1`
  - `.tools/find-herestring-markers.ps1`
  - `scripts/run_full_debug.ps1`
  - `scripts/start-server-and-wait.ps1`

Quick local checks
- Run the repository parse-check helper locally:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass .\scripts\ci\ps-parsecheck.ps1 -Paths (Get-ChildItem -Path scripts -Filter '*.ps1' -Recurse | ForEach-Object { $_.FullName })
```

- Expect to see `PARSE_OK` for each file. If a file reports parse errors, open it and replace `$var:` with `"$($var):"` or use the format operator as shown above.

Notes
- I pushed fixes and triggered CI; one run is currently in progress. When the run finishes I'll download logs and confirm `ps-parsecheck` success and that the Windows `dotnet publish` step produced `SMServer.exe` in the expected path.

Deterministic publish artifact fallback
 - Problem observed: occasional missing `published-server-win-x64` uploads due to glob/path/upload ordering fragility.
 - Mitigation added: CI now creates a deterministic zip of the publish output (`artifacts/published-server-win-x64.zip`) and uploads it as `published-server-win-x64-zip` in addition to the folder upload.
 - Integration jobs now attempt to download `published-server-win-x64` first; if absent they download `published-server-win-x64-zip` and extract it into `server/USBDeviceManager/bin/Release/net8.0` so `scripts/start-server-and-wait.ps1 -NoBuild` can find `SMServer.exe`.

Verification checklist
 - Confirm `build-and-test` job creates `artifacts/published-server-win-x64.zip` and uploads `published-server-win-x64-zip`.
 - Confirm `integration-tests` job downloads either `published-server-win-x64` or the `published-server-win-x64-zip` and that `server/USBDeviceManager/bin/Release/net8.0/SMServer.exe` exists before starting the server.
 - If the zip is present but the exe still missing after extraction, inspect the zip contents and the `Expand-Archive` output in the integration job logs.

Next steps
 - Wait for the next CI run (after these workflow updates) and validate artifacts. If uploads still fail, add an explicit `Compress-Archive` of the RID folder only and upload that as an additional artifact.

Job rename
- The final reporting job in the integration workflow has been renamed to `Integration Test & Analysis` (job id `integration-test-analysis`). This job downloads `integration-artifacts`, generates the HTML/text integration test report, and uploads `integration-report` and `regression-summary` artifacts. When triaging runs, look for this job name in the Actions UI.
  
  It also packages the collected integration artifacts and logs into `artifacts/integration-report-full.zip` for easy forensic download. Note: this is an integration-text debug bundle (reports, logs, TRX, DB artifacts), not a full test archive.


Local cleanup helper
- `scripts/stop-dotnet.ps1` — helper script created to stop stray local `dotnet` instances started during testing and prevent port conflicts. Usage:

```powershell
# Stop all running dotnet processes (requires appropriate permissions)
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\stop-dotnet.ps1
```

The script prints stopped PIDs and a post-stop check showing remaining `dotnet` processes (if any). Use this before running local integration tests to ensure ports and file locks are free.

Automated local cleanup
- `scripts/run-start-debug.ps1` now invokes `scripts/stop-dotnet.ps1` in a `finally` block so local `dotnet` instances started by the debug run are stopped automatically. Use `scripts/run-start-debug.ps1` to run the start+debug flow and ensure cleanup runs regardless of success or failure.

Best practice
- Run `scripts/stop-dotnet.ps1` before and after local integration/publish tests to avoid stray processes holding ports or files. Consider adding the same cleanup call to any other long-running local test wrappers you use.

Enforced local cleanup policy

- Why this change: during iterative debugging the test host was sometimes intentionally left running to allow additional manual checks without restarting the server; that produced stray `dotnet` processes. To avoid intermittent port/file-lock issues we now mandate explicit cleanup.

- Policy (recommended): Always stop any local `dotnet` instances when a test or manual run completes. For automated wrappers add a `finally`/cleanup block that calls `scripts/stop-dotnet.ps1` so cleanup runs regardless of success or failure.

Server cleanup guarantee

- `scripts/run-integration-noninteractive.ps1` now enforces final cleanup by invoking `scripts/ensure-server-stopped.ps1` in a `finally` block. This ensures stray `SMServer.exe` / `USBDeviceManager` processes are stopped when the wrapper exits, unless you specifically pass `-NoStop` to keep the server running for post-mortem work.
- If you observe a leftover `SMServer.exe` or `asmser.exe` window on your workstation after a local run, either:

  - run the helper to forcibly stop matching server processes:

    ```powershell
    powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ensure-server-stopped.ps1
    ```

  - or stop the specific pid recorded in `scripts/tmp/server.pid`:

    ```powershell
    if (Test-Path scripts/tmp/server.pid) { Stop-Process -Id (Get-Content scripts/tmp/server.pid) -ErrorAction SilentlyContinue }
    ```

Best practice: prefer the `ensure-server-stopped` helper because it matches by process name, commandline, and executable path and writes an `ensure-stopped.log` into `scripts/tmp` for artifact collection.

- Recommended commands (pre/post-test):

```powershell
# Ensure no existing test hosts are running before starting
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\stop-dotnet.ps1

# Run the start+wait wrapper which itself performs cleanup in a finally block
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-start-debug.ps1

# Explicitly stop any remaining dotnet hosts after testing
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\stop-dotnet.ps1
```

Summary of issues found (current investigation)
- **PowerShell parsing fragility:** variable interpolation followed by punctuation and array->string coercion with `Join-Path` caused CI parse failures and strange path resolution behavior; these were patched.
- **Runner vs artifact path mismatch:** `publish-sentinel.txt` contains an absolute runner path (e.g. `D:\a\USBDeviceManager\USBDeviceManager\...\SMServer.exe`) while artifacts contain relative package layouts (`published-server-win-x64/...`), causing integration logic that relied on exact paths to miss the exe unless extraction/copying logic ran.
- **Artifact upload/download fragility:** build logs show `published-server-win-x64` and `published-server-win-x64-zip` uploaded, but programmatic downloads (via API/redirect URLs) can be blocked if tokens/scopes are missing or if storage account disallows anonymous access — this requires authenticated downloads or ensuring runner actions have correct access.
- **CI workflow ordering/race:** potential timing/ordering issues between the publish job and integration job (artifact not uploaded/visible when integration starts) — recommended to add an explicit publish job and `needs:` dependency for integration.
- **Diagnostics and retention gaps:** initial runs lacked consistent diagnostics and preserved temp logs; added `server.log`/`server.err.log` safeguards and collected extended diagnostics to `artifacts/extended-diagnostics-*.zip`.

Immediate prioritized fixes (next actions)
- Add a minimal CI gating change so integration `needs:` the Windows publish job that uploads the RID outputs and `publish-sentinel.txt`.
- Harden integration download step: attempt folder artifact, then zip fallback; fail fast with workspace inventory printed when sentinel missing.
- Ensure artifact downloads use authenticated API flow when necessary (document PAT usage for out-of-band forensic downloads only).
- Keep `scripts/start-server-and-wait.ps1` resilient: treat sentinel runner paths as hints and search published package for `SMServer.exe` by filename, copying into `net8.0` if needed.
- Continue collecting and attaching `artifacts/extended-diagnostics-*.zip` when investigating failures.

Modular CI modules (recommended)
- Design a canonical per-test CI module that follows this pattern:
  - Job A: Build & publish (in-job deterministic `dotnet publish` -> upload `published-server-<rid>-zip`)
  - Job B: Test runner (checkout, download publish artifacts, extract fallback zip, start server via `scripts/start-server-and-wait.ps1`, run tests, copy logs/TRX into `artifacts/`)
  - Job C: Analysis (depends on B): run `scripts/generate-integration-test.ps1` (or test-specific generator), emit txt+HTML reports, package `artifacts/integration-report-full.zip`, upload artifacts.
- Create one template workflow file (example: `.github/workflows/test-module-template.yml`) and instantiate it for `integration`, `e2e`, and `unit` modules so they share the same life-cycle and artifact conventions.
- Benefits: predictable artifact layout, consistent diagnostics, and the ability to compose modules into a full pipeline by chaining `needs:`.

Files/locations of interest produced during investigation
- `artifacts/published-server-win-x64-manifest.txt` — manifest of the extracted package (paths, sizes, SHA256).
- `artifacts/diagnostics-*.zip` and `artifacts/extended-diagnostics-*.zip` — runtime and extended diagnostics collected locally.
- `scripts/tmp/server.log` and `scripts/tmp/server.err.log` — server runtime logs captured during local validation.

Next immediate work
- I'll continue with implementing the CI gating change and the integration artifact-download hardening; I'll also expand the troubleshooting doc with a short reproducible checklist once the gating change is in the repo. If you prefer I can open a PR with the CI changes next.
