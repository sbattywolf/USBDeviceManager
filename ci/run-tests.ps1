<#
CI helper script: run server and agent tests locally.

Exits with non-zero code if any test group fails.
#>

param(
    [switch]$RunAgentTests = $true,
    [switch]$RunServerTests = $true,
    [switch]$NonInteractive
)

$ErrorActionPreference = 'Stop'
$script:exitCode = 0

# Compute repository root (parent of the `ci` folder) so paths are repo-root-relative
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')

Write-Host "CI: Running tests for repository" -ForegroundColor Cyan

# Run server tests if requested and dotnet is installed
if ($RunServerTests) {
    try {
        $dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
        if ($dotnet) {
            Write-Host "Found dotnet CLI at $($dotnet.Path). Running server tests (solution)..." -ForegroundColor Yellow
            Push-Location -Path $RepoRoot
            try {
                # Run tests at the solution level to pick up the server test project
                dotnet test USBDeviceManager.sln --nologo
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
} else {
    Write-Host "Skipping server tests (RunServerTests not set)." -ForegroundColor Gray
}

# Run agent tests (PowerShell) if requested
if ($RunAgentTests) {
    try {
        Write-Host "Running agent PowerShell unit tests..." -ForegroundColor Yellow
        $agentUnitPath = Join-Path $RepoRoot 'agent\SimRacingAgent.Tests\Unit'
        if (-not (Test-Path $agentUnitPath)) {
            Write-Host "Agent unit test folder not found: $agentUnitPath" -ForegroundColor Yellow
        } else {
            Push-Location -Path $agentUnitPath
            # Dot-source the test script to avoid Export-ModuleMember errors when importing as a module
            try {
                . .\AgentMonitoringTests.ps1
            } catch {
                Write-Host "Warning: failed to dot-source AgentMonitoringTests.ps1: $($_.Exception.Message)" -ForegroundColor Yellow
            }
            $res = Invoke-AgentMonitoringTests
            if (-not $res.Success) {
                Write-Host "Agent tests reported failures." -ForegroundColor Red
                $script:exitCode = 1
            }
            Pop-Location
        }
    } catch {
        Write-Host "Agent tests failed to run: $($_.Exception.Message)" -ForegroundColor Red
        $script:exitCode = 1
    }
} else {
    Write-Host "Skipping agent tests (RunAgentTests not set)." -ForegroundColor Gray
}

# Run Pester-based PowerShell tests in scripts/interactive (if present)
try {
    $interactiveTestsPath = Join-Path $RepoRoot 'scripts\interactive\tests'
    if (Test-Path $interactiveTestsPath) {
        Write-Host "Running interactive Pester tests: $interactiveTestsPath" -ForegroundColor Yellow
        Push-Location -Path $interactiveTestsPath
        if (Get-Command Invoke-Pester -ErrorAction SilentlyContinue) {
            $outFile = Join-Path $RepoRoot 'artifacts\interactive-pester-results.xml'
            Invoke-Pester -Script @{ Path = $interactiveTestsPath; OutputFormat = 'NUnitXml'; OutputFile = $outFile }
            if (-not (Test-Path $outFile)) { Write-Host "Pester did not produce results file." -ForegroundColor Yellow }
        } else {
            Write-Host 'Pester not available on this runner; skipping interactive Pester tests.' -ForegroundColor Yellow
        }
        Pop-Location
    } else {
        Write-Host "No interactive tests found at $interactiveTestsPath" -ForegroundColor Gray
    }
} catch {
    Write-Host "Interactive Pester tests failed: $($_.Exception.Message)" -ForegroundColor Red
    $script:exitCode = 1
}

if ($script:exitCode -eq 0) { Write-Host "All tests passed." -ForegroundColor Green } else { Write-Host "Some tests failed." -ForegroundColor Red }

exit $script:exitCode
