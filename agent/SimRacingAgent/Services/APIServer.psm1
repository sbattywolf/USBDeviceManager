#
# APIServer.psm1 - REST API server for SimRacing Agent
#

$Global:HttpListener = $null
$Global:APIServerRunspace = $null

function Start-APIServer {
    <#
    .SYNOPSIS
        Start the REST API server
    #>
    param(
        [Parameter(Mandatory=$false)]
        [int]$Port = 8080
    )
    
    try {
        if ($Global:HttpListener) {
            Write-AgentLog "SimRacingApp server is already running" -Level Warning -Component "API"
            return
        }
        
        Write-AgentLog "Starting SimRacingApp server on port $Port..." -Level Info -Component "API"
        
        # Create HTTP listener
        $Global:HttpListener = New-Object System.Net.HttpListener
        $Global:HttpListener.Prefixes.Add("http://localhost:$Port/")
        $Global:HttpListener.Start()
        
        # Start listener in background runspace
        $Global:APIServerRunspace = [powershell]::Create()
        $Global:APIServerRunspace.AddScript({
            param($Listener, $Config)
            
            try {
                while ($Listener.IsListening) {
                    $context = $Listener.GetContext()
                    $request = $context.Request
                    $response = $context.Response
                    
                    try {
                        # Check if request is from allowed host
                        $clientIP = $request.RemoteEndPoint.Address.ToString()
                        if ($Config.Network.IntranetOnly -and -not (Test-IntranetIP $clientIP)) {
                            Send-APIResponse $response 403 @{ error = "Access denied from external network" }
                            continue
                        }
                        
                        # Route the request
                        $result = Invoke-APIRoute -Request $request -Config $Config
                        Send-APIResponse $response $result.StatusCode $result.Data
                    }
                    catch {
                        Write-Host "API Error: $_" -ForegroundColor Red
                        Send-APIResponse $response 500 @{ error = $_.ToString() }
                    }
                }
            }
            catch {
                Write-Host "API Server Error: $_" -ForegroundColor Red
            }
        })
        
        $Global:APIServerRunspace.AddParameter("Listener", $Global:HttpListener)
        $Global:APIServerRunspace.AddParameter("Config", $Global:AgentConfig)
        $Global:APIServerRunspace.BeginInvoke() | Out-Null
        
        Write-AgentLog "API server started successfully on http://localhost:$Port/" -Level Info -Component "API"
    }
    catch {
        Write-AgentLog "Failed to start API server: $_" -Level Error -Component "API"
        throw
    }
}

function Stop-APIServer {
    <#
    .SYNOPSIS
        Stop the REST API server
    #>
    
    try {
        if ($Global:HttpListener) {
            $Global:HttpListener.Stop()
            $Global:HttpListener.Close()
            $Global:HttpListener = $null
        }
        
        if ($Global:APIServerRunspace) {
            $Global:APIServerRunspace.Stop()
            $Global:APIServerRunspace.Dispose()
            $Global:APIServerRunspace = $null
        }
        
        Write-AgentLog "API server stopped" -Level Info -Component "API"
    }
    catch {
        Write-AgentLog "Error stopping API server: $_" -Level Error -Component "API"
    }
}

function Invoke-APIRoute {
    <#
    .SYNOPSIS
        Route API requests to appropriate handlers
    #>
    param(
        [System.Net.HttpListenerRequest]$Request,
        [hashtable]$Config
    )
    
    $method = $Request.HttpMethod
    $path = $Request.Url.AbsolutePath.TrimEnd('/')
    $query = @{}
    
    # Parse query parameters
    foreach ($key in $Request.QueryString.AllKeys) {
        if ($key) {
            $query[$key] = $Request.QueryString[$key]
        }
    }
    
    # Parse request body for POST/PUT requests
    $body = $null
    if ($method -in @("POST", "PUT") -and $Request.HasEntityBody) {
        $reader = New-Object System.IO.StreamReader($Request.InputStream)
        $bodyText = $reader.ReadToEnd()
        $reader.Close()
        
        if ($Request.ContentType -like "*application/json*") {
            try {
                $body = $bodyText | ConvertFrom-Json -AsHashtable
            }
            catch {
                return @{ StatusCode = 400; Data = @{ error = "Invalid JSON in request body" } }
            }
        } else {
            $body = $bodyText
        }
    }
    
    # Route to handlers
    switch -Regex ($path) {
        "^/?$" {
            # Root - API info
            return @{ 
                StatusCode = 200
                Data = @{
                    name = "SimRacingApp API"
                    version = $Global:AgentVersion
                    status = "running"
                    endpoints = @(
                        "/status",
                        "/usb",
                        "/processes",
                        "/config"
                    )
                }
            }
        }
        
        "^/status/?$" {
            return Invoke-StatusAPI -Method $method -Query $query -Body $body
        }
        
        "^/usb/?$" {
            return Invoke-USBAPI -Method $method -Query $query -Body $body
        }
        
        "^/usb/([^/]+)/?$" {
            $deviceId = $matches[1]
            return Invoke-USBDeviceAPI -Method $method -DeviceId $deviceId -Query $query -Body $body
        }
        
        "^/processes/?$" {
            return Invoke-ProcessAPI -Method $method -Query $query -Body $body
        }
        
        "^/processes/([^/]+)/?$" {
            $processName = $matches[1]
            return Invoke-ProcessControlAPI -Method $method -ProcessName $processName -Query $query -Body $body
        }
        
        "^/config/?$" {
            return Invoke-ConfigAPI -Method $method -Query $query -Body $body
        }
        
        # HEALTH CHECK ENDPOINTS - PUT-based polling for efficient monitoring
        "^/healthcheck/?$" {
            return Invoke-HealthCheckAPI -Method $method -Query $query -Body $body
        }
        
        "^/healthcheck/usb/?$" {
            return Invoke-USBHealthCheckAPI -Method $method -Query $query -Body $body
        }
        
        "^/healthcheck/processes/?$" {
            return Invoke-ProcessHealthCheckAPI -Method $method -Query $query -Body $body
        }
        
        # ALIASES for backward compatibility and convenience
        "^/health/?$" {
            return Invoke-HealthCheckAPI -Method $method -Query $query -Body $body
        }
        
        "^/health/usb/?$" {
            return Invoke-USBHealthCheckAPI -Method $method -Query $query -Body $body
        }
        
        "^/health/processes/?$" {
            return Invoke-ProcessHealthCheckAPI -Method $method -Query $query -Body $body
        }
        
        default {
            return @{ StatusCode = 404; Data = @{ error = "Endpoint not found" } }
        }
    }
}

function Invoke-StatusAPI {
    param($Method, $Query, $Body)
    
    if ($Method -eq "GET") {
        $versionInfo = Get-AgentVersion
        $usbStats = Get-USBStatistics
        
        return @{
            StatusCode = 200
            Data = @{
                agent = @{
                    version = $versionInfo.Version
                    pid = $Global:AgentPID
                    uptime = (Get-Date) - (Get-Process -Id $Global:AgentPID).StartTime
                    buildDate = $versionInfo.BuildDate
                }
                usb = $usbStats
                processes = @{
                    managedCount = $Global:ManagedProcesses.Count
                    runningCount = ($Global:ManagedProcesses.Values | Where-Object { $_.Status -eq "Running" }).Count
                }
                api = @{
                    port = $Global:AgentConfig.API.Port
                    requestCount = if ($Global:APIRequestCount) { $Global:APIRequestCount } else { 0 }
                }
                timestamp = Get-Date
            }
        }
    } else {
        return @{ StatusCode = 405; Data = @{ error = "Method not allowed" } }
    }
}

function Invoke-USBAPI {
    param($Method, $Query, $Body)
    
    switch ($Method) {
        "GET" {
            $devices = Get-USBDevices
            return @{
                StatusCode = 200
                Data = @{
                    devices = $devices
                    count = $devices.Count
                    timestamp = Get-Date
                }
            }
        }
        
        "POST" {
            if ($Body -and $Body.action) {
                switch ($Body.action) {
                    "refresh" {
                        $result = Invoke-USBRefresh
                        return @{
                            StatusCode = if ($result) { 200 } else { 500 }
                            Data = @{
                                action = "refresh"
                                success = $result
                                message = if ($result) { "USB subsystem refreshed" } else { "Failed to refresh USB subsystem" }
                            }
                        }
                    }
                    default {
                        return @{ StatusCode = 400; Data = @{ error = "Unknown action: $($Body.action)" } }
                    }
                }
            } else {
                return @{ StatusCode = 400; Data = @{ error = "Action required in request body" } }
            }
        }
        
        default {
            return @{ StatusCode = 405; Data = @{ error = "Method not allowed" } }
        }
    }
}

function Invoke-USBDeviceAPI {
    param($Method, $DeviceId, $Query, $Body)
    
    switch ($Method) {
        "POST" {
            if ($Body -and $Body.action) {
                $decodedDeviceId = [System.Net.WebUtility]::UrlDecode($DeviceId)
                
                switch ($Body.action) {
                    "enable" {
                        $result = Enable-USBDevice -DeviceID $decodedDeviceId
                        return @{
                            StatusCode = if ($result) { 200 } else { 500 }
                            Data = @{
                                deviceId = $decodedDeviceId
                                action = "enable"
                                success = $result
                            }
                        }
                    }
                    
                    "disable" {
                        $result = Disable-USBDevice -DeviceID $decodedDeviceId
                        return @{
                            StatusCode = if ($result) { 200 } else { 500 }
                            Data = @{
                                deviceId = $decodedDeviceId
                                action = "disable"
                                success = $result
                            }
                        }
                    }
                    
                    default {
                        return @{ StatusCode = 400; Data = @{ error = "Unknown action: $($Body.action)" } }
                    }
                }
            } else {
                return @{ StatusCode = 400; Data = @{ error = "Action required in request body" } }
            }
        }
        
        default {
            return @{ StatusCode = 405; Data = @{ error = "Method not allowed" } }
        }
    }
}

function Invoke-ProcessAPI {
    param($Method, $Query, $Body)
    
    switch ($Method) {
        "GET" {
            $processes = Get-ManagedProcesses
            return @{
                StatusCode = 200
                Data = @{
                    processes = $processes
                    count = $processes.Count
                    timestamp = Get-Date
                }
            }
        }
        
        "POST" {
            # Add new managed process
            if ($Body -and $Body.name -and $Body.executablePath) {
                $result = Add-ManagedProcess -Name $Body.name -ExecutablePath $Body.executablePath -Arguments $Body.arguments -WorkingDirectory $Body.workingDirectory -AutoRestart $Body.autoRestart -RestartDelay $Body.restartDelay -MaxRestarts $Body.maxRestarts
                
                return @{
                    StatusCode = if ($result) { 201 } else { 500 }
                    Data = @{
                        name = $Body.name
                        success = $result
                        message = if ($result) { "Process added successfully" } else { "Failed to add process" }
                    }
                }
            } else {
                return @{ StatusCode = 400; Data = @{ error = "Name and executablePath required" } }
            }
        }
        
        default {
            return @{ StatusCode = 405; Data = @{ error = "Method not allowed" } }
        }
    }
}

function Invoke-ProcessControlAPI {
    param($Method, $ProcessName, $Query, $Body)
    
    $decodedProcessName = [System.Net.WebUtility]::UrlDecode($ProcessName)
    
    switch ($Method) {
        "GET" {
            $status = Get-ProcessStatus -ProcessName $decodedProcessName
            if ($status) {
                return @{
                    StatusCode = 200
                    Data = $status
                }
            } else {
                return @{ StatusCode = 404; Data = @{ error = "Process not found" } }
            }
        }
        
        "POST" {
            if ($Body -and $Body.action) {
                switch ($Body.action) {
                    "start" {
                        $result = Start-ManagedProcess -ProcessName $decodedProcessName -AdditionalArguments $Body.arguments
                        return @{
                            StatusCode = if ($result) { 200 } else { 500 }
                            Data = @{
                                processName = $decodedProcessName
                                action = "start"
                                success = $result
                            }
                        }
                    }
                    
                    "stop" {
                        $result = Stop-ManagedProcess -ProcessName $decodedProcessName -Force $Body.force
                        return @{
                            StatusCode = if ($result) { 200 } else { 500 }
                            Data = @{
                                processName = $decodedProcessName
                                action = "stop"
                                success = $result
                            }
                        }
                    }
                    
                    "restart" {
                        $result = Restart-ManagedProcess -ProcessName $decodedProcessName -AdditionalArguments $Body.arguments -DelaySeconds $Body.delaySeconds
                        return @{
                            StatusCode = if ($result) { 200 } else { 500 }
                            Data = @{
                                processName = $decodedProcessName
                                action = "restart"
                                success = $result
                            }
                        }
                    }
                    
                    default {
                        return @{ StatusCode = 400; Data = @{ error = "Unknown action: $($Body.action)" } }
                    }
                }
            } else {
                return @{ StatusCode = 400; Data = @{ error = "Action required in request body" } }
            }
        }
        
        "DELETE" {
            $result = Remove-ManagedProcess -ProcessName $decodedProcessName
            return @{
                StatusCode = if ($result) { 200 } else { 500 }
                Data = @{
                    processName = $decodedProcessName
                    action = "delete"
                    success = $result
                }
            }
        }
        
        default {
            return @{ StatusCode = 405; Data = @{ error = "Method not allowed" } }
        }
    }
}

function Invoke-ConfigAPI {
    param($Method, $Query, $Body)
    
    switch ($Method) {
        "GET" {
            # Get configuration (sanitized)
            $config = $Global:AgentConfig.Clone()
            # Remove sensitive information
            $config.Remove('ConfigFilePath')
            
            return @{
                StatusCode = 200
                Data = $config
            }
        }
        
        "PUT" {
            # Update configuration
            if ($Body -and $Body.key -and $Body.ContainsKey('value')) {
                try {
                    Update-ConfigurationValue -KeyPath $Body.key -Value $Body.value
                    return @{
                        StatusCode = 200
                        Data = @{
                            key = $Body.key
                            value = $Body.value
                            message = "Configuration updated successfully"
                        }
                    }
                }
                catch {
                    return @{
                        StatusCode = 500
                        Data = @{
                            error = "Failed to update configuration: $_"
                        }
                    }
                }
            } else {
                return @{ StatusCode = 400; Data = @{ error = "Key and value required" } }
            }
        }
        
        default {
            return @{ StatusCode = 405; Data = @{ error = "Method not allowed" } }
        }
    }
}

function Invoke-HealthCheckAPI {
    <#
    .SYNOPSIS
        Handle comprehensive health check requests
    .DESCRIPTION
        CRITICAL API: This endpoint handles PUT-based polling for agent health.
        Replaces continuous monitoring with on-demand health checking.
        Clients should use PUT to trigger fresh status collection.
    #>
    param($Method, $Query, $Body)
    
    switch ($Method) {
        "GET" {
            # Return basic health check info (lightweight)
            return @{
                StatusCode = 200
                Data = @{
                    service = "healthcheck"
                    mode = "polling"
                    endpoints = @("/healthcheck/usb", "/healthcheck/processes")
                    intervals = @{
                        usb = $Global:AgentConfig.USB.HealthCheckInterval
                        processes = $Global:AgentConfig.ProcessManager.HealthCheckInterval
                        agentIdle = $Global:AgentConfig.AgentHealthCheck.IdleTimeoutSeconds
                    }
                }
            }
        }
        
        "PUT" {
            # COMPREHENSIVE: Trigger comprehensive health check across all components
            try {
                $healthCheckStartTime = Get-Date
                Write-AgentLog "🚀 Comprehensive health check requested via API" -Level Info -Component "API-HealthCheck"
                
                # Parallel health check execution for optimal performance
                $usbHealth = Get-USBHealthCheck
                $processHealth = Get-ProcessHealthCheck
                $totalDuration = ((Get-Date) - $healthCheckStartTime).TotalMilliseconds
                
                # COMPREHENSIVE: Aggregate analytics across all components
                $overallHealth = @{
                    score = [math]::Round((
                        ($usbHealth.DeviceCount * 10) + 
                        ($processHealth.Analytics.HealthyProcesses * 20) - 
                        ($processHealth.Analytics.UnhealthyProcesses * 15)
                    ) / [math]::Max(1, $usbHealth.DeviceCount + $processHealth.ProcessCount), 2)
                    status = "Unknown"
                    recommendations = @()
                }
                
                # Intelligent overall status determination
                if ($overallHealth.score -ge 80) { $overallHealth.status = "Excellent" }
                elseif ($overallHealth.score -ge 60) { $overallHealth.status = "Good" }
                elseif ($overallHealth.score -ge 40) { $overallHealth.status = "Warning" }
                else { $overallHealth.status = "Critical" }
                
                # Aggregate recommendations
                if ($usbHealth.Recommendations.Activity -eq "High") {
                    $overallHealth.recommendations += "High USB activity detected"
                }
                if ($processHealth.Recommendations.Activity -eq "Critical") {
                    $overallHealth.recommendations += "Critical process issues detected"
                }
                
                return @{
                    StatusCode = 200
                    Data = @{
                        timestamp = Get-Date
                        agent = @{
                            version = $Global:AgentVersion
                            pid = $Global:AgentPID
                            uptime = (Get-Date) - (Get-Process -Id $Global:AgentPID).StartTime
                        }
                        usb = $usbHealth
                        processes = $processHealth
                        overall = $overallHealth
                        performance = @{
                            totalDuration = [math]::Round($totalDuration, 2)
                            usbScanTime = $usbHealth.Performance.TotalDuration
                            processScanTime = $processHealth.Performance.HealthCheckDuration
                        }
                        healthCheckMode = $true
                        nextRecommendedCheck = [math]::Min(
                            $usbHealth.Recommendations.NextCheckIn,
                            $processHealth.Recommendations.NextCheckIn
                        )
                    }
                }
            }
            catch {
                Write-AgentLog "❌ Health check failed: $_" -Level Error -Component "API-HealthCheck"
                return @{
                    StatusCode = 500
                    Data = @{
                        error = "Health check failed: $_"
                        timestamp = Get-Date
                        healthCheckMode = $true
                        fallbackRecommendation = "Try individual component health checks"
                    }
                }
            }
        }
        
        default {
            return @{ StatusCode = 405; Data = @{ error = "Method not allowed" } }
        }
    }
}

function Invoke-USBHealthCheckAPI {
    <#
    .SYNOPSIS
        Handle USB-specific health check requests  
    .DESCRIPTION
        USB HEALTH CHECK: PUT-based polling for USB device status.
        More efficient than continuous monitoring - only checks when requested.
    #>
    param($Method, $Query, $Body)
    
    switch ($Method) {
        "GET" {
            # Return USB health check configuration
            return @{
                StatusCode = 200
                Data = @{
                    service = "usb-healthcheck"
                    interval = $Global:AgentConfig.USB.HealthCheckInterval
                    enabled = $Global:AgentConfig.USB.Enabled
                    monitoringMode = "polling"
                }
            }
        }
        
        "PUT" {
            # CRITICAL: Trigger fresh USB device health check
            try {
                if (-not $Global:AgentConfig.USB.Enabled) {
                    return @{
                        StatusCode = 503
                        Data = @{ error = "USB monitoring is disabled" }
                    }
                }
                
                Write-AgentLog "USB health check requested via API" -Level Debug -Component "API-USB-HealthCheck"
                $usbHealth = Get-USBHealthCheck
                
                return @{
                    StatusCode = 200
                    Data = $usbHealth
                }
            }
            catch {
                Write-AgentLog "USB health check failed: $_" -Level Error -Component "API-USB-HealthCheck"
                return @{
                    StatusCode = 500
                    Data = @{
                        error = "USB health check failed: $_"
                        timestamp = Get-Date
                    }
                }
            }
        }
        
        default {
            return @{ StatusCode = 405; Data = @{ error = "Method not allowed" } }
        }
    }
}

function Invoke-ProcessHealthCheckAPI {
    <#
    .SYNOPSIS
        Handle process-specific health check requests
    .DESCRIPTION
        PROCESS HEALTH CHECK: PUT-based polling for managed process status.
        Critical for process lifecycle management and auto-restart decisions.
    #>
    param($Method, $Query, $Body)
    
    switch ($Method) {
        "GET" {
            # Return process health check configuration  
            return @{
                StatusCode = 200
                Data = @{
                    service = "process-healthcheck"
                    interval = $Global:AgentConfig.ProcessManager.HealthCheckInterval
                    enabled = $Global:AgentConfig.ProcessManager.Enabled
                    managedCount = $Global:ManagedProcesses.Count
                    monitoringMode = "polling"
                }
            }
        }
        
        "PUT" {
            # CRITICAL: Trigger fresh process health check
            try {
                if (-not $Global:AgentConfig.ProcessManager.Enabled) {
                    return @{
                        StatusCode = 503
                        Data = @{ error = "Process management is disabled" }
                    }
                }
                
                Write-AgentLog "Process health check requested via API" -Level Debug -Component "API-Process-HealthCheck"
                $processHealth = Get-ProcessHealthCheck
                
                return @{
                    StatusCode = 200
                    Data = $processHealth
                }
            }
            catch {
                Write-AgentLog "Process health check failed: $_" -Level Error -Component "API-Process-HealthCheck"
                return @{
                    StatusCode = 500
                    Data = @{
                        error = "Process health check failed: $_"
                        timestamp = Get-Date
                    }
                }
            }
        }
        
        default {
            return @{ StatusCode = 405; Data = @{ error = "Method not allowed" } }
        }
    }
}

function Send-APIResponse {
    <#
    .SYNOPSIS
        Send HTTP response with JSON data
    #>
    param(
        [System.Net.HttpListenerResponse]$Response,
        [int]$StatusCode,
        [object]$Data
    )
    
    try {
        $Response.StatusCode = $StatusCode
        $Response.ContentType = "application/json"
        $Response.Headers.Add("Access-Control-Allow-Origin", "*")
        $Response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        $Response.Headers.Add("Access-Control-Allow-Headers", "Content-Type")
        
        $json = $Data | ConvertTo-Json -Depth 10 -Compress
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
        $Response.ContentLength64 = $buffer.Length
        $Response.OutputStream.Write($buffer, 0, $buffer.Length)
    }
    catch {
        Write-Host "Error sending response: $_" -ForegroundColor Red
    }
    finally {
        try {
            $Response.OutputStream.Close()
        } catch {}
    }
}

function Test-IntranetIP {
    <#
    .SYNOPSIS
        Test if IP address is in intranet range
    #>
    param([string]$IPAddress)
    
    try {
        $ip = [System.Net.IPAddress]::Parse($IPAddress)
        $bytes = $ip.GetAddressBytes()
        
        # Check localhost
        if ($IPAddress -in @("127.0.0.1", "::1")) {
            return $true
        }
        
        # Check private network ranges
        # 192.168.0.0/16
        if ($bytes[0] -eq 192 -and $bytes[1] -eq 168) {
            return $true
        }
        
        # 10.0.0.0/8
        if ($bytes[0] -eq 10) {
            return $true
        }
        
        # 172.16.0.0/12
        if ($bytes[0] -eq 172 -and $bytes[1] -ge 16 -and $bytes[1] -le 31) {
            return $true
        }
        
        return $false
    }
    catch {
        return $false
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Start-APIServer',
    'Stop-APIServer'
)