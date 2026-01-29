# Run interactive test suite (mock-mode by default)
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ci\run_interactive_tests.ps1

$root = $PSScriptRoot

Write-Host "Running interactive mock tests..."
Write-Host "Running interactive mock tests..."
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'test_process_menu_mock.ps1')
$ec1 = $LASTEXITCODE
if ($ec1 -ne 0) { Write-Host "Interactive mock tests failed (code $ec1)" -ForegroundColor Red; exit $ec1 }

Write-Host "Running acceptance tests (mock + timeout)..."
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'test_process_menu_acceptance_mock.ps1')
$ec2 = $LASTEXITCODE
if ($ec2 -ne 0) { Write-Host "Acceptance mock test failed (code $ec2)" -ForegroundColor Red; exit $ec2 }


# Regression: ensure auto-advance is disabled by default
Write-Host "Running regression: no auto-advance by default..."
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'test_process_menu_regression_no_auto_advance.ps1')
$ec_reg = $LASTEXITCODE
if ($ec_reg -ne 0) { Write-Host "Regression no-auto-advance failed (code $ec_reg)" -ForegroundColor Red; exit $ec_reg }

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'test_process_menu_acceptance_timeout.ps1')
$ec3 = $LASTEXITCODE
if ($ec3 -ne 0) { Write-Host "Acceptance timeout test failed (code $ec3)" -ForegroundColor Red; exit $ec3 }

Write-Host "Running setup/owners acceptance test..."
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'test_process_menu_setup_owners.ps1')
$ec_setup = $LASTEXITCODE
if ($ec_setup -ne 0) { Write-Host "Setup owners test failed (code $ec_setup)" -ForegroundColor Red; exit $ec_setup }
if ($env:PROCESS_MENU_REAL_TEST -eq '1') {
	Write-Host "PROCESS_MENU_REAL_TEST=1 detected; running guarded real-mode acceptance test..."
	& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'test_process_menu_acceptance_real.ps1')
	$ec4 = $LASTEXITCODE
	if ($ec4 -ne 0) { Write-Host "Real-mode acceptance test failed (code $ec4)" -ForegroundColor Red; exit $ec4 }
} else {
	Write-Host "Skipping real-mode acceptance test. Set PROCESS_MENU_REAL_TEST=1 to enable." -ForegroundColor Yellow
}

Write-Host "All interactive tests passed." -ForegroundColor Green
exit 0
