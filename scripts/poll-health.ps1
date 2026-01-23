param(
    [Parameter(Mandatory=$true)]
    [string]$Url,
    [int]$TimeoutSec = 60
)

$start = Get-Date
Write-Host "Polling health: $Url (timeout ${TimeoutSec}s)"
while ((Get-Date) -lt $start.AddSeconds($TimeoutSec)) {
    try {
        $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        if ($resp.StatusCode -eq 200) {
            Write-Host "Health OK: $Url"
            exit 0
        }
    } catch {
        Start-Sleep -Seconds 1
    }
}
Write-Error "Timeout waiting for health at $Url"
exit 1
