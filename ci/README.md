# CI orchestrator

This folder contains a simple CI orchestrator and usage notes.

- `run-ci.ps1` - PowerShell script that starts the server, waits for it, runs the agent PowerShell tests and the server `dotnet test`, collects logs and TRX files into an artifacts folder, and stops the server.

Quick local run (from repository root):

```powershell
# run with defaults
powershell -NoProfile -ExecutionPolicy Bypass -File ci/run-ci.ps1

# specify artifacts directory
powershell -NoProfile -ExecutionPolicy Bypass -File ci/run-ci.ps1 -ArtifactsDir artifacts/local-ci
```

Notes:
- The script assumes a Windows runner with `dotnet` and PowerShell available.
- The GitHub Actions workflow is defined at `.github/workflows/ci.yml` and invokes the script on `windows-latest`.
- If the agent test runner path differs in your workspace, adjust the `$agentScript` variable inside `run-ci.ps1`.
