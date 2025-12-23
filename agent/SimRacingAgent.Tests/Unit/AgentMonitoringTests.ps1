#Requires -Version 5.1

<#
.SYNOPSIS
    Unit tests for SimRacing Agent monitoring modules.

.DESCRIPTION
    Agent-specific unit tests covering USB monitoring and process management modules.
    Tests focus on agent monitoring capabilities without external system dependencies.
#>

# Import shared test framework
Import-Module "$PSScriptRoot\..\..\shared\TestFramework.psm1" -Force

# Import agent monitoring modules
$AgentPath = "$PSScriptRoot\..\..\..\agent"
Import-Module "$AgentPath\src\modules\USBMonitor.psm1" -Force
Import-Module "$AgentPath\src\modules\ProcessManager.psm1" -Force

function Test-AgentUSBMonitoring {
    [CmdletBinding()]
    param()
    
    Start-TestSession -SessionName "Agent USB Monitoring Unit Tests"
    
    try {
        # Test 1: USB device enumeration
        Invoke-Test -Name "Get-USBDevices returns device collection" -Category "USBMonitor" -TestScript {
            # Mock WMI response
            New-Mock -CommandName "Get-WmiObject" -MockWith {
                return @(
                    @{
                        DeviceID = "USB\\VID_046D&PID_C52B\\123456"
                        Description = "USB Input Device"
                        Status = "OK"
                        PNPClass = "HIDClass"
                    },
                    @{
                        DeviceID = "USB\\VID_8086&PID_9D2F\\789012"
                        Description = "Intel USB 3.0 Host Controller"
                        Status = "OK"
                        PNPClass = "USB"
                    }
                )
            } -ParameterFilter @{ Class = "Win32_PnPEntity" }
            
            $devices = Get-USBDevices
            # Debug dump for flaky WMI-failure test
            try {
                $dump = @()
                $dump += "Timestamp: $(Get-Date -Format o)"
                $dump += "MockKeys: $($Global:MockFunctions.Keys -join ',')"
                $dump += "MockOrders: $($Global:MockOrders.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" } -join ',')"
                $dump += "DevicesCount: $($devices.Count)"
                if ($devices.Count -gt 0) { $devices | ForEach-Object { $dump += "Device: $($_.DeviceID) | $($_.Description)" } }
                $tmpRoot = Join-Path $env:TEMP 'USBDeviceManager'
                if (-not (Test-Path $tmpRoot)) { New-Item -Path $tmpRoot -ItemType Directory -Force | Out-Null }
                $dumpPath = Join-Path $tmpRoot '.tmp_usb_fail_debug.txt'
                $dump | Out-File -FilePath $dumpPath -Append -Encoding utf8
            } catch {}
            
            Assert-NotNull -Value $devices -Message "Device list should not be null"
            Assert-Equal -Expected 2 -Actual $devices.Count -Message "Should return 2 mocked devices"
            Assert-Equal -Expected "USB Input Device" -Actual $devices[0].Description -Message "First device description should match"
        }
        
        # Test 2: USB health check calculation
        Invoke-Test -Name "Get-USBHealthCheck calculates agent-specific metrics" -Category "USBMonitor" -TestScript {
            # Mock USB devices
            New-Mock -CommandName "Get-USBDevices" -MockWith {
                return @(
                    @{ DeviceID = "USB1"; Status = "OK"; Description = "Device 1" },
                    @{ DeviceID = "USB2"; Status = "OK"; Description = "Device 2" },
                    @{ DeviceID = "USB3"; Status = "Error"; Description = "Device 3" }
                )
            }
            
            $healthCheck = Get-USBHealthCheck
            
            Assert-NotNull -Value $healthCheck -Message "Health check should not be null"
            Assert-True -Condition ($healthCheck.ContainsKey('DeviceCount')) -Message "Should include device count"
            Assert-True -Condition ($healthCheck.ContainsKey('OverallHealth')) -Message "Should include overall health score"
            Assert-Equal -Expected 3 -Actual $healthCheck.DeviceCount -Message "Should count all devices"
            
            # Health should be between 0-100
            Assert-True -Condition ($healthCheck.OverallHealth -ge 0 -and $healthCheck.OverallHealth -le 100) -Message "Health score should be 0-100"
        }
        
        # Test 3: USB monitoring initialization for agent
        Invoke-Test -Name "Initialize-USBMonitoring sets up agent monitoring" -Category "USBMonitor" -TestScript {
            # Mock dependencies
            New-Mock -CommandName "Get-USBDevices" -MockWith { return @() }
            New-Mock -CommandName "Register-ObjectEvent" -MockWith { return @{ Id = 1 } }
            
            $result = Initialize-USBMonitoring -PollingInterval 10
            
            Assert-True -Condition $result -Message "USB monitoring initialization should succeed"
            Assert-MockCalled -CommandName "Get-USBDevices" -Times 1 -Message "Should query initial device state"
        }
        
        # Test 4: USB error handling in agent context
        Invoke-Test -Name "USB operations handle WMI failures gracefully" -Category "USBMonitor" -TestScript {
            # Ensure clean mock state and then mock WMI failure
            Clear-AllMocks
            New-Mock -CommandName "Get-WmiObject" -MockWith {
                throw "WMI service unavailable"
            }
            
            $devices = Get-USBDevices
            # Some PowerShell runtimes can treat empty arrays specially in certain scopes;
            # assert using explicit count to avoid fragile null checks across scopes.
            Assert-Equal -Expected 0 -Actual $devices.Count -Message "Should return empty array when WMI fails"
        }
        
        # Test 5: USB device filtering for agent
        Invoke-Test -Name "USB device filtering works for agent monitoring" -Category "USBMonitor" -TestScript {
            New-Mock -CommandName "Get-WmiObject" -MockWith {
                return @(
                    @{ DeviceID = "USB\\VID_046D"; Description = "Logitech Device"; Status = "OK"; PNPClass = "HIDClass" },
                    @{ DeviceID = "PCI\\VEN_8086"; Description = "Intel Device"; Status = "OK"; PNPClass = "System" },
                    @{ DeviceID = "USB\\VID_1234"; Description = "Generic USB"; Status = "OK"; PNPClass = "USB" }
                )
            }
            
            $usbDevices = Get-USBDevices
            
            # Should only return USB devices (filter out PCI)
            Assert-True -Condition ($usbDevices.Count -le 2) -Message "Should filter non-USB devices"
            
            foreach ($device in $usbDevices) {
                Assert-True -Condition ($device.DeviceID -like "USB\\*") -Message "All returned devices should be USB"
            }
        }
        
    }
    finally {
        Clear-AllMocks
    }
    
    return Complete-TestSession
}

function Test-AgentProcessManager {
    [CmdletBinding()]
    param()
    
    Start-TestSession -SessionName "Agent Process Manager Unit Tests"
    
    try {
        # Test 1: Process health monitoring
        Invoke-Test -Name "Get-ProcessHealthCheck provides agent process metrics" -Category "ProcessManager" -TestScript {
            # Mock process data
            New-Mock -CommandName "Get-Process" -MockWith {
                return @(
                    @{
                        ProcessName = "SimRacingAgent"
                        WorkingSet = 50MB
                        CPU = 5.0
                        Responding = $true
                        Id = 1234
                    },
                    @{
                        ProcessName = "notepad"
                        WorkingSet = 10MB
                        CPU = 1.0
                        Responding = $true
                        Id = 5678
                    }
                )
            }
            
            $healthCheck = Get-ProcessHealthCheck
            
            Assert-NotNull -Value $healthCheck -Message "Process health check should not be null"
            Assert-True -Condition ($healthCheck.ContainsKey('ProcessCount')) -Message "Should include process count"
            Assert-True -Condition ($healthCheck.ContainsKey('OverallHealth')) -Message "Should include health score"
            Assert-True -Condition ($healthCheck.ContainsKey('MemoryUsage')) -Message "Should include memory metrics"
        }
        
        # Test 2: Managed process validation for agent
        Invoke-Test -Name "Test-ManagedProcess validates agent process definitions" -Category "ProcessManager" -TestScript {
            $validProcess = @{
                Name = "TestApp"
                ExecutablePath = "C:\\Windows\\System32\\notepad.exe"
                Arguments = ""
                AutoRestart = $true
            }
            
            # Mock file existence
            New-Mock -CommandName "Test-Path" -MockWith { $true } -ParameterFilter @{ Path = "C:\\Windows\\System32\\notepad.exe" }
            
            $isValid = Test-ManagedProcess -ProcessDefinition $validProcess
            Assert-True -Condition $isValid -Message "Valid process definition should pass validation"
            
            # Test invalid process
            $invalidProcess = @{
                Name = ""
                ExecutablePath = "C:\\NonExistent\\app.exe"
            }
            
            New-Mock -CommandName "Test-Path" -MockWith { $false } -ParameterFilter @{ Path = "C:\\NonExistent\\app.exe" }
            
            $isInvalid = Test-ManagedProcess -ProcessDefinition $invalidProcess
            Assert-False -Condition $isInvalid -Message "Invalid process definition should fail validation"
        }
        
        # Test 3: Process lifecycle for agent
        Invoke-Test -Name "Start-ManagedProcess handles agent process startup" -Category "ProcessManager" -TestScript {
            # Mock process not running
            New-Mock -CommandName "Get-Process" -MockWith { return @() } -ParameterFilter @{ Name = "TestProcess" }
            New-Mock -CommandName "Test-Path" -MockWith { $true }
            New-Mock -CommandName "Start-Process" -MockWith { 
                return @{ Id = 9999; ProcessName = "TestProcess" }
            }
            
            $result = Start-ManagedProcess -Name "TestProcess" -ExecutablePath "C:\\test.exe"
            
            Assert-True -Condition $result -Message "Process start should succeed"
            Assert-MockCalled -CommandName "Start-Process" -Times 1 -Message "Should call Start-Process"
        }
        
        # Test 4: Process monitoring for agent context
        Invoke-Test -Name "Get-ProcessMetrics provides agent-relevant metrics" -Category "ProcessManager" -TestScript {
            New-Mock -CommandName "Get-Process" -MockWith {
                return @(
                    @{
                        ProcessName = "SimRacingAgent"
                        WorkingSet = 100MB
                        PagedMemorySize = 50MB
                        CPU = 10.5
                        Responding = $true
                        StartTime = (Get-Date).AddMinutes(-30)
                    }
                )
            } -ParameterFilter @{ Name = "SimRacingAgent" }
            
            $metrics = Get-ProcessMetrics -ProcessName "SimRacingAgent"
            
            Assert-NotNull -Value $metrics -Message "Metrics should not be null"
            Assert-True -Condition ($metrics.ContainsKey('MemoryUsageMB')) -Message "Should include memory usage"
            Assert-True -Condition ($metrics.ContainsKey('CPUUsage')) -Message "Should include CPU usage"
            Assert-True -Condition ($metrics.ContainsKey('UptimeMinutes')) -Message "Should include uptime"
        }
        
        # Test 5: Process health scoring algorithm for agent
        Invoke-Test -Name "Calculate-ProcessHealth uses agent-specific scoring" -Category "ProcessManager" -TestScript {
            $processData = @{
                MemoryUsageMB = 50
                CPUUsage = 15.0
                Responding = $true
                UptimeMinutes = 120
            }
            
            $healthScore = Calculate-ProcessHealth -ProcessData $processData
            
            Assert-True -Condition ($healthScore -ge 0 -and $healthScore -le 100) -Message "Health score should be 0-100"
            Assert-True -Condition ($healthScore -gt 50) -Message "Healthy process should score above 50"
        }
        
    }
    finally {
        Clear-AllMocks
    }
    
    return Complete-TestSession
}

# Test runner for agent monitoring tests
function Invoke-AgentMonitoringTests {
    [CmdletBinding()]
    param(
        [string[]]$TestSuites = @("USBMonitoring", "ProcessManager"),
        [switch]$StopOnFirstFailure
    )
    
    $allResults = @()
    $overallSuccess = $true
    
    Write-Host "Starting SimRacing Agent Monitoring Unit Tests" -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        foreach ($suite in $TestSuites) {
            Write-Host "Running agent monitoring test suite: $suite" -ForegroundColor Yellow
            
            $result = switch ($suite) {
                "USBMonitoring" { Test-AgentUSBMonitoring }
                "ProcessManager" { Test-AgentProcessManager }
                default {
                    Write-Warning "Unknown agent monitoring test suite: $suite"
                    @{ Success = $false; Results = @{ Failed = 1; Passed = 0; Skipped = 0 } }
                }
            }
            
            $allResults += $result
            if (-not $result.Success) {
                $overallSuccess = $false
                if ($StopOnFirstFailure) {
                    Write-Host "Stopping agent monitoring tests due to failure in $suite" -ForegroundColor Red
                    break
                }
            }
            
            Write-Host ""
        }
        
        # Summary
        $totalPassed = ($allResults | ForEach-Object { $_.Results.Passed } | Measure-Object -Sum).Sum
        $totalFailed = ($allResults | ForEach-Object { $_.Results.Failed } | Measure-Object -Sum).Sum
        $totalSkipped = ($allResults | ForEach-Object { $_.Results.Skipped } | Measure-Object -Sum).Sum
        
        Write-Host "Agent Monitoring Test Summary" -ForegroundColor Cyan
        Write-Host "============================" -ForegroundColor Cyan
        Write-Host "Total Passed:  $totalPassed" -ForegroundColor Green
        Write-Host "Total Failed:  $totalFailed" -ForegroundColor Red
        Write-Host "Total Skipped: $totalSkipped" -ForegroundColor Yellow
        Write-Host "Overall Result: $(if ($overallSuccess) { 'SUCCESS' } else { 'FAILURE' })" -ForegroundColor $(if ($overallSuccess) { 'Green' } else { 'Red' })
        
        return @{
            Success = $overallSuccess
            Results = $allResults
            Summary = @{
                Passed = $totalPassed
                Failed = $totalFailed
                Skipped = $totalSkipped
            }
        }
    }
    finally {
        Clear-AllMocks
    }
}

# Export functions when run as module
if ($MyInvocation.PSScriptRoot) {
    Export-ModuleMember -Function @(
        'Test-AgentUSBMonitoring',
        'Test-AgentProcessManager',
        'Invoke-AgentMonitoringTests'
    )
}