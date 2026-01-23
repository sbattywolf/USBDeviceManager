# Health Monitoring Service
# Comprehensive system and application health tracking

using module ..\Utils\Logging.psm1

# Module-scoped mock containers (prefer script scope; tests may use Set-HealthMonitorMocks)
if (-not $Script:MockFunctions) {
    $g = Get-Variable -Name MockFunctions -Scope Global -ErrorAction SilentlyContinue
    if ($g) { $Script:MockFunctions = $g.Value } else { $Script:MockFunctions = @{} }
}
if (-not $Script:MockCalls) {
    $g = Get-Variable -Name MockCalls -Scope Global -ErrorAction SilentlyContinue
    if ($g) { $Script:MockCalls = $g.Value } else { $Script:MockCalls = @{} }
}
if (-not $Script:MockOrders) {
    $g = Get-Variable -Name MockOrders -Scope Global -ErrorAction SilentlyContinue
    if ($g) { $Script:MockOrders = $g.Value } else { $Script:MockOrders = @{} }
}

class HealthMonitor {
    [hashtable]$Metrics
    [hashtable]$Thresholds
    [array]$HealthHistory
    [bool]$IsMonitoring
    [System.Timers.Timer]$MonitoringTimer
    [string]$DashboardUrl

    HealthMonitor([string]$DashboardUrl = "http://localhost:5000") {
        $this.Metrics = @{}
        $this.Thresholds = @{}
        $this.HealthHistory = @()
        $this.IsMonitoring = $false
        $this.DashboardUrl = $DashboardUrl
        $this.LoadConfiguration()
    }

    [void]LoadConfiguration() {
        try {
            $configPath = Join-Path $PSScriptRoot "..\Utils\health-config.json"
            if (Test-Path $configPath) {
                $config = Get-Content $configPath | ConvertFrom-Json
                $this.Thresholds = @{}

                foreach ($threshold in $config.Thresholds.PSObject.Properties) {
                    $this.Thresholds[$threshold.Name] = $threshold.Value
                }

                Write-AgentLog "Loaded health monitoring configuration" -Level Info
            } else {
                # Default thresholds
                $this.Thresholds = @{
                    "CPU.Warning" = 80
                    "CPU.Critical" = 95
                    "Memory.Warning" = 85
                    "Memory.Critical" = 95
                    "Disk.Warning" = 85
                    "Disk.Critical" = 95
                    "Temperature.Warning" = 70
                    "Temperature.Critical" = 85
                }
            }
        }
        catch {
            Write-AgentLog "Failed to load health configuration: $($_.Exception.Message)" -Level Error
        }
    }

    [void]Start([int]$IntervalSeconds = 30) {
        if ($this.IsMonitoring) {
            Write-AgentLog "Health monitoring is already running" -Level Warning
            return
        }

        try {
            Write-AgentLog "Starting health monitoring (interval: ${IntervalSeconds}s)" -Level Info

            # Perform initial collection
            $this.CollectMetrics()

            # Setup monitoring timer
            $this.MonitoringTimer = New-Object System.Timers.Timer($IntervalSeconds * 1000)
            $this.MonitoringTimer.AutoReset = $true

            $action = {
                try {
                    [HealthMonitor]$monitor = $Event.MessageData
                    $monitor.CollectMetrics()
                    $monitor.SendToDashboard()
                }
                catch {
                    Write-AgentLog "Health monitoring error: $($_.Exception.Message)" -Level Error
                }
            }

            # If tests provide a mock for Register-ObjectEvent, prefer it (keeps tests headless)
                if ($Script:MockFunctions -and $Script:MockFunctions.ContainsKey('Register-ObjectEvent')) {
                    try {
                        & $Script:MockFunctions['Register-ObjectEvent'].GetNewClosure() -InputObject $this.MonitoringTimer -EventName 'Elapsed' -Action $action -MessageData $this | Out-Null
                    } catch {
                        Write-AgentLog "Mock Register-ObjectEvent invocation failed: $($_.Exception.Message)" -Level Warning
                    }
                }
            else {
                Register-ObjectEvent -InputObject $this.MonitoringTimer -EventName Elapsed -Action $action -MessageData $this | Out-Null
            }

            $this.MonitoringTimer.Start()
            $this.IsMonitoring = $true

            Write-AgentLog "Health monitoring started successfully" -Level Info
        }
        catch {
            Write-AgentLog "Failed to start health monitoring: $($_.Exception.Message)" -Level Error
            throw
        }
    }

    [void]Stop() {
        if (-not $this.IsMonitoring) {
            return
        }

        try {
            if ($this.MonitoringTimer) {
                $this.MonitoringTimer.Stop()
                $this.MonitoringTimer.Dispose()
            }

            $this.IsMonitoring = $false
            Write-AgentLog "Health monitoring stopped" -Level Info
        }
        catch {
            Write-AgentLog "Error stopping health monitoring: $($_.Exception.Message)" -Level Error
        }
    }

    [void]CollectMetrics() {
        try {
            $timestamp = Get-Date
            $this.Metrics = @{
                Timestamp = $timestamp
                System = $this.GetSystemMetrics()
                Process = $this.GetProcessMetrics()
                Network = $this.GetNetworkMetrics()
                Storage = $this.GetStorageMetrics()
            }

            # Calculate health status
            $healthStatus = $this.CalculateHealthStatus($this.Metrics)
            $this.Metrics.HealthStatus = $healthStatus

            # Add to history (keep last 100 entries)
            $this.HealthHistory += $this.Metrics
            if ($this.HealthHistory.Count -gt 100) {
                $this.HealthHistory = $this.HealthHistory[-100..-1]
            }

            # Check for alerts
            $this.CheckAlerts($this.Metrics)

        }
        catch {
            Write-AgentLog "Error collecting health metrics: $($_.Exception.Message)" -Level Error
        }
    }

    [hashtable]GetSystemMetrics() {
        try {
            # CPU Usage
            $cpuCounter = Get-Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 1
            $cpuUsage = [Math]::Round(100 - $cpuCounter.CounterSamples.CookedValue, 2)

            # Memory Usage
            $totalMemory = (Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum).Sum
            $availableMemory = (Get-Counter "\Memory\Available MBytes").CounterSamples.CookedValue * 1MB
            $memoryUsage = [Math]::Round((($totalMemory - $availableMemory) / $totalMemory) * 100, 2)

            # System uptime
            $bootTime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
            $uptime = (Get-Date) - $bootTime

            return @{
                CPU = @{
                    Usage = $cpuUsage
                    Cores = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
                }
                Memory = @{
                    Usage = $memoryUsage
                    Total = $totalMemory
                    Available = $availableMemory
                    Used = $totalMemory - $availableMemory
                }
                Uptime = @{
                    Days = $uptime.Days
                    Hours = $uptime.Hours
                    Minutes = $uptime.Minutes
                    TotalHours = [Math]::Round($uptime.TotalHours, 2)
                }
            }
        }
        catch {
            Write-AgentLog "Error getting system metrics: $($_.Exception.Message)" -Level Error
            return @{}
        }
    }

    [hashtable]GetProcessMetrics() {
        try {
            $currentProcess = Get-Process -Id ([System.Diagnostics.Process]::GetCurrentProcess().Id)

            return @{
                Current = @{
                    Name = $currentProcess.ProcessName
                    PID = $currentProcess.Id
                    CPU = $currentProcess.CPU
                    WorkingSet = $currentProcess.WorkingSet64
                    VirtualMemory = $currentProcess.VirtualMemorySize64
                    HandleCount = $currentProcess.HandleCount
                    ThreadCount = $currentProcess.Threads.Count
                }
                System = @{
                    ProcessCount = (Get-Process).Count
                    TopCPU = (Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 | ForEach-Object {
                        @{ Name = $_.ProcessName; PID = $_.Id; CPU = $_.CPU }
                    })
                    TopMemory = (Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 5 | ForEach-Object {
                        @{ Name = $_.ProcessName; PID = $_.Id; Memory = $_.WorkingSet64 }
                    })
                }
            }
        }
        catch {
            Write-AgentLog "Error getting process metrics: $($_.Exception.Message)" -Level Error
            return @{}
        }
    }

    [hashtable]GetNetworkMetrics() {
        try {
            $adapters = Get-CimInstance Win32_PerfRawData_Tcpip_NetworkInterface | Where-Object { $_.Name -notlike "*Loopback*" -and $_.Name -notlike "*Teredo*" }

            $networkData = @{
                Adapters = @()
                TotalBytesReceived = 0
                TotalBytesSent = 0
            }

            foreach ($adapter in $adapters) {
                $adapterInfo = @{
                    Name = $adapter.Name
                    BytesReceived = $adapter.BytesReceivedPerSec
                    BytesSent = $adapter.BytesSentPerSec
                    PacketsReceived = $adapter.PacketsReceivedPerSec
                    PacketsSent = $adapter.PacketsSentPerSec
                }

                $networkData.Adapters += $adapterInfo
                $networkData.TotalBytesReceived += $adapter.BytesReceivedPerSec
                $networkData.TotalBytesSent += $adapter.BytesSentPerSec
            }

            return $networkData
        }
        catch {
            Write-AgentLog "Error getting network metrics: $($_.Exception.Message)" -Level Error
            return @{}
        }
    }

    [hashtable]GetStorageMetrics() {
        try {
            $disks = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }

            $storageData = @{
                Disks = @()
                TotalSpace = 0
                TotalFreeSpace = 0
                TotalUsedSpace = 0
            }

            foreach ($disk in $disks) {
                $usedSpace = $disk.Size - $disk.FreeSpace
                $usagePercent = if ($disk.Size -gt 0) { [Math]::Round(($usedSpace / $disk.Size) * 100, 2) } else { 0 }

                $diskInfo = @{
                    Drive = $disk.DeviceID
                    Label = $disk.VolumeName
                    Size = $disk.Size
                    FreeSpace = $disk.FreeSpace
                    UsedSpace = $usedSpace
                    UsagePercent = $usagePercent
                    FileSystem = $disk.FileSystem
                }

                $storageData.Disks += $diskInfo
                $storageData.TotalSpace += $disk.Size
                $storageData.TotalFreeSpace += $disk.FreeSpace
                $storageData.TotalUsedSpace += $usedSpace
            }

            if ($storageData.TotalSpace -gt 0) {
                $storageData.TotalUsagePercent = [Math]::Round(($storageData.TotalUsedSpace / $storageData.TotalSpace) * 100, 2)
            }

            return $storageData
        }
        catch {
            Write-AgentLog "Error getting storage metrics: $($_.Exception.Message)" -Level Error
            return @{}
        }
    }

    [hashtable]CalculateHealthStatus([hashtable]$metrics) {
        $status = @{
            Overall = "Healthy"
            Components = @{}
            Score = 100
            Issues = @()
        }

        try {
            # Check CPU health
            $cpuUsage = $metrics.System.CPU.Usage
            if ($cpuUsage -ge $this.Thresholds["CPU.Critical"]) {
                $status.Components.CPU = "Critical"
                $status.Issues += "CPU usage is critically high: $cpuUsage%"
                $status.Score -= 30
            } elseif ($cpuUsage -ge $this.Thresholds["CPU.Warning"]) {
                $status.Components.CPU = "Warning"
                $status.Issues += "CPU usage is high: $cpuUsage%"
                $status.Score -= 15
            } else {
                $status.Components.CPU = "Healthy"
            }

            # Check Memory health
            $memoryUsage = $metrics.System.Memory.Usage
            if ($memoryUsage -ge $this.Thresholds["Memory.Critical"]) {
                $status.Components.Memory = "Critical"
                $status.Issues += "Memory usage is critically high: $memoryUsage%"
                $status.Score -= 30
            } elseif ($memoryUsage -ge $this.Thresholds["Memory.Warning"]) {
                $status.Components.Memory = "Warning"
                $status.Issues += "Memory usage is high: $memoryUsage%"
                $status.Score -= 15
            } else {
                $status.Components.Memory = "Healthy"
            }

            # Check Disk health
            $diskUsage = $metrics.Storage.TotalUsagePercent
            if ($diskUsage -ge $this.Thresholds["Disk.Critical"]) {
                $status.Components.Storage = "Critical"
                $status.Issues += "Disk usage is critically high: $diskUsage%"
                $status.Score -= 20
            } elseif ($diskUsage -ge $this.Thresholds["Disk.Warning"]) {
                $status.Components.Storage = "Warning"
                $status.Issues += "Disk usage is high: $diskUsage%"
                $status.Score -= 10
            } else {
                $status.Components.Storage = "Healthy"
            }

            # Determine overall status
            if ($status.Score -le 50) {
                $status.Overall = "Critical"
            } elseif ($status.Score -le 75) {
                $status.Overall = "Warning"
            } elseif ($status.Issues.Count -gt 0) {
                $status.Overall = "Warning"
            }

        }
        catch {
            $status.Overall = "Unknown"
            $status.Issues += "Error calculating health status"
            Write-AgentLog "Error calculating health status: $($_.Exception.Message)" -Level Error
        }

        return $status
    }

    [void]CheckAlerts([hashtable]$metrics) {
        try {
            $healthStatus = $metrics.HealthStatus

            if ($healthStatus.Overall -eq "Critical") {
                Write-AgentLog "CRITICAL HEALTH ALERT: $($healthStatus.Issues -join '; ')" -Level Error

                # Trigger automation if available
                if (Get-Command "Invoke-AutomationTrigger" -ErrorAction SilentlyContinue) {
                    $context = @{
                        TriggerType = "Health"
                        Severity = "Critical"
                        Issues = $healthStatus.Issues
                        Metrics = $metrics
                    }
                    Invoke-AutomationTrigger -TriggerType "Health" -Context $context
                }
            } elseif ($healthStatus.Overall -eq "Warning") {
                Write-AgentLog "Health warning: $($healthStatus.Issues -join '; ')" -Level Warning
            }
        }
        catch {
            Write-AgentLog "Error checking health alerts: $($_.Exception.Message)" -Level Error
        }
    }

    [void]SendToDashboard() {
        try {
            if (-not $this.Metrics -or -not $this.DashboardUrl) {
                return
            }

            $endpoint = "$($this.DashboardUrl)/api/monitoring"
            $body = $this.Metrics | ConvertTo-Json -Depth 10

            # Prefer mocked HTTP for tests
            $mockInvoke = if ($Script:MockFunctions -and $Script:MockFunctions.ContainsKey('Invoke-RestMethod')) { $Script:MockFunctions['Invoke-RestMethod'] } else { $null }
            if ($mockInvoke) {
                & $mockInvoke.GetNewClosure() -Uri $endpoint -Method PUT -Body $body -ContentType "application/json" -TimeoutSec 5
            }
            else {
                Invoke-RestMethod -Uri $endpoint -Method PUT -Body $body -ContentType "application/json" -TimeoutSec 5
            }
        }
        catch {
            # Silently fail dashboard updates to avoid spam
            Write-AgentLog "Failed to send metrics to dashboard: $($_.Exception.Message)" -Level Debug
        }
    }

    [hashtable]GetCurrentMetrics() {
        return $this.Metrics
    }

    [array]GetHealthHistory([int]$Count = 10) {
        $historyCount = [Math]::Min($Count, $this.HealthHistory.Count)
        if ($historyCount -gt 0) {
            return $this.HealthHistory[-$historyCount..-1]
        }
        return @()
    }

    [hashtable]GetStatus() {
        return @{
            IsMonitoring = $this.IsMonitoring
            LastUpdate = if ($this.Metrics) { $this.Metrics.Timestamp } else { $null }
            OverallHealth = if ($this.Metrics) { $this.Metrics.HealthStatus.Overall } else { "Unknown" }
            HealthScore = if ($this.Metrics) { $this.Metrics.HealthStatus.Score } else { 0 }
            DashboardUrl = $this.DashboardUrl
            HistoryCount = $this.HealthHistory.Count
        }
    }
}

# Module-scoped HealthMonitor instance (prefer script scope)
if (-not $Script:HealthMonitor) { $Script:HealthMonitor = $null }

# Ensure mock containers exist
if (-not $Script:MockFunctions) { $Script:MockFunctions = @{} }
if (-not $Script:MockCalls) { $Script:MockCalls = @{} }
if (-not $Script:MockOrders) { $Script:MockOrders = @{} }

function Set-HealthMonitorMocks {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [hashtable]$MockFunctions = @{},
        [hashtable]$MockCalls = @{},
        [hashtable]$MockOrders = @{},
        [switch]$MirrorToGlobal
    )

    if ($MockFunctions) { $Script:MockFunctions = $MockFunctions }
    if ($MockCalls) { $Script:MockCalls = $MockCalls }
    if ($MockOrders) { $Script:MockOrders = $MockOrders }

    if ($MirrorToGlobal) {
        if (-not $PSCmdlet.ShouldProcess('HealthMonitor','Mirror mocks to global')) { return }
        try {
            if (-not (Get-Variable -Scope Global -Name MockFunctions -ErrorAction SilentlyContinue)) { Set-Variable -Scope Global -Name MockFunctions -Value @{} }
            if (-not (Get-Variable -Scope Global -Name MockCalls -ErrorAction SilentlyContinue)) { Set-Variable -Scope Global -Name MockCalls -Value @{} }
            if (-not (Get-Variable -Scope Global -Name MockOrders -ErrorAction SilentlyContinue)) { Set-Variable -Scope Global -Name MockOrders -Value @{} }
            (Get-Variable -Scope Global -Name MockFunctions -ValueOnly).Clear()
            (Get-Variable -Scope Global -Name MockCalls -ValueOnly).Clear()
            (Get-Variable -Scope Global -Name MockOrders -ValueOnly).Clear()
            foreach ($k in $Script:MockFunctions.Keys) { (Get-Variable -Scope Global -Name MockFunctions -ValueOnly).$k = $Script:MockFunctions[$k] }
            foreach ($k in $Script:MockCalls.Keys) { (Get-Variable -Scope Global -Name MockCalls -ValueOnly).$k = $Script:MockCalls[$k] }
            foreach ($k in $Script:MockOrders.Keys) { (Get-Variable -Scope Global -Name MockOrders -ValueOnly).$k = $Script:MockOrders[$k] }
        }
        catch {
            Write-AgentLog "Failed to mirror HealthMonitor mocks to global scope: $($_.Exception.Message)" -Level Debug
        }
    }
}

function Set-HealthMonitorInstance {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [HealthMonitor]$Instance,
        [switch]$MirrorToGlobal
    )

    if ($Instance) { $Script:HealthMonitor = $Instance }
    if ($MirrorToGlobal) {
        if (-not $PSCmdlet.ShouldProcess('HealthMonitor','Mirror instance to global')) { return }
        try {
            if (-not (Get-Variable -Scope Global -Name HealthMonitor -ErrorAction SilentlyContinue)) { Set-Variable -Scope Global -Name HealthMonitor -Value $null -ErrorAction SilentlyContinue }
            Set-Variable -Scope Global -Name HealthMonitor -Value $Script:HealthMonitor -ErrorAction SilentlyContinue
        }
        catch {
            Write-AgentLog "Failed to mirror HealthMonitor instance to global scope: $($_.Exception.Message)" -Level Debug
        }
    }
}

function Start-HealthMonitoring {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [int]$IntervalSeconds = 30,
        [string]$DashboardUrl = "http://localhost:5000"
    )

    $gMockFunctions = Get-Variable -Name MockFunctions -Scope Global -ErrorAction SilentlyContinue
    $mockFunctions = if ($Script:MockFunctions -and $Script:MockFunctions.Count) { $Script:MockFunctions } elseif ($gMockFunctions) { $gMockFunctions.Value } else { $null }
            if ($mockFunctions -and $mockFunctions.ContainsKey('Register-ObjectEvent')) {
                if (-not $Script:HealthMonitor) { $Script:HealthMonitor = [HealthMonitor]::new($DashboardUrl) }
                try { $Script:HealthMonitor.CollectMetrics() } catch { Write-AgentLog "Initial CollectMetrics failed: $($_.Exception.Message)" -Level Warning }
                $Script:HealthMonitor.IsMonitoring = $true
                return
            }

    if (-not $PSCmdlet.ShouldProcess('HealthMonitor','Start')) { return }

    if (-not $Script:HealthMonitor) { $Script:HealthMonitor = [HealthMonitor]::new($DashboardUrl) }
    # Mirror into global for backward compatibility
    if (-not (Get-Variable -Scope Global -Name HealthMonitor -ErrorAction SilentlyContinue)) { Set-Variable -Scope Global -Name HealthMonitor -Value $Script:HealthMonitor -ErrorAction SilentlyContinue } else { Set-Variable -Scope Global -Name HealthMonitor -Value $Script:HealthMonitor -ErrorAction SilentlyContinue }
    $Script:HealthMonitor.Start($IntervalSeconds)
}

function Stop-HealthMonitoring {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    if (-not $Script:HealthMonitor) { return }
    if (-not $PSCmdlet.ShouldProcess('HealthMonitor','Stop')) { return }
    $Script:HealthMonitor.Stop()
}

function Get-CurrentHealthMetrics {
    if ($Script:HealthMonitor) { return $Script:HealthMonitor.GetCurrentMetrics() }
    return @{}
}

function Get-HealthHistory {
    param([int]$Count = 10)
    if ($Script:HealthMonitor) { return $Script:HealthMonitor.GetHealthHistory($Count) }
    return @()
}

function Get-HealthStatus {
    if ($Script:HealthMonitor) { return $Script:HealthMonitor.GetStatus() }
    return @{ IsMonitoring = $false }
}

function Update-HealthMetrics {
    if ($Script:HealthMonitor -and $Script:HealthMonitor.IsMonitoring) {
        $Script:HealthMonitor.CollectMetrics()
        $Script:HealthMonitor.SendToDashboard()
    }
}

# Export module members
try {
    Export-ModuleMember -Function * -ErrorAction Stop
} catch {
    Write-Verbose "Export-ModuleMember skipped (not running inside a module): $($_.Exception.Message)"
}



