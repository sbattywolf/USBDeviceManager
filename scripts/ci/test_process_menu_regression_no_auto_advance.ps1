<#
Regression: Ensure process-menu does NOT auto-advance by default.
This test starts `process-menu.ps1` in mock-mode WITHOUT setting
`PROCESS_MENU_ENABLE_AUTO_ADVANCE` and asserts the script remains
running (awaiting user input) for a short interval.
#>

$ErrorActionPreference = 'Stop'

$env:PROCESS_MENU_MOCK = '1'
# Intentionally DO NOT set PROCESS_MENU_ENABLE_AUTO_ADVANCE

$scriptRoot = $PSScriptRoot
$menuScript = Resolve-Path -Path (Join-Path $scriptRoot '..\process-menu.ps1')

Write-Host "[TEST] Starting process-menu in mock-mode WITHOUT auto-advance"

$outStd = Join-Path $scriptRoot 'regression_no_autoadvance.stdout'
$outErr = Join-Path $scriptRoot 'regression_no_autoadvance.stderr'
if (Test-Path $outStd) { Remove-Item $outStd -Force -ErrorAction SilentlyContinue }
if (Test-Path $outErr) { Remove-Item $outErr -Force -ErrorAction SilentlyContinue }

$proc = Start-Process -FilePath powershell -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$menuScript) -RedirectStandardOutput $outStd -RedirectStandardError $outErr -PassThru

try {
    Start-Sleep -Seconds 3
    $proc.Refresh()
    if ($proc.HasExited) {
        Write-Host '[FAIL] process-menu exited unexpectedly (auto-advance occurred).' -ForegroundColor Red
        Write-Host '---- stdout ----'
        if (Test-Path $outStd) { Get-Content $outStd | ForEach-Object { Write-Host $_ } }
        Write-Host '---- stderr ----'
        if (Test-Path $outErr) { Get-Content $outErr | ForEach-Object { Write-Host $_ } }
        exit 1
    }

    # Read stdout and assert that the main prompt or menu header is present while waiting
    $promptFound = $false
    if (Test-Path $outStd) {
        $content = Get-Content -Path $outStd -Raw -ErrorAction SilentlyContinue
        if ($content -match 'Select an option' -or $content -match '=== Process Menu: Server vs Agent ===' -or $content -match '0\) Exit') { $promptFound = $true }
    }

    if (-not $promptFound) {
        Write-Host "[FAIL] expected menu prompt/header not found in stdout." -ForegroundColor Red
        Write-Host '---- stdout ----'
        if (Test-Path $outStd) { Get-Content $outStd | ForEach-Object { Write-Host $_ } }
        exit 1
    }

    Write-Host '[PASS] process-menu remained running and prompt displayed (no auto-advance)'
    exit 0
} finally {
    try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch {}
}
