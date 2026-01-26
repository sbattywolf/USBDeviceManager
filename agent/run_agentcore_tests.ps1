$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = Join-Path $scriptRoot 'SimRacingAgent.Tests\Unit\AgentCoreTests.ps1'
Import-Module $modulePath -Force
$res = Invoke-AgentCoreTests -StopOnFirstFailure
Write-Host '--- JSON RESULT ---'
$res | ConvertTo-Json -Depth 5
