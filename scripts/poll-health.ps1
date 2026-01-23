param(
    [Parameter(Mandatory=$true)]
    [string]$Url,
    [int]$TimeoutSec = 60
)

$start = Get-Date
Write-Host "Polling health: $Url (timeout ${TimeoutSec}s)"
while ((Get-Date) -lt $start.AddSeconds($TimeoutSec)) {
    $attemptUrls = @($Url)
    # If the URL contains localhost, also try IPv4 and IPv6 variants to
    # avoid binding differences on runners.
    if ($Url -match "localhost") {
        $attemptUrls += ($Url -replace 'localhost','127.0.0.1')
        # IPv6 localhost may require brackets for URIs
        $attemptUrls += ($Url -replace 'localhost','[::1]')
    }

    $succeeded = $false
    foreach ($u in $attemptUrls) {
        try {
            $resp = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            if ($resp.StatusCode -eq 200) {
                Write-Host "Health OK: $u"
                exit 0
            }
        } catch {
            # continue to next variant
        }
    }
    Start-Sleep -Seconds 1
}
Write-Error "Timeout waiting for health at $Url"
exit 1
