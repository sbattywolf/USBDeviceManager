# Getting Started

This quickstart shows how to run the server and agent tests and start the server locally for development.

## Prerequisites
- Windows 10/11 (PowerShell 5.1 for the agent tests)
- .NET SDK 8 (for server build/tests)
- Git

## Run agent unit tests
Open a PowerShell (5.1) prompt and run:

```powershell
# Use repository-root relative paths so these commands work on any machine.
Set-Location <REPO_ROOT>/agent/SimRacingAgent.Tests/Unit
# or, from the repository root:
# cd agent/SimRacingAgent.Tests/Unit
Import-Module .\AgentMonitoringTests.ps1 -Force
Invoke-AgentMonitoringTests
```

## Run server tests
From a developer PowerShell or terminal with dotnet available:

```powershell
Set-Location <REPO_ROOT>/server/USBDeviceManager
dotnet test
```

## Run both quickly (CI script)
A helper script is provided at `ci/run-tests.ps1`. It will:
- Run `dotnet test` in the server (if `dotnet` exists)
- Run the agent PowerShell unit tests

To run:

```powershell
Set-Location <REPO_ROOT>
.\ci\run-tests.ps1
```

## Useful file locations
- Agent modules: `agent/src/modules/`
- Agent tests and harness: `agent/SimRacingAgent.Tests/`
-- Server app: `server/USBDeviceManager/`
- Documentation: `docs/` and `docs/shared/`

If you need me to add CI pipeline YAML for GitHub Actions or Azure Pipelines, I can scaffold that next.