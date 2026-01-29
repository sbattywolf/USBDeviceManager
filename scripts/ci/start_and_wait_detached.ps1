Set-StrictMode -Version Latest
Set-Location -Path (Join-Path $PSScriptRoot "..\..")

# Start the CI runner detached
$proc = Start-Process -FilePath powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','.\scripts\ci\run_and_assert_process_menu_mock.ps1' -PassThru
Write-Host "Started detached runner PID=$($proc.Id)"

$log = 'scripts/ci/process-menu-mock-run.log'
$timeout = 120
for ($i=0; $i -lt $timeout; $i++) {
    if (Test-Path $log) {
        try {
            $len = (Get-Item $log).Length
            if ($len -gt 0) { break }
        } catch {}
    }
    Start-Sleep -Seconds 1
}

if (Test-Path $log) {
    Write-Host '--- Final log ---'
    Get-Content $log -Raw | Write-Host
    Write-Host '--- End log ---'
} else {
    Write-Host "<log missing after ${timeout}s>"
}

Write-Host "Detached runner PID was $($proc.Id)"
