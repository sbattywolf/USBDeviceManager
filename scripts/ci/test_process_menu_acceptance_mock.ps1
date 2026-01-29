Param()
$ErrorActionPreference = 'Stop'

$marker = Join-Path $PSScriptRoot 'process-menu-acceptance-marker.txt'
Remove-Item -Force -ErrorAction SilentlyContinue $marker

$env:PROCESS_MENU_MOCK = '1'
$env:PROCESS_MENU_SKIP_PAUSE = '1'
$env:PROCESS_MENU_ENABLE_AUTO_ADVANCE = '1'
$env:PROCESS_MENU_TEST_MARKER = $marker

# menu script path (parent folder of ci)
$menu = Join-Path $PSScriptRoot '..\process-menu.ps1'
if (-not (Test-Path $menu)) { Write-Error "Menu script not found: $menu"; exit 2 }

Write-Host "Running mock acceptance test against $menu"
& $menu

Start-Sleep -Seconds 1
if (-not (Test-Path $marker)) { Write-Error "Marker file not created: $marker"; exit 3 }
$content = Get-Content $marker -Raw
if ($content -notmatch 'Start-Server') { Write-Warning "Start-Server marker not found in marker file."; Write-Host "Marker contents:`n$content"; exit 4 }
Write-Host "Mock acceptance test: PASS"
exit 0
