Import-Module 'E:/Workspaces/Git/SimRacing/USBDeviceManager/agent/SimRacingAgent.Tests/Unit/AgentCoreTests.ps1' -Force
$res = Invoke-AgentCoreTests -StopOnFirstFailure
Write-Host '--- JSON RESULT ---'
$res | ConvertTo-Json -Depth 5
