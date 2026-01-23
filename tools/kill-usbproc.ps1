Get-Process -Name USBDeviceManager -ErrorAction SilentlyContinue | Select-Object Id,ProcessName,StartTime
Stop-Process -Name USBDeviceManager -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500
Get-Process -Name USBDeviceManager -ErrorAction SilentlyContinue | Select-Object Id,ProcessName,HasExited