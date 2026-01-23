# Quick Agent Validation Script
# Tests health alert suppression and basic functionality

param([int]$TestDurationSeconds = 20)

Write-Output "=== SimRacing Agent Quick Validation ==="
Write-Output "Testing for $TestDurationSeconds seconds..."

# Start agent in background and capture output
$agentJob = Start-Job -ScriptBlock {
    param($AgentPath)
    & powershell.exe -ExecutionPolicy Bypass -File $AgentPath -LogLevel Info
} -ArgumentList "agent\SimRacingAgent\SimRacingAgent.ps1"

try {
    # Wait and monitor for health alerts
    $healthAlertsFound = $false
    $agentStarted = $false
    $startTime = Get-Date

    while ((Get-Date) -lt $startTime.AddSeconds($TestDurationSeconds)) {
        # Check job output
        $jobOutput = Receive-Job -Job $agentJob -Keep
        if ($jobOutput) {
            $outputText = $jobOutput -join "`n"

            # Check for health alerts
            if ($outputText -match "CRITICAL HEALTH ALERT") {
                $healthAlertsFound = $true
                Write-Error "❌ CRITICAL HEALTH ALERT found!"
                Write-Output $outputText
                break
            }

            # Check if agent started
            if ($outputText -match "SimRacing Agent Interactive Mode") {
                $agentStarted = $true
                Write-Output "✅ Agent started successfully"
            }
        }

        Start-Sleep -Seconds 2
    }

    # Final validation
    Write-Output "`n=== VALIDATION RESULTS ==="

    if (-not $healthAlertsFound) {
        Write-Output "✅ HEALTH ALERTS SUPPRESSED: No critical health alerts detected"
    } else {
        Write-Error "❌ HEALTH ALERTS PRESENT: Critical health alerts still showing"
    }

    if ($agentStarted) {
        Write-Output "✅ AGENT STARTUP: Interactive mode reached successfully"
    } else {
        Write-Error "❌ AGENT STARTUP: Failed to reach interactive mode"
    }

    # Check configuration
    $config = Get-Content "agent\SimRacingAgent\Utils\agent-config.json" | ConvertFrom-Json
    $healthMonitoringEnabled = $config.HealthMonitoring.Enabled

    if ($healthMonitoringEnabled -eq $false) {
        Write-Output "✅ CONFIGURATION: Health monitoring properly disabled"
    } else {
        Write-Error "❌ CONFIGURATION: Health monitoring still enabled"
    }

    # Summary
    $allTestsPassed = (-not $healthAlertsFound) -and $agentStarted -and ($healthMonitoringEnabled -eq $false)

    Write-Output "`n=== SUMMARY ==="
    if ($allTestsPassed) {
        Write-Output "🎉 ALL TESTS PASSED - Agent is working correctly!"
        Write-Output "• Health alerts suppressed ✅"
        Write-Output "• Agent starts cleanly ✅"
        Write-Output "• Configuration updated ✅"
    } else {
        Write-Warning "⚠️ SOME ISSUES DETECTED - Check results above"
    }
}
finally {
    # Clean up
    Write-Output "`nStopping agent..."
    Stop-Job -Job $agentJob -PassThru | Remove-Job
}

Write-Output "`nValidation completed."



