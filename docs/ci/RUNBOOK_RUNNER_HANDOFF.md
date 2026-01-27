# Runner Operator Handoff — Self-hosted Windows Runner

Purpose
- Provide the operator with a short, copyable runbook to prepare a self-hosted Windows runner for E2E CI.

Prerequisites
- Admin access on the runner host (for system-wide .NET install) is preferred.
- A clone of this repository available on the runner host.

Quick checklist (recommended order)

1. Stop any manually-started test server (operator)

```powershell
# in the terminal where you started the server: Ctrl+C then close the shell
# otherwise find and stop by name or PID
Get-Process | Where-Object { $_.ProcessName -like '*USBDeviceManager*' } | Select-Object Id,ProcessName,StartTime
Stop-Process -Id <PID> -Confirm:$false
```

2. Run automated prep as Administrator (preferred)

```powershell
# from the repo clone on the runner host (elevated PowerShell)
cd E:\Workspaces\Git\SimRacing\USBDeviceManager\scripts\ci
powershell -NoProfile -ExecutionPolicy Bypass -File .\prepare_and_restart_runner.ps1 -RunnerDir 'C:\actions-runner'
```

What this does
- If elevated: calls `install_dotnet_on_runner.ps1` to install .NET 8 to `C:\Program Files\dotnet`, then restarts the runner service (best-effort).
- If non-elevated: attempts a non-admin user-local install to `C:\dotnet` and starts the runner interactively if no service is present.
- Writes logs to `C:\ci-artifacts\forensics\<timestamp>` for post-run review.

3. If the service restart fails, start the runner interactively

```powershell
cd C:\actions-runner
.\run.cmd
```

4. Confirm runner is Online in GitHub: Repository → Settings → Actions → Runners

5. Start or allow the test server to be launched by CI

```powershell
# example: start server after runner is ready
cd C:\path\to\server\build\output
Start-Process -FilePath dotnet -ArgumentList 'USBDeviceManager.dll' -NoNewWindow -PassThru
```

Troubleshooting
- If `Restart-Service` fails because the service cannot stop, collect logs and escalate to a privileged operator; ensure no running `Runner.Listener` processes remain.
- If `dotnet` still missing after admin install, reboot the machine and re-run `dotnet --info`.

Links
- Automation PR (scripts + docs): see PR #61

Contact
- Add notes to `C:\ci-artifacts\forensics\<timestamp>/notes.txt` describing what you ran and any manual steps performed.
