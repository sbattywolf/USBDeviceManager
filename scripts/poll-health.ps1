param(
    [Parameter(Mandatory=$true)]
    [string]$Url,
    [int]$TimeoutSec = 60,
    [int]$PerAttemptTimeout = 5
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
# Load shared utilities (safe date parsing, etc.) if available
$utilsPath = Join-Path $scriptDir 'utils.ps1'
if (Test-Path $utilsPath) { . $utilsPath }

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
            try {
                $resp = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec $PerAttemptTimeout -ErrorAction Stop
            } catch {
                # If Uri parsing failed due to unbracketed IPv6, try bracketed form once
                $errMsg = $_.Exception.Message
                if ($errMsg -and $u -match 'http://::[0-9]') {
                    $tryBracket = $u -replace 'http://(::[0-9]+)','http://[$1]'
                    Write-Host "Retrying with bracketed IPv6: $tryBracket"
                    try { $resp = Invoke-WebRequest -Uri $tryBracket -UseBasicParsing -TimeoutSec $PerAttemptTimeout -ErrorAction Stop } catch { throw }
                } else { throw }
            }
            if ($resp.StatusCode -eq 200) {
                Write-Host "Health OK: $u"
                exit 0
            } else {
                Write-Host "Health returned $($resp.StatusCode) for $u"
            }
        } catch {
            $lastErr = $_.Exception.Message
            Write-Host "Health check failed for ${u}: $lastErr"
            if ($_.Exception -is [System.Management.Automation.ParameterBindingException]) {
                Write-Error "Parameter binding failure in poll-health: $($_.Exception | Out-String)"
            }
            # continue to next variant
        }
    }

    # Exponential backoff (cap at 8s) before next overall attempt
    # Use floating-point overloads to avoid PowerShell attempting to
    # convert large pow results to Int32 (which can overflow, e.g. 2^33).
    $sleepSeconds = [int][math]::Min(8.0, [math]::Pow(2.0, [int]($attempt - 1)))
    Write-Host "Attempted variants; sleeping ${sleepSeconds}s before retry. (elapsed $([int]((Get-Date) - $start).TotalSeconds)s)"
    Start-Sleep -Seconds $sleepSeconds
}
Write-Error "Timeout waiting for health at $Url"
exit 1

