# End-to-End Test Plan — USB Device Manager

Purpose
- Verify full application behavior: agent ↔ server ↔ GUI and device interactions.

Prerequisites
- Windows machine with admin rights for device simulation.
- Repository checked out at workspace root.
- Agent running (see `scripts/run-agent.ps1`).
- .NET 8 SDK installed and on PATH for server/GUI.
- PowerShell 5.1+ available for agent scripts.

Key endpoints & artifacts
- GUI/dashboard: http://localhost:5000
- API docs: http://localhost:5000/swagger
- Server log: server/USBDeviceManager/dashboard.log
- Agent log: agent/SimRacingAgent/agent-run.log
- Database: server/USBDeviceManager/simracing.db

Test data and reset commands
- To reset local DB (destructive): remove `server/USBDeviceManager/simracing.db` and restart server.
- To seed data: use API POST /api/devices or use tests/fixtures in test projects.

High-level flows (test cases)

1) Smoke: Dashboard available
- Steps: Open http://localhost:5000 and /swagger
- Expected: Dashboard loads, swagger page returns 200
- Artifacts: screenshot, server dashboard.log lines

2) Agent Heartbeat
- Steps: Ensure agent running; watch agent log for heartbeat POST to /api/agents/{id}/heartbeat.
- Validate: server API accepts heartbeat (200). Query DB for agent status.
- Commands:
  - Tail agent log: `Get-Content agent/SimRacingAgent/agent-run.log -Wait`
  - Check API: `Invoke-WebRequest http://localhost:5000/api/agents` (or use Swagger)

3) Device lifecycle (Create → Read → Update → Delete)
- Steps:
  - Create a device via POST /api/devices with minimal valid payload.
  - Confirm API returns 201 and Location header.
  - GET the device and verify fields.
  - Update device fields (PUT) and verify persisted changes.
  - DELETE device and verify it is removed.
- Expected: All operations return appropriate status codes and DB reflects changes.
- Verification: Query `simracing.db` (SQLite) using `sqlite3` or GUI tool.

4) Device detection end-to-end (Agent-detected)
- Steps:
  - Attach a physical USB device or simulate via the agent (if a simulation tool exists).
  - Confirm `Get-USBDevices` detection in agent log and POST /api/devices or /api/agents/{id}/events.
  - Confirm device appears in GUI and DB.
- Expected: Device shows up in GUI within a few seconds; server records device status.

5) Toggle/Control from GUI to Agent
- Steps:
  - In GUI, toggle device enable/disable.
  - Observe server API request and agent reaction (agent should poll or receive callback depending on architecture).
  - Verify device state change in agent log and DB.
- Expected: Toggle flows from GUI to server to agent and back; no errors.

6) Automation workflows (Rule execution)
- Steps:
  - Create automation rule in GUI (or POST /api/automation) that triggers on device+software condition and performs an action (e.g., start software or log event).
  - Trigger the condition (attach device or simulate event).
  - Verify rule executed: action performed and logs show success.
- Expected: Rules execute reliably and in correct order.

7) Error & recovery tests
- Network failure: stop server transiently, ensure agent retries heartbeats and recovers when server returns.
- WMI failure: simulate WMI error for agent and confirm agent handles gracefully (no crash) and reports status.

8) Security / Negative tests
- Send malformed API payloads; server should return 4xx and not crash.
- Verify authentication/authorization (if enabled) for protected endpoints.

9) Performance / Load (optional)
- Simulate multiple agents/devices (50+) and measure server responsiveness and DB behavior.

Observability & Debugging
- Logs:
  - `server/USBDeviceManager/dashboard.log`
  - `agent/SimRacingAgent/agent-run.log`
- DB: `server/USBDeviceManager/simracing.db` (use `sqlite3` or DB Browser for SQLite)
- To run server in Debug configuration and attach a debugger: `dotnet run -c Debug` inside `server/USBDeviceManager`.

Manual test checklist (step-by-step)
1. Ensure agent is running: check `agent/SimRacingAgent/agent-run.log` and heartbeats.
2. Ensure server is running: open http://localhost:5000 and confirm swagger.
3. Ensure GUI loads device list.
4. Create a test device via GUI; verify DB and GUI reflect it.
5. Attach a USB device and verify detection end-to-end.
6. Create an automation rule and validate execution.
7. Run error scenarios and confirm graceful handling.

Tickets / Escalation points
- If agent cannot reach dashboard: check firewall/port blocking and server process.
- If DB locked: check permissions on `simracing.db` and restart server.

Appendix: Useful commands
```powershell
# Start agent (foreground)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run-agent.ps1

# Start GUI / server (foreground)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run-gui.ps1

# Reset DB
Remove-Item server/USBDeviceManager/simracing.db -Force

# Tail logs
Get-Content server/USBDeviceManager/dashboard.log -Wait
Get-Content agent/SimRacingAgent/agent-run.log -Wait
```

Contact
- Ask me to run any of the above steps or to automate E2E runs. 
