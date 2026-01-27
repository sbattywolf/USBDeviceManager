param(
    [string] $RunId = $(Get-Date -Format "yyyyMMdd_HHmmss"),
    [switch] $DryRun
)

# Directory where per-run TRX files will be stored
$root = Join-Path $PSScriptRoot "..\..\artifacts\test-results\$RunId"
New-Item -ItemType Directory -Force -Path $root | Out-Null

Write-Host "Test run id: $RunId"
Write-Host "Output directory: $root"
if ($DryRun) { Write-Host "DRY RUN: commands will be printed but not executed." }

$suites = @(
    @{ Name='Unit'; Filter='Category=Unit'; Log='unit-tests.trx' },
    @{ Name='Integration'; Filter='Category=Integration'; Log='integration-tests.trx' },
    @{ Name='Functional'; Filter='Category=Functional'; Log='functional-tests.trx' },
    @{ Name='Regression'; Filter='Category=Regression'; Log='regression-tests.trx' }
)

foreach ($s in $suites) {
    $name = $s.Name
    $filter = $s.Filter
    $log = $s.Log
    $outPath = $root
    Write-Host "\n--- Running $name tests ---"
    $cmdArgs = @('test','USBDeviceManager.sln','--configuration','Release','--logger',"trx;LogFileName=$log",'--results-directory',$outPath,'--filter',$filter)
    Write-Host ('dotnet ' + ($cmdArgs -join ' '))
    if (-not $DryRun) {
        $proc = Start-Process -FilePath 'dotnet' -ArgumentList $cmdArgs -NoNewWindow -Wait -PassThru
        if ($proc.ExitCode -ne 0) {
            Write-Host "Command exited with code $($proc.ExitCode) for $name tests (continuing to next suite)." -ForegroundColor Yellow
        }
    }
}

# Run E2E self-hosted wrapper (will write AgentE2E.selfhost.trx to artifacts/test-results)
Write-Host "\n--- Running E2E self-hosted wrapper ---"
$e2eCmd = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ci\run_e2e_selfhost.ps1"
Write-Host $e2eCmd
if (-not $DryRun) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ci\run_e2e_selfhost.ps1
    # copy AgentE2E TRX into run folder if present
    $e2eTrx = Join-Path (Join-Path $PSScriptRoot "..\..\artifacts\test-results") 'AgentE2E.selfhost.trx'
    if (Test-Path $e2eTrx) {
        Copy-Item $e2eTrx -Destination (Join-Path $root 'AgentE2E.selfhost.trx') -Force
    }
}

# Merge TRX files from this run using repository merge_trx.py if available
$mergePy = Join-Path $PSScriptRoot 'merge_trx.py'
if (Test-Path $mergePy) {
    $outMerged = Join-Path $root 'all-tests.trx'
    Write-Host "\n--- Merging TRX files for run into $outMerged ---"
    Write-Host ('python ' + $mergePy + ' --src ' + $root + ' --out ' + $outMerged)
    if (-not $DryRun) {
        & python $mergePy --src $root --out $outMerged
        if ($LASTEXITCODE -ne 0) { Write-Host "merge_trx.py returned exit code $LASTEXITCODE" -ForegroundColor Yellow }
    }
} else {
    Write-Host "merge_trx.py not found in scripts/ci; skipping merge." -ForegroundColor Yellow
}

Write-Host "\nRun complete. TRX artifacts are in: $root"
if ($DryRun) { Write-Host "(Dry run finished)" }
