param(
    [int]$Port = 5006,
    [int]$TimeoutSeconds = 60,
    [switch]$NoBuild,
    [switch]$KeepRunning,
    [string]$LogFile = ".\smoke-results.log",
    [switch]$Verbose
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$proj = Join-Path $scriptDir ".."
$proj = [System.IO.Path]::GetFullPath($proj)
Write-Host "Project dir: $proj"

if (-not $NoBuild) {
    Write-Host "Building project..."
    dotnet build $proj -c Debug
}

$urls = "http://localhost:$Port"
$startInfo = @{ FilePath = "dotnet"; ArgumentList = @('run','--no-build','--urls',$urls); WorkingDirectory = $proj }
$proc = Start-Process @startInfo -PassThru

function Log { param($m) if ($Verbose) { Write-Host $m } $m | Out-File -FilePath $LogFile -Append -Encoding utf8 }

try {
    $base = $urls
    Log "Waiting for server at $base..."
    $ready = $false
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while (-not $ready -and $sw.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        try {
            $r = Invoke-WebRequest -Uri "$base/api/configs" -Method GET -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
            if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 300) { $ready = $true; break }
        } catch { Start-Sleep -Milliseconds 500 }
    }
    if (-not $ready) { Log "Server did not start in time"; throw "Server did not start in time" }

    Log "Server ready - running smoke requests..."

    # GET endpoints
    $r = Invoke-WebRequest -Uri "$base/api/configs" -Method GET -UseBasicParsing
    Log "GET /api/configs -> $($r.StatusCode)"

    $r = Invoke-WebRequest -Uri "$base/api/logs" -Method GET -UseBasicParsing
    Log "GET /api/logs -> $($r.StatusCode)"

    try { $r = Invoke-WebRequest -Uri "$base/api/agent/download" -Method GET -UseBasicParsing -TimeoutSec 5; Log "GET /api/agent/download -> $($r.StatusCode)" } catch { Log "GET /api/agent/download -> not available: $($_.Exception.Message)" }

    # POST a log
    $log = '{"deviceId":"SMOKE-DEV","eventType":"CONNECTED","message":"smoke"}'
    $r1 = Invoke-WebRequest -Uri "$base/api/logs" -Method POST -Body $log -ContentType 'application/json' -UseBasicParsing -ErrorAction Stop
    Log "POST /api/logs -> $($r1.StatusCode)"

    # POST a config
    $cfg = '{"triggerPath":"C:\\Temp\\smoke.exe","softwareName":"SmokeApp"}'
    $r2 = Invoke-WebRequest -Uri "$base/api/configs" -Method POST -Body $cfg -ContentType 'application/json' -UseBasicParsing -ErrorAction Stop
    Log "POST /api/configs -> $($r2.StatusCode)"

    Log "All smoke checks passed."
    if ($KeepRunning) { Log "Leaving server running (pid $($proc.Id))"; exit 0 }

} finally {
    if ($proc -and -not $proc.HasExited -and -not $KeepRunning) {
        Write-Host "Stopping server (PID $($proc.Id))..."
        Stop-Process -Id $proc.Id -Force
    }
}
