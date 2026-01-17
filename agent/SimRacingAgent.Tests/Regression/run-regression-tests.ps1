<#
Simple placeholder regression runner for agent tests.
Expands later with focused regression scenarios (heartbeat, lifecycle).
#>

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

Write-Output "Starting Agent regression runner (standalone heartbeat) ..."

powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\test-heartbeat-regression.ps1"

if ($LASTEXITCODE -eq 0) { Write-Output "Heartbeat regression runner completed."; exit 0 } else { Write-Error "Heartbeat regression runner failed."; exit $LASTEXITCODE }




