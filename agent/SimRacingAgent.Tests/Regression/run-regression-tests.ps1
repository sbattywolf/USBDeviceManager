<#
Simple placeholder regression runner for agent tests.
Expands later with focused regression scenarios (heartbeat, lifecycle).
#>

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

Write-Host "Starting Agent regression runner (standalone heartbeat) ..." -ForegroundColor Cyan

powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\test-heartbeat-regression.ps1"

if ($LASTEXITCODE -eq 0) { Write-Host "Heartbeat regression runner completed." -ForegroundColor Green; exit 0 } else { Write-Host "Heartbeat regression runner failed." -ForegroundColor Red; exit $LASTEXITCODE }
