param()
$ErrorActionPreference = 'Stop'

# Pick an available TCP port for TEST_PORT
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback,0)
$listener.Start()
$port = ($listener.LocalEndpoint -as [System.Net.IPEndPoint]).Port
$listener.Stop()

Write-Host "TEST_PORT=$port"
$env:TEST_PORT = $port

if (Test-Path ./scripts/start-server-and-wait.ps1) {
    Write-Host 'Starting server via scripts/start-server-and-wait.ps1'
    $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwshCmd) { $pwshPath = $pwshCmd.Source } else { $pwshPath = $null }
    if (-not $pwshPath) {
        $psCmd = Get-Command powershell -ErrorAction SilentlyContinue
        if ($psCmd) { $pwshPath = $psCmd.Source } else { $pwshPath = $null }
    }
    if ($pwshPath) {
        Start-Process -FilePath $pwshPath -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','./scripts/start-server-and-wait.ps1','-NonInteractive','-Port',$port -NoNewWindow -PassThru | Out-File -FilePath ./scripts/server-start-proc.txt -Append
        Start-Sleep -Seconds 5
    } else {
        Write-Host 'No pwsh/powershell executable found on PATH; cannot start server.'
    }
} else {
    Write-Host 'No start-server-and-wait.ps1 found; skipping server start.'
}

Write-Host 'Running E2E Heartbeat test (single)'
dotnet test server/AgentE2E.Tests/AgentE2E.Tests.csproj --configuration Debug --filter "FullyQualifiedName=USBDeviceManager.Tests.Integration.Regression.HeartbeatRegressionTests.Heartbeat_Post_WithLegacySchema_ShouldReturnOk" --logger "trx;LogFileName=local-Heartbeat.trx"

Write-Host 'Running ShellRunner cancellation unit test (single)'
dotnet test USBDeviceManager.sln --configuration Debug --filter "FullyQualifiedName=USBDeviceManager.Tests.Unit.Adapters.ShellRunnerTests.RunAsync_Cancellation_TriggersTaskCanceled" --logger "trx;LogFileName=local-shellrunner.trx"

Write-Host 'Local repro script completed.'

# CI trigger timestamp: 2026-01-24T00:00:00Z
