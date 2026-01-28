Param()
$ErrorActionPreference = 'Stop'

Write-Host "Real-mode acceptance test runner (guarded)."

if ($env:PROCESS_MENU_REAL_TEST -ne '1') {
    Write-Host "Skipping real-mode acceptance test: set PROCESS_MENU_REAL_TEST=1 to enable." -ForegroundColor Yellow
    exit 0
}

# Ensure elevation
try {
    $isElevated = ([Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch { $isElevated = $false }
if (-not $isElevated) {
    Write-Error "Real-mode acceptance test requires elevation. Rerun elevated or set PROCESS_MENU_REAL_TEST=0 to skip."
    exit 2
}

$marker = Join-Path $PSScriptRoot 'process-menu-acceptance-real-marker.txt'
Remove-Item -Force -ErrorAction SilentlyContinue $marker

Write-Host "Running process-menu in REAL mode (will run default action)."
$env:PROCESS_MENU_MOCK = '0'
$env:PROCESS_MENU_SKIP_PAUSE = '1'
$env:PROCESS_MENU_ENABLE_AUTO_ADVANCE = '1'
$env:PROCESS_MENU_TEST_MARKER = $marker
$env:PROCESS_MENU_DEFAULT_ACTION = '2'

$menu = Join-Path $PSScriptRoot '..\process-menu.ps1'
if (-not (Test-Path $menu)) { Write-Error "Menu script not found: $menu"; exit 3 }

Write-Host "About to execute real-mode menu. This may start/stop processes on this machine. Proceeding..."
& powershell -NoProfile -ExecutionPolicy Bypass -File $menu

Start-Sleep -Seconds 2
if (Test-Path $marker) {
    Write-Host "Marker file created (real-mode):" -ForegroundColor Green
    Get-Content $marker | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Warning "Marker file not created by real-mode run. Inspect logs or actions manually."
}

Write-Host "Real-mode acceptance test completed." -ForegroundColor Green
exit 0
