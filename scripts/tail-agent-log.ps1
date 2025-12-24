$logsDir = 'E:\Workspaces\Git\SimRacing\USBDeviceManager\agent\SimRacingAgent\Logs'
$log = Get-ChildItem -Path $logsDir -Filter 'SimRacingAgent-*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
if ($null -eq $log) {
    Write-Host "No agent log found in $logsDir"
    Pause
} else {
    Write-Host "Tailing agent log: $log"
    Get-Content -Path $log -Wait -Tail 200
}
