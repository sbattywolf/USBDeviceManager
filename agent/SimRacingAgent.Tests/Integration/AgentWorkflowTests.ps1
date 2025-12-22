#Requires -Version 5.1

<#
.SYNOPSIS
    Integration tests for SimRacing Agent workflow orchestration.

.DESCRIPTION
    Agent-specific integration tests that validate end-to-end workflows
    including health check orchestration, monitoring initialization, and
    agent state management across multiple components.
#>

# Import shared test framework
Import-Module "$PSScriptRoot\..\..\shared\TestFramework.psm1" -Force

# Import agent modules
$AgentPath = "$PSScriptRoot\..\..\..\agent"
Import-Module "$AgentPath\src\modules\ConfigManager.psm1" -Force
Import-Module "$AgentPath\src\modules\AgentCore.psm1" -Force
Import-Module "$AgentPath\src\modules\USBMonitor.psm1" -Force
Import-Module "$AgentPath\src\modules\ProcessManager.psm1" -Force

function Test-AgentHealthCheckWorkflow {
    [CmdletBinding()]
    param()
    
    Start-TestSession -SessionName "Agent Health Check Workflow Integration Tests"
    
    try {
        # Test 1: Complete health check orchestration
        Invoke-Test -Name "Agent health check workflow executes end-to-end" -Category "AgentWorkflow" -TestScript {
            # Mock all component health checks
            New-Mock -CommandName "Get-USBHealthCheck" -MockWith {
                return @{
                    DeviceCount = 5
                    HealthyDevices = 5
                    OverallHealth = 100
                    Timestamp = Get-Date
                }
            }
            
            New-Mock -CommandName "Get-ProcessHealthCheck" -MockWith {
                return @{
                    ProcessCount = 3
                    HealthyProcesses = 3
                    OverallHealth = 95
                    MemoryUsage = 150MB
                    Timestamp = Get-Date
                }
            }
            
            New-Mock -CommandName "Get-AgentConfiguration" -MockWith {
                return @{
                    AgentName = "SimRacingAgent"
                    HealthCheckInterval = 30
                    MonitoringEnabled = $true
                }
            }
            
            # Execute orchestrated health check
            $healthResult = Invoke-HealthCheckWorkflow
            
            Assert-NotNull -Value $healthResult -Message "Health check result should not be null"
            Assert-True -Condition ($healthResult.ContainsKey('OverallHealth')) -Message "Should include overall health score"
            Assert-True -Condition ($healthResult.ContainsKey('ComponentResults')) -Message "Should include component results"
            Assert-True -Condition ($healthResult.ContainsKey('Timestamp')) -Message "Should include timestamp"
            
            # Verify component integration
            Assert-MockCalled -CommandName "Get-USBHealthCheck" -Times 1 -Message "Should call USB health check"
            Assert-MockCalled -CommandName "Get-ProcessHealthCheck" -Times 1 -Message "Should call process health check"
            
            # Check aggregated health score
            Assert-True -Condition ($healthResult.OverallHealth -ge 90) -Message "Overall health should reflect component health"
        }
        
        # Test 2: Agent initialization workflow
        Invoke-Test -Name "Agent initialization workflow sets up all components" -Category "AgentWorkflow" -TestScript {
            # Mock configuration loading
            New-Mock -CommandName "Initialize-AgentConfiguration" -MockWith { return $true }
            New-Mock -CommandName "Get-AgentConfiguration" -MockWith {
                return @{
                    AgentName = "SimRacingAgent"
                    MonitoringEnabled = $true
                    USBPollingInterval = 15
                    ProcessMonitoringEnabled = $true
                    LogLevel = "Info"
                }
            }
            
            # Mock component initialization
            New-Mock -CommandName "Initialize-USBMonitoring" -MockWith { return $true }
            New-Mock -CommandName "Initialize-ProcessMonitoring" -MockWith { return $true }
            New-Mock -CommandName "Start-AgentLogging" -MockWith { return $true }
            
            # Execute initialization workflow
            $initResult = Initialize-AgentWorkflow
            
            Assert-True -Condition $initResult -Message "Agent initialization should succeed"
            
            # Verify initialization sequence
            Assert-MockCalled -CommandName "Initialize-AgentConfiguration" -Times 1 -Message "Should initialize configuration first"
            Assert-MockCalled -CommandName "Initialize-USBMonitoring" -Times 1 -Message "Should initialize USB monitoring"
            Assert-MockCalled -CommandName "Initialize-ProcessMonitoring" -Times 1 -Message "Should initialize process monitoring"
            Assert-MockCalled -CommandName "Start-AgentLogging" -Times 1 -Message "Should start logging"
        }
        
        # Test 3: Agent shutdown workflow
        Invoke-Test -Name "Agent shutdown workflow cleanly stops all components" -Category "AgentWorkflow" -TestScript {
            # Mock component cleanup
            New-Mock -CommandName "Stop-USBMonitoring" -MockWith { return $true }
            New-Mock -CommandName "Stop-ProcessMonitoring" -MockWith { return $true }
            New-Mock -CommandName "Stop-AgentLogging" -MockWith { return $true }
            New-Mock -CommandName "Save-AgentConfiguration" -MockWith { return $true }
            
            # Execute shutdown workflow
            $shutdownResult = Stop-AgentWorkflow
            
            Assert-True -Condition $shutdownResult -Message "Agent shutdown should succeed"
            
            # Verify cleanup sequence
            Assert-MockCalled -CommandName "Stop-USBMonitoring" -Times 1 -Message "Should stop USB monitoring"
            Assert-MockCalled -CommandName "Stop-ProcessMonitoring" -Times 1 -Message "Should stop process monitoring"
            Assert-MockCalled -CommandName "Save-AgentConfiguration" -Times 1 -Message "Should save configuration"
            Assert-MockCalled -CommandName "Stop-AgentLogging" -Times 1 -Message "Should stop logging last"
        }
        
        # Test 4: Agent error recovery workflow
        Invoke-Test -Name "Agent handles component failures gracefully" -Category "AgentWorkflow" -TestScript {
            # Mock component failure
            New-Mock -CommandName "Get-USBHealthCheck" -MockWith {
                throw "USB monitoring service unavailable"
            }
            
            New-Mock -CommandName "Get-ProcessHealthCheck" -MockWith {
                return @{
                    ProcessCount = 2
                    HealthyProcesses = 2
                    OverallHealth = 90
                }
            }
            
            New-Mock -CommandName "Write-AgentLog" -MockWith { }
            
            # Execute health check with component failure
            $healthResult = Invoke-HealthCheckWorkflow
            
            Assert-NotNull -Value $healthResult -Message "Should return result despite component failure"
            Assert-True -Condition ($healthResult.ContainsKey('ComponentErrors')) -Message "Should report component errors"
            Assert-True -Condition ($healthResult.OverallHealth -lt 100) -Message "Overall health should reflect component failure"
            
            # Verify error logging
            Assert-MockCalled -CommandName "Write-AgentLog" -Message "Should log component failures"
        }
        
        # Test 5: Configuration change workflow
        Invoke-Test -Name "Agent handles configuration changes dynamically" -Category "AgentWorkflow" -TestScript {
            # Mock configuration update
            $originalConfig = @{
                USBPollingInterval = 30
                ProcessMonitoringEnabled = $true
                LogLevel = "Info"
            }
            
            $updatedConfig = @{
                USBPollingInterval = 15
                ProcessMonitoringEnabled = $false
                LogLevel = "Debug"
            }
            
            New-Mock -CommandName "Get-AgentConfiguration" -MockWith { return $originalConfig } -Verifiable
            New-Mock -CommandName "Set-AgentConfiguration" -MockWith { return $true }
            New-Mock -CommandName "Restart-USBMonitoring" -MockWith { return $true }
            New-Mock -CommandName "Stop-ProcessMonitoring" -MockWith { return $true }
            New-Mock -CommandName "Set-LoggingLevel" -MockWith { return $true }
            
            # Execute configuration update workflow
            $updateResult = Update-AgentConfiguration -NewConfiguration $updatedConfig
            
            Assert-True -Condition $updateResult -Message "Configuration update should succeed"
            
            # Verify component reconfiguration
            Assert-MockCalled -CommandName "Restart-USBMonitoring" -Times 1 -Message "Should restart USB monitoring with new interval"
            Assert-MockCalled -CommandName "Stop-ProcessMonitoring" -Times 1 -Message "Should stop process monitoring when disabled"
            Assert-MockCalled -CommandName "Set-LoggingLevel" -Times 1 -Message "Should update logging level"
        }
        
    }
    finally {
        Clear-AllMocks
    }
    
    return Complete-TestSession
}

function Test-AgentMonitoringIntegration {
    [CmdletBinding()]
    param()
    
    Start-TestSession -SessionName "Agent Monitoring Integration Tests"
    
    try {
        # Test 1: USB and Process monitoring coordination
        Invoke-Test -Name "USB and Process monitors coordinate data collection" -Category "MonitoringIntegration" -TestScript {
            # Setup shared monitoring state
            New-Mock -CommandName "Get-USBDevices" -MockWith {
                return @(
                    @{ DeviceID = "USB1"; Status = "OK"; Description = "Racing Wheel" },
                    @{ DeviceID = "USB2"; Status = "OK"; Description = "Pedal Set" }
                )
            }
            
            New-Mock -CommandName "Get-Process" -MockWith {
                return @(
                    @{ ProcessName = "SimApp"; WorkingSet = 500MB; CPU = 25.0; Responding = $true }
                )
            }
            
            # Execute coordinated monitoring
            $monitoringData = Get-CoordinatedMonitoringData
            
            Assert-NotNull -Value $monitoringData -Message "Coordinated data should not be null"
            Assert-True -Condition ($monitoringData.ContainsKey('USBData')) -Message "Should include USB data"
            Assert-True -Condition ($monitoringData.ContainsKey('ProcessData')) -Message "Should include process data"
            Assert-True -Condition ($monitoringData.ContainsKey('CorrelatedMetrics')) -Message "Should include correlated metrics"
            
            # Verify data correlation
            Assert-Equal -Expected 2 -Actual $monitoringData.USBData.DeviceCount -Message "Should capture USB device count"
            Assert-Equal -Expected 1 -Actual $monitoringData.ProcessData.ProcessCount -Message "Should capture process count"
        }
        
        # Test 2: Real-time monitoring event handling
        Invoke-Test -Name "Agent handles real-time monitoring events across components" -Category "MonitoringIntegration" -TestScript {
            # Mock event registration
            New-Mock -CommandName "Register-EngineEvent" -MockWith {
                return @{ Id = [System.Random]::new().Next(1000, 9999) }
            }
            
            New-Mock -CommandName "Unregister-Event" -MockWith { }
            
            # Setup monitoring events
            $eventHandlers = Initialize-MonitoringEvents
            
            Assert-NotNull -Value $eventHandlers -Message "Event handlers should be initialized"
            Assert-True -Condition ($eventHandlers.Count -gt 0) -Message "Should register monitoring events"
            
            # Simulate USB device change event
            $usbEvent = @{
                EventType = "DeviceChange"
                DeviceID = "USB\\VID_046D\\PID_C294"
                Action = "Connected"
                Timestamp = Get-Date
            }
            
            # Process event through agent
            $eventResult = Process-MonitoringEvent -Event $usbEvent
            
            Assert-True -Condition $eventResult -Message "Event processing should succeed"
            
            # Verify cross-component notification
            Assert-MockCalled -CommandName "Register-EngineEvent" -Message "Should register for monitoring events"
        }
        
        # Test 3: Multi-component health aggregation
        Invoke-Test -Name "Agent aggregates health across all monitoring components" -Category "MonitoringIntegration" -TestScript {
            # Setup component health data
            New-Mock -CommandName "Get-USBHealthCheck" -MockWith {
                return @{
                    OverallHealth = 85
                    ComponentWeight = 0.4
                    CriticalIssues = @()
                }
            }
            
            New-Mock -CommandName "Get-ProcessHealthCheck" -MockWith {
                return @{
                    OverallHealth = 92
                    ComponentWeight = 0.3
                    CriticalIssues = @()
                }
            }
            
            New-Mock -CommandName "Get-SystemHealthCheck" -MockWith {
                return @{
                    OverallHealth = 88
                    ComponentWeight = 0.3
                    CriticalIssues = @("High memory usage")
                }
            }
            
            # Calculate aggregated health
            $aggregatedHealth = Get-AggregatedHealthScore
            
            Assert-NotNull -Value $aggregatedHealth -Message "Aggregated health should not be null"
            Assert-True -Condition ($aggregatedHealth.OverallScore -ge 0 -and $aggregatedHealth.OverallScore -le 100) -Message "Overall score should be 0-100"
            
            # Verify weighted calculation: (85*0.4 + 92*0.3 + 88*0.3) = 88.2
            $expectedScore = (85 * 0.4) + (92 * 0.3) + (88 * 0.3)
            Assert-True -Condition (Math.Abs($aggregatedHealth.OverallScore - $expectedScore) -lt 1) -Message "Should calculate weighted health score correctly"
            
            Assert-True -Condition ($aggregatedHealth.ContainsKey('CriticalIssues')) -Message "Should aggregate critical issues"
            Assert-Equal -Expected 1 -Actual $aggregatedHealth.CriticalIssues.Count -Message "Should include system critical issues"
        }
        
        # Test 4: Performance monitoring integration
        Invoke-Test -Name "Agent tracks performance across monitoring components" -Category "MonitoringIntegration" -TestScript {
            # Mock performance counters
            New-Mock -CommandName "Get-PerformanceCounter" -MockWith {
                param($CounterPath)
                switch ($CounterPath) {
                    "\\Memory\\Available MBytes" { return 4096 }
                    "\\Processor(_Total)\\% Processor Time" { return 25.5 }
                    default { return 0 }
                }
            }
            
            New-Mock -CommandName "Measure-Command" -MockWith {
                return New-Object TimeSpan(0, 0, 0, 0, 150)  # 150ms
            }
            
            # Collect performance metrics
            $perfData = Get-MonitoringPerformanceMetrics
            
            Assert-NotNull -Value $perfData -Message "Performance data should not be null"
            Assert-True -Condition ($perfData.ContainsKey('SystemMetrics')) -Message "Should include system metrics"
            Assert-True -Condition ($perfData.ContainsKey('MonitoringOverhead')) -Message "Should include monitoring overhead"
            
            # Verify performance impact tracking
            Assert-True -Condition ($perfData.MonitoringOverhead.TotalExecutionTime -gt 0) -Message "Should track execution time"
            Assert-True -Condition ($perfData.SystemMetrics.AvailableMemoryMB -gt 0) -Message "Should track available memory"
        }
        
        # Test 5: Agent state synchronization
        Invoke-Test -Name "Agent maintains consistent state across components" -Category "MonitoringIntegration" -TestScript {
            # Mock state management
            $agentState = @{
                Status = "Running"
                MonitoringActive = $true
                LastHealthCheck = Get-Date
                ComponentStates = @{}
            }
            
            New-Mock -CommandName "Get-AgentState" -MockWith { return $agentState }
            New-Mock -CommandName "Set-AgentState" -MockWith { 
                param($NewState)
                $script:agentState = $NewState  # Use script scope to persist changes
                return $true 
            }
            
            # Update component states
            $componentUpdates = @{
                USBMonitor = @{ Status = "Active"; LastUpdate = Get-Date }
                ProcessManager = @{ Status = "Active"; LastUpdate = Get-Date }
            }
            
            $syncResult = Sync-ComponentStates -ComponentStates $componentUpdates
            
            Assert-True -Condition $syncResult -Message "State synchronization should succeed"
            
            # Verify state consistency
            $currentState = Get-AgentState
            Assert-True -Condition ($currentState.ComponentStates.ContainsKey('USBMonitor')) -Message "Should include USB monitor state"
            Assert-True -Condition ($currentState.ComponentStates.ContainsKey('ProcessManager')) -Message "Should include process manager state"
            
            # Verify timestamps are recent
            $usbTimestamp = $currentState.ComponentStates.USBMonitor.LastUpdate
            Assert-True -Condition ((Get-Date) - $usbTimestamp).TotalSeconds -lt 5 -Message "USB monitor timestamp should be recent"
        }
        
    }
    finally {
        Clear-AllMocks
    }
    
    return Complete-TestSession
}

# Test runner for agent integration tests
function Invoke-AgentIntegrationTests {
    [CmdletBinding()]
    param(
        [string[]]$TestSuites = @("HealthCheckWorkflow", "MonitoringIntegration"),
        [switch]$StopOnFirstFailure
    )
    
    $allResults = @()
    $overallSuccess = $true
    
    Write-Host "Starting SimRacing Agent Integration Tests" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        foreach ($suite in $TestSuites) {
            Write-Host "Running agent integration test suite: $suite" -ForegroundColor Yellow
            
            $result = switch ($suite) {
                "HealthCheckWorkflow" { Test-AgentHealthCheckWorkflow }
                "MonitoringIntegration" { Test-AgentMonitoringIntegration }
                default {
                    Write-Warning "Unknown agent integration test suite: $suite"
                    @{ Success = $false; Results = @{ Failed = 1; Passed = 0; Skipped = 0 } }
                }
            }
            
            $allResults += $result
            if (-not $result.Success) {
                $overallSuccess = $false
                if ($StopOnFirstFailure) {
                    Write-Host "Stopping agent integration tests due to failure in $suite" -ForegroundColor Red
                    break
                }
            }
            
            Write-Host ""
        }
        
        # Summary
        $totalPassed = ($allResults | ForEach-Object { $_.Results.Passed } | Measure-Object -Sum).Sum
        $totalFailed = ($allResults | ForEach-Object { $_.Results.Failed } | Measure-Object -Sum).Sum
        $totalSkipped = ($allResults | ForEach-Object { $_.Results.Skipped } | Measure-Object -Sum).Sum
        
        Write-Host "Agent Integration Test Summary" -ForegroundColor Cyan
        Write-Host "==============================" -ForegroundColor Cyan
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
        'Test-AgentHealthCheckWorkflow',
        'Test-AgentMonitoringIntegration',
        'Invoke-AgentIntegrationTests'
    )
}