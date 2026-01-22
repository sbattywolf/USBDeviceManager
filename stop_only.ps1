Set-StrictMode -Version Latest
$stopped = @()
function TryStopPid([int]$idToKill, [string]$label){
    try{
        Stop-Process -Id $idToKill -Force -ErrorAction Stop
        $script:stopped += ("Stopped {0} PID {1}" -f $label, $idToKill)
    } catch {
        $script:stopped += ("Failed to stop {0} PID {1} - {2}" -f $label, $idToKill, $_.Exception.Message)
    }
}

# dotnet server
try{
    $procs = Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'dotnet' -and ($_.CommandLine -match 'USBDeviceManager' -or $_.CommandLine -match 'server\\USBDeviceManager') }
    foreach($p in $procs){ TryStopPid -idToKill $p.ProcessId -label 'dotnet server' }
} catch { $stopped += ("Error finding dotnet: {0}" -f $_.Exception.Message) }

# agent powershell
try{
    $procs = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -match 'SimRacingAgent.ps1' }
    foreach($p in $procs){ TryStopPid -idToKill $p.ProcessId -label 'agent' }
} catch { $stopped += ("Error finding agents: {0}" -f $_.Exception.Message) }

# python GUI
try{
    $procs = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and ($_.CommandLine -match 'gui[\\/]main.py' -or $_.CommandLine -match 'gui[\\/]toggle_test.py') }
    foreach($p in $procs){ TryStopPid -idToKill $p.ProcessId -label 'python gui' }
} catch { $stopped += ("Error finding python gui: {0}" -f $_.Exception.Message) }

# log tails (Get-Content -Wait)
try{
    $procs = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and ($_.CommandLine -match 'Get-Content' -or $_.CommandLine -match 'desktop_gui.log' -or $_.CommandLine -match 'gui\\logs') }
    foreach($p in $procs){ TryStopPid -idToKill $p.ProcessId -label 'log-tail' }
} catch { $stopped += ("Error finding tails: {0}" -f $_.Exception.Message) }

Write-Output '=== Stop Summary ==='
if($stopped.Count -gt 0){ $stopped | ForEach-Object { Write-Output $_ } } else { Write-Output 'No matching processes found.' }

# confirm port
$listen = Get-NetTCPConnection -LocalPort 5000 -ErrorAction SilentlyContinue
if($listen){ Write-Output ("Port 5000 in use by: {0}" -f ($listen | Select-Object -ExpandProperty OwningProcess -Unique)) } else { Write-Output 'Port 5000 is free.' }
