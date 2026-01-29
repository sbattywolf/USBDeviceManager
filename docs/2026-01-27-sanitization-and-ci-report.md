# Sanitization & CI activity — 2026-01-27

Summary
- Branch: `ci/sanitize-personal-info` — sanitization scripts authored and applied.
- PR created with sanitization changes and description: PR #69.
- Backups: `.sanitize-backup/` contains original files backed up before edits.
- Replacements applied: `LITTLE_BEAST -> BRNMTHF`, `sbatt`/`sbattywolf`/`sbattywolf` -> `Sbatta` (deterministic mapping).

What I did today
- Created and ran PowerShell sanitization scripts to replace personal tokens and redact run JSONs.
- Committed changes to `ci/sanitize-personal-info` and opened PR #69 against repository default branch.
- Downloaded and inspected CI artifacts from several runs; located TRX artifacts and scanned them for the replacement tokens.
- Dispatched the `CI` workflow on `ci/sanitize-personal-info` to verify artifact uploads.
- Investigated a failing self-hosted E2E run (21413310879) and confirmed failure due to missing `SMServer.exe` (no TRX uploaded).
- Implemented a runner re-registration workflow and added `scripts/runner/register-runner-from-bitwarden.ps1` to assist secure re-registration using Bitwarden CLI.

Important verification results
- Scanned TRX artifacts from run `21410131619`: no occurrences of `LITTLE_BEAST`, `sbatt`, `sbattywolf`, `BRNMTHF`, or `Sbatta` were found.
- Run `21413310879` failed with exit code 2; log shows `SMServer.exe` missing and no TRX artifacts uploaded.

Files added
- `scripts/runner/register-runner-from-bitwarden.ps1` — automated secure runner registration helper.
- `docs/2026-01-27-sanitization-and-ci-report.md` (this file).
- `docs/troubleshooting-runner.md` (detailed troubleshooting guide — see next file).

Next recommended actions
- Fix `SMServer.exe` packaging or CI pre-step so E2E job can find the binary and upload TRX.
- Re-register or rename the self-hosted runner to a sanitized name before running more jobs (runner name appears in job setup logs).
- Re-run the full CI that produces TRX on `ci/sanitize-personal-info`, then download and scan the TRX artifacts from that run.

Status
- Sanitization changes committed and PR created.
- CI verification in-progress — waiting for a successful TRX-producing run on `ci/sanitize-personal-info`.
