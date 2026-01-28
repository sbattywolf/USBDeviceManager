<#
test_process_menu_mock.ps1
Runs `process-menu.ps1` in mock-mode, asserts that mock log entries were produced.

Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ci\test_process_menu_mock.ps1
#>

$env:PROCESS_MENU_MOCK = '1'
$env:PROCESS_MENU_INPUT_TIMEOUT = '2'
$env:PROCESS_MENU_DEFAULT_ACTION = '2'
$env:PROCESS_MENU_SKIP_PAUSE = '1'

# For test harness, enable auto-advance so we exercise the timeout/default flow
$env:PROCESS_MENU_ENABLE_AUTO_ADVANCE = '1'

# marker file for robust detection of mock actions
$marker = Join-Path $PSScriptRoot 'process-menu-mock-marker.txt'
if (Test-Path $marker) { Remove-Item $marker -Force -ErrorAction SilentlyContinue }
$env:PROCESS_MENU_TEST_MARKER = $marker

$scriptRoot = $PSScriptRoot
$menuScript = Resolve-Path -Path (Join-Path $scriptRoot '..\process-menu.ps1')

# Ensure logs are present and cleared
$serverLog = (Join-Path $scriptRoot '..\server\USBDeviceManager\server.log')
$agentLog = (Join-Path $scriptRoot '..\agent\SimRacingAgent\agent-run.log')
foreach ($p in @($serverLog,$agentLog)) {
	try {
		$dir = Split-Path -Path $p -Parent
		if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
		if (Test-Path $p) { Clear-Content -Path $p -ErrorAction SilentlyContinue }
		else { New-Item -Path $p -ItemType File -Force | Out-Null }
	} catch {
		Write-Host "[WARN] Could not prepare ${p}: $($_.Exception.Message)" -ForegroundColor Yellow
	}
}

Write-Host "[TEST] Running process-menu in mock-mode (timeout -> default)"
& powershell -NoProfile -ExecutionPolicy Bypass -File $menuScript -TestInputs '__TIMEOUT__'

Start-Sleep -Seconds 1

Write-Host "[TEST] Verifying mock marker entries..."
$markerText = ''
if (Test-Path $marker) { $markerText = Get-Content -Path $marker -Raw -ErrorAction SilentlyContinue }

$ok = $true
if (-not ($markerText -and $markerText -match 'MOCK_MARK Start-ServerDetached')) {
	Write-Host "[FAIL] marker missing Start-ServerDetached entry" -ForegroundColor Red
	$ok = $false
} else { Write-Host "[PASS] marker contains Start-ServerDetached" }

if (-not ($markerText -and $markerText -match 'MOCK_MARK Start-AgentDetached')) {
	Write-Host "[WARN] marker missing Start-AgentDetached entry" -ForegroundColor Yellow
} else { Write-Host "[PASS] marker contains Start-AgentDetached" }

if (-not $ok) {
	Write-Host "[TEST] Mock test FAILED" -ForegroundColor Red
	exit 1
}

Write-Host "[TEST] Mock test succeeded" -ForegroundColor Green