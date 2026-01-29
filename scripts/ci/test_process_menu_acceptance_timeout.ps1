Param()
$ErrorActionPreference = 'Stop'

$marker = Join-Path $PSScriptRoot 'process-menu-acceptance-timeout-marker.txt'
Remove-Item -Force -ErrorAction SilentlyContinue $marker

$env:PROCESS_MENU_MOCK = '1'
$env:PROCESS_MENU_SKIP_PAUSE = '1'
$env:PROCESS_MENU_ENABLE_AUTO_ADVANCE = '1'
$env:PROCESS_MENU_INPUT_TIMEOUT = '2'
$env:PROCESS_MENU_TEST_MARKER = $marker

# menu script path (parent folder of ci)
$menu = Join-Path $PSScriptRoot '..\process-menu.ps1'
if (-not (Test-Path $menu)) { Write-Error "Menu script not found: $menu"; exit 2 }

Write-Host "Running timeout acceptance test against $menu (timeout=2s)"
& $menu

Start-Sleep -Seconds 1
if (-not (Test-Path $marker)) { Write-Error "Marker file not created after timeout: $marker"; exit 3 }
$content = Get-Content $marker -Raw
Write-Host "Marker contents:`n$content"
Write-Host "Timeout acceptance test: PASS (marker present)"
exit 0
