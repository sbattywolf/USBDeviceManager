param(
    [string]$DeviceId = 'assistant-test-1',
    [string]$EventType = 'CONNECTED',
    [string]$Message = 'Device connected (test)'
)

$body = @{ deviceId = $DeviceId; eventType = $EventType; message = $Message }
try {
    Invoke-RestMethod -Uri 'http://localhost:5400/api/logs' -Method Post -ContentType 'application/json' -Body ($body | ConvertTo-Json -Depth 10) -ErrorAction Stop
    Write-Output 'POST_OK'
}
catch {
    Write-Error "POST_FAILED: $($_.Exception.Message)"
    exit 1
}
