$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = Join-Path $ScriptRoot 'SimRacingAgent.Tests\shared\AdapterStubs.psm1'
if (Test-Path $modulePath) {
	Import-Module $modulePath -Force -ErrorAction SilentlyContinue
} else {
	Write-Host "DEBUG: AdapterStubs not found at $modulePath" -ForegroundColor Yellow
}

$o = [PSCustomObject]@{A=1}
Add-ContainsKeyMethod $o
Write-Host "Members count: $($o.PSObject.Members.Match('ContainsKey').Count)"
try { Write-Host "ContainsKey('A') => $($o.ContainsKey('A'))" } catch { Write-Host "ContainsKey failed: $($_.Exception.Message)" }
