# SimRacing Agent Automated Integration Tests
# Tests for health alert suppression and interactive mode functionality

param(
    [switch]$NoCleanup,
    [int]$TimeoutSeconds = 60,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

# Ensure a logs directory and a reproducible log file for CI capture
$logDir = Join-Path $PSScriptRoot 'logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$Global:TestLogFile = Join-Path $logDir 'integration-run-latest.log'
try { Remove-Item $Global:TestLogFile -ErrorAction SilentlyContinue } catch { }
'' | Out-File -FilePath $Global:TestLogFile -Encoding utf8

# Test configuration
$TestConfig = @{
    AgentPath = "agent\SimRacingAgent\SimRacingAgent.ps1"
    DashboardPath = "Helpers/test-dashboard-server.ps1"
    Port = 5000
    TestDuration = 30 # seconds
}

# Test utilities
function Write-TestLog {
    param($Message, $Level = "Info")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "Info" { "White" }
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
    }
    $line = "[$timestamp] [$Level] $Message"
    Write-Output $line
    try { Add-Content -Path $Global:TestLogFile -Value $line -Encoding utf8 } catch { }
}

function Resolve-WorkspacePath {
    param([string]$RelativePath)
    try {
        # Prefer direct path checks to avoid host-specific Resolve-Path parsing issues
        $workspaceRoot = Join-Path $PSScriptRoot '..\..\..'
        if (Test-Path $workspaceRoot) { $workspaceRoot = (Get-Item -LiteralPath $workspaceRoot -ErrorAction SilentlyContinue).FullName } else { $workspaceRoot = (Join-Path $PSScriptRoot '..\..\..') }

        $candidate = Join-Path $workspaceRoot $RelativePath
        if (Test-Path $candidate) { return (Get-Item -LiteralPath $candidate -ErrorAction SilentlyContinue).FullName }
        if (Test-Path $RelativePath) { return (Get-Item -LiteralPath $RelativePath -ErrorAction SilentlyContinue).FullName }
        return $null
    } catch { return $null }
}

function Start-TestProcess {
    param(
        [string]$FilePath,
        [string]$Arguments = "",
        [string]$TestName
    )
    try {
        # Resolve file path relative to workspace when needed
        $resolved = Resolve-WorkspacePath -RelativePath $FilePath
        if ($resolved) { $FilePath = $resolved }

        $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processStartInfo.FileName = "powershell.exe"
        $processStartInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$FilePath`" $Arguments"
        $processStartInfo.UseShellExecute = $false
        $processStartInfo.RedirectStandardOutput = $true
        $processStartInfo.RedirectStandardError = $true
        $processStartInfo.RedirectStandardInput = $false
        $processStartInfo.CreateNoWindow = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processStartInfo
        $started = $process.Start()

        # Create concurrent queues for async capture
        $stdoutQueue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[System.String]'
        $stderrQueue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[System.String]'

        # Register events to capture output lines
        $outSub = Register-ObjectEvent -InputObject $process -EventName 'OutputDataReceived' -Action {
            if ($EventArgs.Data) { $stdoutQueue.Enqueue($EventArgs.Data) }
        }
        $errSub = Register-ObjectEvent -InputObject $process -EventName 'ErrorDataReceived' -Action {
            if ($EventArgs.Data) { $stderrQueue.Enqueue($EventArgs.Data) }
        }

        # Begin async reads
        $process.BeginOutputReadLine()
        $process.BeginErrorReadLine()

        Write-TestLog (("Started {0} process (PID: {1})" -f $TestName, $process.Id)) "Success"

        return @{ Process = $process; OutQueue = $stdoutQueue; ErrQueue = $stderrQueue; OutSub = $outSub; ErrSub = $errSub }
    }
    catch {
        Write-TestLog (("Failed to start {0} process: {1}" -f $TestName, $_.Exception.Message)) "Error"
        throw
    }
}

function Test-HealthAlertSuppression {
    Write-TestLog "Testing health alert suppression..." "Info"

    # Start dashboard server
    $dashboardProcess = Start-TestProcess -FilePath $TestConfig.DashboardPath -Arguments "-Port $($TestConfig.Port)" -TestName "Dashboard Server"

    try {
        Start-Sleep -Seconds 3 # Allow dashboard to start

        # Start agent
        $agentProcess = Start-TestProcess -FilePath $TestConfig.AgentPath -Arguments "-LogLevel Info" -TestName "SimRacing Agent"

        try {
            # Monitor agent output for health alerts
            $alertsFound = $false
            $startTime = Get-Date
            $output = ""

            while ((Get-Date) -lt $startTime.AddSeconds($TestConfig.TestDuration)) {
                if (-not $agentProcess.Process.HasExited) {
                    try {
                        $line = $null
                        while ($agentProcess.OutQueue.TryDequeue([ref]$line)) {
                            if ($line) {
                                $output += $line + "`n"
                                if ($line -match "CRITICAL HEALTH ALERT") {
                                    $alertsFound = $true
                                    Write-TestLog "❌ CRITICAL HEALTH ALERT found in agent output" "Error"
                                    break
                                }
                            }
                        }
                        if ($alertsFound) { break }
                    }
                    catch {
                        # Continue monitoring
                    }
                }
                Start-Sleep -Seconds 1
            }

            if (-not $alertsFound) {
                Write-TestLog "✅ No health alerts found - suppression working correctly" "Success"
                return $true
            } else {
                Write-TestLog "❌ Health alerts still present despite suppression" "Error"
                return $false
            }
        }
        finally {
            try {
                if ($agentProcess -and $agentProcess.Process -and -not $agentProcess.Process.HasExited) {
                    $agentProcess.Process.Kill()
                    $agentProcess.Process.WaitForExit(5000)
                }
            } catch { }
            try { Unregister-Event -SubscriptionId $agentProcess.OutSub.Id -ErrorAction SilentlyContinue } catch { }
            try { Unregister-Event -SubscriptionId $agentProcess.ErrSub.Id -ErrorAction SilentlyContinue } catch { }
        }
    }
    finally {
        try {
            if ($dashboardProcess -and $dashboardProcess.Process -and -not $dashboardProcess.Process.HasExited) {
                $dashboardProcess.Process.Kill()
                $dashboardProcess.Process.WaitForExit(5000)
            }
        } catch { }
        try { Unregister-Event -SubscriptionId $dashboardProcess.OutSub.Id -ErrorAction SilentlyContinue } catch { }
        try { Unregister-Event -SubscriptionId $dashboardProcess.ErrSub.Id -ErrorAction SilentlyContinue } catch { }
    }
}

function Test-InteractiveMode {
    Write-TestLog "Testing interactive mode functionality..." "Info"

    # Start dashboard server
    $dashboardProcess = Start-TestProcess -FilePath $TestConfig.DashboardPath -Arguments "-Port $($TestConfig.Port)" -TestName "Dashboard Server"

    try {
        Start-Sleep -Seconds 3

        # Start agent with explicit output redirection to files so we can reliably capture logs
        # Resolve workspace root robustly
        $candidateRoot = Join-Path $PSScriptRoot '..\..\..'
        if (Test-Path $candidateRoot) { $workspaceRoot = (Get-Item -LiteralPath $candidateRoot -ErrorAction SilentlyContinue).FullName } else { $workspaceRoot = $candidateRoot }

        $fullAgentCandidate = Join-Path $workspaceRoot $TestConfig.AgentPath
        if (Test-Path $fullAgentCandidate) { $fullAgentPath = (Get-Item -LiteralPath $fullAgentCandidate -ErrorAction SilentlyContinue).FullName } else { $fullAgentPath = $fullAgentCandidate }
        $outFile = Join-Path $logDir 'agent-interactive-out.txt'
        $errFile = Join-Path $logDir 'agent-interactive-err.txt'

        # Remove old files
        try { Remove-Item -Path $outFile -ErrorAction SilentlyContinue } catch { }
        try { Remove-Item -Path $errFile -ErrorAction SilentlyContinue } catch { }

        $psCmd = "& { & '$fullAgentPath' -LogLevel Info *> '$outFile' 2> '$errFile' }"
        $agentProcess = Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-Command",$psCmd) -PassThru

        try {
            $start = Get-Date
            $timeout = [TimeSpan]::FromSeconds(30)
            $found = $false
            while ((Get-Date) -lt $start.Add($timeout)) {
                Start-Sleep -Seconds 1
                if (Test-Path $outFile) {
                    try { $content = Get-Content -Path $outFile -Raw -ErrorAction SilentlyContinue } catch { $content = "" }
                    if ($content -and $content -match "SimRacing Agent Interactive Mode") {
                        $found = $true
                        break
                    }
                    if ($content -and ($content -match "\[Error\]")) {
                        Write-TestLog ("Agent emitted error during interactive startup: {0}" -f $Matches[0]) "Error"
                        break
                    }
                }
            }

            if ($found) {
                Write-TestLog ("✅ Interactive mode test passed - agent wrote interactive marker to {0}" -f $outFile) "Success"
                return $true
            } else {
                Write-TestLog "❌ Interactive mode issues detected (no interactive marker in output)" "Error"
                return $false
            }
        }
        finally {
            try { if ($agentProcess -and -not $agentProcess.HasExited) { $agentProcess.Kill(); $agentProcess.WaitForExit(5000) } } catch { }
        }
    }
    finally {
        try {
            if ($dashboardProcess -and $dashboardProcess.Process -and -not $dashboardProcess.Process.HasExited) {
                $dashboardProcess.Process.Kill()
                $dashboardProcess.Process.WaitForExit(5000)
            }
        } catch { }
        try { Unregister-Event -SubscriptionId $dashboardProcess.OutSub.Id -ErrorAction SilentlyContinue } catch { }
        try { Unregister-Event -SubscriptionId $dashboardProcess.ErrSub.Id -ErrorAction SilentlyContinue } catch { }
    }
}

function Test-AgentStartupClean {
    Write-TestLog "Testing agent startup for clean execution..." "Info"

    # Start dashboard server
    $dashboardProcess = Start-TestProcess -FilePath $TestConfig.DashboardPath -Arguments "-Port $($TestConfig.Port)" -TestName "Dashboard Server"

    try {
        Start-Sleep -Seconds 3

        # Start agent
        $agentProcess = Start-TestProcess -FilePath $TestConfig.AgentPath -Arguments "-LogLevel Info" -TestName "SimRacing Agent"

        try {
            # Monitor for errors during startup
            $errorsFound = $false
            $startupOutput = ""
            $startTime = Get-Date

            while ((Get-Date) -lt $startTime.AddSeconds(15)) { # 15 second startup window
                if (-not $agentProcess.Process.HasExited) {
                    try {
                        $line = $null
                        while ($agentProcess.OutQueue.TryDequeue([ref]$line)) {
                            if ($line) {
                                $startupOutput += $line + "`n"
                                # Check for specific errors (excluding dashboard connection warnings)
                                if ($line -match "\[Error\]" -and $line -notmatch "Could not connect to dashboard") {
                                    $errorsFound = $true
                                    Write-TestLog ("❌ Startup error found: {0}" -f $line) "Error"
                                }
                            }
                        }
                    }
                    catch {
                        # Continue monitoring
                    }
                }

                # Check if agent reached interactive mode
                if ($startupOutput -match "SimRacing Agent Interactive Mode") {
                    Write-TestLog "✅ Agent reached interactive mode successfully" "Success"
                    break
                }

                Start-Sleep -Seconds 1
            }

            if (-not $errorsFound) {
                Write-TestLog "✅ Clean startup test passed" "Success"
                return $true
            } else {
                Write-TestLog "❌ Startup errors detected" "Error"
                return $false
            }
        }
        finally {
            try {
                if ($agentProcess -and $agentProcess.Process -and -not $agentProcess.Process.HasExited) {
                    $agentProcess.Process.Kill()
                    $agentProcess.Process.WaitForExit(5000)
                }
            } catch { }
            try { Unregister-Event -SubscriptionId $agentProcess.OutSub.Id -ErrorAction SilentlyContinue } catch { }
            try { Unregister-Event -SubscriptionId $agentProcess.ErrSub.Id -ErrorAction SilentlyContinue } catch { }
        }
    }
    finally {
        try {
            if ($dashboardProcess -and $dashboardProcess.Process -and -not $dashboardProcess.Process.HasExited) {
                $dashboardProcess.Process.Kill()
                $dashboardProcess.Process.WaitForExit(5000)
            }
        } catch { }
        try { Unregister-Event -SubscriptionId $dashboardProcess.OutSub.Id -ErrorAction SilentlyContinue } catch { }
        try { Unregister-Event -SubscriptionId $dashboardProcess.ErrSub.Id -ErrorAction SilentlyContinue } catch { }
    }
}

function Test-DashboardConnectivity {
    Write-TestLog "Testing agent-dashboard connectivity..." "Info"

    # Start dashboard server
    $dashboardProcess = Start-TestProcess -FilePath $TestConfig.DashboardPath -Arguments "-Port $($TestConfig.Port)" -TestName "Dashboard Server"

    try {
        Start-Sleep -Seconds 3

        # Test direct connection
        try {
            $uri = "http://localhost:$($TestConfig.Port)/api/health"
            try {
                # Try HttpClient (load assembly if necessary)
                if (-not ([type]::GetType("System.Net.Http.HttpClient", $false))) {
                    try { [Reflection.Assembly]::LoadWithPartialName('System.Net.Http') | Out-Null } catch { }
                }
                $client = New-Object System.Net.Http.HttpClient
                $task = $client.GetAsync($uri)
                $task.Wait(5000)
                if (-not $task.IsCompleted) { throw "Timeout waiting for dashboard response" }
                $resp = $task.Result
                if ($resp.IsSuccessStatusCode) {
                    try { $content = $resp.Content.ReadAsStringAsync().Result } catch { $content = "" }
                    try { $dashboardLog = Join-Path $PSScriptRoot 'logs' 'dashboard-response.txt'; $content | Out-File -FilePath $dashboardLog -Encoding utf8 -Append } catch { }
                    Write-TestLog "✅ Dashboard server responding correctly" "Success"
                    return $true
                } else {
                    Write-TestLog "❌ Dashboard connectivity test failed: HTTP $($resp.StatusCode)" "Error"
                    return $false
                }
            } catch {
                # Fallback to Invoke-WebRequest with basic parsing to avoid interactive prompts
                try {
                    $response = Invoke-WebRequest -Uri $uri -Method GET -UseBasicParsing -TimeoutSec 5
                    if ($response.StatusCode -eq 200) {
                        try { $content = $response.Content } catch { $content = "" }
                        try { $dashboardLog = Join-Path $PSScriptRoot 'logs' 'dashboard-response.txt'; $content | Out-File -FilePath $dashboardLog -Encoding utf8 -Append } catch { }
                        Write-TestLog "✅ Dashboard server responding correctly (fallback)" "Success"
                        return $true
                    } else {
                        Write-TestLog "❌ Dashboard connectivity test failed (fallback): HTTP $($response.StatusCode)" "Error"
                        return $false
                    }
                } catch {
                    Write-TestLog "❌ Dashboard connectivity test failed (fallback): $($_.Exception.Message)" "Error"
                    return $false
                }
            }
        }
        catch {
            Write-TestLog "❌ Dashboard connectivity test failed: $($_.Exception.Message)" "Error"
            return $false
        }
    }
    finally {
        try {
            if ($dashboardProcess -and $dashboardProcess.Process -and -not $dashboardProcess.Process.HasExited) {
                $dashboardProcess.Process.Kill()
                $dashboardProcess.Process.WaitForExit(5000)
            }
        } catch { }
        try { Unregister-Event -SubscriptionId $dashboardProcess.OutSub.Id -ErrorAction SilentlyContinue } catch { }
        try { Unregister-Event -SubscriptionId $dashboardProcess.ErrSub.Id -ErrorAction SilentlyContinue } catch { }
    }
}

# Main test execution
Write-TestLog "Starting SimRacing Agent Automated Tests" "Info"
Write-TestLog "Test Configuration: Port $($TestConfig.Port), Duration $($TestConfig.TestDuration)s" "Info"

$testResults = @{
    HealthAlertSuppression = Test-HealthAlertSuppression
    InteractiveMode = Test-InteractiveMode
    AgentStartupClean = Test-AgentStartupClean
    DashboardConnectivity = Test-DashboardConnectivity
}

# Generate test report
Write-TestLog "=== TEST RESULTS ===" "Info"
$passedTests = 0
$totalTests = $testResults.Count

foreach ($test in $testResults.GetEnumerator()) {
    $status = if ($test.Value) { "PASS" } else { "FAIL" }
    Write-Output "  $($test.Key): $status"
    if ($test.Value) { $passedTests++ }
}

Write-TestLog "=== SUMMARY ===" "Info"
Write-TestLog "Tests Passed: $passedTests / $totalTests" $(if ($passedTests -eq $totalTests) { "Success" } else { "Warning" })

if ($passedTests -eq $totalTests) {
    Write-TestLog "✅ All tests passed! Agent is working correctly." "Success"
    exit 0
} else {
    Write-TestLog "❌ Some tests failed. Check the output above for details." "Error"
    exit 1
}



