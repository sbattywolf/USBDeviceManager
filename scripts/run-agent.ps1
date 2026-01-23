Set-Location 'E:\Workspaces\Git\SimRacing\USBDeviceManager\agent\SimRacingAgent'
Write-Host "Starting SimRacing Agent in foreground. Console + file logs will appear under Logs\"
# Prefer stable log path, but if the file is locked, fall back to a timestamped file to avoid startup failure.
$defaultLog = 'E:\Workspaces\Git\SimRacing\USBDeviceManager\agent\SimRacingAgent\agent-run.log'
$logPath = $defaultLog
try {
	# Try to open for append to detect lock
	$stream = [System.IO.File]::Open($logPath, 'Append', 'Write', 'None')
	$stream.Close()
} catch {
	$ts = (Get-Date).ToString('yyyyMMdd-HHmmss')
	$logPath = "E:\Workspaces\Git\SimRacing\USBDeviceManager\agent\SimRacingAgent\agent-run-$ts.log"
	Write-Host "Default log locked; using fallback log: $logPath"
}

# Run the agent script in the same folder; allow script to write its own logs
powershell -NoProfile -ExecutionPolicy Bypass -File '.\SimRacingAgent.ps1' 2>&1 | Tee-Object -FilePath $logPath
