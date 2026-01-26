$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = Join-Path $ScriptRoot 'SimRacingAgent.Tests\shared\AdapterStubs.psm1'
if (Test-Path $modulePath) {
	Import-Module $modulePath -Force -ErrorAction SilentlyContinue
} else {
	Write-Host "DEBUG: AdapterStubs not found at $modulePath" -ForegroundColor Yellow
}

$p = Join-Path $env:TEMP 'test_agent.log'
if (Test-Path $p) { Remove-Item $p -Force }
Write-AgentLog -Message 'Probe' -Level 'Info' -Component 'Probe' -LogPath $p
Write-Host "Exists: $(Test-Path $p)"
if (Test-Path $p) { Write-Host "Content:"; Get-Content $p -Raw }
