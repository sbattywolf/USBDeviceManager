$body = @{
    deviceId = 'assistant-test-1'
    eventType = 'INFO'
    message = 'Test log from assistant (valid payload)'
} | ConvertTo-Json

Invoke-RestMethod -Uri 'http://localhost:5400/api/logs' -Method Post -Body $body -ContentType 'application/json' -ErrorAction Stop
Write-Output 'POST_OK'