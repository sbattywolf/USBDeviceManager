# Agent Modes and Server Policy

This document describes the `AgentMode` configuration and the server's behavior when deciding whether to accept or reject agent registration/heartbeats.

## AgentMode values

- `External` (default):
  - The server accepts connections and heartbeats from external agents running on other machines or the same host.
  - The server will not attempt to start or host an agent process.

- `Embedded`:
  - The server may start and host a local agent process (child process) for tight integration.
  - When an embedded/local agent process is active, the server will reject heartbeats and registration attempts from remote agents to enforce a single-agent-per-PC rule.
  - The server's UI will expose controls to start/stop the embedded agent and will persist the chosen `AgentMode` in `config/service-config.json`.

- `Disabled`:
  - Agent functionality is disabled. The server will reject agent heartbeats and registration attempts while in this mode.

## Server behavior and HTTP responses

- If `AgentMode == "Embedded"` and a local embedded agent process is running, the server returns HTTP `409 Conflict` for remote heartbeats with JSON `{ status: "conflict", reason: "embedded_agent_active" }`.
- If `AgentMode == "Disabled"`, the server returns HTTP `403 Forbidden` for agent heartbeats/registration attempts.
- Otherwise (default `External` mode), the server accepts heartbeats and returns `200 OK`.

## Admin guidance

- To switch modes, use the Settings page in the Dashboard (Settings → Agent). Changing to `Embedded` will not automatically start the agent unless `AutostartAgent` is enabled or you explicitly start it via the UI.
- To allow a remote agent to register on a machine currently hosting an embedded agent, first stop the embedded agent via the UI (`Settings → Agent → Stop Agent`), then switch `AgentMode` to `External` and save.
- To completely disable agent interactions (for maintenance), set `AgentMode` to `Disabled`.

## Troubleshooting

- If a remote agent is unable to connect and receives HTTP 409, check the Dashboard Settings to see if the server is in `Embedded` mode and that a local agent process is active.
- Logs for the embedded agent process are available via the server UI and under `server/USBDeviceManager/logs/` (or the configured log location).

