param(
    [string]$File = "agent/SimRacingAgent.Tests/TestRunner.ps1"
)
$i = 1
Get-Content -LiteralPath $File | ForEach-Object {
    '{0:000} {1}' -f $i, $_
    $i++
}
