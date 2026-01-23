Adds CI step to run `server/AgentHeartbeat.Tests` and upload its TRX artifact.

Changes included in this branch:
- CI workflow: `.github/workflows/ci.yml` — runs the isolated `AgentHeartbeat` test project and includes its TRX in uploaded artifacts.
- New test project: `server/AgentHeartbeat.Tests` (unit tests for `AgentsController` heartbeat policy).
- Minor test fixes: updated global usings and ensured `appsettings.Testing.json` is copied to test output so functional/integration tests run in CI.

Local verification: ran `dotnet test` for the solution locally — `USBDeviceManager.Tests` passed (68/68) and the isolated `AgentHeartbeat.Tests` passed.

Please review the CI change; this keeps the new isolated tests exercised independently while we continue stabilizing the larger server test graph.
