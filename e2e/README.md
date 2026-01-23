E2E harness (scaffold)

Purpose
- Lightweight harness for local end-to-end testing: starts the server in test mode and runs a simulated agent that posts heartbeats and simple device events.

Usage (local developer machine, Windows PowerShell):

1. Start the server in a background terminal (listens on localhost:5000):

```powershell
# from repo root
dotnet run --project server/USBDeviceManager --urls "http://localhost:5000"
```

2. In a separate terminal, run the simulated agent to post a heartbeat:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\e2e\sim_agent.ps1 -ServerUrl http://localhost:5000
```

Scripts
- `run_e2e_local.ps1` — launches server (background) and runs `sim_agent.ps1`.
- `sim_agent.ps1` — posts a registration and heartbeat to the server API. Adjust `-ServerUrl` if your server runs on a different port.

Notes
- This scaffold is intentionally minimal: it demonstrates orchestration and can be extended to include device simulation, file uploads, and verification assertions.

Next steps
- Add an automated `dotnet test` project that uses `WebApplicationFactory` to start the server in-memory and a .NET test client to simulate the agent programmatically.
