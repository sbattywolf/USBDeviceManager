param(
	[string] $MetricsFile
)

New-Item -ItemType Directory -Force -Path .\artifacts\test-results | Out-Null

# Pre-check: ensure SMServer binary is present in expected build output
$expectedServer = Join-Path $PSScriptRoot "..\..\server\USBDeviceManager\bin\Debug\net8.0\SMServer.exe"
if (-not (Test-Path $expectedServer)) {
	Write-Error "SMServer.exe not found at expected path: $expectedServer"
	Write-Error "Ensure the server is published to the test artifact location or update CI build to place the binary there."
	if ($MetricsFile) { "precheck,$(Get-Date -Format o),$(Get-Date -Format o),0,2,SMServer.exe missing" | Out-File -FilePath $MetricsFile -Append -Encoding utf8 }
	exit 2
}

# Optional: run a lightweight health check (poll /api/configs) to validate server readiness before tests.
# This expects the test harness to start the server; if you need the script to start the server, do that separately.
$healthCheckScript = Join-Path $PSScriptRoot "smoke_health_check.ps1"
if (Test-Path $healthCheckScript) {
	$hcStart = Get-Date
	& powershell -NoProfile -ExecutionPolicy Bypass -File $healthCheckScript -HealthUrl 'http://localhost:5000/api/configs' -TimeoutSec 30 -MetricsFile $MetricsFile
	$hcEnd = Get-Date
	$hcDur = (New-TimeSpan -Start $hcStart -End $hcEnd).TotalMilliseconds
	if ($MetricsFile) { "health_check,$($hcStart.ToString('o')),$($hcEnd.ToString('o')),$([math]::Round($hcDur,0)),$LASTEXITCODE," | Out-File -FilePath $MetricsFile -Append -Encoding utf8 }
	if ($LASTEXITCODE -ne 0) {
		Write-Error "Health check failed. Aborting test run."
		exit $LASTEXITCODE
	}
} else {
	Write-Host "Health check script not found; skipping health check. ($healthCheckScript)"
}

# Build (no restore; restore handled earlier)
Write-Host "Building AgentE2E.Tests..."
$buildStart = Get-Date
dotnet build server/AgentE2E.Tests/AgentE2E.Tests.csproj --configuration Release --no-restore
$buildEnd = Get-Date
$buildDur = (New-TimeSpan -Start $buildStart -End $buildEnd).TotalMilliseconds
if ($MetricsFile) { "build_agent_e2e,$($buildStart.ToString('o')),$($buildEnd.ToString('o')),$([math]::Round($buildDur,0)),0," | Out-File -FilePath $MetricsFile -Append -Encoding utf8 }

# Run tests and write TRX into artifacts/test-results
Write-Host "Running AgentE2E tests..."
$testStart = Get-Date
dotnet test server/AgentE2E.Tests/AgentE2E.Tests.csproj --configuration Debug --logger "trx;LogFileName=AgentE2E.selfhost.trx" --results-directory .\artifacts\test-results
$testEnd = Get-Date
$testDur = (New-TimeSpan -Start $testStart -End $testEnd).TotalMilliseconds
if ($MetricsFile) { "agent_e2e_tests,$($testStart.ToString('o')),$($testEnd.ToString('o')),$([math]::Round($testDur,0)),$LASTEXITCODE," | Out-File -FilePath $MetricsFile -Append -Encoding utf8 }
