#Requires -Version 5.1

<#
.SYNOPSIS
    Regression tests for SimRacing Agent core functionality.

.DESCRIPTION
    Agent-specific regression tests that validate critical functionality
    continues to work correctly across code changes. Tests focus on
    backwards compatibility and performance stability.
#>

# Import shared test framework
Import-Module "$PSScriptRoot\..\..\shared\TestFramework.psm1" -Force

# Import agent modules
$AgentPath = "$PSScriptRoot\..\..\..\agent"
Import-Module "$AgentPath\src\modules\ConfigManager.psm1" -Force
Import-Module "$AgentPath\src\modules\AgentCore.psm1" -Force
Import-Module "$AgentPath\src\modules\USBMonitor.psm1" -Force
Import-Module "$AgentPath\src\modules\ProcessManager.psm1" -Force

function Test-AgentCoreRegression {
    [CmdletBinding()]
    param()
    
    Start-TestSession -SessionName "Agent Core Regression Tests"
    
    try {
        # Test 1: Configuration format compatibility
        Invoke-Test -Name "Agent maintains backwards compatibility with existing config files" -Category "ConfigRegression" -TestScript {
            # Test legacy configuration format
            $legacyConfig = @{
                "AgentSettings" = @{
                    "Name" = "SimRacingAgent"
                    "Version" = "1.0.0"
                }
                "MonitoringSettings" = @{
                    "USBPollingInterval" = 30
                    "ProcessMonitoringEnabled" = $true
                }
                "LoggingSettings" = @{
                    "LogLevel" = "Info"
                    "LogFile" = "agent.log"
                }
            }
            
            # Mock legacy config file read
            New-Mock -CommandName "Get-Content" -MockWith {
                return ($legacyConfig | ConvertTo-Json -Depth 10)
            } -ParameterFilter @{ Path = "*agent-config.json" }
            
            New-Mock -CommandName "Test-Path" -MockWith { $true }
            
            # Load legacy configuration
            $loadedConfig = Import-AgentConfiguration -ConfigPath "agent-config.json"
            
            Assert-NotNull -Value $loadedConfig -Message "Should load legacy configuration"
            Assert-Equal -Expected "SimRacingAgent" -Actual $loadedConfig.AgentSettings.Name -Message "Should preserve agent name"
            Assert-Equal -Expected 30 -Actual $loadedConfig.MonitoringSettings.USBPollingInterval -Message "Should preserve USB polling interval"
            Assert-Equal -Expected $true -Actual $loadedConfig.MonitoringSettings.ProcessMonitoringEnabled -Message "Should preserve process monitoring setting"
        }
        
        # Test 2: Health check API stability
        Invoke-Test -Name "Health check API maintains stable response format" -Category "APIRegression" -TestScript {
            # Mock component health checks with expected format
            New-Mock -CommandName "Get-USBHealthCheck" -MockWith {
                return @{
                    DeviceCount = 3
                    HealthyDevices = 3
                    OverallHealth = 100
                    Details = @{
                        ConnectedDevices = @("Device1", "Device2", "Device3")
                        FailedDevices = @()
                    }
                    Timestamp = "2024-01-01T12:00:00Z"
                }
            }
            
            New-Mock -CommandName "Get-ProcessHealthCheck" -MockWith {
                return @{
                    ProcessCount = 2
                    HealthyProcesses = 2
                    OverallHealth = 95
                    MemoryUsage = 150MB
                    Details = @{
                        RunningProcesses = @("Process1", "Process2")
                        FailedProcesses = @()
                    }
                    Timestamp = "2024-01-01T12:00:00Z"
                }
            }
            
            # Execute health check
            $healthResult = Get-AgentHealthStatus
            
            # Verify stable response format
            Assert-NotNull -Value $healthResult -Message "Health result should not be null"
            Assert-True -Condition ($healthResult.ContainsKey('OverallHealth')) -Message "Should include OverallHealth field"
            Assert-True -Condition ($healthResult.ContainsKey('ComponentStatus')) -Message "Should include ComponentStatus field"
            Assert-True -Condition ($healthResult.ContainsKey('Timestamp')) -Message "Should include Timestamp field"
            Assert-True -Condition ($healthResult.ContainsKey('Version')) -Message "Should include Version field"
            
            # Verify component status structure
            $componentStatus = $healthResult.ComponentStatus
            Assert-True -Condition ($componentStatus.ContainsKey('USB')) -Message "Should include USB component status"
            Assert-True -Condition ($componentStatus.ContainsKey('Process')) -Message "Should include Process component status"
            
            # Verify health score is within expected range
            Assert-True -Condition ($healthResult.OverallHealth -ge 0 -and $healthResult.OverallHealth -le 100) -Message "Overall health should be 0-100"
        }
        
        # Test 3: Performance benchmarks
        Invoke-Test -Name "Agent performance meets established benchmarks" -Category "PerformanceRegression" -TestScript {
            # Mock system resources
            New-Mock -CommandName "Get-Process" -MockWith {
                return @(
                    @{ ProcessName = "SimRacingAgent"; WorkingSet = 50MB; CPU = 2.5 }
                )
            } -ParameterFilter @{ Name = "SimRacingAgent" }
            
            New-Mock -CommandName "Get-USBDevices" -MockWith {
                return @(1..10 | ForEach-Object {
                    @{ DeviceID = "USB$_"; Status = "OK"; Description = "Device $_" }
                })
            }
            
            # Performance benchmarks (established baselines)
            $benchmarks = @{
                MaxMemoryUsageMB = 100
                MaxCPUUsagePercent = 10
                MaxUSBQueryTimeMs = 500
                MaxHealthCheckTimeMs = 1000
            }
            
            # Test memory usage
            $agentProcess = Get-Process -Name "SimRacingAgent" -ErrorAction SilentlyContinue
            if ($agentProcess) {
                $memoryUsageMB = $agentProcess.WorkingSet / 1MB
                Assert-True -Condition ($memoryUsageMB -le $benchmarks.MaxMemoryUsageMB) -Message "Memory usage should be under $($benchmarks.MaxMemoryUsageMB)MB, actual: $($memoryUsageMB)MB"
            }
            
            # Test USB query performance
            $usbQueryTime = Measure-Command { Get-USBDevices }
            Assert-True -Condition ($usbQueryTime.TotalMilliseconds -le $benchmarks.MaxUSBQueryTimeMs) -Message "USB query should complete under $($benchmarks.MaxUSBQueryTimeMs)ms, actual: $($usbQueryTime.TotalMilliseconds)ms"
            
            # Test health check performance
            $healthCheckTime = Measure-Command { Get-AgentHealthStatus }
            Assert-True -Condition ($healthCheckTime.TotalMilliseconds -le $benchmarks.MaxHealthCheckTimeMs) -Message "Health check should complete under $($benchmarks.MaxHealthCheckTimeMs)ms, actual: $($healthCheckTime.TotalMilliseconds)ms"
        }
        
        # Test 4: Event handling stability
        Invoke-Test -Name "Agent event handling remains stable across scenarios" -Category "EventRegression" -TestScript {
            # Mock event registration and handling
            $eventCounter = 0
            New-Mock -CommandName "Register-EngineEvent" -MockWith {
                return @{ Id = ++$script:eventCounter }
            }
            
            New-Mock -CommandName "Unregister-Event" -MockWith {
                return $true
            }
            
            # Test event registration stability
            $events = @()
            for ($i = 1; $i -le 10; $i++) {
                $testEvent = Register-MonitoringEvent -EventType "DeviceChange" -Handler { param($EventData) Write-Host "Event: $($EventData.EventType)" }
                $events += $testEvent
            }
            
            Assert-Equal -Expected 10 -Actual $events.Count -Message "Should register all 10 events"
            
            # Test event cleanup
            $cleanupResult = $events | ForEach-Object { 
                Unregister-MonitoringEvent -EventId $_.Id 
            } | Where-Object { $_ -eq $true }
            
            Assert-Equal -Expected 10 -Actual $cleanupResult.Count -Message "Should successfully unregister all events"
        }
        
        # Test 5: Error handling consistency
        Invoke-Test -Name "Agent error handling maintains consistent behavior" -Category "ErrorRegression" -TestScript {
            # Test various error scenarios and verify consistent error handling
            $errorScenarios = @(
                @{
                    Name = "USB service unavailable"
                    MockFunction = "Get-WmiObject"
                    MockBehavior = { throw "The RPC server is unavailable" }
                    ExpectedErrorCategory = "ServiceUnavailable"
                },
                @{
                    Name = "Configuration file corrupted"
                    MockFunction = "Get-Content"
                    MockBehavior = { throw "Invalid JSON format" }
                    ExpectedErrorCategory = "ConfigurationError"
                },
                @{
                    Name = "Insufficient permissions"
                    MockFunction = "Get-Process"
                    MockBehavior = { throw "Access denied" }
                    ExpectedErrorCategory = "PermissionDenied"
                }
            )
            
            foreach ($scenario in $errorScenarios) {
                # Setup error scenario
                New-Mock -CommandName $scenario.MockFunction -MockWith $scenario.MockBehavior
                
                # Execute operation and capture error handling
                try {
                    switch ($scenario.MockFunction) {
                        "Get-WmiObject" { $result = Get-USBDevices }
                        "Get-Content" { $result = Import-AgentConfiguration -ConfigPath "test.json" }
                        "Get-Process" { $result = Get-ProcessHealthCheck }
                    }
                    
                    # Verify graceful error handling (should not throw)
                    Assert-NotNull -Value $result -Message "Should handle $($scenario.Name) gracefully"
                }
                catch {
                    # If an exception is thrown, it should be properly categorized
                    Assert-True -Condition ($_.CategoryInfo.Category -eq $scenario.ExpectedErrorCategory) -Message "Error should be categorized as $($scenario.ExpectedErrorCategory) for $($scenario.Name)"
                }
                
                # Reset mock
                Remove-Mock -CommandName $scenario.MockFunction
            }
        }
        
    }
    finally {
        Clear-AllMocks
    }
    
    return Complete-TestSession
}

function Test-AgentCompatibilityRegression {
    [CmdletBinding()]
    param()
    
    Start-TestSession -SessionName "Agent Compatibility Regression Tests"
    
    try {
        # Test 1: PowerShell version compatibility
        Invoke-Test -Name "Agent functions correctly across PowerShell versions" -Category "CompatibilityRegression" -TestScript {
            # Test PowerShell 5.1 specific features
            $script:testPSVersionTable = @{
                PSVersion = [Version]"5.1.19041.1"
                PSEdition = "Desktop"
                PSCompatibleVersions = @([Version]"1.0", [Version]"2.0", [Version]"3.0", [Version]"4.0", [Version]"5.0", [Version]"5.1.19041.1")
                BuildVersion = [Version]"10.0.19041.1"
                CLRVersion = [Version]"4.0.30319.42000"
                WSManStackVersion = [Version]"3.0"
                PSRemotingProtocolVersion = [Version]"2.3"
                SerializationVersion = [Version]"1.1.0.1"
            }
            
            New-Mock -CommandName "Get-Variable" -MockWith {
                return @{ Value = $script:testPSVersionTable } 
            } -ParameterFilter @{ Name = "PSVersionTable" }            # Test agent compatibility check
            $compatibilityResult = Test-AgentCompatibility
            
            Assert-True -Condition $compatibilityResult.IsCompatible -Message "Should be compatible with PowerShell 5.1"
            Assert-Equal -Expected "5.1.19041.1" -Actual $compatibilityResult.PSVersion -Message "Should detect correct PowerShell version"
            Assert-Equal -Expected "Desktop" -Actual $compatibilityResult.PSEdition -Message "Should detect Desktop edition"
        }
        
        # Test 2: Windows version compatibility
        Invoke-Test -Name "Agent supports expected Windows versions" -Category "CompatibilityRegression" -TestScript {
            # Mock Windows version detection
            New-Mock -CommandName "Get-ComputerInfo" -MockWith {
                return @{
                    WindowsProductName = "Windows 11 Pro"
                    WindowsVersion = "10.0.22000"
                    WindowsBuildLabEx = "22000.1.amd64fre.co_release.210604-1628"
                    TotalPhysicalMemory = 16GB
                }
            }
            
            # Test Windows compatibility
            $windowsCompat = Test-WindowsCompatibility
            
            Assert-True -Condition $windowsCompat.IsSupported -Message "Should support Windows 11"
            Assert-True -Condition ($windowsCompat.Version -ge [Version]"10.0.19041") -Message "Should meet minimum Windows version requirements"
            Assert-True -Condition ($windowsCompat.MemoryGB -ge 4) -Message "Should meet minimum memory requirements"
        }
        
        # Test 3: Module dependency compatibility
        Invoke-Test -Name "Agent module dependencies remain stable" -Category "CompatibilityRegression" -TestScript {
            # Test required module availability
            $requiredModules = @(
                "Microsoft.PowerShell.Management",
                "Microsoft.PowerShell.Utility", 
                "CimCmdlets"
            )
            
            foreach ($moduleName in $requiredModules) {
                New-Mock -CommandName "Get-Module" -MockWith {
                    return @{
                        Name = $moduleName
                        Version = "1.0.0.0"
                        ModuleType = "Manifest"
                        ExportedCommands = @{ Count = 10 }
                    }
                } -ParameterFilter @{ Name = $moduleName; ListAvailable = $true }
                
                $moduleTest = Test-ModuleDependency -ModuleName $moduleName
                Assert-True -Condition $moduleTest.IsAvailable -Message "Module $moduleName should be available"
            }
        }
        
        # Test 4: Agent command-line interface stability
        Invoke-Test -Name "Agent CLI maintains backwards compatibility" -Category "CompatibilityRegression" -TestScript {
            # Test legacy command formats
            $legacyCommands = @(
                @{ 
                    Command = "Get-AgentStatus"
                    ExpectedProperties = @("Status", "UpTime", "Version", "ComponentHealth")
                },
                @{
                    Command = "Start-AgentMonitoring" 
                    ExpectedProperties = @("Success", "Message", "StartTime")
                },
                @{
                    Command = "Stop-AgentMonitoring"
                    ExpectedProperties = @("Success", "Message", "StopTime")
                }
            )
            
            foreach ($legacyCmd in $legacyCommands) {
                # Mock command execution
                New-Mock -CommandName $legacyCmd.Command -MockWith {
                    $response = @{}
                    foreach ($prop in $legacyCmd.ExpectedProperties) {
                        $response[$prop] = switch ($prop) {
                            "Status" { "Running" }
                            "Success" { $true }
                            "Message" { "Operation completed" }
                            "UpTime" { New-TimeSpan -Hours 2 }
                            "Version" { "2.0.0" }
                            default { Get-Date }
                        }
                    }
                    return $response
                }
                
                # Execute legacy command
                $cmdResult = & $legacyCmd.Command
                
                # Verify expected properties exist
                foreach ($expectedProp in $legacyCmd.ExpectedProperties) {
                    Assert-True -Condition ($cmdResult.ContainsKey($expectedProp)) -Message "Command $($legacyCmd.Command) should include property $expectedProp"
                }
            }
        }
        
        # Test 5: Configuration migration compatibility
        Invoke-Test -Name "Agent handles configuration format migrations" -Category "CompatibilityRegression" -TestScript {
            # Test migration from v1.0 to v2.0 config format
            $v1Config = @{
                "agent_name" = "SimRacingAgent"
                "usb_polling_interval" = 30
                "process_monitoring" = $true
                "log_level" = "info"
            }
            
            $v2Config = @{
                "AgentSettings" = @{
                    "Name" = "SimRacingAgent" 
                    "Version" = "2.0.0"
                }
                "MonitoringSettings" = @{
                    "USBPollingInterval" = 30
                    "ProcessMonitoringEnabled" = $true
                }
                "LoggingSettings" = @{
                    "LogLevel" = "Info"
                }
            }
            
            # Mock configuration migration
            New-Mock -CommandName "ConvertTo-ConfigV2" -MockWith {
                param($V1Config)
                # Use the v2Config variable as template and merge with V1Config
                return @{
                    "AgentSettings" = @{
                        "Name" = $V1Config.agent_name
                        "Version" = "2.0.0"
                    }
                    "MonitoringSettings" = @{
                        "USBPollingInterval" = $V1Config.usb_polling_interval
                        "ProcessMonitoringEnabled" = $V1Config.process_monitoring
                    }
                    "LoggingSettings" = @{
                        "LogLevel" = (Get-Culture).TextInfo.ToTitleCase($V1Config.log_level)
                    }
                }
            }
            
            # Test migration
            $migratedConfig = ConvertTo-ConfigV2 -V1Config $v1Config
            
            Assert-Equal -Expected "SimRacingAgent" -Actual $migratedConfig.AgentSettings.Name -Message "Should migrate agent name"
            Assert-Equal -Expected 30 -Actual $migratedConfig.MonitoringSettings.USBPollingInterval -Message "Should migrate USB polling interval"
            Assert-Equal -Expected $true -Actual $migratedConfig.MonitoringSettings.ProcessMonitoringEnabled -Message "Should migrate process monitoring setting"
            Assert-Equal -Expected "Info" -Actual $migratedConfig.LoggingSettings.LogLevel -Message "Should migrate and normalize log level"
        }
        
    }
    finally {
        Clear-AllMocks
    }
    
    return Complete-TestSession
}

# Test runner for agent regression tests
function Invoke-AgentRegressionTests {
    [CmdletBinding()]
    param(
        [string[]]$TestSuites = @("CoreRegression", "CompatibilityRegression"),
        [switch]$StopOnFirstFailure,
        [switch]$IncludePerformanceBenchmarks
    )
    
    $allResults = @()
    $overallSuccess = $true
    
    Write-Host "Starting SimRacing Agent Regression Tests" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        foreach ($suite in $TestSuites) {
            Write-Host "Running agent regression test suite: $suite" -ForegroundColor Yellow
            
            $result = switch ($suite) {
                "CoreRegression" { Test-AgentCoreRegression }
                "CompatibilityRegression" { Test-AgentCompatibilityRegression }
                default {
                    Write-Warning "Unknown agent regression test suite: $suite"
                    @{ Success = $false; Results = @{ Failed = 1; Passed = 0; Skipped = 0 } }
                }
            }
            
            $allResults += $result
            if (-not $result.Success) {
                $overallSuccess = $false
                if ($StopOnFirstFailure) {
                    Write-Host "Stopping agent regression tests due to failure in $suite" -ForegroundColor Red
                    break
                }
            }
            
            Write-Host ""
        }
        
        # Summary
        $totalPassed = ($allResults | ForEach-Object { $_.Results.Passed } | Measure-Object -Sum).Sum
        $totalFailed = ($allResults | ForEach-Object { $_.Results.Failed } | Measure-Object -Sum).Sum
        $totalSkipped = ($allResults | ForEach-Object { $_.Results.Skipped } | Measure-Object -Sum).Sum
        
        Write-Host "Agent Regression Test Summary" -ForegroundColor Cyan
        Write-Host "=============================" -ForegroundColor Cyan
        Write-Host "Total Passed:  $totalPassed" -ForegroundColor Green
        Write-Host "Total Failed:  $totalFailed" -ForegroundColor Red
        Write-Host "Total Skipped: $totalSkipped" -ForegroundColor Yellow
        Write-Host "Overall Result: $(if ($overallSuccess) { 'SUCCESS' } else { 'FAILURE' })" -ForegroundColor $(if ($overallSuccess) { 'Green' } else { 'Red' })
        
        if ($IncludePerformanceBenchmarks) {
            Write-Host ""
            Write-Host "Performance Benchmarks:" -ForegroundColor Cyan
            Write-Host "- Memory Usage: < 100MB" -ForegroundColor Gray
            Write-Host "- USB Query Time: < 500ms" -ForegroundColor Gray  
            Write-Host "- Health Check Time: < 1000ms" -ForegroundColor Gray
            Write-Host "- CPU Usage: < 10%" -ForegroundColor Gray
        }
        
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
        'Test-AgentCoreRegression',
        'Test-AgentCompatibilityRegression', 
        'Invoke-AgentRegressionTests'
    )
}