# Troubleshooting: self-hosted runner & re-registration

This guide covers common issues encountered when working with the Windows self-hosted Actions runner and steps we used during the 2026-01-27 sanitization work.

1) Symptom: Runner name shows personal machine name (e.g. `LITTLE_BEAST`) in job setup logs
   - Cause: The self-hosted runner registration includes the machine name provided at registration.
   - Fix: Re-register or rename the runner with a sanitized name.

2) Symptom: `config.cmd` not found when running from PowerShell
   - Cause: You are not in the runner installation folder.
   - Fix: Find the runner folder and run `config.cmd` from there. Example search command (PowerShell):
     ```powershell
     Get-ChildItem -Path C:\actions-runner,C:\runner,E:\actions-runner,E:\Workspaces -Filter config.cmd -Recurse -ErrorAction SilentlyContinue | Select-Object -First 5 -ExpandProperty FullName
     ```

3) Symptom: Service stop/delete succeeded but `config.cmd` still not found
   - Cause: You executed service commands from a different working directory.
   - Fix: `Set-Location` to the runner folder and run `.
un.cmd` or `.
un.cmd remove` as needed.

4) Symptom: Need to re-register runner securely (avoid pasting PATs in console)
   - Use the repo-admin PAT stored in a secret vault (Bitwarden recommended) and the included helper script `scripts/runner/register-runner-from-bitwarden.ps1`.
   - Steps summary:
     1. Install Bitwarden CLI (`bw`) and login/unlock on the runner host.
     2. Store your repo-admin PAT in Bitwarden (password field) under a clear item name.
     3. Run the supplied script from an elevated PowerShell prompt, passing `-Owner`, `-Repo`, `-BWItem` (the Bitwarden item name), `-RunnerName`, and `-RunnerFolder`.
     4. After successful `config.cmd` registration, install/start the service from Git Bash:
        ```bash
        ./svc.sh install
        ./svc.sh start
        ```

5) Symptom: Runner job fails and TRX not uploaded (example: `SMServer.exe` missing)
   - Fix: Ensure the CI build step copies the server binary to the expected path before the E2E step. Update `scripts/ci/run_e2e_selfhost.ps1` to fail early and create a small diagnostic artifact that will be uploaded even on failure:
     ```powershell
     if (-not (Test-Path $expectedServerExe)) {
       Write-Warning "SMServer.exe missing at $expectedServerExe"
       New-Item -Path $env:GITHUB_WORKSPACE\test-results -ItemType Directory -Force
       'SMServer.exe missing' | Out-File -FilePath .\test-results\missing-server.txt
       Exit 1
     }
     ```

6) Verify artifacts after a run
   - Use `gh run download <run-id> --dir artifacts_run<run-id>` to fetch artifacts for inspection.
   - Search downloaded TRX/logs for tokens using PowerShell `Select-String`:
     ```powershell
     Select-String -Path "artifacts_run<run-id>\\**\\*" -Pattern 'LITTLE_BEAST|sbatt|sbattywolf|BRNMTHF|Sbatta' -AllMatches
     ```

7) If you require log redaction or deletion
   - GitHub-hosted run logs cannot be edited by maintainers; options:
     - Delete the run from the Actions UI (repo admin) to remove its artifacts/logs.
     - Contact GitHub Support if you need official redaction.

8) Security notes
   - Registration tokens are short lived — use automation (Bitwarden + script) to avoid manual copy/paste.
   - Keep repo-admin PATs and vault credentials tightly controlled and never commit them to the repo.

9) Quick checklist to prepare a runner for E2E runs
   - Runner installed and registered (sanitized name).
   - `SMServer.exe` built and placed in the server path before E2E step.
   - `test-results` path exists and CI uploads TRX/artifacts per job.

If you want, I can open a small PR that adds a short `README.md` under `scripts/runner/` pointing to `register-runner-from-bitwarden.ps1` and including the quick commands above.
