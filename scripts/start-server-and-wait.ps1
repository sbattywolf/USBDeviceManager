param(
    [string]$ProjectPath = "server/USBDeviceManager",
    [int]$Port = 5000,
    [int]$TimeoutSec = 90,
    [switch]$NoBuild,
    [string]$LogFile = ""
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$tmpDir = Join-Path $scriptDir "tmp"
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

$args = "run --project `"$ProjectPath`" --urls http://localhost:$Port"
Write-Host "Starting server project: $ProjectPath on port $Port"
if ($NoBuild) { $args += ' --no-build' }

# Ensure log file path
if ([string]::IsNullOrWhiteSpace($LogFile)) {
    $logFile = Join-Path $tmpDir "server.log"
} else {
    $logFile = $LogFile
}

Write-Host "Server log: $logFile"

# Start the server and redirect stdout/stderr to log files so startup errors are captured
$errFile = Join-Path $tmpDir "server.err.log"
$startInfo = @{
    FilePath = 'dotnet'
    ArgumentList = $args
    WorkingDirectory = (Get-Location).Path
    RedirectStandardOutput = $logFile
    RedirectStandardError  = $errFile
    NoNewWindow = $true
    PassThru = $true
}

$proc = Start-Process @startInfo
Set-Content -Path (Join-Path $tmpDir "server.pid") -Value $proc.Id
Write-Host "Server started (pid $($proc.Id)), waiting for health..."
Write-Host "Stdout: $logFile" -ForegroundColor DarkGreen
Write-Host "Stderr: $errFile" -ForegroundColor DarkYellow

# Poll the API health endpoint (the app exposes `/api/health`).
& "$scriptDir/poll-health.ps1" -Url "http://localhost:$Port/api/health" -TimeoutSec $TimeoutSec

if ($LASTEXITCODE -ne 0) {
    Write-Error "Server did not become healthy within timeout. See server output."
    exit 1
}

Write-Host "Server healthy and ready: http://localhost:$Port"
exit 0
