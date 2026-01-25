param(
    [int]$TargetPid = $null,
    [string]$PidFile = 'scripts/tmp/server.pid',
    [switch]$Force
)

# Resolve PID: prefer explicit TargetPid, then pidfile
if (-not $TargetPid) {
    if (Test-Path $PidFile) {
        try { $TargetPid = [int](Get-Content $PidFile -ErrorAction Stop) } catch { $TargetPid = $null }
    }
}

if (-not $TargetPid) { Write-Host "No PID available to stop (PidFile: $PidFile); nothing to do."; exit 1 }

Write-Host "Stopping server process $TargetPid..."
try {
    # Attempt graceful stop
    Stop-Process -Id $TargetPid -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    if (Get-Process -Id $TargetPid -ErrorAction SilentlyContinue) {
        if ($Force) {
            Write-Host "Process still running; forcing stop..."
            Stop-Process -Id $TargetPid -Force -ErrorAction SilentlyContinue
        } else {
            Write-Host "Process still running after graceful stop; use -Force to kill." 
            exit 2
        }
    }
    # Remove pidfile if present
    if (Test-Path $PidFile) { Remove-Item -Path $PidFile -ErrorAction SilentlyContinue }
    Write-Host "Stopped process $TargetPid"
    exit 0
} catch {
    Write-Error ("Failed to stop process {0}: {1}" -f $TargetPid, $_.Exception.Message)
    exit 3
}
