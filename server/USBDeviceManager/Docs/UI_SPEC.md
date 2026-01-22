# UI Spec — Dashboard

Purpose
- Define pages, components, data contracts, API mappings, SignalR events, and minimal wireframes for the USBDeviceManager dashboard.

Pages (top-level)
- Overview: health checks, system summary, quick actions.
- Devices: list, details, enable/disable toggle, status history.
- Software: list of managed software, start/stop/restart controls, run status and PID.
- Automation: rules list, create/edit automation rules, run/trigger actions.
- Logs: recent server log tailing and live log stream via SignalR.
- Settings: environment and logging configuration, agent download endpoint.

Component Responsibilities
- `DeviceList` — fetch `/api/devices`, render rows with `Toggle` control that POSTs JSON boolean to `/api/devices/{id}/toggle`.
- `DeviceDetail` — fetch device status/history `/api/devices/{id}/status` and `/api/devices/{id}/status/history`.
- `SoftwareList` — fetch `/api/software`, render start/stop buttons that POST to `/api/software/{id}/start` and `/api/software/{id}/stop`.
- `AutomationEditor` — CRUD automation rules (client-side model; server support TBD).
- `LogViewer` — initial GET `api/logs/recent`, subscribe to SignalR `LogLine` events for live updates.
- `HealthCard` — GET `api/health` and show status.

Data Models (client-side DTOs)
- DeviceSummary: { int Id, string Name, bool Enabled, string Status }
- SoftwareSummary: { int Id, string Name, string ExecutablePath, string Status, int? ProcessId }
- Health: { string status }

API Mappings (quick)
- GET `/api/health` -> `HealthCard`
- GET `/api/devices` -> `DeviceList` (returns array of DeviceSummary or full model)
- POST `/api/devices/{id}/toggle` with body `true|false` (JSON boolean)
- GET `/api/devices/{id}/status` and `/status/history` -> `DeviceDetail`
- GET `/api/software` -> `SoftwareList`
- POST `/api/software/{id}/start` -> start; body optional (use server contract)
- POST `/api/software/{id}/stop` -> stop
- GET `/api/agent/download` -> provide download link in `Settings`
- POST `/api/agents/{id}/heartbeat` -> used by agent status indicator

SignalR (MonitoringHub)
- Hub path: `/hubs/monitoring`
- Events to subscribe to:
  - `DeviceUpdated` (payload: DeviceSummary)
  - `SoftwareUpdated` (payload: SoftwareSummary)
  - `LogLine` (payload: { string Line, DateTime Timestamp, string Level })
  - `AgentHeartbeat` (payload: { Guid AgentId, DateTime Timestamp })

Navigation & Layout
- Top/side nav with tabs: Overview | Devices | Software | Automation | Logs | Settings
- Each page uses a single-column content area with small cards for items and a right-side details drawer for selected item.

Minimal Wireframes (text)
- Overview: [HealthCard] [Quick Actions: Reload devices, Run scan] [Recent log lines]
- Devices: [DeviceList]
  - Row actions: Toggle (switch), Details (open drawer)
- Software: [SoftwareList]
  - Row actions: Start / Stop / Restart
- Logs: [LogViewer] — scrollable pre element with auto-scroll toggle

Accessibility & UX
- Buttons have aria-labels; toggles are keyboard operable; color contrast for status chips.

Testing Notes
- Unit: component rendering and API-mocking for `DeviceList` and `SoftwareList`.
- Integration: smoke test sequence — GET `/api/health`, GET `/api/devices`, POST toggle, GET `/api/software`, POST start (use smoke exe path), verify SignalR events are received.

Next Tasks
1. Implement `Services/DashboardClient` (HttpClient wrapper + HubConnection factory).
2. Convert `Pages/*` scaffolds into components using `DeviceList`/`SoftwareList` and wire `DashboardClient`.
3. Add basic test harness for smoke scenarios (PowerShell or xUnit integration tests).

Notes
- Server endpoints exist and were inspected; some server behaviors require valid executable paths for software start — use a smoke exe for testing.
