param(
    [string] $HealthUrl = 'http://localhost:5000/api/configs',
    [int] $TimeoutSec = 30,
    [int] $IntervalSec = 2,
    [string] $MetricsFile
)

Write-Host "Running smoke health check against $HealthUrl (timeout ${TimeoutSec}s)"
$start = Get-Date
$sw = [System.Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
    try {
        $resp = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        if ($resp.StatusCode -eq 200) {
            $end = Get-Date
            $dur = (New-TimeSpan -Start $start -End $end).TotalMilliseconds
            Write-Host "Health check succeeded (200) in $([math]::Round($dur,0)) ms."
            if ($MetricsFile) { "health_check,$($start.ToString('o')),$($end.ToString('o')),$([math]::Round($dur,0)),0,OK" | Out-File -FilePath $MetricsFile -Append -Encoding utf8 }
            exit 0
        } else {
            Write-Host "Health check returned status $($resp.StatusCode); retrying..."
        }
    } catch {
        Write-Host "Health check attempt failed: $($_.Exception.Message)"
    }
    Start-Sleep -Seconds $IntervalSec
}

$end = Get-Date
$dur = (New-TimeSpan -Start $start -End $end).TotalMilliseconds
Write-Error "Health check timed out after ${TimeoutSec}s waiting for $HealthUrl"
if ($MetricsFile) { "health_check,$($start.ToString('o')),$($end.ToString('o')),$([math]::Round($dur,0)),3,Timeout" | Out-File -FilePath $MetricsFile -Append -Encoding utf8 }
exit 3
