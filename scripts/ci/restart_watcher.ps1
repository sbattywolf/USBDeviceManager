# Stop any running watch_scanner.ps1 instances
$ps = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and ($_.CommandLine -match 'watch_scanner.ps1') }
if ($ps) {
    $ps | Select-Object ProcessId,Name,CommandLine | Format-Table | Out-String | Write-Host
    foreach ($p in $ps) {
        try {
            Stop-Process -Id $p.ProcessId -ErrorAction Stop
            Write-Host "Stopped $($p.ProcessId)"
        } catch {
            Write-Host "Failed stopping $($p.ProcessId): $($_.Exception.Message)"
        }
    }
} else {
    Write-Host 'No existing watcher processes'
}

# Start new watcher with 5s interval
Start-Process -FilePath powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','.\\scripts\\ci\\watch_scanner.ps1','-Interval','5' -WindowStyle Hidden
Write-Host 'Started watcher with interval=5s'