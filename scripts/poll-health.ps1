param(
    [Parameter(Mandatory=$true)]
    [string]$Url,
    [int]$TimeoutSec = 60,
    [int]$PerAttemptTimeout = 5
)

$start = Get-Date
Write-Host "Polling health: $Url (overall timeout ${TimeoutSec}s, per-attempt timeout ${PerAttemptTimeout}s)"
while ((Get-Date) -lt $start.AddSeconds($TimeoutSec)) {
    $attempt = [int]((Get-Date) - $start).TotalSeconds + 1
    $attemptUrls = @($Url)
    # If the URL contains localhost or an IP loopback literal, also try
    # the common IPv4/IPv6 loopback variants to avoid binding differences
    # on runners.
    if ($Url -match 'localhost') {
        $attemptUrls += ($Url -replace 'localhost','127.0.0.1')
        $attemptUrls += ($Url -replace 'localhost','[::1]')
    } elseif ($Url -match '\[::1\]' -or $Url -match '::1') {
        # Normalize IPv6 literal variants: try bracketed form and IPv4 loopback
        $attemptUrls += ($Url -replace '\[::1\]','127.0.0.1')
        $attemptUrls += ($Url -replace '::1','[::1]')
    } elseif ($Url -match '127\\.0\\.0\\.1') {
        # also try IPv6 literal form (bracketed) but avoid unbracketed '::1'
        $attemptUrls += ($Url -replace '127.0.0.1','[::1]')
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

    $lastErr = $null
    foreach ($u in $expanded) {
        try {
            Write-Host "Trying: $u"
            $resp = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec $PerAttemptTimeout -ErrorAction Stop
            if ($resp.StatusCode -eq 200) {
                Write-Host "Health OK: $u"
                exit 0
            } else {
                Write-Host "Health returned $($resp.StatusCode) for $u"
            }
        } catch {
            $lastErr = $_.Exception.Message
            Write-Host "Health check failed for ${u}: $lastErr"
            # continue to next variant
        }
    }

    # Exponential backoff (cap at 8s) before next overall attempt
    $sleepSeconds = [int][math]::Min(8, [math]::Pow(2, [int]($attempt - 1)))
    Write-Host "Attempted variants; sleeping ${sleepSeconds}s before retry. (elapsed $([int](Get-Date - $start).TotalSeconds)s)"
    Start-Sleep -Seconds $sleepSeconds
}
Write-Error "Timeout waiting for health at $Url"
exit 1

