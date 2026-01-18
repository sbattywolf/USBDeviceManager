Set-Location 'E:\Workspaces\Git\SimRacing\USBDeviceManager\agent\SimRacingAgent'
Write-Host "Starting SimRacing Agent in foreground. Console + file logs will appear under Logs\"
# Run the agent script in the same folder; allow script to write its own logs
powershell -NoProfile -ExecutionPolicy Bypass -File '.\SimRacingAgent.ps1' 2>&1 | Tee-Object -FilePath 'E:\Workspaces\Git\SimRacing\USBDeviceManager\agent\SimRacingAgent\agent-run.log'
