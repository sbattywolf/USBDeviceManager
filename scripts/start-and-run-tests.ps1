$port=5000

# Check if port is listening
$t = Test-NetConnection -ComputerName 127.0.0.1 -Port $port -WarningAction SilentlyContinue
if (-not $t.TcpTestSucceeded) {
    Write-Host 'Server not listening; starting dotnet server...'
    Start-Process -FilePath 'dotnet' -ArgumentList 'run','--project','server/USBDeviceManager','--urls','http://localhost:5000' -WorkingDirectory 'E:\Workspaces\Git\SimRacing\USBDeviceManager' -PassThru | Out-Null
    Start-Sleep -Seconds 3
}

# Wait up to 30s for the server to be listening
$sw = [System.Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalSeconds -lt 30) {
    $t = Test-NetConnection -ComputerName 127.0.0.1 -Port $port -WarningAction SilentlyContinue
    if ($t.TcpTestSucceeded) { Write-Host "Server is listening on port $port"; break }
    Start-Sleep -Seconds 1
}

if (-not $t.TcpTestSucceeded) {
    Write-Host 'Server did not start listening within timeout'
    exit 1
}

Write-Host 'Running TestRunner...'
PowerShell -NoProfile -ExecutionPolicy Bypass -File .\agent\SimRacingAgent.Tests\TestRunner.ps1
