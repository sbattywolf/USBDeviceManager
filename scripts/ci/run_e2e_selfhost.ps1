New-Item -ItemType Directory -Force -Path .\artifacts\test-results | Out-Null

# Pre-check: ensure SMServer binary is present in expected build output
$expectedServer = Join-Path $PSScriptRoot "..\..\server\USBDeviceManager\bin\Debug\net8.0\SMServer.exe"
if (-not (Test-Path $expectedServer)) {
	Write-Error "SMServer.exe not found at expected path: $expectedServer"
	Write-Error "Ensure the server is published to the test artifact location or update CI build to place the binary there."
	exit 2
}

# Optional: run a lightweight health check (poll /api/configs) to validate server readiness before tests.
# This expects the test harness to start the server; if you need the script to start the server, do that separately.
$healthCheckScript = Join-Path $PSScriptRoot "smoke_health_check.ps1"
if (Test-Path $healthCheckScript) {
	& powershell -NoProfile -ExecutionPolicy Bypass -File $healthCheckScript -HealthUrl 'http://localhost:5000/api/configs' -TimeoutSec 30
	if ($LASTEXITCODE -ne 0) {
		Write-Error "Health check failed. Aborting test run."
		exit $LASTEXITCODE
	}
} else {
	Write-Host "Health check script not found; skipping health check. ($healthCheckScript)"
}

# Build (no restore; restore handled earlier)
dotnet build server/AgentE2E.Tests/AgentE2E.Tests.csproj --configuration Release --no-restore

# Run tests and write TRX into artifacts/test-results
dotnet test server/AgentE2E.Tests/AgentE2E.Tests.csproj --configuration Debug --logger "trx;LogFileName=AgentE2E.selfhost.trx" --results-directory .\artifacts\test-results
