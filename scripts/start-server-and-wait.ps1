param(
    [string]$ProjectPath = "server/USBDeviceManager",
    [int]$Port = 5000,
    [int]$TimeoutSec = 90,
    [switch]$NoBuild
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$tmpDir = Join-Path $scriptDir "tmp"
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

Write-Host "Starting server project: $ProjectPath on port $Port"

$args = "run --project `"$ProjectPath`" --urls http://localhost:$Port"
if ($NoBuild) { $args += ' --no-build' }

$proc = Start-Process -FilePath dotnet -ArgumentList $args -WorkingDirectory $PWD -PassThru
Set-Content -Path (Join-Path $tmpDir "server.pid") -Value $proc.Id
Write-Host "Server started (pid $($proc.Id)), waiting for health..."

& "$scriptDir/poll-health.ps1" -Url "http://localhost:$Port/health" -TimeoutSec $TimeoutSec

if ($LASTEXITCODE -ne 0) {
    Write-Error "Server did not become healthy within timeout. See server output."
    exit 1
}

Write-Host "Server healthy and ready: http://localhost:$Port"
exit 0
