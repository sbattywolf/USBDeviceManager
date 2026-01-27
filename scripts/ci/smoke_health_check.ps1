param(
    [string] $HealthUrl = 'http://localhost:5000/api/configs',
    [int] $TimeoutSec = 30,
    [int] $IntervalSec = 2
)

Write-Host "Running smoke health check against $HealthUrl (timeout ${TimeoutSec}s)"
$sw = [System.Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
    try {
        $resp = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        if ($resp.StatusCode -eq 200) {
            Write-Host "Health check succeeded (200)."
            exit 0
        } else {
            Write-Host "Health check returned status $($resp.StatusCode); retrying..."
        }
    } catch {
        Write-Host "Health check attempt failed: $($_.Exception.Message)"
    }
    Start-Sleep -Seconds $IntervalSec
}

Write-Error "Health check timed out after ${TimeoutSec}s waiting for $HealthUrl"
exit 3
