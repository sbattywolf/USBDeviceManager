Push-Location "e:\Workspaces\Git\SimRacing\USBDeviceManager\agent\SimRacingAgent.Tests\Unit"
. .\AgentMonitoringTests.ps1
$res = Invoke-AgentMonitoringTests
Write-Output '---AGENT_TEST_RESULT---'
$res | ConvertTo-Json -Depth 6
if ($res.Success) { exit 0 } else { exit 1 }
Pop-Location
