$p = "E:\Workspaces\Git\SimRacing\USBDeviceManager\agent\SimRacingAgent\agent-run.log"
if (-not (Test-Path $p)) {
    Write-Output "LOG_NOT_FOUND:$p"
    exit 1
}
Write-Output "Watching $p for 'heartbeat'..."
$line = Get-Content -Path $p -Wait -Tail 0 | Where-Object { $_ -match 'heartbeat' } | Select-Object -First 1
Write-Output "Captured: $line"
