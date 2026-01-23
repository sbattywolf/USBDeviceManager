Import-Module (Join-Path $PSScriptRoot '..\..\agent\SimRacingAgent.Tests\shared\AdapterStubs.psm1') -Force
$temp = (Join-Path $PSScriptRoot 'legacy_test_config.json')
$legacy = @{
    'AgentSettings' = @{ 'Name' = 'SimRacingAgent'; 'Version'='1.0.0' }
    'MonitoringSettings' = @{ 'USBPollingInterval' = 30; 'ProcessMonitoringEnabled' = $true }
    'LoggingSettings' = @{ 'LogLevel'='Info' }
}
$legacy | ConvertTo-Json -Depth 10 | Set-Content -Path $temp -Encoding UTF8
Write-Host "Wrote temp config: $temp"
$res = Import-AgentConfiguration -ConfigPath $temp
Write-Host 'Imported object JSON:'
$res | ConvertTo-Json -Depth 10 | Write-Host
Write-Host "AgentSettings exists? $($res.PSObject.Properties.Name -contains 'AgentSettings')"
if ($res.PSObject.Properties.Name -contains 'AgentSettings') { Write-Host "AgentSettings.Name=[$($res.AgentSettings.Name)]" } else { Write-Host 'No AgentSettings' }
if ($res.PSObject.Properties.Name -contains 'Agent') { Write-Host "Agent.Name=[$($res.Agent.Name)]" } else { Write-Host 'No Agent' }
