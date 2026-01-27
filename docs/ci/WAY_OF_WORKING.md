**Way Of Working (CI) — Non-interactive runs & forensics**

Purpose
- Short guidance for running CI-related tasks non-interactively, capturing forensics, and managing externally started services/processes used during local or runner investigations.

Non-interactive prompts
- Always prefer flags that avoid prompts (examples used in repo): `--no-restore`, `--no-build`, `--verbosity minimal`.
- When a tool may prompt, run it under an explicit non-interactive mode or provide environment variables that suppress prompts.
- For scripted admin tasks that require consent, produce an annotated script and ask an operator to run it interactively.

Record run IDs & terminal commands
- Capture key run identifiers and full commands in `ci-artifacts/forensics/<YYYYMMDD-HHMMSS>/`.
- Minimum items to save for each investigation:
  - `run-id.txt` — GitHub Actions run ID or local session label
  - `cmds.txt` — the exact commands run (copied from the terminal history)
  - `full-log.txt` — concatenated runner logs or `gh run view <id> --log` output

Example collection commands
```powershell
$stamp = (Get-Date -Format 'yyyyMMdd-HHmmss')
$dir = "ci-artifacts/forensics/$stamp"
New-Item -ItemType Directory -Path $dir -Force | Out-Null
Set-Content -Path "$dir/run-id.txt" -Value "$env:GITHUB_RUN_ID"
Get-History | Out-File "$dir/cmds.txt"
gh run view $env:LAST_RUN_ID --log > "$dir/full-log.txt"
```

Managing an external server session (power-user checklist)
- If you started the server in a visible PowerShell window with `dotnet run` or `.oo.exe`: stop with Ctrl+C and then close the terminal.
- If the server was backgrounded or persists after closing the terminal, find and stop it:
```powershell
# find process
Get-Process | Where-Object { $_.ProcessName -like '*USBDeviceManager*' } | Select-Object Id,ProcessName,StartTime

# stop by PID
Stop-Process -Id <PID> -Confirm:$false
```
- If you used `Start-Process -NoNewWindow -PassThru` capture the returned `Id` in a file so you can later `Stop-Process` by that PID.
- If the app was installed as a Windows Service:
```powershell
Get-Service -Name '*USBDeviceManager*' -ErrorAction SilentlyContinue
Stop-Service -Name NameOfService -Force
sc.exe delete NameOfService
```
- Preserve logs first (copy to `ci-artifacts/forensics/<stamp>/logs`) before stopping the process.

Credential helper / push warnings
- The `git: 'credential-manager-core' is not a git command` message means Git tried to use a credential helper that is missing. If pushes succeed you can ignore it, otherwise:
  - Install Git Credential Manager (recommended): https://aka.ms/gcm/latest
  - Or set credentials manually via `git config --global credential.helper manager-core` after installing.

Notes and traceability
- Add a short note file in the same forensics dir describing why the session was started and any manual interventions (`notes.txt`).
- Keep entries concise and machine-parsable where possible (JSON or key=value blocks) to allow later automation.

Where to put things
- Forensics and logs: `ci-artifacts/forensics/<YYYYMMDD-HHMMSS>/`
- Temporary investigator files: `ci-artifacts/archive/<branch>/<stamp>/`

When in doubt
- Do not remove or uninstall system runtimes on a shared runner host without coordination; prefer documenting the issue and requesting a privileged operator to make changes.

**Runner maintenance runbook**

When preparing a self-hosted Windows runner for CI (recommended order):

- Step 1 — Stop any manually-started server process (operator): keep the server stopped while preparing the runner.
  ```powershell
  # if running in a visible terminal use Ctrl+C then close the shell
  # otherwise find and stop the process by name or PID
  Get-Process | Where-Object { $_.ProcessName -like '*USBDeviceManager*' } | Select-Object Id,ProcessName,StartTime
  Stop-Process -Id <PID> -Confirm:$false
  ```

- Step 2 — Run the automated prep as Administrator (preferred). This installs .NET (system-wide) if needed and restarts the runner service.
  ```powershell
  # from the repo clone on the runner host (elevated PowerShell)
  cd E:\Workspaces\Git\SimRacing\USBDeviceManager\scripts\ci
  powershell -NoProfile -ExecutionPolicy Bypass -File .\prepare_and_restart_runner.ps1 -RunnerDir 'C:\actions-runner'
  ```

- Step 3 — If the service restart fails, start the runner interactively (temporary, non-service mode):
  ```powershell
  cd C:\actions-runner
  .\run.cmd
  ```

- Step 4 — Once the runner is confirmed Online in GitHub Actions, restart or start the test server as required for E2E (or let the test job launch it).
  ```powershell
  # start server (example)
  cd C:\path\to\server\build\output
  Start-Process -FilePath dotnet -ArgumentList 'USBDeviceManager.dll' -NoNewWindow -PassThru
  ```

Notes
- Keep the server stopped while restarting the runner service to avoid port conflicts.
- Non-admin fallback: `prepare_and_restart_runner.ps1` attempts a user-local install to `C:\dotnet` if run without elevation; prefer the admin run for a system-wide install.
- All prep logs are written to `C:\ci-artifacts\forensics\<timestamp>` by the automation script for post-mortem.
