# Health Monitoring Service
# Comprehensive system and application health tracking

using module ..\Utils\Logging.psm1

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
            
            Register-ObjectEvent -InputObject $this.MonitoringTimer -EventName Elapsed -Action {
                try {
                    [HealthMonitor]$monitor = $Event.MessageData
                    $monitor.CollectMetrics()
                    $monitor.SendToDashboard()
                }
                catch {
                    Write-AgentLog "Health monitoring error: $($_.Exception.Message)" -Level Error
                }
            } -MessageData $this | Out-Null
            
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
            
            Invoke-RestMethod -Uri $endpoint -Method PUT -Body $body -ContentType "application/json" -TimeoutSec 5
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

# Module functions
function Start-HealthMonitoring {
    param(
        [int]$IntervalSeconds = 30,
        [string]$DashboardUrl = "http://localhost:5000"
    )
    
    if (-not $Global:HealthMonitor) {
        $Global:HealthMonitor = [HealthMonitor]::new($DashboardUrl)
    }
    
    $Global:HealthMonitor.Start($IntervalSeconds)
}

function Stop-HealthMonitoring {
    if ($Global:HealthMonitor) {
        $Global:HealthMonitor.Stop()
    }
}

function Get-CurrentHealthMetrics {
    if ($Global:HealthMonitor) {
        return $Global:HealthMonitor.GetCurrentMetrics()
    }
    return @{}
}

function Get-HealthHistory {
    param([int]$Count = 10)
    
    if ($Global:HealthMonitor) {
        return $Global:HealthMonitor.GetHealthHistory($Count)
    }
    return @()
}

function Get-HealthStatus {
    if ($Global:HealthMonitor) {
        return $Global:HealthMonitor.GetStatus()
    }
    return @{ IsMonitoring = $false }
}

function Update-HealthMetrics {
    if ($Global:HealthMonitor -and $Global:HealthMonitor.IsMonitoring) {
        $Global:HealthMonitor.CollectMetrics()
        $Global:HealthMonitor.SendToDashboard()
    }
}

# Export module members
Export-ModuleMember -Function *