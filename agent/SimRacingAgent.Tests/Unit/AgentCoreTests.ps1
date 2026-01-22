#Requires -Version 5.1

<#
.SYNOPSIS
    Unit tests for SimRacing Agent core functionality.

.DESCRIPTION
    Agent-specific unit tests covering ConfigManager and AgentCore modules.
    These tests focus on agent internals without external dependencies.
#>

# Import shared test framework
Import-Module "$PSScriptRoot\..\..\shared\TestFramework.psm1" -Force

# Import agent modules
$AgentPath = "$PSScriptRoot\..\..\..\agent"
Import-Module "$AgentPath\src\core\ConfigManager.psm1" -Force
Import-Module "$AgentPath\src\core\AgentCore.psm1" -Force

function Test-AgentConfigManager {
    [CmdletBinding()]
    param()

    Start-TestSession -SessionName "Agent ConfigManager Unit Tests"

    try {
        # Test 1: Default configuration initialization
        Invoke-Test -Name "Get-DefaultConfiguration returns valid agent config" -Category "ConfigManager" -TestScript {
            $config = Get-DefaultConfiguration

            Assert-NotNull -Value $config -Message "Configuration should not be null"
            Assert-True -Condition ($config.ContainsKey('Agent')) -Message "Config should contain Agent section"
            Assert-Equal -Expected "SimRacingAgent" -Actual $config.Agent.Name -Message "Agent name should be SimRacingAgent"
            Assert-True -Condition ($config.Agent.DataPath.Contains("SimRacingAgent")) -Message "Data path should reference SimRacingAgent"
        }

        # Test 2: Configuration validation
        Invoke-Test -Name "Test-Configuration validates agent settings correctly" -Category "ConfigManager" -TestScript {
            $validConfig = Get-DefaultConfiguration
            $isValid = Test-Configuration -Config $validConfig
            Assert-True -Condition $isValid -Message "Default configuration should be valid"

            # Test invalid configuration
            $invalidConfig = @{ InvalidSection = "test" }
            $isInvalid = Test-Configuration -Config $invalidConfig
            Assert-False -Condition $isInvalid -Message "Invalid configuration should fail validation"
        }

        # Test 3: Configuration file operations
        Invoke-Test -Name "Save-Configuration and Load-Configuration work for agent" -Category "ConfigManager" -TestScript {
            $tempPath = Join-Path $env:TEMP "agent_config_test.json"
            $config = Get-DefaultConfiguration
            $config.Agent.Name = "TestAgent"

            $saved = Save-Configuration -Config $config -Path $tempPath
            Assert-True -Condition $saved -Message "Configuration should be saved successfully"
            Assert-PathExists -Path $tempPath -Message "Config file should be created"

            $loaded = Load-Configuration -Path $tempPath
            Assert-Equal -Expected "TestAgent" -Actual $loaded.Agent.Name -Message "Loaded config should match saved data"
        } -Teardown {
            $tempPath = Join-Path $env:TEMP "agent_config_test.json"
            if (Test-Path $tempPath) { Remove-Item $tempPath -Force }
        }

        # Test 4: Agent-specific configuration paths
        Invoke-Test -Name "Configuration paths are agent-specific" -Category "ConfigManager" -TestScript {
            $config = Get-DefaultConfiguration

            Assert-True -Condition ($config.Agent.DataPath -like "*SimRacingAgent*") -Message "Data path should be agent-specific"
            Assert-True -Condition ($config.Logging.LogFilePath -like "*SimRacingAgent*") -Message "Log path should be agent-specific"
        }

        # Test 5: Configuration export with agent naming
        Invoke-Test -Name "Export-Configuration uses agent naming" -Category "ConfigManager" -TestScript {
            $config = Get-DefaultConfiguration
            $exportResult = Export-Configuration -Config $config

            Assert-NotNull -Value $exportResult -Message "Export should return result"
            Assert-True -Condition ($exportResult.FileName -like "*SimRacingAgent*") -Message "Export filename should include agent name"
        }

    }
    finally {
        Clear-AllMocks
    }

    return Complete-TestSession
}

function Test-AgentCore {
    [CmdletBinding()]
    param()

    Start-TestSession -SessionName "Agent Core Unit Tests"

    try {
        # Test 1: Agent instance management
        Invoke-Test -Name "Test-AgentRunning detects agent instances correctly" -Category "AgentCore" -TestScript {
            # Mock no running processes
            New-Mock -CommandName "Get-Process" -MockWith { return @() }

            $isRunning = Test-AgentRunning
            Assert-False -Condition $isRunning -Message "Should return false when no agent is running"

            Assert-MockCalled -CommandName "Get-Process" -Times 1
        }

        # Test 2: Agent lock file operations
        Invoke-Test -Name "Set-AgentLock creates lock file with correct data" -Category "AgentCore" -TestScript {
            $tempLockPath = Join-Path $env:TEMP "test_agent.lock"

            # Mock global variable
            $script:originalLockFile = $Global:AgentLockFile
            $Global:AgentLockFile = $tempLockPath

            $result = Set-AgentLock
            Assert-True -Condition $result -Message "Lock should be created successfully"
            Assert-PathExists -Path $tempLockPath -Message "Lock file should exist"

            $lockData = Get-Content $tempLockPath -Raw | ConvertFrom-Json
            Assert-Equal -Expected $PID -Actual $lockData.ProcessId -Message "Lock should contain current process ID"
            Assert-NotNull -Value $lockData.Timestamp -Message "Lock should contain timestamp"
        } -Teardown {
            $tempLockPath = Join-Path $env:TEMP "test_agent.lock"
            if (Test-Path $tempLockPath) { Remove-Item $tempLockPath -Force }
            if ($script:originalLockFile) { $Global:AgentLockFile = $script:originalLockFile }
        }

        # Test 3: Agent logging functionality
        Invoke-Test -Name "Write-AgentLog writes agent-specific logs" -Category "AgentCore" -TestScript {
            $tempLogPath = Join-Path $env:TEMP "test_agent.log"

            Write-AgentLog -Message "Test agent message" -Level "Info" -Component "Test" -LogPath $tempLogPath

            Assert-PathExists -Path $tempLogPath -Message "Log file should be created"
            $logContent = Get-Content $tempLogPath -Raw
            Assert-Contains -Collection $logContent -Item "Test agent message" -Message "Log should contain test message"
            Assert-Contains -Collection $logContent -Item "[Info]" -Message "Log should contain info level"
            Assert-Contains -Collection $logContent -Item "[Test]" -Message "Log should contain component name"
        } -Teardown {
            $tempLogPath = Join-Path $env:TEMP "test_agent.log"
            if (Test-Path $tempLogPath) { Remove-Item $tempLogPath -Force }
        }

        # Test 4: Agent status collection
        Invoke-Test -Name "Get-AgentStatus provides comprehensive agent information" -Category "AgentCore" -TestScript {
            $config = Get-DefaultConfiguration

            # Mock dependencies
            New-Mock -CommandName "Test-Path" -MockWith { $true }
            New-Mock -CommandName "Get-Process" -MockWith {
                return @(@{
                    ProcessName = "powershell"
                    WorkingSet = 50MB
                    Id = $PID
                })
            }

            $status = Get-AgentStatus -Config $config

            Assert-NotNull -Value $status -Message "Status should not be null"
            Assert-True -Condition ($status.ContainsKey('AgentRunning')) -Message "Status should include agent running state"
            Assert-True -Condition ($status.ContainsKey('ConfigValid')) -Message "Status should include config validation"
            Assert-True -Condition ($status.ContainsKey('MemoryUsage')) -Message "Status should include memory usage"
        }

        # Test 5: Agent cleanup operations
        Invoke-Test -Name "Clear-AgentLock removes lock file properly" -Category "AgentCore" -TestScript {
            $tempLockPath = Join-Path $env:TEMP "test_cleanup.lock"

            # Create test lock file
            @{ ProcessId = $PID; Timestamp = (Get-Date).ToString() } | ConvertTo-Json | Out-File $tempLockPath
            Assert-PathExists -Path $tempLockPath -Message "Test lock file should exist"

            # Mock global variable
            $script:originalLockFile = $Global:AgentLockFile
            $Global:AgentLockFile = $tempLockPath

            $result = Clear-AgentLock
            Assert-True -Condition $result -Message "Lock cleanup should succeed"
            Assert-False -Condition (Test-Path $tempLockPath) -Message "Lock file should be removed"
        } -Teardown {
            $tempLockPath = Join-Path $env:TEMP "test_cleanup.lock"
            if (Test-Path $tempLockPath) { Remove-Item $tempLockPath -Force }
            if ($script:originalLockFile) { $Global:AgentLockFile = $script:originalLockFile }
        }

        # Test 6: Single-instance enforcement via named mutex
        Invoke-Test -Name "Agent single-instance prevents second process" -Category "AgentCore" -TestScript {
            # Create a named mutex that simulates a running agent
            $mutexName = "Global\SimRacingAgent_$($env:COMPUTERNAME)"
            $created = $false
            $ownerMutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$created)

            try {
                # Attempt to start a new agent process which should fail due to mutex
                $agentScript = Join-Path $AgentPath 'SimRacingAgent\SimRacingAgent.ps1'

                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = 'powershell.exe'
                $psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $agentScript + '" -DashboardUrl "http://localhost:5000"'
                $psi.UseShellExecute = $false
                $psi.RedirectStandardOutput = $true
                $psi.RedirectStandardError = $true
                $psi.CreateNoWindow = $true

                $proc = New-Object System.Diagnostics.Process
                $proc.StartInfo = $psi
                $proc.Start() | Out-Null
                $proc.WaitForExit(5000) # Wait up to 5s

                # When mutex is held, agent should exit non-zero
                $exit = $proc.ExitCode
                Assert-True -Condition ($exit -ne 0) -Message "Agent should exit with non-zero when mutex already exists (ExitCode: $exit)"
            }
            finally {
                try { $ownerMutex.ReleaseMutex(); $ownerMutex.Close() } catch {}
            }
        }

    }
    finally {
        Clear-AllMocks
    }

    return Complete-TestSession
}

# Test runner for agent core tests
function Invoke-AgentCoreTests {
    [CmdletBinding()]
    param(
        [string[]]$TestSuites = @("ConfigManager", "AgentCore"),
        [switch]$StopOnFirstFailure
    )

    $allResults = @()
    $overallSuccess = $true

    Write-Output "Starting SimRacing Agent Core Unit Tests"
    Write-Output "======================================="
    Write-Output ""

    try {
        foreach ($suite in $TestSuites) {
            Write-Output "Running agent test suite: $suite"

            $result = switch ($suite) {
                "ConfigManager" { Test-AgentConfigManager }
                "AgentCore" { Test-AgentCore }
                "Extra" { Invoke-ExtraAgentTests }
                default {
                    Write-Warning "Unknown agent test suite: $suite"
                    @{ Success = $false; Results = @{ Failed = 1; Passed = 0; Skipped = 0 } }
                }
            }

            $allResults += $result
            if (-not $result.Success) {
                $overallSuccess = $false
                if ($StopOnFirstFailure) {
                    Write-Error "Stopping agent tests due to failure in $suite"
                    break
                }
            }

            Write-Output ""
        }

        # Summary
        $totalPassed = ($allResults | ForEach-Object { $_.Results.Passed } | Measure-Object -Sum).Sum
        $totalFailed = ($allResults | ForEach-Object { $_.Results.Failed } | Measure-Object -Sum).Sum
        $totalSkipped = ($allResults | ForEach-Object { $_.Results.Skipped } | Measure-Object -Sum).Sum

        Write-Output "Agent Core Test Summary"
        Write-Output "======================"
        Write-Output "Total Passed:  $totalPassed"
        Write-Output "Total Failed:  $totalFailed"
        Write-Output "Total Skipped: $totalSkipped"
        Write-Output "Overall Result: $(if ($overallSuccess) { 'SUCCESS' } else { 'FAILURE' })"

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

# Attempt to export functions when run as a module; ignore when dot-sourced
try {
    Export-ModuleMember -Function @(
        'Test-AgentConfigManager',
        'Test-AgentCore',
        'Invoke-AgentCoreTests'
    )
} catch {
    # Export-ModuleMember throws when executed in script scope (dot-sourced); ignore
}



