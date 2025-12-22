# Quick Agent Validation Script
# Tests health alert suppression and basic functionality

param([int]$TestDurationSeconds = 20)

Write-Host "=== SimRacing Agent Quick Validation ===" -ForegroundColor Yellow
Write-Host "Testing for $TestDurationSeconds seconds..." -ForegroundColor Gray

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
                Write-Host "❌ CRITICAL HEALTH ALERT found!" -ForegroundColor Red
                Write-Host $outputText -ForegroundColor Gray
                break
            }
            
            # Check if agent started
            if ($outputText -match "SimRacing Agent Interactive Mode") {
                $agentStarted = $true
                Write-Host "✅ Agent started successfully" -ForegroundColor Green
            }
        }
        
        Start-Sleep -Seconds 2
    }
    
    # Final validation
    Write-Host "`n=== VALIDATION RESULTS ===" -ForegroundColor Yellow
    
    if (-not $healthAlertsFound) {
        Write-Host "✅ HEALTH ALERTS SUPPRESSED: No critical health alerts detected" -ForegroundColor Green
    } else {
        Write-Host "❌ HEALTH ALERTS PRESENT: Critical health alerts still showing" -ForegroundColor Red
    }
    
    if ($agentStarted) {
        Write-Host "✅ AGENT STARTUP: Interactive mode reached successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ AGENT STARTUP: Failed to reach interactive mode" -ForegroundColor Red
    }
    
    # Check configuration
    $config = Get-Content "agent\SimRacingAgent\Utils\agent-config.json" | ConvertFrom-Json
    $healthMonitoringEnabled = $config.HealthMonitoring.Enabled
    
    if ($healthMonitoringEnabled -eq $false) {
        Write-Host "✅ CONFIGURATION: Health monitoring properly disabled" -ForegroundColor Green
    } else {
        Write-Host "❌ CONFIGURATION: Health monitoring still enabled" -ForegroundColor Red
    }
    
    # Summary
    $allTestsPassed = (-not $healthAlertsFound) -and $agentStarted -and ($healthMonitoringEnabled -eq $false)
    
    Write-Host "`n=== SUMMARY ===" -ForegroundColor Yellow
    if ($allTestsPassed) {
        Write-Host "🎉 ALL TESTS PASSED - Agent is working correctly!" -ForegroundColor Green
        Write-Host "• Health alerts suppressed ✅" -ForegroundColor White
        Write-Host "• Agent starts cleanly ✅" -ForegroundColor White
        Write-Host "• Configuration updated ✅" -ForegroundColor White
    } else {
        Write-Host "⚠️ SOME ISSUES DETECTED - Check results above" -ForegroundColor Yellow
    }
}
finally {
    # Clean up
    Write-Host "`nStopping agent..." -ForegroundColor Gray
    Stop-Job -Job $agentJob -PassThru | Remove-Job
}

Write-Host "`nValidation completed." -ForegroundColor Yellow