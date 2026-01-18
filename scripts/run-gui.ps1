Set-Location 'E:\Workspaces\Git\SimRacing\USBDeviceManager\server\SimRacingDashboard'
Write-Host "Starting GUI/dashboard in foreground (project: server/SimRacingDashboard). Logs -> dashboard.log"
dotnet run -c Debug 2>&1 | Tee-Object -FilePath 'E:\Workspaces\Git\SimRacing\USBDeviceManager\server\SimRacingDashboard\dashboard.log'
