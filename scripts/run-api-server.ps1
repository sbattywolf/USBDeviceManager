Set-Location 'E:\Workspaces\Git\SimRacing\USBDeviceManager\server\USBDeviceManager'
Write-Host "Starting API server in foreground (project: server/USBDeviceManager). Logs -> server.log"
dotnet run -c Debug 2>&1 | Tee-Object -FilePath 'E:\Workspaces\Git\SimRacing\USBDeviceManager\server\USBDeviceManager\server.log'
