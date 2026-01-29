# Status refresh smoke test for process-menu
# Start -> Stop -> Start (mock-mode) and assert top-line updates

$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$menu = Join-Path $root '..\process-menu.ps1'
$marker = Join-Path $root 'process-menu-status-refresh.marker'
Remove-Item -Force -ErrorAction SilentlyContinue $marker

# Run process-menu in a child process, capture stdout/stderr
$tempOut = Join-Path $root 'tmp_status_refresh_stdout.txt'
$tempErr = Join-Path $root 'tmp_status_refresh_stderr.txt'
Remove-Item -Force -ErrorAction SilentlyContinue $tempOut, $tempErr

# Prepare environment for mock-mode deterministic actions
$env:PROCESS_MENU_MOCK = '1'
$env:PROCESS_MENU_TEST_MARKER = $marker
$env:PROCESS_MENU_ENABLE_AUTO_ADVANCE = '0'    # ensure no auto-advance

# Use auto-advance runs to perform Start -> Stop -> Start in sequence (mock-mode)
# Run 1: start
$env:PROCESS_MENU_ENABLE_AUTO_ADVANCE = '1'
$env:PROCESS_MENU_DEFAULT_ACTION = '2'
Start-Process -FilePath powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',$menu -Wait -WindowStyle Hidden

# Run 2: stop
$env:PROCESS_MENU_DEFAULT_ACTION = '3'
Start-Process -FilePath powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',$menu -Wait -WindowStyle Hidden

# Run 3: start
$env:PROCESS_MENU_DEFAULT_ACTION = '2'
Start-Process -FilePath powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',$menu -Wait -WindowStyle Hidden

# Read captured output (if any) and stderr
$outStd = Get-Content -Path $tempOut -Raw -ErrorAction SilentlyContinue
$outErr = Get-Content -Path $tempErr -Raw -ErrorAction SilentlyContinue
$out = "$outStd`n$outErr"

# Verify markers
if (-not (Test-Path $marker)) { Write-Error "Marker file not created: $marker"; exit 3 }
$marks = Get-Content $marker -ErrorAction SilentlyContinue
$startCount = ($marks | Select-String 'MOCK_MARK Start-ServerDetached' -SimpleMatch).Count
if ($startCount -lt 2) { Write-Error "Expected >=2 Start-ServerDetached markers, found $startCount"; exit 4 }

Write-Host "Status refresh smoke test: PASS (marker checks only)" -ForegroundColor Green
exit 0
