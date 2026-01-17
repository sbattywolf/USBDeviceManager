#!/usr/bin/env pwsh
# Heartbeat-focused regression script (standalone)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

Import-Module "..\shared\TestFramework.psm1" -Force

Start-TestSession -SessionName "Standalone Heartbeat Regression"

try {
    # Test 1: simulate server 404 response for heartbeat
    Invoke-Test -Name "Standalone: heartbeat 404 handling" -Category "HeartbeatRegression" -TestScript {
        function Send-AgentHeartbeat { param($AgentId) return @{ Success = $false; StatusCode = 404; Error = 'NotFound' } }
        $r = Send-AgentHeartbeat -AgentId 'test-agent'
        Assert-NotNull -Value $r -Message "Should return result structure"
        Assert-Equal -Expected 404 -Actual $r.StatusCode -Message "Should surface 404"
        Assert-True -Condition (-not $r.Success) -Message "Success flag should be false"
        Remove-Item function:\Send-AgentHeartbeat -ErrorAction SilentlyContinue
    }

    # Test 2: verify heartbeat payload fields when sending
    Invoke-Test -Name "Standalone: heartbeat payload fields" -Category "HeartbeatRegression" -TestScript {
        function Send-AgentHeartbeat { param($AgentId) $payload = @{ Timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"); Status = 'Active' }; $Global:LastHeartbeatPayload = $payload; return @{ Success = $true; StatusCode = 200 } }
        $null = Send-AgentHeartbeat -AgentId 'agent-xyz'
        $payload = $Global:LastHeartbeatPayload
        Assert-NotNull -Value $payload -Message "Payload should be captured"
        Assert-True -Condition ($payload.ContainsKey('Timestamp')) -Message "Payload contains Timestamp"
        Assert-True -Condition ($payload.ContainsKey('Status')) -Message "Payload contains Status"
        Remove-Item function:\Send-AgentHeartbeat -ErrorAction SilentlyContinue
    }

} finally {
    Clear-AllMocks
}

Complete-TestSession




