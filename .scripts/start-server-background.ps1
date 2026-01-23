Set-Location 'E:\Workspaces\Git\SimRacing\USBDeviceManager'
if (-not (Test-Path '.\logs')) { New-Item -ItemType Directory -Path '.\logs' | Out-Null }
Write-Output "Starting server and writing logs to .\logs\server-run.log"
# Redirect all output to log file
& dotnet run --project server/USBDeviceManager --urls 'http://localhost:5000' *> .\logs\server-run.log
