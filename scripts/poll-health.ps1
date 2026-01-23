param(
    [Parameter(Mandatory=$true)][string]$Url,
    [int]$IntervalSec = 2,
    [int]$TimeoutSec = 60
)

$start = Get-Date
Write-Host "Polling health endpoint: $Url (timeout ${TimeoutSec}s, interval ${IntervalSec}s)"

while ((Get-Date) -lt $start.AddSeconds($TimeoutSec)) {
    try {
        $resp = Invoke-WebRequest -UseBasicParsing -Uri $Url -Method Get -TimeoutSec 5 -ErrorAction Stop
        if ($resp.StatusCode -eq 200) {
            Write-Host "Health check OK (200)"
            exit 0
        }
        else {
            Write-Host "Health check returned status $($resp.StatusCode); retrying..."
        }
    }
    catch {
        Write-Host "Health check failed: $($_.Exception.Message); retrying..."
    }

    Start-Sleep -Seconds $IntervalSec
}

Write-Error "Health check did not return success within $TimeoutSec seconds"
exit 1
