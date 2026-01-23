. "$PSScriptRoot\SimRacingAgent.Tests\shared\TestFramework.psm1"
$AgentPath = "$PSScriptRoot\.."
Import-Module (Join-Path $AgentPath 'src\core\ConfigManager.psm1') -Force -ErrorAction SilentlyContinue
Import-Module (Join-Path $AgentPath 'src\core\AgentCore.psm1') -Force -ErrorAction SilentlyContinue

New-Mock -CommandName "Test-Path" -MockWith { $true }
New-Mock -CommandName "Get-Process" -MockWith { return @(@{ ProcessName = "powershell"; WorkingSet = 50MB; Id = $PID }) }

$config = Get-DefaultConfiguration
$status = Get-AgentStatus -Config $config
Write-Host "Status type: $($status.GetType().FullName)"
Write-Host "Has ContainsKey member? $(($status.PSObject.Members.Match('ContainsKey').Count))"
try { Write-Host "ContainsKey('AgentRunning') => $($status.ContainsKey('AgentRunning'))" } catch { Write-Host "ContainsKey call failed: $($_.Exception.Message)" }
Write-Host "Members: $($status.PSObject.Properties.Name -join ',')"
