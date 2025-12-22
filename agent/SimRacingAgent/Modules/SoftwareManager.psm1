# Software Manager Module
# Automated software lifecycle management for SimRacing applications

# SimRacing Agent Software Manager
# Manages software lifecycle and process monitoring

using module ..\Utils\Logging.psm1

class SoftwareManager {
    [hashtable]$ManagedSoftware
    [hashtable]$RunningProcesses
    [bool]$IsMonitoring
    [System.Timers.Timer]$MonitoringTimer

    SoftwareManager() {
        $this.ManagedSoftware = @{}
        $this.RunningProcesses = @{}
        $this.IsMonitoring = $false
        $this.LoadSoftwareConfig()
    }

    [void]LoadSoftwareConfig() {
        try {
            $configPath = Join-Path $PSScriptRoot "..\Utils\software-config.json"
            if (Test-Path $configPath) {
                $config = Get-Content $configPath | ConvertFrom-Json
                $config.Software | ForEach-Object {
                    $this.ManagedSoftware[$_.Name] = @{
                        Name = $_.Name
                        ExecutablePath = $_.ExecutablePath
                        Arguments = $_.Arguments
                        WorkingDirectory = $_.WorkingDirectory
                        AutoStart = $_.AutoStart
                        IsEnabled = $_.IsEnabled
                        ProcessName = [System.IO.Path]::GetFileNameWithoutExtension($_.ExecutablePath)
                    }
                }
                Write-AgentLog "Loaded $($this.ManagedSoftware.Count) software configurations" -Level Info
            }
        }
        catch {
            Write-AgentLog "Failed to load software configuration: $($_.Exception.Message)" -Level Error
        }
    }

    [void]Start([int]$IntervalSeconds = 10) {
        if ($this.IsMonitoring) {
            Write-AgentLog "Software monitoring is already running" -Level Warning
            return
        }

        try {
            Write-AgentLog "Starting software monitoring (interval: ${IntervalSeconds}s)" -Level Info
            
            # Perform initial scan
            $this.ScanRunningProcesses()
            
            # Auto-start enabled software
            $this.AutoStartSoftware()
            
            # Setup monitoring timer
            $this.MonitoringTimer = New-Object System.Timers.Timer($IntervalSeconds * 1000)
            $this.MonitoringTimer.AutoReset = $true
            
            Register-ObjectEvent -InputObject $this.MonitoringTimer -EventName Elapsed -Action {
                try {
                    [SoftwareManager]$manager = $Event.MessageData
                    $manager.ScanRunningProcesses()
                }
                catch {
                    Write-AgentLog "Software monitoring error: $($_.Exception.Message)" -Level Error
                }
            } -MessageData $this | Out-Null
            
            $this.MonitoringTimer.Start()
            $this.IsMonitoring = $true
            
            Write-AgentLog "Software monitoring started successfully" -Level Info
        }
        catch {
            Write-AgentLog "Failed to start software monitoring: $($_.Exception.Message)" -Level Error
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
            Write-AgentLog "Software monitoring stopped" -Level Info
        }
        catch {
            Write-AgentLog "Error stopping software monitoring: $($_.Exception.Message)" -Level Error
        }
    }

    [void]ScanRunningProcesses() {
        try {
            $currentProcesses = @{}
            
            # Check each managed software
            foreach ($softwareName in $this.ManagedSoftware.Keys) {
                $software = $this.ManagedSoftware[$softwareName]
                $processName = $software.ProcessName
                
                $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
                
                if ($processes) {
                    foreach ($process in $processes) {
                        $processInfo = @{
                            Name = $softwareName
                            ProcessId = $process.Id
                            ProcessName = $process.ProcessName
                            StartTime = $process.StartTime
                            WorkingSet = $process.WorkingSet64
                            CPUTime = $process.TotalProcessorTime
                            Status = "Running"
                        }
                        
                        $currentProcesses[$softwareName] = $processInfo
                    }
                }
            }
            
            # Check for newly started processes
            foreach ($softwareName in $currentProcesses.Keys) {
                if (-not $this.RunningProcesses.ContainsKey($softwareName)) {
                    Write-AgentLog "Software started: $softwareName" -Level Info
                    $this.OnSoftwareStarted($currentProcesses[$softwareName])
                }
            }
            
            # Check for stopped processes
            $stoppedSoftware = @()
            foreach ($softwareName in $this.RunningProcesses.Keys) {
                if (-not $currentProcesses.ContainsKey($softwareName)) {
                    $stoppedSoftware += $softwareName
                }
            }
            
            foreach ($softwareName in $stoppedSoftware) {
                Write-AgentLog "Software stopped: $softwareName" -Level Info
                $this.OnSoftwareStopped($this.RunningProcesses[$softwareName])
                $this.RunningProcesses.Remove($softwareName)
            }
            
            # Update running processes
            $this.RunningProcesses = $currentProcesses
        }
        catch {
            Write-AgentLog "Error scanning processes: $($_.Exception.Message)" -Level Error
        }
    }

    [void]AutoStartSoftware() {
        foreach ($softwareName in $this.ManagedSoftware.Keys) {
            $software = $this.ManagedSoftware[$softwareName]
            if ($software.AutoStart -and $software.IsEnabled) {
                $this.StartSoftware($softwareName)
            }
        }
    }

    [bool]StartSoftware([string]$SoftwareName) {
        if (-not $this.ManagedSoftware.ContainsKey($SoftwareName)) {
            Write-AgentLog "Unknown software: $SoftwareName" -Level Error
            return $false
        }

        $software = $this.ManagedSoftware[$SoftwareName]
        
        if (-not $software.IsEnabled) {
            Write-AgentLog "Software is disabled: $SoftwareName" -Level Warning
            return $false
        }

        if ($this.RunningProcesses.ContainsKey($SoftwareName)) {
            Write-AgentLog "Software is already running: $SoftwareName" -Level Warning
            return $false
        }

        # Check if executable exists before attempting to start
        if (-not (Test-Path $software.ExecutablePath)) {
            Write-AgentLog "Software executable not found: $SoftwareName at $($software.ExecutablePath)" -Level Warning
            return $false
        }

        try {
            $startInfo = New-Object System.Diagnostics.ProcessStartInfo
            $startInfo.FileName = $software.ExecutablePath
            $startInfo.Arguments = $software.Arguments
            $startInfo.WorkingDirectory = $software.WorkingDirectory
            $startInfo.UseShellExecute = $true
            
            $process = [System.Diagnostics.Process]::Start($startInfo)
            
            Write-AgentLog "Started software: $SoftwareName (PID: $($process.Id))" -Level Info
            return $true
        }
        catch {
            Write-AgentLog "Failed to start software ${SoftwareName}: $($_.Exception.Message)" -Level Error
            return $false
        }
    }

    [bool]StopSoftware([string]$SoftwareName) {
        if (-not $this.RunningProcesses.ContainsKey($SoftwareName)) {
            Write-AgentLog "Software is not running: $SoftwareName" -Level Warning
            return $false
        }

        try {
            $processInfo = $this.RunningProcesses[$SoftwareName]
            $process = Get-Process -Id $processInfo.ProcessId -ErrorAction SilentlyContinue
            
            if ($process) {
                $process.Kill()
                $process.WaitForExit(5000) # Wait up to 5 seconds
                Write-AgentLog "Stopped software: $SoftwareName" -Level Info
                return $true
            } else {
                Write-AgentLog "Process not found for software: $SoftwareName" -Level Warning
                return $false
            }
        }
        catch {
            Write-AgentLog "Failed to stop software ${SoftwareName}: $($_.Exception.Message)" -Level Error
            return $false
        }
    }

    [bool]RestartSoftware([string]$SoftwareName) {
        Write-AgentLog "Restarting software: $SoftwareName" -Level Info
        $stopped = $this.StopSoftware($SoftwareName)
        
        if ($stopped) {
            Start-Sleep -Seconds 2
            return $this.StartSoftware($SoftwareName)
        }
        
        return $false
    }

    [void]OnSoftwareStarted([hashtable]$processInfo) {
        try {
            # Trigger automation if configured
            if (Get-Command "Invoke-SoftwareAutomation" -ErrorAction SilentlyContinue) {
                Invoke-SoftwareAutomation -Event "Started" -Software $processInfo
            }
        }
        catch {
            Write-AgentLog "Error handling software start: $($_.Exception.Message)" -Level Error
        }
    }

    [void]OnSoftwareStopped([hashtable]$processInfo) {
        try {
            # Trigger automation if configured
            if (Get-Command "Invoke-SoftwareAutomation" -ErrorAction SilentlyContinue) {
                Invoke-SoftwareAutomation -Event "Stopped" -Software $processInfo
            }
        }
        catch {
            Write-AgentLog "Error handling software stop: $($_.Exception.Message)" -Level Error
        }
    }

    [array]GetManagedSoftware() {
        return $this.ManagedSoftware.Values
    }

    [array]GetRunningProcesses() {
        return $this.RunningProcesses.Values
    }

    [hashtable]GetSoftwareStatus([string]$SoftwareName) {
        if ($this.ManagedSoftware.ContainsKey($SoftwareName)) {
            $software = $this.ManagedSoftware[$SoftwareName]
            $isRunning = $this.RunningProcesses.ContainsKey($SoftwareName)
            
            $status = @{
                Name = $SoftwareName
                IsConfigured = $true
                IsEnabled = $software.IsEnabled
                IsRunning = $isRunning
                AutoStart = $software.AutoStart
                ExecutablePath = $software.ExecutablePath
            }
            
            if ($isRunning) {
                $processInfo = $this.RunningProcesses[$SoftwareName]
                $status.ProcessId = $processInfo.ProcessId
                $status.StartTime = $processInfo.StartTime
                $status.WorkingSet = $processInfo.WorkingSet
            }
            
            return $status
        }
        
        return @{
            Name = $SoftwareName
            IsConfigured = $false
        }
    }

    [hashtable]GetStatus() {
        return @{
            IsMonitoring = $this.IsMonitoring
            ManagedSoftwareCount = $this.ManagedSoftware.Count
            RunningSoftwareCount = $this.RunningProcesses.Count
            EnabledSoftwareCount = ($this.ManagedSoftware.Values | Where-Object { $_.IsEnabled }).Count
            AutoStartSoftwareCount = ($this.ManagedSoftware.Values | Where-Object { $_.AutoStart }).Count
        }
    }
}

# Module functions
function Start-SoftwareMonitoring {
    param([int]$IntervalSeconds = 10)
    
    if (-not $Global:SoftwareManager) {
        $Global:SoftwareManager = [SoftwareManager]::new()
    }
    
    $Global:SoftwareManager.Start($IntervalSeconds)
}

function Stop-SoftwareMonitoring {
    if ($Global:SoftwareManager) {
        $Global:SoftwareManager.Stop()
    }
}

function Start-Software {
    param([string]$SoftwareName)
    
    if ($Global:SoftwareManager) {
        return $Global:SoftwareManager.StartSoftware($SoftwareName)
    }
    return $false
}

function Stop-Software {
    param([string]$SoftwareName)
    
    if ($Global:SoftwareManager) {
        return $Global:SoftwareManager.StopSoftware($SoftwareName)
    }
    return $false
}

function Restart-Software {
    param([string]$SoftwareName)
    
    if ($Global:SoftwareManager) {
        return $Global:SoftwareManager.RestartSoftware($SoftwareName)
    }
    return $false
}

function Get-ManagedSoftware {
    if ($Global:SoftwareManager) {
        return $Global:SoftwareManager.GetManagedSoftware()
    }
    return @()
}

function Get-RunningSoftware {
    if ($Global:SoftwareManager) {
        return $Global:SoftwareManager.GetRunningProcesses()
    }
    return @()
}

function Get-SoftwareStatus {
    param([string]$SoftwareName)
    
    if ($Global:SoftwareManager) {
        return $Global:SoftwareManager.GetSoftwareStatus($SoftwareName)
    }
    return @{ IsConfigured = $false }
}

function Get-SoftwareMonitoringStatus {
    if ($Global:SoftwareManager) {
        return $Global:SoftwareManager.GetStatus()
    }
    return @{ IsMonitoring = $false }
}

# Export module members
Export-ModuleMember -Function *