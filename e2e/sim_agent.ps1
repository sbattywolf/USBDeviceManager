param(
    [string]$ServerUrl = 'http://localhost:5000'
)

# Simple simulated agent: POSTs a heartbeat JSON to the server
$heartbeat = @{ 
    agentId = "sim-agent-1"
    version = "0.1.0"
    mode = "Simulated"
    timestamp = (Get-Date).ToString("o")
} | ConvertTo-Json

$uri = "$ServerUrl/api/agents/heartbeat"
Write-Host "Posting heartbeat to $uri"

try {
    $r = Invoke-RestMethod -Uri $uri -Method Post -Body $heartbeat -ContentType 'application/json'
    Write-Host "Server response:`n$r"
} catch {
    Write-Host "Failed to POST heartbeat: $_" -ForegroundColor Red
    exit 1
}

Write-Host "Simulated agent done."