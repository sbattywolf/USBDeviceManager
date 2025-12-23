param(
    [string]$Port = "5006",
    [int]$TimeoutSeconds = 60
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$proj = Join-Path $scriptDir ".."
$proj = [System.IO.Path]::GetFullPath($proj)
Write-Host "Project dir: $proj"

Write-Host "Building project..."
dotnet build $proj -c Debug

$urls = "http://localhost:$Port"
$startInfo = @{ FilePath = "dotnet"; ArgumentList = @('run','--no-build','--urls',$urls); WorkingDirectory = $proj }
$proc = Start-Process @startInfo -PassThru

try {
    $base = "http://localhost:$Port"
    Write-Host "Waiting for server at $base..."
    $ready = $false
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while (-not $ready -and $sw.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        try {
            $r = Invoke-WebRequest -Uri "$base/api/configs" -Method GET -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
            if ($r.StatusCode -eq 200) { $ready = $true; break }
        } catch { Start-Sleep -Milliseconds 500 }
    }
    if (-not $ready) { throw "Server did not start in time" }

    Write-Host "Server ready - running smoke requests..."

    # GET endpoints
    Invoke-WebRequest -Uri "$base/api/configs" -Method GET -UseBasicParsing
    Invoke-WebRequest -Uri "$base/api/logs" -Method GET -UseBasicParsing
    try { Invoke-WebRequest -Uri "$base/api/agent/download" -Method GET -UseBasicParsing } catch { Write-Host "agent download may not be available" }

    # POST a log
    $log = '{"deviceId":"SMOKE-DEV","eventType":"CONNECTED","message":"smoke"}'
    $r1 = Invoke-WebRequest -Uri "$base/api/logs" -Method POST -Body $log -ContentType 'application/json' -UseBasicParsing -ErrorAction Stop
    Write-Host "POST /api/logs status: $($r1.StatusCode)"

    # POST a config
    $cfg = '{"triggerPath":"C:\\Temp\\smoke.exe","softwareName":"SmokeApp"}'
    $r2 = Invoke-WebRequest -Uri "$base/api/configs" -Method POST -Body $cfg -ContentType 'application/json' -UseBasicParsing -ErrorAction Stop
    Write-Host "POST /api/configs status: $($r2.StatusCode)"

    Write-Host "All smoke checks passed."
} finally {
    if ($proc -and -not $proc.HasExited) {
        Write-Host "Stopping server (PID $($proc.Id))..."
        Stop-Process -Id $proc.Id -Force
    }
}
