Set-Location 'E:\Workspaces\Git\SimRacing\USBDeviceManager'
# Start server detached if not already running
$found = Get-CimInstance Win32_Process -Filter "Name='dotnet.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match 'server\\USBDeviceManager' }
if ($found) { Write-Host 'Server process already appears to be running; skipping start.' } else { Start-Process -FilePath 'dotnet' -ArgumentList 'run','--project','server/USBDeviceManager','--urls','http://localhost:5000' -WorkingDirectory (Get-Location) -WindowStyle Hidden; Write-Host 'Started server (detached).' }
# Wait for readiness and open page
$timeout = 30; $t = 0; while ($t -lt $timeout) { try { $r = Invoke-WebRequest -Uri 'http://localhost:5000/health' -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop; if ($r.StatusCode -eq 200) { Write-Host 'Server is ready.'; Start-Process 'http://localhost:5000/server-status'; exit 0 } } catch { } Start-Sleep -Seconds 1; $t++ }
Write-Host 'Server did not report ready within timeout; opening ServerStatus page anyway.'; Start-Process 'http://localhost:5000/server-status'