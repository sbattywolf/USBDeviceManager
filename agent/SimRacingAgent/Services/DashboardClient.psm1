# Dashboard API Client
# REST API client for communicating with SimRacing Dashboard

using module ..\Utils\Logging.psm1

class DashboardClient {
    [string]$BaseUrl
    [hashtable]$Headers
    [int]$TimeoutSeconds
    [bool]$IsConnected

    DashboardClient([string]$BaseUrl = "http://localhost:5000") {
        $this.BaseUrl = $BaseUrl.TrimEnd('/')
        $this.Headers = @{
            'Content-Type' = 'application/json'
            'User-Agent' = 'SimRacingAgent/1.0'
        }
        $this.TimeoutSeconds = 30
        $this.IsConnected = $false
        $this.TestConnection()
    }

    [bool]TestConnection() {
        try {
            $response = Invoke-RestMethod -Uri "$($this.BaseUrl)/api/health" -Method GET -Headers $this.Headers -TimeoutSec 5
            $this.IsConnected = $response.Status -eq "Healthy"
            
            if ($this.IsConnected) {
                Write-AgentLog "Connected to dashboard at $($this.BaseUrl)" -Level Info
            }
            
            return $this.IsConnected
        }
        catch {
            $this.IsConnected = $false
            Write-AgentLog "Failed to connect to dashboard: $($_.Exception.Message)" -Level Warning
            return $false
        }
    }

    [hashtable]SendRequest([string]$Method, [string]$Endpoint, [object]$Body = $null) {
        try {
            $uri = "$($this.BaseUrl)$Endpoint"
            $params = @{
                Uri = $uri
                Method = $Method
                Headers = $this.Headers
                TimeoutSec = $this.TimeoutSeconds
            }
            
            if ($Body) {
                $params.Body = if ($Body -is [string]) { $Body } else { $Body | ConvertTo-Json -Depth 10 }
            }
            
            $response = Invoke-RestMethod @params
            
            return @{
                Success = $true
                Data = $response
                StatusCode = 200
            }
        }
        catch {
            Write-AgentLog "Dashboard API error ($Method $Endpoint): $($_.Exception.Message)" -Level Error
            
            return @{
                Success = $false
                Error = $_.Exception.Message
                StatusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { 0 }
            }
        }
    }

    # Device Management
    [hashtable]SendDeviceEvent([string]$EventType, [hashtable]$DeviceData) {
        $endpoint = "/api/devices/events"
        $payload = @{
            Event = $EventType
            Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
            Device = $DeviceData
        }
        
        return $this.SendRequest("POST", $endpoint, $payload)
    }

    [hashtable]GetDevices() {
        return $this.SendRequest("GET", "/api/devices")
    }

    [hashtable]GetDevice([string]$DeviceId) {
        return $this.SendRequest("GET", "/api/devices/$DeviceId")
    }

    [hashtable]UpdateDeviceConfiguration([string]$DeviceId, [hashtable]$Configuration) {
        return $this.SendRequest("PUT", "/api/devices/$DeviceId/config", $Configuration)
    }

    # Software Management
    [hashtable]SendSoftwareEvent([string]$EventType, [hashtable]$SoftwareData) {
        $endpoint = "/api/software/events"
        $payload = @{
            Event = $EventType
            Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
            Software = $SoftwareData
        }
        
        return $this.SendRequest("POST", $endpoint, $payload)
    }

    [hashtable]GetSoftware() {
        return $this.SendRequest("GET", "/api/software")
    }

    [hashtable]StartSoftware([string]$SoftwareId) {
        return $this.SendRequest("POST", "/api/software/$SoftwareId/start")
    }

    [hashtable]StopSoftware([string]$SoftwareId) {
        return $this.SendRequest("POST", "/api/software/$SoftwareId/stop")
    }

    [hashtable]GetSoftwareStatus([string]$SoftwareId) {
        return $this.SendRequest("GET", "/api/software/$SoftwareId/status")
    }

    # Automation Management
    [hashtable]SendAutomationEvent([string]$RuleId, [string]$EventType, [hashtable]$Context) {
        $endpoint = "/api/automation/events"
        $payload = @{
            RuleId = $RuleId
            Event = $EventType
            Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
            Context = $Context
        }
        
        return $this.SendRequest("POST", $endpoint, $payload)
    }

    [hashtable]GetAutomationRules() {
        return $this.SendRequest("GET", "/api/automation/rules")
    }

    [hashtable]GetAutomationRule([string]$RuleId) {
        return $this.SendRequest("GET", "/api/automation/rules/$RuleId")
    }

    [hashtable]ExecuteAutomationRule([string]$RuleId) {
        return $this.SendRequest("POST", "/api/automation/rules/$RuleId/execute")
    }

    [hashtable]EnableAutomationRule([string]$RuleId) {
        return $this.SendRequest("POST", "/api/automation/rules/$RuleId/enable")
    }

    [hashtable]DisableAutomationRule([string]$RuleId) {
        return $this.SendRequest("POST", "/api/automation/rules/$RuleId/disable")
    }

    # Health Monitoring
    [hashtable]SendHealthMetrics([hashtable]$Metrics) {
        return $this.SendRequest("PUT", "/api/monitoring", $Metrics)
    }

    [hashtable]GetHealthStatus() {
        return $this.SendRequest("GET", "/api/monitoring/health")
    }

    [hashtable]GetMetricsHistory([int]$Hours = 24) {
        return $this.SendRequest("GET", "/api/monitoring/history?hours=$Hours")
    }

    # Agent Registration
    [hashtable]RegisterAgent([hashtable]$AgentInfo) {
        $endpoint = "/api/agents/register"
        $payload = @{
            AgentId = $AgentInfo.Id
            Name = $AgentInfo.Name
            Version = $AgentInfo.Version
            Hostname = $AgentInfo.Hostname
            Platform = $AgentInfo.Platform
            Capabilities = $AgentInfo.Capabilities
            RegisteredAt = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
        }
        
        return $this.SendRequest("POST", $endpoint, $payload)
    }

    [hashtable]UpdateAgentStatus([string]$AgentId, [hashtable]$Status) {
        return $this.SendRequest("PUT", "/api/agents/$AgentId/status", $Status)
    }

    [hashtable]SendAgentHeartbeat([string]$AgentId) {
        $payload = @{
            Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
            Status = "Active"
        }
        
        return $this.SendRequest("POST", "/api/agents/$AgentId/heartbeat", $payload)
    }

    # Configuration Management
    [hashtable]GetConfiguration([string]$Section = "") {
        $endpoint = if ($Section) { "/api/config/$Section" } else { "/api/config" }
        return $this.SendRequest("GET", $endpoint)
    }

    [hashtable]UpdateConfiguration([string]$Section, [hashtable]$Configuration) {
        return $this.SendRequest("PUT", "/api/config/$Section", $Configuration)
    }

    # Logging
    [hashtable]SendLogs([array]$LogEntries) {
        $endpoint = "/api/logs"
        $payload = @{
            Source = "SimRacingAgent"
            Entries = $LogEntries
        }
        
        return $this.SendRequest("POST", $endpoint, $payload)
    }

    # Utilities
    [string]FormatEndpoint([string]$Template, [hashtable]$Parameters) {
        $endpoint = $Template
        foreach ($param in $Parameters.GetEnumerator()) {
            $endpoint = $endpoint -replace "{$($param.Key)}", $param.Value
        }
        return $endpoint
    }

    [hashtable]GetApiInfo() {
        return $this.SendRequest("GET", "/api/info")
    }

    [hashtable]GetStatus() {
        return @{
            BaseUrl = $this.BaseUrl
            IsConnected = $this.IsConnected
            TimeoutSeconds = $this.TimeoutSeconds
            LastConnectionTest = Get-Date
        }
    }
}

# Module functions
function Initialize-DashboardClient {
    param([string]$BaseUrl = "http://localhost:5000")
    
    if (-not $Global:DashboardClient -or $Global:DashboardClient.BaseUrl -ne $BaseUrl) {
        $Global:DashboardClient = [DashboardClient]::new($BaseUrl)
    }
    
    return $Global:DashboardClient.IsConnected
}

function Test-DashboardConnection {
    if ($Global:DashboardClient) {
        return $Global:DashboardClient.TestConnection()
    }
    return $false
}

function Send-DeviceEvent {
    param(
        [string]$EventType,
        [hashtable]$DeviceData
    )
    
    if ($Global:DashboardClient) {
        return $Global:DashboardClient.SendDeviceEvent($EventType, $DeviceData)
    }
    return @{ Success = $false; Error = "Dashboard client not initialized" }
}

function Send-SoftwareEvent {
    param(
        [string]$EventType,
        [hashtable]$SoftwareData
    )
    
    if ($Global:DashboardClient) {
        return $Global:DashboardClient.SendSoftwareEvent($EventType, $SoftwareData)
    }
    return @{ Success = $false; Error = "Dashboard client not initialized" }
}

function Send-HealthMetrics {
    param([hashtable]$Metrics)
    
    if ($Global:DashboardClient) {
        return $Global:DashboardClient.SendHealthMetrics($Metrics)
    }
    return @{ Success = $false; Error = "Dashboard client not initialized" }
}

function Register-Agent {
    param([hashtable]$AgentInfo)
    
    if ($Global:DashboardClient) {
        return $Global:DashboardClient.RegisterAgent($AgentInfo)
    }
    return @{ Success = $false; Error = "Dashboard client not initialized" }
}

function Send-AgentHeartbeat {
    param([string]$AgentId)
    
    if ($Global:DashboardClient) {
        return $Global:DashboardClient.SendAgentHeartbeat($AgentId)
    }
    return @{ Success = $false; Error = "Dashboard client not initialized" }
}

function Get-DashboardConfiguration {
    param([string]$Section = "")
    
    if ($Global:DashboardClient) {
        return $Global:DashboardClient.GetConfiguration($Section)
    }
    return @{ Success = $false; Error = "Dashboard client not initialized" }
}

function Send-LogsToDashboard {
    param([array]$LogEntries)
    
    if ($Global:DashboardClient) {
        return $Global:DashboardClient.SendLogs($LogEntries)
    }
    return @{ Success = $false; Error = "Dashboard client not initialized" }
}

function Get-DashboardClientStatus {
    if ($Global:DashboardClient) {
        return $Global:DashboardClient.GetStatus()
    }
    return @{ IsConnected = $false; BaseUrl = ""; Error = "Not initialized" }
}

# Export module members
Export-ModuleMember -Function *