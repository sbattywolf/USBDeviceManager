# Restart helper: stops server/agent/gui then starts server, agent, GUI, and tails the GUI log
Set-StrictMode -Version Latest
$stopped = @()

# Helper to stop a PID
function TryStopPid([int]$pid, [string]$label) {
    try {
        Stop-Process -Id $pid -Force -ErrorAction Stop
        $script:stopped += "Stopped $label PID $pid"
    } catch {
        $script:stopped += "Failed to stop $label PID $pid - $($_.Exception.Message)"
    }
}

# Stop processes listening on port 5000
try {
    $tcp = Get-NetTCPConnection -LocalPort 5000 -ErrorAction SilentlyContinue
    if ($tcp) {
        $pids = $tcp | Select-Object -ExpandProperty OwningProcess -Unique
        foreach ($pid in $pids) { TryStopPid -pid $pid -label 'listener' }
    }
} catch {
    $stopped += "Error checking port 5000: $($_.Exception.Message)"
}

# Stop any powershell process running SimRacingAgent.ps1
try {
    $agentProcs = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -match 'SimRacingAgent.ps1' }
    foreach ($p in $agentProcs) { TryStopPid -pid $p.ProcessId -label 'agent' }
} catch {
    $stopped += "Error stopping agent processes: $($_.Exception.Message)"
}

# Stop any python processes running gui/main.py or toggle_test.py
try {
    $pyProcs = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and ($_.CommandLine -match 'gui[\\/](main.py|toggle_test.py)') }
    foreach ($p in $pyProcs) { TryStopPid -pid $p.ProcessId -label 'python GUI' }
} catch {
    $stopped += "Error stopping python GUI processes: $($_.Exception.Message)"
}

# Stop dotnet processes running USBDeviceManager
try {
    $dotnetProcs = Get-CimInstance Win32_Process | Where-Object { $_.Name -and $_.Name -match 'dotnet' -and ($_.CommandLine -match 'USBDeviceManager' -or $_.CommandLine -match 'server\\USBDeviceManager') }
    foreach ($p in $dotnetProcs) { TryStopPid -pid $p.ProcessId -label 'dotnet' }
} catch {
    $stopped += "Error stopping dotnet processes: $($_.Exception.Message)"
}

# Report stopped items
Write-Output "=== Stop Summary ==="
if ($stopped.Count -gt 0) { $stopped | ForEach-Object { Write-Output $_ } } else { Write-Output 'No matching processes were found to stop.' }

# Confirm port 5000 freed
$listen = Get-NetTCPConnection -LocalPort 5000 -ErrorAction SilentlyContinue
if ($listen) { Write-Output ("Port 5000 still in use by: {0}" -f ($listen | Select-Object -ExpandProperty OwningProcess -Unique)) } else { Write-Output 'Port 5000 is free.' }

# Start server, agent, GUI, and tail logs in separate windows
Write-Output 'Starting server (dotnet run --project server/USBDeviceManager)...'
Start-Process -FilePath 'dotnet' -ArgumentList @('run','--project','server/USBDeviceManager','--urls','http://localhost:5000') -WindowStyle Normal
Start-Sleep -Seconds 3

Write-Output 'Starting agent (SimRacingAgent.ps1)...'
Start-Process -FilePath 'powershell' -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','agent/SimRacingAgent/SimRacingAgent.ps1' -WindowStyle Normal
Start-Sleep -Seconds 2

Write-Output 'Starting desktop GUI (python gui/main.py)...'
Start-Process -FilePath 'python' -ArgumentList 'gui/main.py' -WindowStyle Normal
Start-Sleep -Seconds 2

# Ensure log file exists and tail it
New-Item -ItemType Directory -Force -Path gui\logs | Out-Null
if (-not (Test-Path 'gui\logs\desktop_gui.log')) { '' | Out-File -FilePath gui\logs\desktop_gui.log -Encoding utf8 }
Write-Output 'Opening live tail of gui/logs/desktop_gui.log in new window...'
Start-Process -FilePath 'powershell' -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-Command','Get-Content -Path "gui\\logs\\desktop_gui.log" -Wait -Tail 200' -WindowStyle Normal

Write-Output 'Restart sequence complete.'
