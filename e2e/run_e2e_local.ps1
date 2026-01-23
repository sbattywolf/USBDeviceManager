param(
    [string]$ServerProject = 'server/USBDeviceManager',
    [string]$ServerUrl = 'http://localhost:5000'
)

# Starts server in background and runs simulated agent
Write-Host "Starting server ($ServerProject) in background..."
$serverProcess = Start-Process -FilePath 'dotnet' -ArgumentList "run --project $ServerProject --urls '$ServerUrl'" -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 4

try {
    Write-Host "Running simulated agent against $ServerUrl"
    powershell -NoProfile -ExecutionPolicy Bypass -File .\e2e\sim_agent.ps1 -ServerUrl $ServerUrl
} finally {
    if ($null -ne $serverProcess) {
        Write-Host "Stopping server (Id: $($serverProcess.Id))"
        Stop-Process -Id $serverProcess.Id -ErrorAction SilentlyContinue
    }
}

Write-Host "E2E run complete."