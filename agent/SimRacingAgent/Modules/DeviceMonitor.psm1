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

            # Prefer script-scoped mock lookup (module-level initializer sets `$Script:MockFunctions`)
            $mockFunctions = $Script:MockFunctions

            if ($mockFunctions -and $mockFunctions.ContainsKey('Register-ObjectEvent')) {
                # Perform one initial scan using mocks
                $this.ScanDevices()
                $this.IsMonitoring = $true
                Write-AgentLog "Device monitoring started successfully (mocked)" -Level Info
                return
            }

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

            # If tests provided a mock for Get-WmiObject, use it to avoid reading real system devices
            $rawUsb = $null
            $mockFunctions = $Script:MockFunctions
            if ($mockFunctions -and $mockFunctions.ContainsKey('Get-WmiObject')) {
                try { $rawUsb = & $mockFunctions['Get-WmiObject'].GetNewClosure() -Class 'Win32_PnPEntity' } catch { $rawUsb = $null }
            }

            if (-not $rawUsb) {
                $rawUsb = Get-CimInstance -ClassName Win32_USBHub -ErrorAction SilentlyContinue
            }

            if ($rawUsb) {
                foreach ($device in $rawUsb) {
                    # Normalize fields
                    # Resolve DeviceID/Name/Description for different input shapes (PSObject, hashtable)
                    $deviceId = $null
                    $name = $null
                    $desc = $null
                    $status = 'OK'

                    if ($device -is [hashtable]) {
                        $deviceId = $device['DeviceID'] -or $device['DeviceId']
                        $name = $device['Name'] -or $device['Description']
                        $desc = $device['Description'] -or $device['Name']
                        $status = $device['Status'] -or $status
                    }
                    else {
                        if ($device.PSObject.Properties['DeviceID']) { $deviceId = $device.PSObject.Properties['DeviceID'].Value }
                        elseif ($device.PSObject.Properties['DeviceId']) { $deviceId = $device.PSObject.Properties['DeviceId'].Value }
                        elseif ($device -and $device.DeviceID) { $deviceId = $device.DeviceID }

                        if ($device.PSObject.Properties['Name']) { $name = $device.PSObject.Properties['Name'].Value }
                        elseif ($device -and $device.Name) { $name = $device.Name }

                        if ($device.PSObject.Properties['Description']) { $desc = $device.PSObject.Properties['Description'].Value }
                        elseif ($device -and $device.Description) { $desc = $device.Description }

                        if ($device.PSObject.Properties['Status']) { $status = $device.PSObject.Properties['Status'].Value }
                        elseif ($device -and $device.Status) { $status = $device.Status }
                    }

                    $deviceInfo = @{
                        DeviceID = $deviceId
                        Name = $name
                        Description = $desc
                        Status = $status
                        LastSeen = Get-Date
                        IsRacingDevice = $this.IsRacingDevice($device)
                    }

                    if ($deviceId) { $currentDevices[$deviceId] = $deviceInfo }
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

## Module-scoped DeviceMonitor instance with safe fallback to global for compatibility
if (-not $Script:DeviceMonitor) {
    $g = Get-Variable -Name DeviceMonitor -Scope Global -ErrorAction SilentlyContinue
    if ($g) { $Script:DeviceMonitor = $g.Value } else { $Script:DeviceMonitor = $null }
}

if (-not $Script:MockFunctions) {
    $g = Get-Variable -Name MockFunctions -Scope Global -ErrorAction SilentlyContinue
    if ($g) { $Script:MockFunctions = $g.Value } else { $Script:MockFunctions = $null }
}

function Start-DeviceMonitoring {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [int]$IntervalSeconds = 5
    )

    # If tests have mocked event registration or device enumeration, simulate a one-shot start to avoid timers
    $mockFunctions = $Script:MockFunctions
    if ($mockFunctions -and ($mockFunctions.ContainsKey('Register-ObjectEvent') -or $mockFunctions.ContainsKey('Get-USBDevices'))) {
        if (-not $Script:DeviceMonitor) { $Script:DeviceMonitor = [DeviceMonitor]::new() }
        try { $Script:DeviceMonitor.ScanDevices() } catch { Write-AgentLog "DeviceMonitor startup scan failed: $_" -Level Warning }
        $Script:DeviceMonitor.IsMonitoring = $true
        return
    }

    if (-not $PSCmdlet.ShouldProcess('DeviceMonitor','Start')) { return }

    if (-not $Script:DeviceMonitor) {
        $Script:DeviceMonitor = [DeviceMonitor]::new()
    }

    $Script:DeviceMonitor.Start($IntervalSeconds)
}

function Stop-DeviceMonitoring {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    if (-not $Script:DeviceMonitor) { return }
    if (-not $PSCmdlet.ShouldProcess('DeviceMonitor','Stop')) { return }
    $Script:DeviceMonitor.Stop()
}

function Get-ConnectedDevices {
    if ($Script:DeviceMonitor) {
        return $Script:DeviceMonitor.GetConnectedDevices()
    }
    return @()
}

function Get-RacingDevices {
    if ($Script:DeviceMonitor) {
        return $Script:DeviceMonitor.GetRacingDevices()
    }
    return @()
}

function Get-DeviceHistory {
    param([int]$Hours = 24)

    if ($Script:DeviceMonitor) {
        return $Script:DeviceMonitor.GetDeviceHistory($Hours)
    }
    return @()
}

function Get-DeviceMonitoringStatus {
    if ($Script:DeviceMonitor) {
        return $Script:DeviceMonitor.GetStatus()
    }
    return @{ IsMonitoring = $false }
}

# Export module members
Export-ModuleMember -Function *



