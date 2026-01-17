Push-Location 'E:\Workspaces\Git\SimRacing\USBDeviceManager\agent\SimRacingAgent.Tests\Unit'
. .\AgentMonitoringTests.ps1
$res = Invoke-AgentMonitoringTests
if ($res -and $res.Success) { Write-Host 'Unit tests passed.'; $rc = 0 } else { Write-Host 'Unit tests failed.'; $rc = 1 }
Pop-Location
exit $rc
