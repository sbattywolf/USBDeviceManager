#Requires -Version 5.1

<#
.SYNOPSIS
  Additional unit tests for device normalization and software lifecycle.
#>

# Import shared test framework
Import-Module "$PSScriptRoot\..\..\shared\TestFramework.psm1" -Force

# Import modules under test (use src adapter modules)
$AgentPath = "$PSScriptRoot\..\..\..\agent"
Import-Module "$AgentPath\src\modules\USBMonitor.psm1" -Force -ErrorAction SilentlyContinue
Import-Module "$AgentPath\src\modules\ProcessManager.psm1" -Force -ErrorAction SilentlyContinue

function Test-DeviceNormalization {
    [CmdletBinding()]
    param()

    Start-TestSession -SessionName "Device Normalization Tests"

    try {
        Invoke-Test -Name "Get-USBDevices normalizes varied WMI shapes" -Category "USBMonitor" -TestScript {
            New-Mock -CommandName "Get-WmiObject" -MockWith {
                return @(
                    @{ DeviceID = "USB\\VID_1234&PID_0001\\AAA"; Name = "Device A"; Status = "OK"; PNPClass = "HIDClass" },
                    @{ DeviceId = "USB\\VID_2345&PID_0002\\BBB"; Description = "Device B"; Status = "OK"; PNPClass = "USB" },
                    @{ DeviceID = $null; Description = "Non-USB Device"; Status = "OK"; PNPClass = "System" }
                )
            } -ParameterFilter @{ Class = "Win32_PnPEntity" }

            $devices = Get-USBDevices
            Assert-NotNull -Value $devices -Message "Device list should not be null"
            Assert-Equal -Expected 2 -Actual $devices.Count -Message "Should return only USB devices"
            Assert-True -Condition ($devices[0].DeviceID -like 'USB\\*' -or $devices[1].DeviceID -like 'USB\\*') -Message "DeviceID should be normalized and present"
        }
    }
    finally { Clear-AllMocks }

    return Complete-TestSession
}

function Test-SoftwareStartStop {
    [CmdletBinding()]
    param()

    Start-TestSession -SessionName "Software Start/Stop Tests"

    try {
        Invoke-Test -Name "Start-ManagedProcess uses Start-Process mock when provided" -Category "ProcessManager" -TestScript {
            # Ensure Test-Path returns false to test mock behavior
            New-Mock -CommandName "Test-Path" -MockWith { return $false } -ParameterFilter @{ Path = 'C:\test\app.exe' }
            New-Mock -CommandName "Start-Process" -MockWith { return @{ Id = 4242; ProcessName = 'TestApp' } }

            $result = Start-ManagedProcess -Name 'TestApp' -ExecutablePath 'C:\test\app.exe'
            Assert-True -Condition $result -Message "Start-ManagedProcess should succeed when Start-Process mock is provided"
        }

        Invoke-Test -Name "Start-ManagedProcess returns false when path missing and no Start-Process mock" -Category "ProcessManager" -TestScript {
            Clear-AllMocks
            New-Mock -CommandName "Test-Path" -MockWith { return $false } -ParameterFilter @{ Path = 'C:\nonexistent\app.exe' }
            $result = Start-ManagedProcess -Name 'MissingApp' -ExecutablePath 'C:\nonexistent\app.exe'
            Assert-False -Condition $result -Message "Should not start when executable missing and no mock"
        }
    }
    finally { Clear-AllMocks }

    return Complete-TestSession
}

function Invoke-ExtraAgentTests {
    [CmdletBinding()]
    param()

    $res1 = Test-DeviceNormalization
    $res2 = Test-SoftwareStartStop

    $passed = $res1.Summary.Passed + $res2.Summary.Passed
    $failed = $res1.Summary.Failed + $res2.Summary.Failed

    return @{ Success = ($failed -eq 0); Results = @($res1, $res2); Summary = @{ Passed = $passed; Failed = $failed; Skipped = 0 } }
}

# Export when used as module
try { Export-ModuleMember -Function @('Invoke-ExtraAgentTests','Test-DeviceNormalization','Test-SoftwareStartStop') } catch {}
