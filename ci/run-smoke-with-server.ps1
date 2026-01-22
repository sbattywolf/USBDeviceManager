# Start server, wait for health, run smoke test, then stop server
$serverProc = Start-Process -FilePath 'dotnet' -ArgumentList @('run','--project','server/USBDeviceManager','--urls','http://localhost:5000') -PassThru
Start-Sleep -Seconds 2

$up = $false
for ($i=0; $i -lt 30; $i++) {
    try {
        $r = Invoke-WebRequest -Uri 'http://localhost:5000/api/devices' -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
        if ($r.StatusCode -eq 200) { $up = $true; break }
    } catch { }
    Start-Sleep -Seconds 1
}

if (-not $up) {
    Write-Host 'ERROR: Server did not start within timeout.'
    if ($serverProc -and $serverProc.Id) { Stop-Process -Id $serverProc.Id -Force -ErrorAction SilentlyContinue }
    exit 2
}

Write-Host 'Server is up; running smoke-test.ps1'
powershell -NoProfile -ExecutionPolicy Bypass -File ci/smoke-test.ps1

Write-Host 'Stopping server'
if ($serverProc -and $serverProc.Id) { Stop-Process -Id $serverProc.Id -Force -ErrorAction SilentlyContinue }
exit 0
