# Guarded real-mode singleton acceptance test for process-menu
# Requires elevation. This will start the real server the first run and skip on second run.
$ErrorActionPreference = 'Stop'

# Check elevation
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'This test must be run elevated. Re-run with administrative privileges.' -ForegroundColor Yellow
    exit 2
}

$root = $PSScriptRoot
$menu = Join-Path $root '..\process-menu.ps1'
$marker = Join-Path $root 'process-menu-singleton-real.marker'
Remove-Item -Force -ErrorAction SilentlyContinue $marker

# Enable real-mode and write test markers
$env:PROCESS_MENU_TEST_MARKER = $marker
$env:PROCESS_MENU_REAL_TEST = '1'
$env:PROCESS_MENU_ENABLE_AUTO_ADVANCE = '1'
$env:PROCESS_MENU_DEFAULT_ACTION = '2'  # Start

# Run the menu twice; first should start, second should detect existing and skip
for ($i = 1; $i -le 2; $i++) {
    Start-Process -FilePath powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',$menu -Wait
    Start-Sleep -Seconds 2
}

if (-not (Test-Path $marker)) {
    Write-Error "Marker file not created: $marker"
    exit 3
}

$marks = Get-Content $marker -ErrorAction Stop
$startedCount = ($marks | Select-String 'STARTED Start-ServerDetached' -SimpleMatch).Count
$skipCount = ($marks | Select-String 'SKIP_ALREADY_RUNNING Start-ServerDetached' -SimpleMatch).Count

if ($startedCount -ne 1) { Write-Error "Expected exactly 1 STARTED, found $startedCount"; exit 4 }
if ($skipCount -ne 1) { Write-Error "Expected exactly 1 SKIP_ALREADY_RUNNING, found $skipCount"; exit 5 }

Write-Host "Real-mode singleton test: PASS (STARTED=$startedCount SKIP=$skipCount)" -ForegroundColor Green
exit 0
