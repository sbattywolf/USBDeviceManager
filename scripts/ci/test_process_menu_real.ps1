# Placeholder: test_process_menu_real.ps1
# Runs the process-menu in real-mode. WARNING: this may start/stop real processes and requires elevation.

# Usage (elevated):
# powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ci\test_process_menu_real.ps1

# Ensure not running in CI by default; require explicit opt-in env var
if (-not $env:PROCESS_MENU_REAL_TEST -or $env:PROCESS_MENU_REAL_TEST -ne '1') {
    Write-Host "Real-mode tests are disabled by default. Set PROCESS_MENU_REAL_TEST=1 to opt-in (must be elevated)." -ForegroundColor Yellow
    exit 0
}

# Check elevation
$isElevated = $false
try { $isElevated = ([Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) } catch { }
if (-not $isElevated) { Write-Host 'This test must be run elevated.'; exit 1 }

# Run a single scenario: trigger timeout default (which will be real action)
$env:PROCESS_MENU_MOCK = '0'
$env:PROCESS_MENU_INPUT_TIMEOUT = '2'
$env:PROCESS_MENU_DEFAULT_ACTION = '2'

& powershell -NoProfile -ExecutionPolicy Bypass -File "..\process-menu.ps1" -TestInputs '__TIMEOUT__'

Write-Host "[TEST] real run invoked - inspect server logs and processes."