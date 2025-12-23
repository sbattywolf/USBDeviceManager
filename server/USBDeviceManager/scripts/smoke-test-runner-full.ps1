<#
Feature-rich smoke test runner for SimRacingDashboard

Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\smoke-test-runner-full.ps1 [-Port 5006] [-TimeoutSeconds 90] [-NoBuild] [-KeepRunning] [-BuildConfig Debug|Release] [-Verbose]
#>

param(
    [int]$Port = 5006,
    [int]$TimeoutSeconds = 90,
    [switch]$NoBuild,
    [switch]$KeepRunning,
    [ValidateSet('Debug','Release')][string]$BuildConfig = 'Debug',
    [int]$WaitIntervalMs = 500,
    [string]$LogFile = '.\\smoke-results-full.log',
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$proj = Join-Path $scriptDir '..'
$proj = [System.IO.Path]::GetFullPath($proj)
Write-Host "Project dir: $proj"

function Log([string]$m) {
    $timestamp = (Get-Date).ToString('o')
    $line = "$timestamp `t $m"
    if ($Verbose) { Write-Host $line }
    $line | Out-File -FilePath $LogFile -Append -Encoding utf8
}

function Start-Server {
    param($urls)
    Log "Starting server with urls=$urls"
    $args = @('run','--no-build','--urls',$urls)
    $startInfo = @{ FilePath = 'dotnet'; ArgumentList = $args; WorkingDirectory = $proj }
    $proc = Start-Process @startInfo -PassThru
    return $proc
}

function Wait-ForReady {
    param($baseUrl, $timeoutSeconds)
    Log "Waiting up to $timeoutSeconds seconds for $baseUrl/api/configs"
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $timeoutSeconds) {
        try {
            $resp = Invoke-WebRequest -Uri "$baseUrl/api/configs" -Method GET -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
            if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 300) { Log "Server ready (status $($resp.StatusCode))"; return $true }
        } catch {
            Start-Sleep -Milliseconds $WaitIntervalMs
        }
    }
    Log "Server not ready after $timeoutSeconds seconds"
    return $false
}

function Do-Request {
    param(
        [string]$Method,
        [string]$Path,
        [string]$Body = $null,
        [int[]]$ExpectedStatus = @()
    )
    $uri = "$Base$Path"
    try {
        if ($Body) { $r = Invoke-WebRequest -Uri $uri -Method $Method -Body $Body -ContentType 'application/json' -UseBasicParsing -ErrorAction Stop }
        else { $r = Invoke-WebRequest -Uri $uri -Method $Method -UseBasicParsing -ErrorAction Stop }
        $status = $r.StatusCode
        Log "$Method $Path -> $status"
        if ($ExpectedStatus.Count -gt 0 -and -not ($ExpectedStatus -contains $status)) {
            Log ("Unexpected status for {0}: {1} (expected {2})" -f $Path, $status, ($ExpectedStatus -join ','))
            return @{ Ok = $false; Response = $r }
        }
        return @{ Ok = $true; Response = $r }
    } catch {
        Log "$Method $Path -> ERROR: $($_.Exception.Message)"
        return @{ Ok = $false; Exception = $_ }
    }
}

# Build
if (-not $NoBuild) {
    Log "Building ($BuildConfig)..."
    dotnet build $proj -c $BuildConfig | Out-String | ForEach-Object { Log $_ }
}

$Base = "http://localhost:$Port"
$proc = Start-Server -urls $Base

$success = $false
try {
    if (-not (Wait-ForReady -baseUrl $Base -timeoutSeconds $TimeoutSeconds)) { throw 'Server failed to become ready' }

    # Checks
    $check1 = Do-Request -Method 'GET' -Path '/api/configs' -ExpectedStatus @(200)
    if (-not $check1.Ok) { throw 'GET /api/configs failed' }

    $check2 = Do-Request -Method 'GET' -Path '/api/logs' -ExpectedStatus @(200)
    if (-not $check2.Ok) { throw 'GET /api/logs failed' }

    $agentCheck = Do-Request -Method 'GET' -Path '/api/agent/download' -ExpectedStatus @(200)
    if (-not $agentCheck.Ok) { Log 'Agent download check returned non-200 (may be OK if agent not present)' }

    # POST log
    $logPayload = '{"deviceId":"SMOKE-FULL","eventType":"CONNECTED","message":"smoke-full"}'
    $p1 = Do-Request -Method 'POST' -Path '/api/logs' -Body $logPayload -ExpectedStatus @(201)
    if (-not $p1.Ok) { throw 'POST /api/logs failed' }

    # POST config
    $cfgPayload = '{"triggerPath":"C:\\Temp\\smoke-full.exe","softwareName":"SmokeFull"}'
    $p2 = Do-Request -Method 'POST' -Path '/api/configs' -Body $cfgPayload -ExpectedStatus @(201)
    if (-not $p2.Ok) { throw 'POST /api/configs failed' }

    $success = $true
    Log 'All smoke-full checks passed.'

    if ($KeepRunning) { Log "Leaving server running (pid $($proc.Id))"; exit 0 }

} catch {
    Log "ERROR: $($_.ToString())"
    if ($p1 -and $p1.Response) { Log "Last response body:"; $p1.Response.Content | Out-String | ForEach-Object { Log $_ } }
    exit 2
} finally {
    if ($proc -and -not $proc.HasExited -and -not $KeepRunning) {
        Log "Stopping server (PID $($proc.Id))"
        Stop-Process -Id $proc.Id -Force
    }
}

if ($success) { exit 0 } else { exit 3 }
