$pidFile = "scripts/tmp/server.pid"
if (Test-Path $pidFile) {
    $raw = Get-Content $pidFile -ErrorAction SilentlyContinue | Out-String
    $pStr = $raw.Trim()
    $procId = $null
    try { $procId = [int]$pStr } catch { $procId = $null }
    if ($procId -and (Get-Process -Id $procId -ErrorAction SilentlyContinue)) {
        Write-Host "Found server pid: $procId"
        try {
            Stop-Process -Id $procId -Force -ErrorAction Stop
            Write-Host "Stopped process $procId"
            Remove-Item $pidFile -ErrorAction SilentlyContinue
        } catch {
            Write-Host ('Failed to stop process {0}: {1}' -f $procId, $_.Exception.Message)
        }
    } else {
        Write-Host "No running server process found for pid file. Removing pid file if present."
        Remove-Item $pidFile -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "No pid file present."
}
