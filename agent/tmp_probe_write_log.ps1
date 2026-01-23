Import-Module 'e:\Workspaces\Git\SimRacing\USBDeviceManager\agent\SimRacingAgent.Tests\shared\AdapterStubs.psm1' -Force
$p = Join-Path $env:TEMP 'test_agent.log'
if (Test-Path $p) { Remove-Item $p -Force }
Write-AgentLog -Message 'Probe' -Level 'Info' -Component 'Probe' -LogPath $p
Write-Host "Exists: $(Test-Path $p)"
if (Test-Path $p) { Write-Host "Content:"; Get-Content $p -Raw }
