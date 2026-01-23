Import-Module 'e:\Workspaces\Git\SimRacing\USBDeviceManager\agent\SimRacingAgent.Tests\shared\AdapterStubs.psm1' -Force
$o = [PSCustomObject]@{A=1}
Add-ContainsKeyMethod $o
Write-Host "Members count: $($o.PSObject.Members.Match('ContainsKey').Count)"
try { Write-Host "ContainsKey('A') => $($o.ContainsKey('A'))" } catch { Write-Host "ContainsKey failed: $($_.Exception.Message)" }
