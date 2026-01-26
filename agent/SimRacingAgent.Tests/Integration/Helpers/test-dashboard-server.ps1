# Simple PowerShell HTTP server for testing SimRacing Agent dashboard connection
param(
    [int]$Port = 5000
)

$ErrorActionPreference = "Stop"
$startTime = Get-Date

Write-Output "Starting SimRacing Dashboard Test Server on port $Port..."

# Create HTTP listener
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")

try {
    $listener.Start()
    Write-Output "Test Dashboard Server running at: http://localhost:$Port"
    Write-Output "Ready to receive agent connections..."
    Write-Output "Press Ctrl+C to stop server"

    while ($listener.IsListening) {
        try {
            $context = $listener.GetContext()
            $request = $context.Request
            $response = $context.Response

            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Write-Output "[$timestamp] $($request.HttpMethod) $($request.Url.AbsolutePath)"

            $body = ""
            if ($request.HasEntityBody) {
                $reader = New-Object System.IO.StreamReader($request.InputStream)
                $body = $reader.ReadToEnd()
                $reader.Close()
                if ($body) { Write-Output "  Body: $body" }
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
    if ($listener.IsListening) { $listener.Stop(); Write-Output "Dashboard test server stopped." }
    $listener.Dispose()
}




