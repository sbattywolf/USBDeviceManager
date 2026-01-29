param(
    [ValidateSet('2','6')]
    [string]$Action = '2'
)

Set-Location -Path (Join-Path $PSScriptRoot "..\..")
$marker = 'scripts/ci/process-menu-run.marker'
$env:PROCESS_MENU_MOCK = '1'
$env:PROCESS_MENU_ENABLE_AUTO_ADVANCE = '1'
$env:PROCESS_MENU_DEFAULT_ACTION = $Action
$env:PROCESS_MENU_TEST_MARKER = $marker

Write-Host "Running process-menu once (auto-action=$Action)"
try { & .\scripts\process-menu.ps1 } catch { Write-Host 'process-menu threw:'; Write-Host $_ }

Write-Host "Completed action $Action"
