# Device Monitor Module
# Real-time USB device monitoring and health tracking

using module ..\Utils\Logging.psm1

class DeviceMonitor {
    [hashtable]$ConnectedDevices
    [System.Collections.ArrayList]$DeviceHistory
    [bool]$IsMonitoring
    [System.Timers.Timer]$MonitoringTimer

    DeviceMonitor() {
        $this.ConnectedDevices = @{}
        $this.DeviceHistory = @()
        $this.IsMonitoring = $false
    }

    [void]Start([int]$IntervalSeconds = 5) {
        if ($this.IsMonitoring) {
            Write-AgentLog "Device monitoring is already running" -Level Warning
            return
        }

        try {
            Write-AgentLog "Starting device monitoring (interval: ${IntervalSeconds}s)" -Level Info
            
            # Perform initial scan
            $this.ScanDevices()
            
            # Setup monitoring timer
            $this.MonitoringTimer = New-Object System.Timers.Timer($IntervalSeconds * 1000)
            $this.MonitoringTimer.AutoReset = $true
            
            Register-ObjectEvent -InputObject $this.MonitoringTimer -EventName Elapsed -Action {
                try {
                    [DeviceMonitor]$monitor = $Event.MessageData
                    $monitor.ScanDevices()
                }
                catch {
                    Write-AgentLog "Device monitoring error: $($_.Exception.Message)" -Level Error
                }
            } -MessageData $this | Out-Null
            
            $this.MonitoringTimer.Start()
            $this.IsMonitoring = $true
            
            Write-AgentLog "Device monitoring started successfully" -Level Info
        }
        catch {
            Write-AgentLog "Failed to start device monitoring: $($_.Exception.Message)" -Level Error
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
            Write-AgentLog "Device monitoring stopped" -Level Info
        }
        catch {
            Write-AgentLog "Error stopping device monitoring: $($_.Exception.Message)" -Level Error
        }
    }

    [void]ScanDevices() {
        try {
            $currentDevices = @{}
            
            # Get USB devices using WMI
            $usbDevices = Get-CimInstance -ClassName Win32_USBHub -ErrorAction SilentlyContinue
            
            if ($usbDevices) {
                foreach ($device in $usbDevices) {
                    $deviceInfo = @{
                        DeviceID = $device.DeviceID
                        Name = $device.Name
                        Description = $device.Description
                        Status = $device.Status
                        LastSeen = Get-Date
                        IsRacingDevice = $this.IsRacingDevice($device)
                    }
                    
                    $currentDevices[$device.DeviceID] = $deviceInfo
                }
            }
            
            # Check for new devices
            foreach ($deviceId in $currentDevices.Keys) {
                if (-not $this.ConnectedDevices.ContainsKey($deviceId)) {
                    Write-AgentLog "New device detected: $($currentDevices[$deviceId].Name)" -Level Info
                    $this.OnDeviceConnected($currentDevices[$deviceId])
                }
            }
            
            # Check for disconnected devices
            $disconnectedDevices = @()
            foreach ($deviceId in $this.ConnectedDevices.Keys) {
                if (-not $currentDevices.ContainsKey($deviceId)) {
                    $disconnectedDevices += $deviceId
                }
            }
            
            foreach ($deviceId in $disconnectedDevices) {
                Write-AgentLog "Device disconnected: $($this.ConnectedDevices[$deviceId].Name)" -Level Info
                $this.OnDeviceDisconnected($this.ConnectedDevices[$deviceId])
                $this.ConnectedDevices.Remove($deviceId)
            }
            
            # Update connected devices
            $this.ConnectedDevices = $currentDevices
        }
        catch {
            Write-AgentLog "Error scanning devices: $($_.Exception.Message)" -Level Error
        }
    }

    [bool]IsRacingDevice([Object]$device) {
        $racingKeywords = @(
            "wheel", "pedal", "shifter", "racing", "thrustmaster", 
            "logitech", "fanatec", "simucube", "heusinkveld"
        )
        
        $deviceText = "$($device.Name) $($device.Description)".ToLower()
        
        foreach ($keyword in $racingKeywords) {
            if ($deviceText -like "*$keyword*") {
                return $true
            }
        }
        
        return $false
    }

    [void]OnDeviceConnected([hashtable]$deviceInfo) {
        try {
            # Log device connection
            $this.DeviceHistory.Add(@{
                Event = "Connected"
                Device = $deviceInfo
                Timestamp = Get-Date
            })
            
            # Trigger automation if configured
            if (Get-Command "Invoke-DeviceAutomation" -ErrorAction SilentlyContinue) {
                Invoke-DeviceAutomation -Event "Connected" -Device $deviceInfo
            }
            
            Write-AgentLog "Device connected: $($deviceInfo.Name)" -Level Info
        }
        catch {
            Write-AgentLog "Error handling device connection: $($_.Exception.Message)" -Level Error
        }
    }

    [void]OnDeviceDisconnected([hashtable]$deviceInfo) {
        try {
            # Log device disconnection
            $this.DeviceHistory.Add(@{
                Event = "Disconnected"
                Device = $deviceInfo
                Timestamp = Get-Date
            })
            
            # Trigger automation if configured
            if (Get-Command "Invoke-DeviceAutomation" -ErrorAction SilentlyContinue) {
                Invoke-DeviceAutomation -Event "Disconnected" -Device $deviceInfo
            }
            
            Write-AgentLog "Device disconnected: $($deviceInfo.Name)" -Level Info
        }
        catch {
            Write-AgentLog "Error handling device disconnection: $($_.Exception.Message)" -Level Error
        }
    }

    [array]GetConnectedDevices() {
        return $this.ConnectedDevices.Values
    }

    [array]GetRacingDevices() {
        return $this.ConnectedDevices.Values | Where-Object { $_.IsRacingDevice -eq $true }
    }

    [array]GetDeviceHistory([int]$Hours = 24) {
        $cutoff = (Get-Date).AddHours(-$Hours)
        return $this.DeviceHistory | Where-Object { $_.Timestamp -ge $cutoff }
    }

    [hashtable]GetStatus() {
        return @{
            IsMonitoring = $this.IsMonitoring
            ConnectedDeviceCount = $this.ConnectedDevices.Count
            RacingDeviceCount = ($this.ConnectedDevices.Values | Where-Object { $_.IsRacingDevice }).Count
            HistoryEntryCount = $this.DeviceHistory.Count
            LastScan = Get-Date
        }
    }
}

# Module functions
function Start-DeviceMonitoring {
    param(
        [int]$IntervalSeconds = 5
    )
    
    if (-not $Global:DeviceMonitor) {
        $Global:DeviceMonitor = [DeviceMonitor]::new()
    }
    
    $Global:DeviceMonitor.Start($IntervalSeconds)
}

function Stop-DeviceMonitoring {
    if ($Global:DeviceMonitor) {
        $Global:DeviceMonitor.Stop()
    }
}

function Get-ConnectedDevices {
    if ($Global:DeviceMonitor) {
        return $Global:DeviceMonitor.GetConnectedDevices()
    }
    return @()
}

function Get-RacingDevices {
    if ($Global:DeviceMonitor) {
        return $Global:DeviceMonitor.GetRacingDevices()
    }
    return @()
}

function Get-DeviceHistory {
    param([int]$Hours = 24)
    
    if ($Global:DeviceMonitor) {
        return $Global:DeviceMonitor.GetDeviceHistory($Hours)
    }
    return @()
}

function Get-DeviceMonitoringStatus {
    if ($Global:DeviceMonitor) {
        return $Global:DeviceMonitor.GetStatus()
    }
    return @{ IsMonitoring = $false }
}

# Export module members
Export-ModuleMember -Function *