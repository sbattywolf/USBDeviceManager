# Debug runner to execute Agent regression tests in-process
Import-Module (Join-Path $PSScriptRoot '..\..\agent\SimRacingAgent.Tests\shared\TestFramework.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\..\agent\SimRacingAgent.Tests\shared\AdapterStubs.psm1') -Force
. (Join-Path $PSScriptRoot '..\..\agent\SimRacingAgent.Tests\Regression\AgentRegressionTests.ps1') | Out-Null

Write-Host "Invoking Test-AgentCoreRegression()"
$result = Test-AgentCoreRegression
Write-Host "Result:"; $result | ConvertTo-Json -Depth 5

# Also run only the specific test block manually (replicate first test)
Write-Host "--- Manual legacy config load check ---"
$legacyConfig = @{ 'AgentSettings' = @{ 'Name' = 'SimRacingAgent'; 'Version'='1.0.0' }; 'MonitoringSettings' = @{ 'USBPollingInterval' = 30; 'ProcessMonitoringEnabled' = $true }; 'LoggingSettings' = @{ 'LogLevel'='Info' } }
# Mock Get-Content and Test-Path similar to test
New-Mock -CommandName "Get-Content" -MockWith { return ($legacyConfig | ConvertTo-Json -Depth 10) } -ParameterFilter @{ Path = "*agent-config.json" }
New-Mock -CommandName "Test-Path" -MockWith { $true }
$loadedConfig = Import-AgentConfiguration -ConfigPath "agent-config.json"
Write-Host "LoadedConfig JSON:"; $loadedConfig | ConvertTo-Json -Depth 10 | Write-Host
Write-Host "AgentSettings.Name=[$($loadedConfig.AgentSettings.Name)]"
Write-Host "Agent.Name=[$($loadedConfig.Agent.Name)]"
Clear-AllMocks
