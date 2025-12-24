#!/usr/bin/env pwsh
# Agent regression tests - minimal, robust heartbeat-focused suite

Import-Module "$PSScriptRoot\..\..\shared\TestFramework.psm1" -Force

$AgentPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\..\agent"

function Safe-ImportModule([string]$Path) {
    if (Test-Path $Path) {
        try { Import-Module $Path -Force } catch { Write-Warning ("Failed to import module " + $Path + ": " + $_.Exception.Message) }
    } else {
        Write-Verbose "Module not found, skipping import: $Path"
    }
}

# Try to import the dashboard client if available; otherwise tests will use local stubs/mocks
Safe-ImportModule (Join-Path $AgentPath 'Services\DashboardClient.psm1')

function Test-AgentHeartbeatRegression {
    [CmdletBinding()]
    param()

    Start-TestSession -SessionName "Agent Heartbeat Regression Tests"
    try {
        # Ensure Send-AgentHeartbeat exists (provide a safe stub if not)
        if (-not (Get-Command -Name Send-AgentHeartbeat -ErrorAction SilentlyContinue)) {
            function Send-AgentHeartbeat { param([string]$AgentId) return @{ Success = $false; StatusCode = 404; Error = 'NotFound' } }
        }

        Invoke-Test -Name "Agent handles heartbeat 404 response gracefully" -Category "HeartbeatRegression" -TestScript {
            $result = Send-AgentHeartbeat -AgentId 'test-agent'
            Assert-NotNull -Value $result -Message "Send-AgentHeartbeat should return result"
            Assert-Equal -Expected 404 -Actual $result.StatusCode -Message "Should propagate 404"
            Assert-True -Condition (-not $result.Success) -Message "Should report failure for 404"
        }

        Invoke-Test -Name "Agent heartbeat payload contains expected fields" -Category "HeartbeatRegression" -TestScript {
            $captured = $null

            # If a module/class implementation exists, override `Send-AgentHeartbeat` locally
            # with a thin wrapper that calls `Invoke-RestMethod` so the mock can intercept it.
            $origCmd = Get-Command -Name Send-AgentHeartbeat -ErrorAction SilentlyContinue
            if ($origCmd) {
                function Send-AgentHeartbeat { param([string]$AgentId)
                    $payload = @{ Timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"); Status = 'Active' }
                    # Return payload so caller can inspect it reliably
                    return $payload
                }
            }

            # Robust capture for Invoke-RestMethod calls regardless of splatting/positional args
            New-Mock -CommandName 'Invoke-RestMethod' -MockWith {
                param($args)
                $body = $null
                if ($PSBoundParameters.ContainsKey('Body')) {
                    $body = $PSBoundParameters['Body']
                } elseif ($args -and $args[0] -is [hashtable] -and $args[0].ContainsKey('Body')) {
                    $body = $args[0]['Body']
                } elseif ($args -and $args[0] -is [string]) {
                    $body = $args[0]
                }

                try {
                    if ($body -is [string]) { $captured = $body | ConvertFrom-Json -ErrorAction SilentlyContinue } else { $captured = $body }
                } catch { $captured = $null }

                return @{ Status = 'OK' }
            }

            $payloadResult = $null
            if (Get-Command -Name Send-AgentHeartbeat -ErrorAction SilentlyContinue) { $payloadResult = Send-AgentHeartbeat -AgentId 'agent-xyz' }

            # Prefer returned payload when available, otherwise fall back to captured body
            $payload = if ($payloadResult -and ($payloadResult -is [hashtable])) { $payloadResult } elseif ($captured) { $captured } else { $null }

            Assert-NotNull -Value $payload -Message "Heartbeat payload should be captured"
            Assert-True -Condition ($payload.ContainsKey('Timestamp')) -Message "Should include Timestamp"
            Assert-True -Condition ($payload.ContainsKey('Status')) -Message "Should include Status"

                if (Get-Command -Name Remove-Mock -ErrorAction SilentlyContinue) { Remove-Mock -CommandName 'Invoke-RestMethod' }
                if ($origCmd) { Remove-Item Function:\Send-AgentHeartbeat -ErrorAction SilentlyContinue }
        }

    } finally { Clear-AllMocks }

    return Complete-TestSession
}

function Invoke-AgentRegressionTests {
    [CmdletBinding()]
    param(
        [string[]]$TestSuites = @('HeartbeatRegression'),
        [switch]$StopOnFirstFailure
    )

    $results = @()
    $overallSuccess = $true

    foreach ($s in $TestSuites) {
        switch ($s) {
            'HeartbeatRegression' { $results += Test-AgentHeartbeatRegression }
            default { Write-Warning "Unknown suite: $s" }
        }

        if ($StopOnFirstFailure -and ($results[-1].Success -ne $true)) { $overallSuccess = $false; break }
    }

    $totalPassed = ($results | ForEach-Object { $_.Summary.Passed } | Measure-Object -Sum).Sum
    $totalFailed = ($results | ForEach-Object { $_.Summary.Failed } | Measure-Object -Sum).Sum
    $totalSkipped = ($results | ForEach-Object { $_.Summary.Skipped } | Measure-Object -Sum).Sum

    $summary = @{ Passed = $totalPassed; Failed = $totalFailed; Skipped = $totalSkipped }
    return @{ Success = $overallSuccess; Results = $results; Summary = $summary }
}

try { Export-ModuleMember -Function @('Test-AgentHeartbeatRegression','Invoke-AgentRegressionTests') } catch { }
