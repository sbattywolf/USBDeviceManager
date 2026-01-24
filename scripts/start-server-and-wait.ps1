param(
    [string]$ProjectPath = "server/USBDeviceManager",
    [int]$Port = 5000,
    [int]$TimeoutSec = 180,
    [switch]$NoBuild
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$tmpDir = Join-Path $scriptDir "tmp"
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

# Load shared utilities (safe date parsing, etc.) if available
$utilsPath = Join-Path $scriptDir 'utils.ps1'
if (Test-Path $utilsPath) { . $utilsPath }

# Prefer explicit IPv4 loopback binding to avoid localhost IPv6/IPv4
# resolution differences on CI runners. Can be overridden with env var
# `CI_BIND_ADDRESS` if necessary.
$bindAddress = $Env:CI_BIND_ADDRESS
if ([string]::IsNullOrWhiteSpace($bindAddress)) { $bindAddress = '127.0.0.1' }

$WriteHostMsg = "Starting server project: $ProjectPath on port $Port (binding: $bindAddress)"
Write-Host $WriteHostMsg

$dotnetArgs = "run --project `"$ProjectPath`" --urls http://$($bindAddress):$Port"
if ($NoBuild) { $dotnetArgs += ' --no-build' }

$outFile = Join-Path $tmpDir "server.log"
$errFile = Join-Path $tmpDir "server.err.log"

# Ensure log files exist so CI artifact upload can pick them up even if the
# process exits quickly and Start-Process hasn't flushed output yet. If the
# files are already present and locked by a running process, leave them alone.
if (-not (Test-Path $outFile)) { New-Item -Path $outFile -ItemType File -Force | Out-Null }
# Note: no placeholder files created here to avoid leaving temporary artifacts in CI.
if (-not (Test-Path $errFile)) { New-Item -Path $errFile -ItemType File -Force | Out-Null }

try {
    $startArgs = $dotnetArgs
    Write-Host "Launching: dotnet $startArgs"
    $proc = Start-Process -FilePath dotnet -ArgumentList $startArgs -WorkingDirectory $PWD.Path -RedirectStandardOutput $outFile -RedirectStandardError $errFile -PassThru
    Set-Content -Path (Join-Path $tmpDir "server.pid") -Value $proc.Id
    Write-Host "Server started (pid $($proc.Id)), waiting for health..."
} catch {
    Write-Error "Failed to start server process: $_"
    Write-Host "Attempting to capture any available output files..."
    if (Test-Path $outFile) { Write-Host "Server stdout (partial):"; Get-Content $outFile -Tail 200 }
    if (Test-Path $errFile) { Write-Host "Server stderr (partial):"; Get-Content $errFile -Tail 200 }
    exit 1
}

# Give the server a short moment; if it exits immediately capture output
# early so diagnostics are available in CI artifacts.
Start-Sleep -Seconds 3
try {
    $p = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
} catch { $p = $null }
if (-not $p) {
    Write-Error "Server process $($proc.Id) terminated early; printing available logs to console."
    if (Test-Path $outFile) { Write-Host '--- server.out (tail 200) ---'; Get-Content $outFile -Tail 200 }
    if (Test-Path $errFile) { Write-Host '--- server.err (tail 200) ---'; Get-Content $errFile -Tail 200 }
    exit 1
}

# Invoke health check with defensive diagnostics; catch parameter binding errors
$healthUrl = "http://$($bindAddress):$Port/api/health"
try {
    & "$scriptDir/poll-health.ps1" -Url $healthUrl -TimeoutSec $TimeoutSec
    $phExit = $LASTEXITCODE
} catch {
    Write-Error "Exception while invoking poll-health.ps1: $($_.Exception.Message)"
    if ($_.Exception -is [System.Management.Automation.ParameterBindingException]) {
        Write-Error "Parameter binding failure details: $($_.Exception | Out-String)"
    }
    Write-Host "Dumping environment and recent logs to help triage:"
    Write-Host "Health URL: $healthUrl"
    Write-Host "Process Id: $($proc.Id)"
    Write-Host "Invocation: $($MyInvocation.Line)"
    Write-Host '--- env vars (selected) ---'
    'CI_BIND_ADDRESS','TEST_PORT','GITHUB_RUN_ID' | ForEach-Object { Write-Host "$_ = $($Env:$_)" }
    if (Test-Path $outFile) { Write-Host '--- server.out (tail 200) ---'; Get-Content $outFile -Tail 200 }
    if (Test-Path $errFile) { Write-Host '--- server.err (tail 200) ---'; Get-Content $errFile -Tail 200 }
    exit 1
}

if ($phExit -ne 0) {
    Write-Error "Server did not become healthy within timeout ($TimeoutSec seconds). Printing available logs to console."
    if (Test-Path $outFile) { Write-Host '--- server.out (tail 200) ---'; Get-Content $outFile -Tail 200 }
    if (Test-Path $errFile) { Write-Host '--- server.err (tail 200) ---'; Get-Content $errFile -Tail 200 }
    exit 1
}

Write-Host "Server healthy and ready: http://$($bindAddress):$Port"
exit 0
