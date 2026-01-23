# Dashboard API Client
# REST API client for communicating with SimRacing Dashboard

using module ..\Utils\Logging.psm1

# Ensure module-scoped mock containers exist. Tests can set mocks via `Set-DashboardClientMocks`.
function Set-DashboardClientMocks {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [hashtable]$Functions = @{},
        [hashtable]$Calls = @{},
        [hashtable]$Orders = @{},
        [switch]$MirrorToGlobal
    )

    # Always set module-scoped mocks for test usage
    $Script:MockFunctions = $Functions
    $Script:MockCalls = $Calls
    $Script:MockOrders = $Orders

    # Mirror into Global only when explicitly requested; guard with ShouldProcess
    if ($MirrorToGlobal) {
        if (-not $PSCmdlet.ShouldProcess('DashboardClient','Mirror mocks to global')) { return }
        try {
            Set-Variable -Name MockFunctions -Value $Script:MockFunctions -Scope Global -ErrorAction SilentlyContinue
            Set-Variable -Name MockCalls -Value $Script:MockCalls -Scope Global -ErrorAction SilentlyContinue
            Set-Variable -Name MockOrders -Value $Script:MockOrders -Scope Global -ErrorAction SilentlyContinue
        }
        catch {
            Write-AgentLog "Failed to mirror DashboardClient mocks to global scope: $($_.Exception.Message)" -Level Debug
        }
    }
}

# Initialize from global if present (back-compat)
if (-not $Script:MockFunctions) {
    if (Get-Variable -Name MockFunctions -Scope Global -ErrorAction SilentlyContinue) { $Script:MockFunctions = (Get-Variable -Name MockFunctions -Scope Global -ValueOnly) } else { $Script:MockFunctions = @{} }
}
if (-not $Script:MockCalls) {
    if (Get-Variable -Name MockCalls -Scope Global -ErrorAction SilentlyContinue) { $Script:MockCalls = (Get-Variable -Name MockCalls -Scope Global -ValueOnly) } else { $Script:MockCalls = @{} }
}
if (-not $Script:MockOrders) {
    if (Get-Variable -Name MockOrders -Scope Global -ErrorAction SilentlyContinue) { $Script:MockOrders = (Get-Variable -Name MockOrders -Scope Global -ValueOnly) } else { $Script:MockOrders = @{} }
}

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
            # Prefer a test-provided mock for Invoke-RestMethod when available
            $mockInvoke = if ($Script:MockFunctions -and $Script:MockFunctions.ContainsKey('Invoke-RestMethod')) { $Script:MockFunctions['Invoke-RestMethod'] } else { $null }
            if ($mockInvoke) {
                $response = & $mockInvoke.GetNewClosure() -Uri "$($this.BaseUrl)/api/health" -Method GET -Headers $this.Headers -TimeoutSec 5
            }
            else {
                $response = Invoke-RestMethod -Uri "$($this.BaseUrl)/api/health" -Method GET -Headers $this.Headers -TimeoutSec 5
            }
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
            # Detailed logging for heartbeat POSTs
            if ($Endpoint -like "/api/agents/*/heartbeat" -and $Method -eq "POST") {
                Write-AgentLog "[DEBUG] Heartbeat POST: $uri Body: $($params.Body)" -Level Info
            }
            # Prefer mocked Invoke-RestMethod if provided by tests (use script-scoped mocks)
            if ($Script:MockFunctions -and $Script:MockFunctions.ContainsKey('Invoke-RestMethod')) {
                $response = & $Script:MockFunctions['Invoke-RestMethod'].GetNewClosure() @params
            }
            else {
                $response = Invoke-RestMethod @params
            }
            if ($Endpoint -like "/api/agents/*/heartbeat" -and $Method -eq "POST") {
                Write-AgentLog "[DEBUG] Heartbeat response: $($response | ConvertTo-Json -Compress)" -Level Info
            }
            return @{
                Success = $true
                Data = $response
                StatusCode = 200
            }
        }
        catch {
            # Detailed error logging for heartbeat POSTs
            if ($Endpoint -like "/api/agents/*/heartbeat" -and $Method -eq "POST") {
                Write-AgentLog "[DEBUG] Heartbeat error: Status $($_.Exception.Response.StatusCode.value__) Message: $($_.Exception.Message)" -Level Error
            }
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
    [CmdletBinding(SupportsShouldProcess=$true)]
    param([string]$BaseUrl = "http://localhost:5000")

    # module-scoped DashboardClient with safe fallback to global
    if (-not $Script:DashboardClient) {
        $g = Get-Variable -Name DashboardClient -Scope Global -ErrorAction SilentlyContinue
        if ($g) { $Script:DashboardClient = $g.Value } else { $Script:DashboardClient = $null }
    }

    if (-not $PSCmdlet.ShouldProcess('DashboardClient','Initialize')) { return $false }

    if (-not $Script:DashboardClient -or $Script:DashboardClient.BaseUrl -ne $BaseUrl) {
        $Script:DashboardClient = [DashboardClient]::new($BaseUrl)
    }

    # Mirror into global scope for backward compatibility with older modules (best-effort)
    try {
        if (-not (Get-Variable -Name DashboardClient -Scope Global -ErrorAction SilentlyContinue)) { Set-Variable -Name DashboardClient -Value $Script:DashboardClient -Scope Global -ErrorAction SilentlyContinue }
    }
    catch {
        Write-AgentLog "Failed to mirror DashboardClient to global scope: $($_.Exception.Message)" -Level Debug
    }

    return $Script:DashboardClient.IsConnected
}

function Test-DashboardConnection {
    if ($Script:DashboardClient) { return $Script:DashboardClient.TestConnection() }
    return $false
}

function Send-DeviceEvent {
    param(
        [string]$EventType,
        [hashtable]$DeviceData
    )

    if ($Script:DashboardClient) { return $Script:DashboardClient.SendDeviceEvent($EventType, $DeviceData) }
    return @{ Success = $false; Error = "Dashboard client not initialized" }
}

function Send-SoftwareEvent {
    param(
        [string]$EventType,
        [hashtable]$SoftwareData
    )

    if ($Script:DashboardClient) { return $Script:DashboardClient.SendSoftwareEvent($EventType, $SoftwareData) }
    return @{ Success = $false; Error = "Dashboard client not initialized" }
}

function Send-HealthMetrics {
    param([hashtable]$Metrics)

    if ($Script:DashboardClient) { return $Script:DashboardClient.SendHealthMetrics($Metrics) }
    return @{ Success = $false; Error = "Dashboard client not initialized" }
}

function Register-Agent {
    param([hashtable]$AgentInfo)

    if ($Script:DashboardClient) { return $Script:DashboardClient.RegisterAgent($AgentInfo) }
    return @{ Success = $false; Error = "Dashboard client not initialized" }
}

function Send-AgentHeartbeat {
    param([string]$AgentId)

    if ($Script:DashboardClient) { return $Script:DashboardClient.SendAgentHeartbeat($AgentId) }
    return @{ Success = $false; Error = "Dashboard client not initialized" }
}

function Get-DashboardConfiguration {
    param([string]$Section = "")

    if ($Script:DashboardClient) { return $Script:DashboardClient.GetConfiguration($Section) }
    return @{ Success = $false; Error = "Dashboard client not initialized" }
}

function Send-LogsToDashboard {
    param([array]$LogEntries)

    if ($Script:DashboardClient) { return $Script:DashboardClient.SendLogs($LogEntries) }
    return @{ Success = $false; Error = "Dashboard client not initialized" }
}

function Get-DashboardClientStatus {
    if ($Script:DashboardClient) { return $Script:DashboardClient.GetStatus() }
    return @{ IsConnected = $false; BaseUrl = ""; Error = "Not initialized" }
}

# Export module members
try {
    Export-ModuleMember -Function * -ErrorAction Stop
} catch {
    Write-Verbose "Export-ModuleMember skipped (not running inside a module): $($_.Exception.Message)"
}



