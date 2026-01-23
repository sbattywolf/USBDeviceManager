<#
.SYNOPSIS
  Orchestrate CI: start server, run agent tests, run server tests, collect artifacts.

.DESCRIPTION
  Cross-project CI helper for local runs and CI runners (Windows). Starts the ASP.NET server
  in the background, waits for it to respond, runs the PowerShell-based agent tests and
  the .NET server tests, collects logs and TRX results into an artifacts folder, and
  stops the server process.
#>

param(
    [string]$ArtifactsDir = "artifacts/ci-run-$(Get-Date -Format 'yyyyMMdd-HHmmss')",
    [int]$ServerPort = 5000,
    [int]$ServerStartTimeoutSec = 60
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "CI run starting. Artifacts: $ArtifactsDir"
New-Item -ItemType Directory -Force -Path $ArtifactsDir | Out-Null

function Start-Server {
    Write-Host "Starting server (dotnet run) in background..."
    $proc = Start-Process -FilePath 'dotnet' -ArgumentList @('run','--project','server/USBDeviceManager','--urls',"http://localhost:$ServerPort") -PassThru
    return $proc
}

function Wait-For-Server {
    param($Url, $TimeoutSec)
    Write-Host "Waiting for server to respond at $Url (timeout ${TimeoutSec}s)..."
    $start = Get-Date
    while ( (Get-Date).Subtract($start).TotalSeconds -lt $TimeoutSec ) {
        try {
            $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 500) {
                Write-Host "Server responded with $($resp.StatusCode)."
                return $true
            }
        } catch {
            Start-Sleep -Seconds 1
        }
    }
    return $false
}

function Run-CommandToFile {
    param($Script, $OutFile)
    Write-Host "Running: $Script -> $OutFile"
    & powershell -NoProfile -ExecutionPolicy Bypass -Command $Script 2>&1 | Tee-Object -FilePath $OutFile
    return $LASTEXITCODE
}

# Start server
$serverProc = Start-Server
Start-Sleep -Seconds 2

$healthUrl = "http://localhost:$ServerPort/api/devices"
if (-not (Wait-For-Server -Url $healthUrl -TimeoutSec $ServerStartTimeoutSec)) {
    Write-Host "ERROR: Server did not start within timeout. Collecting limited logs and failing CI."
    if ($serverProc -and $serverProc.Id) { Get-Process -Id $serverProc.Id -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }
    exit 2
}

# Run agent tests (PowerShell test runner)
$agentLog = Join-Path $ArtifactsDir 'agent-tests.log'
$agentScript = Join-Path $PSScriptRoot '..\agent\SimRacingAgent.Tests\TestRunner.ps1'
if (-not (Test-Path $agentScript)) { $agentScript = Join-Path $PSScriptRoot '..\..\agent\SimRacingAgent.Tests\TestRunner.ps1' }
if (Test-Path $agentScript) {
    Write-Host "Importing agent test module $agentScript"
    try {
        Write-Host "Running agent test runners (unit/integration/functional/regression)"
        $candidate = Join-Path $PSScriptRoot '..\agent\SimRacingAgent.Tests'
        $resolved = Resolve-Path $candidate -ErrorAction SilentlyContinue
        if ($resolved -is [array]) { $resolved = $resolved[0] }
        if ($resolved) { $agentRoot = $resolved.Path } else { $agentRoot = (Join-Path $PSScriptRoot '..\agent\SimRacingAgent.Tests') }
        $agentRoot = [string]$agentRoot
        $runners = @(
            [string](Join-Path $agentRoot 'Unit\\run-unit-tests.ps1'),
            [string](Join-Path $agentRoot 'Integration\\run-integration-tests.ps1'),
            [string](Join-Path $agentRoot 'Functional\\run-functional-tests.ps1'),
            [string](Join-Path $agentRoot 'Regression\\run-regression-tests.ps1')
        )
        foreach ($r in $runners) {
            if (Test-Path $r) {
                $r = [string]$r
                Write-Host "Running runner: $r"
                $runDir = Split-Path -Parent $r
                $cmd = "Set-Location '$runDir'; `$env:CI='1'; & '$r'"
                powershell -NoProfile -ExecutionPolicy Bypass -Command $cmd 2>&1 | Tee-Object -FilePath $agentLog -Append
            } else {
                Write-Host "Runner not found, skipping: $r"
            }
        }
        $agentExit = 0
    } catch {
        Write-Warning "Agent tests invocation failed: $_"
        "Agent runner invocation error: $_" | Out-File -FilePath $agentLog -Append
        $agentExit = 1
    }
} else {
    Write-Host "Warning: agent test runner not found at expected path: $agentScript" | Tee-Object -FilePath $agentLog
    $agentExit = 1
}

# Run server tests (dotnet test), emitting TRX
 $serverTestLog = Join-Path $ArtifactsDir 'server-tests.log'
Write-Host "Running server tests (dotnet test) for projects..."
$serverTestExit = 0
Get-ChildItem -Path server/USBDeviceManager.Tests -Filter *.csproj -Recurse | ForEach-Object {
    $proj = $_.FullName
    $projName = $_.BaseName
    $projLog = Join-Path $ArtifactsDir "$projName-tests.log"
    Write-Host "dotnet test $proj -> $projLog"
    & dotnet test $proj --logger "trx;LogFileName=$projName.trx" *> $projLog
    if ($LASTEXITCODE -ne 0) { $serverTestExit = $LASTEXITCODE }
}

# Collect TRX and other artifacts
Write-Host 'Collecting artifacts...'
try {
    $trxFiles = Get-ChildItem -Path server/USBDeviceManager.Tests -Recurse -Filter *.trx -ErrorAction SilentlyContinue
    foreach ($t in $trxFiles) { Copy-Item $t.FullName -Destination (Join-Path $ArtifactsDir $t.Name) -Force }
} catch {
    Write-Host "No TRX found or error copying TRX: $_"
}

# Copy server DB if present
if (Test-Path 'server/USBDeviceManager/simracing.db') {
    Copy-Item 'server/USBDeviceManager/simracing.db' -Destination (Join-Path $ArtifactsDir 'simracing.db') -Force
}

# Copy common log patterns from repository root artifacts if present
$artifactFiles = Get-ChildItem -Path artifacts -Filter *.log -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notlike (Join-Path $ArtifactsDir '*') }
foreach ($f in $artifactFiles) {
    $dest = Join-Path $ArtifactsDir $f.Name
    try {
        Copy-Item $f.FullName -Destination $dest -Force
    } catch {
        Write-Warning "Failed to copy $($f.FullName) -> $dest : $_"
    }
}

# Stop server
if ($serverProc -and $serverProc.Id) {
    Write-Host "Stopping server (PID $($serverProc.Id))"
    try { Stop-Process -Id $serverProc.Id -Force -ErrorAction SilentlyContinue } catch {}
}

if ($serverTestExit -ne 0) {
    Write-Host "Server tests failed (exit code $serverTestExit). See $serverTestLog"
    exit $serverTestExit
}

Write-Host "CI run completed successfully. Artifacts under: $ArtifactsDir"
exit 0
