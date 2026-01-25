$f = 'artifacts/integration.trx'
if (Test-Path $f) {
    $count = (Select-String -Path $f -Pattern 'outcome="Failed"' | Measure-Object).Count
    Write-Output "FailedCount=$count"
    if ($count -gt 0) {
        Copy-Item -Path 'server/USBDeviceManager/simracing.db' -Destination 'artifacts/ci-local-simracing-on-failure.db' -Force
        Write-Output 'DB_COPIED'
    }
} else {
    Write-Output 'TRX_MISSING'
    Copy-Item -Path 'server/USBDeviceManager/simracing.db' -Destination 'artifacts/ci-local-simracing-on-failure.db' -Force
    Write-Output 'DB_COPIED_NO_TRX'
}