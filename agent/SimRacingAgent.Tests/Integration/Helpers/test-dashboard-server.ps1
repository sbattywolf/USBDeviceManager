# Simple PowerShell HTTP server for testing SimRacing Agent dashboard connection
param(
    [int]$Port = 5000
)

$ErrorActionPreference = "Stop"
$startTime = Get-Date

Write-Host "Starting SimRacing Dashboard Test Server on port $Port..." -ForegroundColor Green

# Create HTTP listener
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")

try {
    $listener.Start()
    Write-Host "Test Dashboard Server running at: http://localhost:$Port" -ForegroundColor Yellow
    Write-Host "Ready to receive agent connections..." -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to stop server" -ForegroundColor Gray
    
    while ($listener.IsListening) {
        try {
            $context = $listener.GetContext()
            $request = $context.Request
            $response = $context.Response
            
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Write-Host "[$timestamp] $($request.HttpMethod) $($request.Url.AbsolutePath)" -ForegroundColor White
            
            $body = ""
            if ($request.HasEntityBody) {
                $reader = New-Object System.IO.StreamReader($request.InputStream)
                $body = $reader.ReadToEnd()
                $reader.Close()
                if ($body) { Write-Host "  Body: $body" -ForegroundColor Gray }
            }

            $response.Headers.Add("Access-Control-Allow-Origin", "*")
            $response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
            $response.Headers.Add("Access-Control-Allow-Headers", "Content-Type, Authorization")

            $path = $request.Url.AbsolutePath
            $method = $request.HttpMethod

            $responseData = @{
                message = "SimRacing Dashboard Test Server"
                endpoint = $path
                method = $method
                timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")
                status = "ok"
            }

            if ($path -match "/api/agents/.+/heartbeat" -and $method -eq "POST") {
                $responseData.type = "heartbeat"
            }
            elseif ($path -match "/api/agents/.+/devices" -and $method -eq "POST") {
                $responseData.type = "device_event"
            }
            elseif ($path -match "/api/agents/.+/software" -and $method -eq "POST") {
                $responseData.type = "software_event"
            }
            elseif ($path -match "/api/agents/.+/automation" -and $method -eq "POST") {
                $responseData.type = "automation_event"
            }
            elseif ($path -eq "/api/health" -and $method -eq "GET") {
                $responseData.type = "health_check"
                $responseData.uptime_seconds = [int]((Get-Date) - $startTime).TotalSeconds
            }

            $responseJson = $responseData | ConvertTo-Json -Compress
            $response.ContentType = "application/json"
            $response.StatusCode = 200

            $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseJson)
            $response.ContentLength64 = $buffer.Length
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            $response.OutputStream.Close()
        }
        catch [System.Net.HttpListenerException] {
            if ($_.Exception.ErrorCode -eq 995) { break }
        }
        catch {
            Write-Error "Request handling error: $($_.Exception.Message)"
        }
    }
}
catch {
    Write-Error "Failed to start server: $($_.Exception.Message)"
}
finally {
    if ($listener.IsListening) { $listener.Stop(); Write-Host "Dashboard test server stopped." -ForegroundColor Red }
    $listener.Dispose()
}
