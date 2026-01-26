Recommended local dependencies and quick install steps (Windows)

1) .NET 8 SDK (required to build/run server)
- Install via official installer: https://dotnet.microsoft.com/en-us/download/dotnet/8.0
- Or use winget:

```powershell
winget install --id Microsoft.DotNet.SDK.8 -e --source winget
```

2) dotnet-ef (optional, for EF migrations / tools)

```powershell
dotnet tool install --global dotnet-ef
# or update
dotnet tool update --global dotnet-ef
```

3) Git (to manage repo)

```powershell
winget install --id Git.Git -e --source winget
```

4) PowerShell for Agent
- The PowerShell Agent is written against Windows PowerShell (5.1) APIs (class syntax, `System.Web.HttpUtility`).
- If you plan to run the agent on PowerShell 7+ you will need to adapt a few types (e.g. replace `System.Web.HttpUtility` with `System.Net.WebUtility` or `[Uri]::UnescapeDataString`).
- Windows usually ships with PowerShell 5.1. To install PowerShell 7 (optional):

```powershell
winget install --id Microsoft.Powershell -e --source winget
```

5) Development extras (recommended)
- Visual Studio 2022/2023 with .NET workloads, or VS Code + C# extension
- SQLite DB browser (optional)

6) Build & run the server

```powershell
cd server/USBDeviceManager
dotnet restore
dotnet build
dotnet run
```

7) Run the PowerShell agent (Windows PowerShell recommended)

```powershell
cd agent/SimRacingAgent
# Configure (interactive)
./SimRacingAgent.ps1 -Configure
# Start
./SimRacingAgent.ps1 -Start
```

8) Run tests

Server:
```powershell
cd server/USBDeviceManager.Tests
dotnet test
```

Agent (PowerShell tests):
```powershell
cd agent/SimRacingAgent.Tests
./TestRunner.ps1
```

Notes and troubleshooting
- Ensure `dotnet` is on your PATH after installing the SDK (`dotnet --info`).
- If the agent hits missing types like `System.Web.HttpUtility` on PowerShell 7, run it in Windows PowerShell 5.1 or update the module code to use `System.Net.WebUtility`.
- If you need to use EF migrations interactively, install `dotnet-ef` and run `dotnet ef migrations add Init` from the server project folder.

If you'd like, I can:
- Run a deeper automated scan for obsolete using directives and missing assembly references.
- Update the agent for PowerShell 7 compatibility (replace `System.Web.HttpUtility` usage), or
- Run the build/tests in this environment and report failures.
