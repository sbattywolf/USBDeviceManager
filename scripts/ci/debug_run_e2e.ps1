$runDir = 'artifacts/test-results/20260128_013739'
$diag = Join-Path $runDir 'diagnostics'
New-Item -ItemType Directory -Force -Path $diag | Out-Null

$dll = 'server/USBDeviceManager/bin/Release/net8.0/SMServer.dll'
if (-not (Test-Path $dll)) {
    Write-Error "SMServer.dll not found at expected path: $dll"
    exit 2
}

Write-Host "Starting server via background job (captures at $diag/server.log)"
$dllAbs = (Resolve-Path $dll).Path
$diagAbs = (Resolve-Path $diag).Path
$logFile = Join-Path $diagAbs 'server.log'
$job = Start-Job -Name SMServerDebug -ScriptBlock {
    param($dllPath, $logFile)
    try {
        $env:TEST_PORT = '5000'
        Set-Location (Split-Path $dllPath)
        dotnet $dllPath *>&1 | Out-File $logFile -Encoding utf8
    } catch {
        "[JOB-ERROR] $_" | Out-File $logFile -Append -Encoding utf8
    }
} -ArgumentList $dllAbs, $logFile

Start-Sleep -Seconds 4
Write-Host "Started job id: $($job.Id) name: $($job.Name)"

# Record port bindings for likely ports
netstat -a -n -o | Select-String ':5000|:5006' | Out-File (Join-Path $diag 'netstat_ports.txt')
$job | Get-Job | Out-File (Join-Path $diag 'server.job.txt')

# Run health check
Write-Host 'Running smoke health check (http://localhost:5000/api/configs)'
& "$PSScriptRoot\smoke_health_check.ps1" -HealthUrl 'http://localhost:5000/api/configs' -TimeoutSec 30 -MetricsFile (Join-Path $runDir 'metrics.csv')
$hc = $LASTEXITCODE
Write-Host "Health check exit code: $hc"

Stop-Job -Name SMServerDebug -ErrorAction SilentlyContinue
Receive-Job -Name SMServerDebug -Keep | Out-File (Join-Path $diagAbs 'server.job.output.txt') -Encoding utf8
Write-Host 'Server job stopped; logs at:' $logFile
exit $hc
