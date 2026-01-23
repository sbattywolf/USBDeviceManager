# Minimal inline test helpers so test scripts can run without loading external TestFramework
$Global:TestSession = $null
function Start-TestSession { param([string]$SessionName) $Global:TestSession = @{ Name = $SessionName; Results = @(); Summary = @{ Passed = 0; Failed = 0; Skipped = 0 }; Success = $true } }
function Invoke-Test { param([string]$Name,[string]$Category,[scriptblock]$TestScript,[scriptblock]$Teardown) try { try { Clear-AllMocks } catch {} ; & $TestScript ; $Global:TestSession.Summary.Passed++ ; $Global:TestSession.Results += @{ Name = $Name; Category = $Category; Success = $true } ; Write-Host "[PASS] $Category - $Name" -ForegroundColor Green } catch { $Global:TestSession.Summary.Failed++ ; $Global:TestSession.Results += @{ Name = $Name; Category = $Category; Success = $false; Error = $_.Exception.Message } ; $Global:TestSession.Success = $false ; Write-Host "[FAIL] $Category - $Name : $($_.Exception.Message)" -ForegroundColor Red } finally { if ($Teardown) { try { & $Teardown } catch {} } ; try { Clear-AllMocks } catch {} } }
function Complete-TestSession { return @{ Success = $Global:TestSession.Success; Results = $Global:TestSession.Results; Summary = $Global:TestSession.Summary } }
function Clear-AllMocks { try { foreach ($name in $Global:MockFunctions.Keys) { Remove-Item -Path ("function:\Global\$name") -ErrorAction SilentlyContinue } } catch {} ; $Global:MockFunctions.Clear(); $Global:MockCalls.Clear(); $Global:MockTimestamps.Clear(); $Global:MockOrders.Clear(); $Global:MockCounter = 0 }
function New-Mock { param([string]$CommandName,[scriptblock]$MockWith) $Global:MockFunctions[$CommandName] = $MockWith ; $Global:MockCalls[$CommandName] = 0 ; $Global:MockTimestamps[$CommandName] = (Get-Date).ToUniversalTime() ; $Global:MockCounter = ($Global:MockCounter -as [int]) + 1 ; $Global:MockOrders[$CommandName] = $Global:MockCounter ; try { $orig = $MockWith; $cmd = $CommandName ; $wrapper = ( { param($args) $Global:MockCalls[$cmd] = ($Global:MockCalls[$cmd] -as [int]) + 1 ; return & $orig @Args } ).GetNewClosure() ; New-Item -Path ("Function:\Global\{0}" -f $cmd) -Value $wrapper -Force | Out-Null } catch {} }
function Remove-Mock { param([string]$CommandName) try { if ($Global:MockFunctions.ContainsKey($CommandName)) { $Global:MockFunctions.Remove($CommandName) | Out-Null } ; Remove-Item -Path ("Function:\Global\{0}" -f $CommandName) -ErrorAction SilentlyContinue ; return $true } catch { return $false } }
function Assert-MockCalled { param([string]$CommandName,[int]$Times=1,[string]$Message="") $count = $Global:MockCalls[$CommandName] -as [int]; if ($count -lt $Times) { throw "Mock $CommandName was not called expected times. $Message" } }
function Assert-NotNull { param($Value,$Message) if ($null -eq $Value) { throw $Message } }
function Assert-True { param($Condition,$Message) if (-not $Condition) { throw $Message } }
function Assert-False { param($Condition,$Message) if ($Condition) { throw $Message } }
function Assert-Equal { param($Expected,$Actual,$Message) if ($Expected -ne $Actual) { throw "$Message (expected: $Expected, actual: $Actual)" } }
function Assert-PathExists { param([string]$Path,$Message) if (-not (Test-Path $Path)) { throw $Message } }
function Assert-Contains { param($Collection,$Item,$Message) if ($Collection -is [string]) { if ($Collection -notlike "*${Item}*") { throw $Message } } else { if (-not ($Collection -contains $Item)) { throw $Message } } }

try {
    # Stub Export-ModuleMember to allow dot-sourcing scripts that call it
    if (-not (Get-Command -Name Export-ModuleMember -CommandType Function -ErrorAction SilentlyContinue)) {
        New-Item -Path Function:\Export-ModuleMember -Value { param($args) } -Force | Out-Null
        $createdExportStub = $true
    } else { $createdExportStub = $false }

    # Ensure AdapterStubs functions are available as global functions (tests expect unqualified calls)
    $adapterPath = (Join-Path $PSScriptRoot '..\..\agent\SimRacingAgent.Tests\shared\AdapterStubs.psm1')
    if (Test-Path $adapterPath) {
        try { Import-Module $adapterPath -Force -ErrorAction SilentlyContinue } catch {}
        $needed = @('Get-DefaultConfiguration','Test-Configuration','Save-Configuration','Load-Configuration','Export-Configuration','Test-AgentRunning','Set-AgentLock','Clear-AgentLock','Write-AgentLog','Get-AgentStatus')
        foreach ($n in $needed) {
            $c = Get-Command -Name $n -ErrorAction SilentlyContinue
            if ($c -and $c.ScriptBlock) { New-Item -Path ("Function:\Global\{0}" -f $n) -Value $c.ScriptBlock -Force | Out-Null }
        }
        try { if (Get-Command -Name Get-DefaultConfiguration -ErrorAction SilentlyContinue) { Write-Host 'Diagnostic: Get-DefaultConfiguration FOUND' } else { Write-Host 'Diagnostic: Get-DefaultConfiguration MISSING' } } catch {}
    }

    try { . (Join-Path $PSScriptRoot '..\..\agent\SimRacingAgent.Tests\Unit\AgentCoreTests.ps1') -ErrorAction Stop ; Write-Host 'Dot-sourced AgentCoreTests OK' } catch { Write-Host 'Dot-source failed:' $_.Exception.Message }
} finally {
    if ($createdStub) { Remove-Item -Path Function:\Import-Module -ErrorAction SilentlyContinue }
    if ($createdExportStub) { Remove-Item -Path Function:\Export-ModuleMember -ErrorAction SilentlyContinue }
}
Write-Host '--- Running Invoke-AgentCoreTests ---'
Write-Host 'Diagnostic: Start-TestSession presence:'
try {
    $cmd = Get-Command -Name Start-TestSession -ErrorAction Stop
    Write-Host "Found: $($cmd.Name) Type=$($cmd.CommandType) Source=$($cmd.Source)" 
} catch { Write-Host 'Start-TestSession NOT FOUND' }
try {
    $r = Invoke-AgentCoreTests -ErrorAction Stop
    Write-Host 'Invoker returned:'
    $r | ConvertTo-Json -Depth 6
} catch {
    Write-Host 'ERROR MESSAGE:' $_.Exception.Message
    Write-Host 'ERROR TYPE:' ($_.Exception.GetType().FullName)
    Write-Host 'STACK:'
    Write-Host $_.Exception.StackTrace
    if ($_.Exception.InnerException) {
        Write-Host 'INNER MESSAGE:' $_.Exception.InnerException.Message
        Write-Host 'INNER STACK:'
        Write-Host $_.Exception.InnerException.StackTrace
    }
    exit 2
}
Write-Host '--- Done ---'