# Minimal mock-mode singleton test for process-menu Start action
$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$menu = Join-Path $root '..\process-menu.ps1'
$marker = Join-Path $root 'process-menu-singleton.marker'
Remove-Item -Force -ErrorAction SilentlyContinue $marker

# Configure mock-mode and auto-advance to repeatedly invoke Start
$env:PROCESS_MENU_MOCK = '1'
$env:PROCESS_MENU_TEST_MARKER = $marker
$env:PROCESS_MENU_ENABLE_AUTO_ADVANCE = '1'
$env:PROCESS_MENU_DEFAULT_ACTION = '2'  # Start

# Invoke the menu Start action once and assert a single mock marker
Start-Process -FilePath powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',$menu -Wait -WindowStyle Hidden

if (-not (Test-Path $marker)) {
    Write-Error "Marker file not created: $marker"
    exit 3
}

$marks = Get-Content $marker -ErrorAction Stop
$startCount = ($marks | Select-String 'MOCK_MARK Start-ServerDetached' -SimpleMatch).Count
if ($startCount -ne 1) {
    Write-Error "Expected exactly 1 Start-ServerDetached marker, found $startCount"
    exit 4
}

Write-Host "MOCK_MARK Start-ServerDetached count: $startCount"
Write-Host 'Singleton mock test: PASS' -ForegroundColor Green
exit 0
