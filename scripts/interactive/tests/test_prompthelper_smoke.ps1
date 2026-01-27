# Smoke test for PromptHelper non-interactive behavior
$env:NONINTERACTIVE = '1'
. $PSScriptRoot\..\PromptHelper.ps1

# Test Read-NonEmptyString with default
$val = Read-NonEmptyString -Prompt 'Enter value (auto)' -Default 'DEFAULT_VAL' -AutoAcceptDefault
Write-Host "Read-NonEmptyString returned: $val"

# Test Read-ValidatedPath with default and CreateIfMissing
$defaultPath = Join-Path (Get-Location) 'artifacts\test-prompthelper-smoke.txt'
$p = Read-ValidatedPath -Prompt 'Enter path (auto)' -Default $defaultPath -AutoAcceptDefault -CreateIfMissing
Write-Host "Read-ValidatedPath returned: $p"

# Clean up artifact created by test
if (Test-Path $p) { Remove-Item $p -Force }
Write-Host 'SMOKE_OK'