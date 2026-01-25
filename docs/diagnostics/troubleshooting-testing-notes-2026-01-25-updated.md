# Troubleshooting Notes — PowerShell parse errors (2026-01-25)

Quick status (2026-01-25)

- **Action:** Investigated Windows CI failures and added defensive fixes to the start script and workflow.
- **Latest CI run inspected:** `21333071826` (branch `chore/ci-fix-env-check`). Run completed but concluded **failure**.
- **Artifacts downloaded:** `artifacts/ci-run-21333071826` (summaries, enriched reports). No `published-server-win-x64` artifact found and no `SMServer.exe` within the downloaded snapshot.
- **Parse-check fix:** Fixed PowerShell parse errors in `scripts/start-server-and-wait.ps1` (use forward-slash paths); pushed commit to `chore/ci-fix-env-check`.
- **Next immediate step:** Harden the build job to guarantee the RID outputs are uploaded (create `publish-sentinel.txt`), or add an explicit upload/copy step in the integration job so `SMServer.exe` is always available to `-NoBuild` runs.

## What I did

- Added a NoBuild fallback to `scripts/start-server-and-wait.ps1` to copy `net8.0/win-x64/SMServer.exe` to `net8.0/SMServer.exe` when present.
- Added an integration pre-start copy in the workflow to copy RID exe into framework-root after artifact download.
- Fixed POSIX-style path parse errors in `scripts/start-server-and-wait.ps1` so the Linux parse-check step succeeds.
- Re-ran and polled CI runs and downloaded artifacts for run `21332908208` and `21333071826` for inspection.

## Observed failures

- The CI run artifacts for `21333071826` include test summaries and enriched reports but do not include the published server artifact (`published-server-win-x64`). Integration tests failed with a small number of 404s; missing server binary is likely a primary cause when integration expects `SMServer.exe` in the framework root.

## Suggested immediate fixes

- Ensure build job creates and uploads a `publish-sentinel.txt` alongside the RID output archive and that artifact upload globs include `server/USBDeviceManager/bin/Release/net8.0/win-x64/**` AND `server/USBDeviceManager/bin/Release/net8.0/SMServer.exe`.
- Alternatively add a workflow step in the integration job to explicitly copy `win-x64/SMServer.exe` into `net8.0/SMServer.exe` immediately after the artifact download (already added defensively; ensure upload is present).
- If artifacts continue to be absent, add logging to the build job to print the output tree prior to upload and fail the job if expected files are missing.

## Findings from run `21333071826`

- Downloaded artifacts: summaries and enriched reports were present under `artifacts/ci-run-21333071826`.
- Missing artifact: no `published-server-win-x64` artifact (the published server binary was not present in the downloaded snapshot).
- Consequence: integration tests showed a small number of 404s; missing `SMServer.exe` (or the binary being in `net8.0/win-x64/` but not copied to `net8.0/`) is the likely cause.

## Where I saved evidence locally

- Downloaded run artifacts: `artifacts/ci-run-21333071826/`.

If you want, I can (a) modify the build job to force the upload and re-run CI now, or (b) open an issue summarizing the artifact gap and attach the downloaded run artifacts for human review. Tell me which and I'll proceed.
