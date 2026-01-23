# Running E2E tests on a self-hosted Windows runner

This document explains how to configure a self-hosted Windows runner for running the repository's E2E tests (`server/AgentE2E.Tests`). Use this when you need reproducible Windows E2E runs (for example to run WebView/WinUI PoC or Windows-only scenarios).

Prerequisites
- A machine (Windows Server / Windows 10+) with administrative access.
- .NET 8 SDK installed and available on PATH.
- A GitHub repository admin or maintainer to create/attach the runner.
- Optional: Visual Studio C++ redistributable if your tests require native libraries.

Recommended runner labels
- `self-hosted` (required by GitHub)
- `Windows` (platform tag)
- `e2e` (custom label used by our workflow)

Registering the runner
1. In your GitHub repo, go to Settings → Actions → Runners → New self-hosted runner.
2. Choose the OS `Windows` and follow the provided instructions. When registering, add the label `e2e` (or edit labels after registration).
3. Run the registration script on the runner machine. Example (PowerShell) steps from GitHub will look like:

```powershell
# from the instructions GitHub shows for your repo
.\config.cmd --url https://github.com/<owner>/<repo> --token <TOKEN> --labels "self-hosted,Windows,e2e"
.\run.cmd
```

Running the runner as a service
- To keep the runner available across reboots, install it as a Windows service (instructions are shown by the runner after configuration):

```powershell
.in\svc.sh install
.in\svc.sh start
```

Security notes
- Run the runner under a dedicated service account with minimum privileges.
- Keep the machine patched and isolated if it will execute untrusted PR code.

How to trigger the E2E job
- We added a manual workflow at `.github/workflows/e2e-self-hosted.yml`. Trigger it from the Actions tab by selecting the workflow and clicking "Run workflow".

- Running E2E tests locally (developer)
- To run the same E2E tests locally on your development machine:

```powershell
dotnet test server/AgentE2E.Tests/AgentE2E.Tests.csproj --logger "trx;LogFileName=AgentE2E.local.trx"
```

Validate runner prerequisites locally
------------------------------------
Use the helper script to validate a Windows machine before registering it as a self-hosted runner. The script performs basic checks and can perform a quick `dotnet restore` + `dotnet build` for the E2E project:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass .\scripts\check-e2e-runner.ps1 -RunBuild
```

Exit codes:
- `0` = success
- `2` = git missing
- `3` = dotnet missing
- `4` = dotnet SDK enumeration failed
- `10` = unexpected error during checks


Collecting artifacts
- The workflow uploads TRX files as an action artifact named `agent-e2e-selfhost`.
- You can also run the tests locally and inspect the generated TRX under `server/AgentE2E.Tests/TestResults`.

Troubleshooting
- If the runner reports missing .NET SDK, verify `dotnet --info` on the runner and install .NET 8.
- If tests fail intermittently, check the TRX and the server logs under `server/` for exceptions.

Contact
- Ask repo maintainers to add the runner or to approve runner registration if organization policies restrict self-hosted runners.
