#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

Set-Location $PSScriptRoot

if (-not (Test-Path .\logs)) { New-Item -ItemType Directory -Path .\logs | Out-Null }
$log = Join-Path $PSScriptRoot 'logs\functional-run-latest.log'
if (Test-Path $log) { Remove-Item $log -Force }

Write-Output "Running agent functional tests (interactive mode, health suppression)"

# Reuse the integration test functions by dot-sourcing the integration script
. .\..\Integration\test-agent-integration.ps1

$results = @{}

try {
    $results.InteractiveMode = Test-InteractiveMode
} catch {
    Write-Error "InteractiveMode test threw: $($_.Exception.Message)"
    $results.InteractiveMode = $false
}

try {
    $results.HealthAlertSuppression = Test-HealthAlertSuppression
} catch {
    Write-Error "HealthAlertSuppression test threw: $($_.Exception.Message)"
    $results.HealthAlertSuppression = $false
}

Write-Output "Functional test results: $(($results | ConvertTo-Json -Compress))"

if (($results.Values | Where-Object { $_ -eq $false }).Count -gt 0) { exit 1 } else { exit 0 }




