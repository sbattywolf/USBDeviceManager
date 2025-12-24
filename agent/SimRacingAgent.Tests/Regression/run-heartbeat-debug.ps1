. "E:\Workspaces\Git\SimRacing\USBDeviceManager\agent\SimRacingAgent.Tests\Regression\AgentRegressionTests.ps1"
Write-Host "Invoking Test-AgentHeartbeatRegression()..." -ForegroundColor Cyan
$r = Test-AgentHeartbeatRegression
Write-Host "=== Result object ===" -ForegroundColor Cyan
$r | Format-List * -Force
Write-Host "=== End ===" -ForegroundColor Cyan
