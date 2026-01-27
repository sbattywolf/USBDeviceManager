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

# Metrics collection
$metrics = @()
$metricsCsv = Join-Path $root 'metrics.csv'
$metricsJson = Join-Path $root 'metrics.json'

function Write-MetricCSVHeader {
    param($path)
    if (-not (Test-Path $path)) {
        "Step,Start,End,DurationMs,ExitCode,Notes" | Out-File -FilePath $path -Encoding utf8
    }
}
Write-MetricCSVHeader -path $metricsCsv

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
        $suiteStart = Get-Date
        $proc = Start-Process -FilePath 'dotnet' -ArgumentList $cmdArgs -NoNewWindow -Wait -PassThru
        $suiteEnd = Get-Date
        $dur = (New-TimeSpan -Start $suiteStart -End $suiteEnd).TotalMilliseconds
        $exit = $proc.ExitCode
        $note = ""
        if ($exit -ne 0) { $note = "Non-zero exit"; Write-Host "Command exited with code $exit for $name tests (continuing to next suite)." -ForegroundColor Yellow }
        $metrics += [pscustomobject]@{ Step = "$name tests"; Start = $suiteStart.ToString('o'); End = $suiteEnd.ToString('o'); DurationMs = [math]::Round($dur,0); ExitCode = $exit; Notes = $note }
        "$($name) tests,$($suiteStart.ToString('o')),$($suiteEnd.ToString('o')),$([math]::Round($dur,0)),$exit,$note" | Out-File -FilePath $metricsCsv -Append -Encoding utf8
    }
}

# Run E2E self-hosted wrapper (will write AgentE2E.selfhost.trx to artifacts/test-results)
Write-Host "\n--- Running E2E self-hosted wrapper ---"
$e2eCmd = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ci\run_e2e_selfhost.ps1"
Write-Host $e2eCmd
if (-not $DryRun) {
    $e2eStart = Get-Date
    & powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ci\run_e2e_selfhost.ps1 -MetricsFile $metricsCsv
    $e2eEnd = Get-Date
    $e2eDur = (New-TimeSpan -Start $e2eStart -End $e2eEnd).TotalMilliseconds
    $metrics += [pscustomobject]@{ Step = 'E2E self-hosted wrapper'; Start = $e2eStart.ToString('o'); End = $e2eEnd.ToString('o'); DurationMs = [math]::Round($e2eDur,0); ExitCode = $LASTEXITCODE; Notes = "" }
    "E2E self-hosted wrapper,$($e2eStart.ToString('o')),$($e2eEnd.ToString('o')),$([math]::Round($e2eDur,0)),$LASTEXITCODE," | Out-File -FilePath $metricsCsv -Append -Encoding utf8
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
    Write-Host ('python ' + $mergePy + ' ' + $root + ' ' + $outMerged)
    if (-not $DryRun) {
        $mergeStart = Get-Date
        & python $mergePy $root $outMerged
        $mergeEnd = Get-Date
        $mergeDur = (New-TimeSpan -Start $mergeStart -End $mergeEnd).TotalMilliseconds
        $mergeExit = $LASTEXITCODE
        if ($mergeExit -ne 0) { Write-Host "merge_trx.py returned exit code $mergeExit" -ForegroundColor Yellow }
        $metrics += [pscustomobject]@{ Step = 'merge_trx'; Start = $mergeStart.ToString('o'); End = $mergeEnd.ToString('o'); DurationMs = [math]::Round($mergeDur,0); ExitCode = $mergeExit; Notes = "" }
        "merge_trx,$($mergeStart.ToString('o')),$($mergeEnd.ToString('o')),$([math]::Round($mergeDur,0)),$mergeExit," | Out-File -FilePath $metricsCsv -Append -Encoding utf8
    }
} else {
    Write-Host "merge_trx.py not found in scripts/ci; skipping merge." -ForegroundColor Yellow
}

Write-Host "\nRun complete. TRX artifacts are in: $root"
if ($DryRun) { Write-Host "(Dry run finished)" }

# Write summary JSON of collected metrics
if (-not $DryRun) {
    $metrics | ConvertTo-Json -Depth 5 | Out-File -FilePath $metricsJson -Encoding utf8
    Write-Host "\nMetrics written to: $metricsJson and $metricsCsv"
    Write-Host "Summary of steps (DurationMs):"
    $metrics | ForEach-Object { Write-Host ("- $($_.Step): $($_.DurationMs) ms (exit=$($_.ExitCode))") }
}
