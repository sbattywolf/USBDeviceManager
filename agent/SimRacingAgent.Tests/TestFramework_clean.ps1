<# Minimal TestFramework: stable, PS5.1-compatible helpers #>

$Global:TestSession = $null
$Global:MockFunctions = @{}
$Global:MockCalls = @{}
$Global:MockTimestamps = @{}
$Global:MockOrders = @{}
$Global:MockCounter = 0

function Start-TestSession { param([string]$SessionName) $Global:TestSession = @{ Name = $SessionName; Results = @(); Summary = @{ Passed = 0; Failed = 0; Skipped = 0 }; Success = $true } }

function Invoke-Test {
    param([string]$Name, [string]$Category, [scriptblock]$TestScript, [scriptblock]$Teardown)
    try {
        try { Clear-AllMocks } catch {}
        & $TestScript
        $Global:TestSession.Summary.Passed++
        $Global:TestSession.Results += @{ Name = $Name; Category = $Category; Success = $true }
        Write-Host "[PASS] $Category - $Name" -ForegroundColor Green
    } catch {
        $Global:TestSession.Summary.Failed++
        $Global:TestSession.Results += @{ Name = $Name; Category = $Category; Success = $false; Error = $_.Exception.Message }
        $Global:TestSession.Success = $false
        Write-Host "[FAIL] $Category - $Name : $($_.Exception.Message)" -ForegroundColor Red
        try {
            $tracePath = Join-Path $PSScriptRoot '..\..\..\.tmp_test_trace.txt'
            try { $keys = if ($Global:MockFunctions) { $Global:MockFunctions.Keys -join ',' } else { '<none>' } } catch { $keys = '<none>' }
            try { $orders = if ($Global:MockOrders) { ($Global:MockOrders.GetEnumerator() | ForEach-Object { "${($_.Key)}=${($_.Value)}" }) -join ',' } else { '<none>' } } catch { $orders = '<none>' }
            "$((Get-Date).ToString('o')) FAILURE $Category - $Name MockKeys=$keys MockOrders=$orders Error=$($_.Exception.Message)" | Out-File -FilePath $tracePath -Append -Encoding utf8
        } catch {}
    } finally {
        if ($Teardown) { try { & $Teardown } catch {} }
        try { Clear-AllMocks } catch {}
    }
}

function Complete-TestSession { return @{ Success = $Global:TestSession.Success; Results = $Global:TestSession.Results; Summary = $Global:TestSession.Summary } }

function Clear-AllMocks {
    try {
        if ($Global:MockFunctions) {
            foreach ($name in $Global:MockFunctions.Keys) { Remove-Item -Path ("Function:\Global\{0}" -f $name) -ErrorAction SilentlyContinue }
        }
    } catch {}
    try { $Global:MockFunctions.Clear(); $Global:MockCalls.Clear(); $Global:MockTimestamps.Clear(); $Global:MockOrders.Clear(); $Global:MockCounter = 0 } catch {}
}

function New-Mock {
    param([Parameter(Mandatory)][string]$CommandName, [Parameter(Mandatory)][scriptblock]$MockWith)
    $Global:MockFunctions[$CommandName] = $MockWith
    $Global:MockCalls[$CommandName] = 0
    $Global:MockTimestamps[$CommandName] = (Get-Date).ToUniversalTime()
    $Global:MockCounter = ($Global:MockCounter -as [int]) + 1
    $Global:MockOrders[$CommandName] = $Global:MockCounter
    try {
        $orig = $MockWith; $cmd = $CommandName
        $wrapper = ( { param($args) try { $Global:MockCalls[$cmd] = ($Global:MockCalls[$cmd] -as [int]) + 1 ; return & $orig @Args } catch { throw } } ).GetNewClosure()
        New-Item -Path ("Function:\Global\{0}" -f $cmd) -Value $wrapper -Force | Out-Null
    } catch {}
}

function Remove-Mock { param([Parameter(Mandatory)][string]$CommandName) try { if ($Global:MockFunctions.ContainsKey($CommandName)) { $Global:MockFunctions.Remove($CommandName) | Out-Null } ; Remove-Item -Path ("Function:\Global\{0}" -f $CommandName) -ErrorAction SilentlyContinue ; return $true } catch { return $false } }

function Assert-MockCalled { param([string]$CommandName,[int]$Times = 1,[string]$Message = "") $count = ($Global:MockCalls[$CommandName] -as [int]) ; if ($count -lt $Times) { throw "Mock $CommandName was not called expected times. $Message" } }
function Assert-NotNull { param($Value,$Message) if ($null -eq $Value) { throw $Message } }
function Assert-True { param($Condition,$Message) if (-not $Condition) { throw $Message } }
function Assert-False { param($Condition,$Message) if ($Condition) { throw $Message } }
function Assert-Equal { param($Expected,$Actual,$Message) if ($Expected -ne $Actual) { throw "$Message (expected: $Expected, actual: $Actual)" } }
function Assert-PathExists { param([string]$Path,$Message) if (-not (Test-Path $Path)) { throw $Message } }
function Assert-Contains { param($Collection,$Item,$Message) if ($Collection -is [string]) { if ($Collection -notlike "*${Item}*") { throw $Message } } else { if (-not ($Collection -contains $Item)) { throw $Message } } }

# Expose helpers to global function table for dot-sourced test scripts
$globalFuncs = @('Start-TestSession','Invoke-Test','Complete-TestSession','Clear-AllMocks','New-Mock','Remove-Mock','Assert-MockCalled','Assert-NotNull','Assert-True','Assert-False','Assert-Equal','Assert-PathExists','Assert-Contains')
foreach ($n in $globalFuncs) { try { $cmd = Get-Command -Name $n -ErrorAction SilentlyContinue ; if ($cmd -and $cmd.ScriptBlock) { New-Item -Path ("Function:\Global\{0}" -f $n) -Value $cmd.ScriptBlock -Force | Out-Null } } catch {} }

# Best-effort import of AdapterStubs if present
$adapter = Join-Path $PSScriptRoot 'AdapterStubs.psm1'
if (Test-Path $adapter) { try { Import-Module $adapter -Force -ErrorAction SilentlyContinue ; Write-Host "DEBUG: AdapterStubs imported from $adapter" } catch { Write-Host "DEBUG: AdapterStubs import failed: $($_.Exception.Message)" -ForegroundColor Yellow } } else { Write-Host "DEBUG: AdapterStubs not found at $adapter" -ForegroundColor Yellow }

Export-ModuleMember -Function *
