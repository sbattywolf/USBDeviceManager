# Architecture Overview

This document summarizes the high-level architecture of the project (Agent + Server), major components, and runtime data flows. It consolidates scattered documentation into a single reference.

## Components
- Agent: PowerShell-based Windows client located under `agent/SimRacingAgent`.
- Server: ASP.NET Core dashboard and API under `server/SimRacingDashboard`.
- Shared docs and configs: moved to `docs/shared` for consolidated documentation.

## High-level Diagram
```mermaid
flowchart LR
  subgraph Agent
    A1[SimRacingAgent.ps1]
    A2[AgentCore.psm1]
    A3[USBMonitor.psm1]
    A4[ProcessManager.psm1]
    A5[AdapterStubs/TestFramework]
  end

  subgraph Server
    S1[SimRacingDashboard API]
    S2[EF Core DB]
    S3[MonitoringHub (SignalR)]
  end

  A1 --> A2
  A2 --> A3
  A2 --> A4
  A3 -->|Telemetry PUT| S1
  A4 -->|Telemetry PUT| S1
  S1 --> S2
  S1 --> S3
  S3 -->|Realtime UI| Clients

  classDef agent fill:#f9f,stroke:#333,stroke-width:1px;
  class Agent agent
  class Server fill:#9ff,stroke:#333,stroke-width:1px;
```

## Data Flows
- Agent collects device/process metrics and sends PUT requests to Server endpoints under `/healthcheck`.
- Server persists telemetry via EF Core then broadcasts updates via SignalR to dashboard clients.
- Tests use `TestFramework` which injects mocks into agent modules via `$Global:MockFunctions` to avoid creating global function wrappers.

## Where to find code
- Agent modules: `agent/src/modules/`
- Agent tests & harness: `agent/SimRacingAgent.Tests/`
- Server app: `server/SimRacingDashboard/`

## Recommended Developer Workflow
1. Run unit tests locally (agent):
```powershell
Set-Location agent\SimRacingAgent.Tests\Unit
Import-Module .\AgentMonitoringTests.ps1 -Force
Invoke-AgentMonitoringTests
```
2. Run server tests and app:
```powershell
Set-Location server\SimRacingDashboard
dotnet test
dotnet run
```

## Next steps
- Add CI script to run both agent and server tests on Windows runner.
- Create a short onboarding `docs/getting-started.md` with local dev quickstart steps.
- Consolidate remaining scattered README notes into `docs/`.
