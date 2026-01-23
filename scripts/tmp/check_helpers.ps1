$names = @('Start-TestSession','New-Mock','Assert-NotNull','Get-DefaultConfiguration','Test-Configuration','Set-AgentLock','Get-AgentStatus','Write-AgentLog')
foreach ($n in $names) {
    $exists = Get-Command -Name $n -ErrorAction SilentlyContinue
    $inGet = if ($exists) { $true } else { $false }
    $inGlobal = Test-Path ("Function:\Global\$n")
    Write-Host "$n : InGetCommand=$inGet ; InFunctionGlobal=$inGlobal"
}
