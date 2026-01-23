param(
    [string]$ProjectPath = "server/USBDeviceManager",
    [int]$Port = 5000,
    [int]$TimeoutSec = 180,
    [switch]$NoBuild
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$tmpDir = Join-Path $scriptDir "tmp"
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

Write-Host "Starting server project: $ProjectPath on port $Port"

$args = "run --project `"$ProjectPath`" --urls http://localhost:$Port"
if ($NoBuild) { $args += ' --no-build' }

$outFile = Join-Path $tmpDir "server.out.log"
$errFile = Join-Path $tmpDir "server.err.log"

try {
    $startArgs = $args
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

& "$scriptDir/poll-health.ps1" -Url "http://localhost:$Port/health" -TimeoutSec $TimeoutSec

if ($LASTEXITCODE -ne 0) {
    Write-Error "Server did not become healthy within timeout ($TimeoutSec seconds). See server output."
    $diagFile = Join-Path $tmpDir "start-server-diagnostics.log"
    Write-Host "Writing diagnostics to $diagFile"
    "Server failed to become healthy within $TimeoutSec seconds" | Out-File -FilePath $diagFile -Encoding UTF8
    if (Test-Path $outFile) { "--- server.out (tail 200) ---" | Out-File -FilePath $diagFile -Append; Get-Content $outFile -Tail 200 | Out-File -FilePath $diagFile -Append }
    if (Test-Path $errFile) { "--- server.err (tail 200) ---" | Out-File -FilePath $diagFile -Append; Get-Content $errFile -Tail 200 | Out-File -FilePath $diagFile -Append }
    exit 1
}

Write-Host "Server healthy and ready: http://localhost:$Port"
exit 0
