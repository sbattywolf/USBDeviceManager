# Package existing artifact and tmp files into a triage or full integration archive
# Default: create a small triage bundle to avoid producing very large zips every run.
$paths = @()
if (-not (Test-Path -Path 'artifacts')) {
    Write-Error 'artifacts not found'
    exit 1
}

# When FULL_INTEGRATION_ARCHIVE=1 create the full archive; otherwise create a triage bundle
$full = $false
if ($env:FULL_INTEGRATION_ARCHIVE -and $env:FULL_INTEGRATION_ARCHIVE -eq '1') { $full = $true }

if ($full) {
    Write-Host 'FULL_INTEGRATION_ARCHIVE=1 detected; creating full forensic archive: integration-report-full.zip'
    $paths += 'artifacts\*'
    if (Test-Path -Path 'scripts\tmp') { $paths += 'scripts\tmp\*' }
    if (Test-Path -Path 'integration_artifacts') { $paths += 'integration_artifacts\*' }
    $dest = 'artifacts/integration-report-full.zip'
} else {
    Write-Host 'Creating triage bundle: integration-report-triage.zip (default)'
    # small triage set: TRX, preserved DB snapshots, publish-sentinel, and key logs
    if (Test-Path -Path 'artifacts\*.trx') { $paths += 'artifacts\*.trx' }
    if (Test-Path -Path 'artifacts\ci-local-dbs-on-failure') { $paths += 'artifacts\ci-local-dbs-on-failure\*' }
    if (Test-Path -Path 'artifacts\ci-local-simracing*.db') { $paths += 'artifacts\ci-local-simracing*.db' }
    if (Test-Path -Path 'artifacts\publish-sentinel*') { $paths += 'artifacts\publish-sentinel*' }
    # include short server logs and integration tests log if present
    if (Test-Path -Path 'artifacts\integration-tests.log') { $paths += 'artifacts\integration-tests.log' }
    if (Test-Path -Path 'artifacts\server.*.log') { $paths += 'artifacts\server.*.log' }
    if (Test-Path -Path 'artifacts\monitor-*.log') { $paths += 'artifacts\monitor-*.log' }
    # aux tmp files useful for triage
    if (Test-Path -Path 'scripts\tmp') { $paths += 'scripts\tmp\*' }
    $dest = 'artifacts/integration-report-triage.zip'
}

if (Test-Path -Path $dest) { Remove-Item -Path $dest -Force }
if ($paths.Count -eq 0) { Write-Warning 'No matching files found to include in package'; exit 0 }
Compress-Archive -Path $paths -DestinationPath $dest -Force
if (Test-Path -Path $dest) {
    Write-Host "Created: $(Resolve-Path $dest)"
} else {
    Write-Error 'Zip not created'
}
