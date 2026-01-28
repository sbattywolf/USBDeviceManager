param(
    [string] $RunId = $(Get-Date -Format "yyyyMMdd_HHmmss"),
    [switch] $DryRun,
    [switch] $AllowDummy
)

# Simple local wrapper around the CI sequential test runner.
# - Uses scripts/ci/run_all_tests_sequential.ps1 to preserve CI behavior
# - Optionally creates a dummy SMServer.exe before running (useful for reproducing CI failures)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ciRunner = Join-Path $scriptRoot "..\ci\run_all_tests_sequential.ps1"

if (-not (Test-Path $ciRunner)) {
    Write-Error "CI runner not found at $ciRunner. Run this from the repo root or adjust path."
    exit 1
}

Write-Host "Local test harness: RunId=$RunId DryRun=$DryRun AllowDummy=$AllowDummy"

if ($AllowDummy) {
    Write-Host "Ensuring SMServer.exe exists (creating dummy if missing)..."
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptRoot "..\ci\check-smserver.ps1") -SearchRoot (Get-Location).Path -AllowDummy
    if ($LASTEXITCODE -ne 0) {
        Write-Host "check-smserver created dummy or reported missing; continuing. Exit=$LASTEXITCODE"
    }
}

# Forward DryRun to underlying script
$argsList = @()
if ($DryRun) { $argsList += '-DryRun' }
$argsList += '-RunId'; $argsList += $RunId

Write-Host "Invoking CI runner: $ciRunner $($argsList -join ' ')"
if (-not $DryRun) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ciRunner @argsList
    exit $LASTEXITCODE
} else {
    Write-Host "Dry run; not executing CI runner."
}
