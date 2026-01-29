# Safely stop detached CI runner processes that match our known script names
$ps = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and ($_.CommandLine -match 'run_and_assert_process_menu_mock.ps1' -or $_.CommandLine -match 'start_and_wait_detached.ps1') }
if (-not $ps) {
    Write-Host 'No detached runner processes found.'
    exit 0
}
foreach ($p in $ps) {
    Write-Host 'Found PID:' $p.ProcessId
    Write-Host $p.CommandLine
    try {
        Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop
        Write-Host 'Stopped PID:' $p.ProcessId
    } catch {
        Write-Warning ("Failed to stop PID {0}: {1}" -f $p.ProcessId, $_.Exception.Message)
    }
}
