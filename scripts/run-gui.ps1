if (Get-Process -Name USBDeviceManager -ErrorAction SilentlyContinue) {
	$p = Get-Process -Name USBDeviceManager -ErrorAction SilentlyContinue | Select-Object -First 1
	Write-Host "USBDeviceManager is already running (PID $($p.Id)). The GUI is available at http://localhost:5000"
	$logPath = 'E:\Workspaces\Git\SimRacing\USBDeviceManager\server\USBDeviceManager\dashboard.log'
	if (Test-Path $logPath) {
		Write-Host "Tailing existing log: $logPath"
		Get-Content -Path $logPath -Wait
	}
	else {
		Write-Host "No dashboard log found at $logPath. Attach a browser to http://localhost:5000 to view the GUI."
	}
	return
}

Set-Location 'E:\Workspaces\Git\SimRacing\USBDeviceManager\server\USBDeviceManager'
$logDir = 'E:\Workspaces\Git\SimRacing\USBDeviceManager\server\USBDeviceManager'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$logPath = Join-Path $logDir 'dashboard.log'
Write-Host "Starting GUI/dashboard in foreground (project: server/USBDeviceManager). Logs -> $logPath"
dotnet run -c Debug 2>&1 | Tee-Object -FilePath $logPath
