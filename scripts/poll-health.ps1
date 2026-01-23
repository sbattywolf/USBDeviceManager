param(
    [Parameter(Mandatory=$true)]
    [string]$Url,
    [int]$TimeoutSec = 60
)

$start = Get-Date
Write-Host "Polling health: $Url (timeout ${TimeoutSec}s)"
while ((Get-Date) -lt $start.AddSeconds($TimeoutSec)) {
    $attemptUrls = @($Url)
    # If the URL contains localhost or an IP loopback literal, also try
    # the common IPv4/IPv6 loopback variants to avoid binding differences
    # on runners.
    if ($Url -match 'localhost') {
        $attemptUrls += ($Url -replace 'localhost','127.0.0.1')
        $attemptUrls += ($Url -replace 'localhost','[::1]')
    } elseif ($Url -match '\[::1\]' -or $Url -match '::1') {
        $attemptUrls += ($Url -replace '\[::1\]','127.0.0.1') -replace '::1','127.0.0.1'
    } elseif ($Url -match '127\.0\.0\.1') {
        # also try IPv6 literal form
        $attemptUrls += ($Url -replace '127.0.0.1','[::1]')
        $attemptUrls += ($Url -replace '127.0.0.1','::1')
    }

    # Expand attempts: for any URL that contains a plain '/health' path, also
    # try the '/api/health' variant to be tolerant of callers using either.
    $expanded = @()
    foreach ($u in $attemptUrls) {
        $expanded += $u
        if ($u -match '/health' -and $u -notmatch '/api/health') {
            $apiVariant = $u -replace '/health','/api/health'
            $expanded += $apiVariant
        }
    }

    foreach ($u in $expanded) {
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

