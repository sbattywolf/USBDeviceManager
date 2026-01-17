. "E:\Workspaces\Git\SimRacing\USBDeviceManager\agent\SimRacingAgent.Tests\Regression\AgentRegressionTests.ps1"
Write-Output "Invoking Test-AgentHeartbeatRegression()..."
$r = Test-AgentHeartbeatRegression
Write-Output "=== Result object ==="
$r | Format-List * -Force
Write-Output "=== End ==="




