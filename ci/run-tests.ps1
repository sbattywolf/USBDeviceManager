<#
CI helper script: run server and agent tests locally.
- Runs `dotnet test` in `server/SimRacingDashboard` if `dotnet` is available.
- Runs agent PowerShell tests by importing the test harness and invoking `Invoke-AgentMonitoringTests`.

Exits with non-zero code if any test group fails.
#>

$ErrorActionPreference = 'Stop'
$script:exitCode = 0

Write-Host "CI: Running tests for repository" -ForegroundColor Cyan

# Run server tests if dotnet is installed
try {
    $dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
    if ($dotnet) {
        Write-Host "Found dotnet CLI at $($dotnet.Path). Running server tests..." -ForegroundColor Yellow
        Push-Location -Path "$(Join-Path $PSScriptRoot '..\server\SimRacingDashboard')"
        try {
            dotnet test --nologo
        } catch {
            Write-Host "Server tests failed: $($_.Exception.Message)" -ForegroundColor Red
            $script:exitCode = 1
        }
        Pop-Location
    } else {
        Write-Host "dotnet CLI not found; skipping server tests." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Error while attempting to run server tests: $($_.Exception.Message)" -ForegroundColor Red
    $script:exitCode = 1
}

# Run agent tests (PowerShell)
try {
    Write-Host "Running agent PowerShell unit tests..." -ForegroundColor Yellow
    Push-Location -Path "$(Join-Path $PSScriptRoot 'agent\SimRacingAgent.Tests\Unit')"
    Import-Module .\AgentMonitoringTests.ps1 -Force
    $res = Invoke-AgentMonitoringTests
    if (-not $res.Success) {
        Write-Host "Agent tests reported failures." -ForegroundColor Red
        $script:exitCode = 1
    }
    Pop-Location
} catch {
    Write-Host "Agent tests failed to run: $($_.Exception.Message)" -ForegroundColor Red
    $script:exitCode = 1
}

if ($script:exitCode -eq 0) { Write-Host "All tests passed." -ForegroundColor Green } else { Write-Host "Some tests failed." -ForegroundColor Red }

exit $script:exitCode
